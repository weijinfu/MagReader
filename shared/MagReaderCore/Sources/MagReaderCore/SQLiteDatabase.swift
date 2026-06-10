import Foundation
import SQLite3

@MainActor
protocol DatabaseClient: AnyObject {
    func listFeeds() throws -> [Feed]
    func createFeed(title: String?, url: String) throws
    func updateFeed(_ id: Int64, title: String?, url: String?, enabled: Bool?, siteUrl: String?, lastFetchedAt: Date?, lastError: String?) throws
    func deleteFeed(_ id: Int64) throws

    func listArticles() throws -> [Article]
    func getArticle(_ id: Int64) throws -> Article?
    func upsertArticle(_ input: ArticleUpsert) throws
    func archiveMissingFeedArticles(feedId: Int64, currentUrls: [String]) throws -> Int
    func markArticle(_ id: Int64, status: ArticleStatus) throws

    func saveWord(word: String, displayWord: String, translation: String, meanings: [WordMeaning], explanation: String, sourceSentence: String?, articleId: Int64?) throws -> [SavedWord]
    func updateSavedWordMeanings(_ id: Int64, meanings: [WordMeaning]) throws -> [SavedWord]
    func saveSentence(text: String, translation: String, explanation: String, articleId: Int64?) throws -> [SavedSentence]
    func listSavedWords() throws -> [SavedWord]
    func listSavedSentences() throws -> [SavedSentence]
    func updateReview(kind: LearningKind, id: Int64, familiarity: Familiarity) throws
    func deleteSavedWord(_ id: Int64) throws -> [SavedWord]
    func deleteSavedSentence(_ id: Int64) throws -> [SavedSentence]

    func getSettings() throws -> ReaderSettings
    func saveSettings(_ settings: ReaderSettings) throws -> ReaderSettings
    func logIngestion(feedId: Int64, status: String, message: String) throws
}

@MainActor
final class SQLiteDatabase: DatabaseClient {
    private nonisolated(unsafe) let handle: OpaquePointer?
    private let path: String
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: String) throws {
        self.path = path
        var database: OpaquePointer?
        guard sqlite3_open(path, &database) == SQLITE_OK else {
            throw MagReaderError.database("Could not open SQLite database.")
        }
        handle = database
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
        try migrate()
    }

    deinit {
        sqlite3_close(handle)
    }

    static func `default`() throws -> SQLiteDatabase {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appending(path: "MagReader", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try SQLiteDatabase(path: directory.appending(path: "magreader-ios.db").path)
    }

    func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS feeds (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          url TEXT NOT NULL UNIQUE,
          site_url TEXT,
          enabled INTEGER NOT NULL DEFAULT 1,
          last_fetched_at TEXT,
          last_error TEXT,
          created_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS articles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          feed_id INTEGER REFERENCES feeds(id) ON DELETE SET NULL,
          guid TEXT,
          url TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          author TEXT,
          published_at TEXT,
          excerpt TEXT,
          content_html TEXT NOT NULL,
          content_text TEXT NOT NULL,
          difficulty TEXT NOT NULL DEFAULT 'B2',
          status TEXT NOT NULL DEFAULT 'unread',
          favorite INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS saved_words (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT NOT NULL UNIQUE,
          display_word TEXT NOT NULL,
          translation TEXT NOT NULL,
          meanings_json TEXT NOT NULL DEFAULT '[]',
          explanation TEXT NOT NULL,
          source_sentence TEXT,
          article_id INTEGER REFERENCES articles(id) ON DELETE SET NULL,
          familiarity TEXT NOT NULL DEFAULT 'new',
          count INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS saved_sentences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          text TEXT NOT NULL UNIQUE,
          translation TEXT NOT NULL,
          explanation TEXT NOT NULL,
          article_id INTEGER REFERENCES articles(id) ON DELETE SET NULL,
          familiarity TEXT NOT NULL DEFAULT 'new',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS ingestion_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          feed_id INTEGER REFERENCES feeds(id) ON DELETE CASCADE,
          status TEXT NOT NULL,
          message TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
        """)
        try addColumnIfNeeded(table: "saved_words", column: "meanings_json", definition: "TEXT NOT NULL DEFAULT '[]'")
    }

    func listFeeds() throws -> [Feed] {
        try query("SELECT * FROM feeds ORDER BY created_at DESC", mapFeed)
    }

    func createFeed(title: String?, url: String) throws {
        guard let parsedURL = URL(string: url), let host = parsedURL.host else { throw MagReaderError.invalidURL }
        try run(
            "INSERT INTO feeds (title, url, enabled, created_at) VALUES (?, ?, 1, ?)",
            [title?.nilIfBlank ?? host, url, encodeDate(now())]
        )
    }

    func updateFeed(_ id: Int64, title: String?, url: String?, enabled: Bool?, siteUrl: String?, lastFetchedAt: Date?, lastError: String?) throws {
        guard let existing = try query("SELECT * FROM feeds WHERE id = ?", [id], mapFeed).first else {
            throw MagReaderError.database("Feed not found.")
        }
        try run(
            "UPDATE feeds SET title = ?, url = ?, site_url = ?, enabled = ?, last_fetched_at = ?, last_error = ? WHERE id = ?",
            [
                title ?? existing.title,
                url ?? existing.url,
                siteUrl ?? existing.siteUrl,
                (enabled ?? existing.enabled) ? 1 : 0,
                encodeDate(lastFetchedAt ?? existing.lastFetchedAt),
                lastError ?? existing.lastError,
                id
            ]
        )
    }

    func deleteFeed(_ id: Int64) throws {
        try run("DELETE FROM feeds WHERE id = ?", [id])
    }

    func listArticles() throws -> [Article] {
        _ = try clearUnsubscribedArticles()
        return try query(
            """
            SELECT articles.*, feeds.title AS feed_title
            FROM articles
            INNER JOIN feeds ON feeds.id = articles.feed_id
            WHERE articles.status != 'archived'
            ORDER BY COALESCE(articles.published_at, articles.created_at) DESC
            """,
            mapArticle
        )
    }

    func getArticle(_ id: Int64) throws -> Article? {
        try query(
            """
            SELECT articles.*, feeds.title AS feed_title
            FROM articles
            LEFT JOIN feeds ON feeds.id = articles.feed_id
            WHERE articles.id = ?
            """,
            [id],
            mapArticle
        ).first
    }

    func upsertArticle(_ input: ArticleUpsert) throws {
        let timestamp = encodeDate(now())
        try run(
            """
            INSERT INTO articles
            (feed_id, guid, url, title, author, published_at, excerpt, content_html, content_text, difficulty, status, favorite, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unread', 0, ?, ?)
            ON CONFLICT(url) DO UPDATE SET
              title = excluded.title,
              feed_id = excluded.feed_id,
              guid = excluded.guid,
              author = excluded.author,
              published_at = excluded.published_at,
              excerpt = excluded.excerpt,
              content_html = excluded.content_html,
              content_text = excluded.content_text,
              difficulty = excluded.difficulty,
              status = CASE WHEN articles.status = 'archived' THEN 'unread' ELSE articles.status END,
              updated_at = excluded.updated_at
            """,
            [
                input.feedId,
                input.guid,
                input.url,
                input.title,
                input.author,
                encodeDate(input.publishedAt),
                input.excerpt,
                input.contentHtml,
                input.contentText,
                input.difficulty,
                timestamp,
                timestamp
            ]
        )
    }

    func archiveMissingFeedArticles(feedId: Int64, currentUrls: [String]) throws -> Int {
        let timestamp = encodeDate(now())
        if currentUrls.isEmpty {
            return try run("UPDATE articles SET status = 'archived', updated_at = ? WHERE feed_id = ? AND status != 'archived'", [timestamp, feedId])
        }
        let placeholders = Array(repeating: "?", count: currentUrls.count).joined(separator: ",")
        var values: [Any?] = [timestamp, feedId]
        values.append(contentsOf: currentUrls)
        return try run("UPDATE articles SET status = 'archived', updated_at = ? WHERE feed_id = ? AND status != 'archived' AND url NOT IN (\(placeholders))", values)
    }

    func markArticle(_ id: Int64, status: ArticleStatus) throws {
        try run("UPDATE articles SET status = ?, updated_at = ? WHERE id = ?", [status.rawValue, encodeDate(now()), id])
    }

    func saveWord(word: String, displayWord: String, translation: String, meanings: [WordMeaning], explanation: String, sourceSentence: String?, articleId: Int64?) throws -> [SavedWord] {
        let cleanWord = normalizedWord(word)
        let timestamp = encodeDate(now())
        let meaningsJSON = encodeMeanings(meanings)
        try run(
            """
            INSERT INTO saved_words
            (word, display_word, translation, meanings_json, explanation, source_sentence, article_id, familiarity, count, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'new', 1, ?, ?)
            ON CONFLICT(word) DO UPDATE SET
              display_word = excluded.display_word,
              translation = excluded.translation,
              meanings_json = CASE WHEN excluded.meanings_json != '[]' THEN excluded.meanings_json ELSE saved_words.meanings_json END,
              explanation = excluded.explanation,
              source_sentence = COALESCE(excluded.source_sentence, saved_words.source_sentence),
              article_id = COALESCE(excluded.article_id, saved_words.article_id),
              count = saved_words.count + 1,
              updated_at = excluded.updated_at
            """,
            [cleanWord, displayWord, translation, meaningsJSON, explanation, sourceSentence, articleId, timestamp, timestamp]
        )
        return try listSavedWords()
    }

    func updateSavedWordMeanings(_ id: Int64, meanings: [WordMeaning]) throws -> [SavedWord] {
        try run(
            "UPDATE saved_words SET meanings_json = ?, updated_at = ? WHERE id = ?",
            [encodeMeanings(meanings), encodeDate(now()), id]
        )
        return try listSavedWords()
    }

    func saveSentence(text: String, translation: String, explanation: String, articleId: Int64?) throws -> [SavedSentence] {
        let timestamp = encodeDate(now())
        try run(
            """
            INSERT INTO saved_sentences
            (text, translation, explanation, article_id, familiarity, created_at, updated_at)
            VALUES (?, ?, ?, ?, 'new', ?, ?)
            ON CONFLICT(text) DO UPDATE SET
              translation = excluded.translation,
              explanation = excluded.explanation,
              article_id = COALESCE(excluded.article_id, saved_sentences.article_id),
              updated_at = excluded.updated_at
            """,
            [text, translation, explanation, articleId, timestamp, timestamp]
        )
        return try listSavedSentences()
    }

    func listSavedWords() throws -> [SavedWord] {
        try query(
            """
            SELECT saved_words.*, articles.title AS article_title
            FROM saved_words
            LEFT JOIN articles ON articles.id = saved_words.article_id
            ORDER BY saved_words.updated_at DESC
            """,
            mapSavedWord
        )
    }

    func listSavedSentences() throws -> [SavedSentence] {
        try query(
            """
            SELECT saved_sentences.*, articles.title AS article_title
            FROM saved_sentences
            LEFT JOIN articles ON articles.id = saved_sentences.article_id
            ORDER BY saved_sentences.updated_at DESC
            """,
            mapSavedSentence
        )
    }

    func updateReview(kind: LearningKind, id: Int64, familiarity: Familiarity) throws {
        let table = kind == .word ? "saved_words" : "saved_sentences"
        try run("UPDATE \(table) SET familiarity = ?, updated_at = ? WHERE id = ?", [familiarity.rawValue, encodeDate(now()), id])
    }

    func deleteSavedWord(_ id: Int64) throws -> [SavedWord] {
        try run("DELETE FROM saved_words WHERE id = ?", [id])
        return try listSavedWords()
    }

    func deleteSavedSentence(_ id: Int64) throws -> [SavedSentence] {
        try run("DELETE FROM saved_sentences WHERE id = ?", [id])
        return try listSavedSentences()
    }

    func getSettings() throws -> ReaderSettings {
        let rows = try query("SELECT key, value FROM settings") { statement in
            (stringColumn(statement, 0), stringColumn(statement, 1))
        }
        var settings = ReaderSettings.default
        for (key, value) in rows {
            switch key {
            case "theme": settings.theme = value
            case "translationProvider": settings.translationProvider = TranslationProvider(rawValue: value) ?? .google
            case "fontFamily": settings.fontFamily = value
            case "fontSize": settings.fontSize = Double(value) ?? settings.fontSize
            case "lineHeight": settings.lineHeight = Double(value) ?? settings.lineHeight
            case "paragraphGap": settings.paragraphGap = Double(value) ?? settings.paragraphGap
            case "speechRate": settings.speechRate = Double(value) ?? settings.speechRate
            case "readerBackground": settings.readerBackground = value
            default: break
            }
        }
        return settings
    }

    func saveSettings(_ settings: ReaderSettings) throws -> ReaderSettings {
        let values: [(String, String)] = [
            ("theme", settings.theme),
            ("translationProvider", settings.translationProvider.rawValue),
            ("fontFamily", settings.fontFamily),
            ("fontSize", String(settings.fontSize)),
            ("lineHeight", String(settings.lineHeight)),
            ("paragraphGap", String(settings.paragraphGap)),
            ("speechRate", String(settings.speechRate)),
            ("readerBackground", settings.readerBackground)
        ]
        for (key, value) in values {
            try run("INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [key, value])
        }
        return try getSettings()
    }

    func logIngestion(feedId: Int64, status: String, message: String) throws {
        try run("INSERT INTO ingestion_logs (feed_id, status, message, created_at) VALUES (?, ?, ?, ?)", [feedId, status, message, encodeDate(now())])
    }

    @discardableResult
    private func clearUnsubscribedArticles() throws -> Int {
        try run(
            """
            DELETE FROM articles
            WHERE feed_id IS NULL
               OR NOT EXISTS (SELECT 1 FROM feeds WHERE feeds.id = articles.feed_id)
            """
        )
    }

    private func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(handle, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "SQLite exec failed."
            sqlite3_free(error)
            throw MagReaderError.database(message)
        }
    }

    private func addColumnIfNeeded(table: String, column: String, definition: String) throws {
        let columns = try query("PRAGMA table_info(\(table))") { statement in
            stringColumn(statement, 1)
        }
        guard !columns.contains(column) else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition);")
    }

    @discardableResult
    private func run(_ sql: String, _ values: [Any?] = []) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw MagReaderError.database(lastError)
        }
        defer { sqlite3_finalize(statement) }
        try bind(values, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MagReaderError.database(lastError)
        }
        return Int(sqlite3_changes(handle))
    }

    private func query<T>(_ sql: String, _ values: [Any?] = [], _ map: (OpaquePointer?) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw MagReaderError.database(lastError)
        }
        defer { sqlite3_finalize(statement) }
        try bind(values, to: statement)
        var output: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            output.append(try map(statement))
        }
        return output
    }

    private func query<T>(_ sql: String, _ map: (OpaquePointer?) throws -> T) throws -> [T] {
        try query(sql, [], map)
    }

    private func bind(_ values: [Any?], to statement: OpaquePointer?) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case nil:
                sqlite3_bind_null(statement, index)
            case let value as Int:
                sqlite3_bind_int64(statement, index, Int64(value))
            case let value as Int64:
                sqlite3_bind_int64(statement, index, value)
            case let value as Bool:
                sqlite3_bind_int64(statement, index, value ? 1 : 0)
            case let value as Double:
                sqlite3_bind_double(statement, index, value)
            case let value as String:
                sqlite3_bind_text(statement, index, value, -1, transient)
            default:
                sqlite3_bind_text(statement, index, String(describing: value!), -1, transient)
            }
        }
    }

    private var lastError: String {
        handle.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? "Unknown SQLite error."
    }
}

private func mapFeed(_ statement: OpaquePointer?) -> Feed {
    Feed(
        id: intColumn(statement, 0),
        title: stringColumn(statement, 1),
        url: stringColumn(statement, 2),
        siteUrl: optionalStringColumn(statement, 3),
        enabled: intColumn(statement, 4) == 1,
        lastFetchedAt: decodeDate(optionalStringColumn(statement, 5)),
        lastError: optionalStringColumn(statement, 6),
        createdAt: decodeDate(optionalStringColumn(statement, 7)) ?? Date()
    )
}

private func mapArticle(_ statement: OpaquePointer?) -> Article {
    Article(
        id: intColumn(statement, 0),
        feedId: optionalIntColumn(statement, 1),
        feedTitle: optionalStringColumn(statement, 15),
        guid: optionalStringColumn(statement, 2),
        url: stringColumn(statement, 3),
        title: stringColumn(statement, 4),
        author: optionalStringColumn(statement, 5),
        publishedAt: decodeDate(optionalStringColumn(statement, 6)),
        excerpt: optionalStringColumn(statement, 7),
        contentHtml: stringColumn(statement, 8),
        contentText: stringColumn(statement, 9),
        difficulty: stringColumn(statement, 10),
        status: ArticleStatus(rawValue: stringColumn(statement, 11)) ?? .unread,
        favorite: intColumn(statement, 12) == 1,
        createdAt: decodeDate(optionalStringColumn(statement, 13)) ?? Date(),
        updatedAt: decodeDate(optionalStringColumn(statement, 14)) ?? Date()
    )
}

private func mapSavedWord(_ statement: OpaquePointer?) -> SavedWord {
    SavedWord(
        id: intColumn(statement, 0),
        word: stringColumn(statement, 1),
        displayWord: stringColumn(statement, 2),
        translation: stringColumn(statement, 3),
        meanings: decodeMeanings(stringColumn(statement, 4)),
        explanation: stringColumn(statement, 5),
        sourceSentence: optionalStringColumn(statement, 6),
        articleId: optionalIntColumn(statement, 7),
        articleTitle: optionalStringColumn(statement, 12),
        familiarity: Familiarity(rawValue: stringColumn(statement, 8)) ?? .new,
        count: Int(intColumn(statement, 9)),
        createdAt: decodeDate(optionalStringColumn(statement, 10)) ?? Date(),
        updatedAt: decodeDate(optionalStringColumn(statement, 11)) ?? Date()
    )
}

private func mapSavedSentence(_ statement: OpaquePointer?) -> SavedSentence {
    SavedSentence(
        id: intColumn(statement, 0),
        text: stringColumn(statement, 1),
        translation: stringColumn(statement, 2),
        explanation: stringColumn(statement, 3),
        articleId: optionalIntColumn(statement, 4),
        articleTitle: optionalStringColumn(statement, 8),
        familiarity: Familiarity(rawValue: stringColumn(statement, 5)) ?? .new,
        createdAt: decodeDate(optionalStringColumn(statement, 6)) ?? Date(),
        updatedAt: decodeDate(optionalStringColumn(statement, 7)) ?? Date()
    )
}

private func stringColumn(_ statement: OpaquePointer?, _ index: Int32) -> String {
    optionalStringColumn(statement, index) ?? ""
}

private func optionalStringColumn(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL, let pointer = sqlite3_column_text(statement, index) else { return nil }
    return String(cString: pointer)
}

private func intColumn(_ statement: OpaquePointer?, _ index: Int32) -> Int64 {
    sqlite3_column_int64(statement, index)
}

private func optionalIntColumn(_ statement: OpaquePointer?, _ index: Int32) -> Int64? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return sqlite3_column_int64(statement, index)
}

private func encodeMeanings(_ meanings: [WordMeaning]) -> String {
    guard let data = try? JSONEncoder().encode(meanings), let json = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return json
}

private func decodeMeanings(_ json: String) -> [WordMeaning] {
    guard let data = json.data(using: .utf8), let meanings = try? JSONDecoder().decode([WordMeaning].self, from: data) else {
        return []
    }
    return meanings
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
final class InMemoryDatabase: DatabaseClient {
    private var feeds: [Feed] = []
    private var articles: [Article] = []
    private var words: [SavedWord] = []
    private var sentences: [SavedSentence] = []
    private var settings = ReaderSettings.default
    private var nextId: Int64 = 1

    func listFeeds() throws -> [Feed] { feeds.sorted { $0.createdAt > $1.createdAt } }

    func createFeed(title: String?, url: String) throws {
        guard let parsedURL = URL(string: url), let host = parsedURL.host else { throw MagReaderError.invalidURL }
        if feeds.contains(where: { $0.url == url }) { return }
        feeds.append(Feed(id: next(), title: title?.nilIfBlank ?? host, url: url, siteUrl: nil, enabled: true, lastFetchedAt: nil, lastError: nil, createdAt: Date()))
    }

    func updateFeed(_ id: Int64, title: String?, url: String?, enabled: Bool?, siteUrl: String?, lastFetchedAt: Date?, lastError: String?) throws {
        guard let index = feeds.firstIndex(where: { $0.id == id }) else { return }
        feeds[index].title = title ?? feeds[index].title
        feeds[index].url = url ?? feeds[index].url
        feeds[index].enabled = enabled ?? feeds[index].enabled
        feeds[index].siteUrl = siteUrl ?? feeds[index].siteUrl
        feeds[index].lastFetchedAt = lastFetchedAt ?? feeds[index].lastFetchedAt
        feeds[index].lastError = lastError ?? feeds[index].lastError
    }

    func deleteFeed(_ id: Int64) throws {
        feeds.removeAll { $0.id == id }
        articles.removeAll { $0.feedId == id }
    }

    func listArticles() throws -> [Article] {
        articles.filter { $0.status != .archived && $0.feedId != nil }.sorted { ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt) }
    }

    func getArticle(_ id: Int64) throws -> Article? { articles.first { $0.id == id } }

    func upsertArticle(_ input: ArticleUpsert) throws {
        if let index = articles.firstIndex(where: { $0.url == input.url }) {
            articles[index].title = input.title
            articles[index].feedId = input.feedId
            articles[index].feedTitle = feeds.first { $0.id == input.feedId }?.title
            articles[index].contentHtml = input.contentHtml
            articles[index].contentText = input.contentText
            articles[index].status = articles[index].status == .archived ? .unread : articles[index].status
            articles[index].updatedAt = Date()
        } else {
            articles.append(Article(id: next(), feedId: input.feedId, feedTitle: feeds.first { $0.id == input.feedId }?.title, guid: input.guid, url: input.url, title: input.title, author: input.author, publishedAt: input.publishedAt, excerpt: input.excerpt, contentHtml: input.contentHtml, contentText: input.contentText, difficulty: input.difficulty, status: .unread, favorite: false, createdAt: Date(), updatedAt: Date()))
        }
    }

    func archiveMissingFeedArticles(feedId: Int64, currentUrls: [String]) throws -> Int {
        var changed = 0
        for index in articles.indices where articles[index].feedId == feedId && !currentUrls.contains(articles[index].url) && articles[index].status != .archived {
            articles[index].status = .archived
            changed += 1
        }
        return changed
    }

    func markArticle(_ id: Int64, status: ArticleStatus) throws {
        guard let index = articles.firstIndex(where: { $0.id == id }) else { return }
        articles[index].status = status
    }

    func saveWord(word: String, displayWord: String, translation: String, meanings: [WordMeaning], explanation: String, sourceSentence: String?, articleId: Int64?) throws -> [SavedWord] {
        let clean = normalizedWord(word)
        if let index = words.firstIndex(where: { $0.word == clean }) {
            words[index].displayWord = displayWord
            words[index].translation = translation
            if !meanings.isEmpty {
                words[index].meanings = meanings
            }
            words[index].explanation = explanation
            words[index].count += 1
            words[index].updatedAt = Date()
        } else {
            words.append(SavedWord(id: next(), word: clean, displayWord: displayWord, translation: translation, meanings: meanings, explanation: explanation, sourceSentence: sourceSentence, articleId: articleId, articleTitle: articles.first { $0.id == articleId }?.title, familiarity: .new, count: 1, createdAt: Date(), updatedAt: Date()))
        }
        return try listSavedWords()
    }

    func updateSavedWordMeanings(_ id: Int64, meanings: [WordMeaning]) throws -> [SavedWord] {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return try listSavedWords() }
        words[index].meanings = meanings
        words[index].updatedAt = Date()
        return try listSavedWords()
    }

    func saveSentence(text: String, translation: String, explanation: String, articleId: Int64?) throws -> [SavedSentence] {
        if let index = sentences.firstIndex(where: { $0.text == text }) {
            sentences[index].translation = translation
            sentences[index].explanation = explanation
            sentences[index].updatedAt = Date()
        } else {
            sentences.append(SavedSentence(id: next(), text: text, translation: translation, explanation: explanation, articleId: articleId, articleTitle: articles.first { $0.id == articleId }?.title, familiarity: .new, createdAt: Date(), updatedAt: Date()))
        }
        return try listSavedSentences()
    }

    func listSavedWords() throws -> [SavedWord] { words.sorted { $0.updatedAt > $1.updatedAt } }
    func listSavedSentences() throws -> [SavedSentence] { sentences.sorted { $0.updatedAt > $1.updatedAt } }

    func updateReview(kind: LearningKind, id: Int64, familiarity: Familiarity) throws {
        if kind == .word, let index = words.firstIndex(where: { $0.id == id }) { words[index].familiarity = familiarity }
        if kind == .sentence, let index = sentences.firstIndex(where: { $0.id == id }) { sentences[index].familiarity = familiarity }
    }

    func deleteSavedWord(_ id: Int64) throws -> [SavedWord] {
        words.removeAll { $0.id == id }
        return try listSavedWords()
    }

    func deleteSavedSentence(_ id: Int64) throws -> [SavedSentence] {
        sentences.removeAll { $0.id == id }
        return try listSavedSentences()
    }

    func getSettings() throws -> ReaderSettings { settings }
    func saveSettings(_ settings: ReaderSettings) throws -> ReaderSettings {
        self.settings = settings
        return settings
    }

    func logIngestion(feedId: Int64, status: String, message: String) throws {}

    private func next() -> Int64 {
        defer { nextId += 1 }
        return nextId
    }
}
