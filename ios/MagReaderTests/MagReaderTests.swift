import XCTest
import SQLite3
import AVFoundation
@testable import MagReader

final class MagReaderTests: XCTestCase {
    private var tempURLs: [URL] = []

    override func tearDown() {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        super.tearDown()
    }

    @MainActor
    func testDatabaseMigrationAndFeedDedupe() throws {
        let db = try makeDatabase()

        try db.createFeed(title: "BBC", url: "https://example.com/rss.xml")
        XCTAssertThrowsError(try db.createFeed(title: "BBC duplicate", url: "https://example.com/rss.xml"))

        let feeds = try db.listFeeds()
        XCTAssertEqual(feeds.count, 1)
        XCTAssertEqual(feeds[0].title, "BBC")
    }

    @MainActor
    func testArticleUpsertAndArchiveVisibility() throws {
        let db = try makeDatabase()
        try db.createFeed(title: "Feed", url: "https://example.com/rss.xml")
        let feed = try XCTUnwrap(db.listFeeds().first)

        try db.upsertArticle(sampleArticle(feedId: feed.id, url: "https://example.com/a", title: "First"))
        try db.upsertArticle(sampleArticle(feedId: feed.id, url: "https://example.com/a", title: "Updated"))

        var articles = try db.listArticles()
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].title, "Updated")

        let archived = try db.archiveMissingFeedArticles(feedId: feed.id, currentUrls: [])
        XCTAssertEqual(archived, 1)
        articles = try db.listArticles()
        XCTAssertTrue(articles.isEmpty)
    }

    @MainActor
    func testSavedWordNormalizationAndCount() throws {
        let db = try makeDatabase()
        let firstMeanings = [
            WordMeaning(partOfSpeech: "noun", definition: "The circumstances around an idea.", translatedDefinition: "想法所处的背景。", example: "Read the word in context.", synonyms: ["setting"])
        ]
        let updatedMeanings = [
            WordMeaning(partOfSpeech: "noun", definition: "Words around a selected word.", translatedDefinition: "所选单词周围的词语。", example: nil, synonyms: ["background"]),
            WordMeaning(partOfSpeech: "noun", definition: "A situation in which something happens.", translatedDefinition: "某事发生的情境。", example: nil, synonyms: [])
        ]

        _ = try db.saveWord(word: "Context,", displayWord: "Context", translation: "语境", meanings: firstMeanings, explanation: "Meaning.", sourceSentence: nil, articleId: nil)
        let words = try db.saveWord(word: "context", displayWord: "context", translation: "上下文", meanings: updatedMeanings, explanation: "Updated.", sourceSentence: nil, articleId: nil)

        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].word, "context")
        XCTAssertEqual(words[0].count, 2)
        XCTAssertEqual(words[0].translation, "上下文")
        XCTAssertEqual(words[0].meanings.count, 2)
        XCTAssertEqual(words[0].meanings[0].translatedDefinition, "所选单词周围的词语。")

        let patchedMeanings = [
            WordMeaning(partOfSpeech: "noun", definition: "A later dictionary meaning.", translatedDefinition: "后续补充的词典释义。", example: nil, synonyms: [])
        ]
        let patched = try db.updateSavedWordMeanings(words[0].id, meanings: patchedMeanings)
        XCTAssertEqual(patched[0].count, 2)
        XCTAssertEqual(patched[0].meanings.count, 1)
        XCTAssertEqual(patched[0].meanings[0].translatedDefinition, "后续补充的词典释义。")
    }

    @MainActor
    func testSavedSentenceDedupeReviewAndDelete() throws {
        let db = try makeDatabase()

        _ = try db.saveSentence(text: "Reading slowly helps.", translation: "慢慢阅读有帮助。", explanation: "Simple sentence.", articleId: nil)
        var sentences = try db.saveSentence(text: "Reading slowly helps.", translation: "慢读有帮助。", explanation: "Updated.", articleId: nil)
        XCTAssertEqual(sentences.count, 1)
        XCTAssertEqual(sentences[0].translation, "慢读有帮助。")

        try db.updateReview(kind: .sentence, id: sentences[0].id, familiarity: .mastered)
        sentences = try db.listSavedSentences()
        XCTAssertEqual(sentences[0].familiarity, .mastered)

        sentences = try db.deleteSavedSentence(sentences[0].id)
        XCTAssertTrue(sentences.isEmpty)
    }

    @MainActor
    func testSettingsPersistAndReload() throws {
        let db = try makeDatabase()

        var settings = ReaderSettings.default
        settings.theme = "dark"
        settings.translationProvider = .mymemory
        settings.fontFamily = "Georgia"
        settings.fontSize = 23
        settings.lineHeight = 1.75
        settings.paragraphGap = 1.4
        settings.speechRate = 0.72
        settings.readerBackground = "green"

        let saved = try db.saveSettings(settings)
        let reloaded = try db.getSettings()

        XCTAssertEqual(saved.theme, "dark")
        XCTAssertEqual(reloaded.translationProvider, .mymemory)
        XCTAssertEqual(reloaded.fontSize, 23)
        XCTAssertEqual(reloaded.lineHeight, 1.75)
        XCTAssertEqual(reloaded.paragraphGap, 1.4)
        XCTAssertEqual(reloaded.speechRate, 0.72)
        XCTAssertEqual(reloaded.readerBackground, "green")
    }

    @MainActor
    func testDeletingFeedRemovesArticlesFromVisibleList() throws {
        let db = try makeDatabase()
        try db.createFeed(title: "Feed", url: "https://example.com/rss.xml")
        let feed = try XCTUnwrap(db.listFeeds().first)
        try db.upsertArticle(sampleArticle(feedId: feed.id, url: "https://example.com/a", title: "First"))

        XCTAssertEqual(try db.listArticles().count, 1)
        try db.deleteFeed(feed.id)
        XCTAssertTrue(try db.listArticles().isEmpty)
    }

    func testHTMLSanitizationAndTextUtilities() throws {
        let unsafe = #"<p onclick="steal()">Safe &amp; sound</p><script>alert(1)</script><style>p{}</style>"#
        let sanitized = sanitizeHTML(unsafe)
        XCTAssertFalse(sanitized.contains("script"))
        XCTAssertFalse(sanitized.contains("style"))
        XCTAssertFalse(sanitized.contains("onclick"))
        XCTAssertEqual(stripHTML(unsafe), "Safe & sound")
        XCTAssertEqual(escapeHTML(#"<tag attr="value">&"#), #"&lt;tag attr=&quot;value&quot;&gt;&amp;"#)
    }

    func testDateDifficultyAndSentenceHelpers() throws {
        let date = try XCTUnwrap(parseRFC822Date("Wed, 03 Jun 2026 12:00:00 +0800"))
        XCTAssertNotNil(decodeDate(encodeDate(date)))
        XCTAssertEqual(rateArticleDifficulty("Short text."), "A2")
        XCTAssertEqual(
            sentenceAround("First sentence. Target context appears here! Final sentence.", selectedText: "context"),
            "Target context appears here!"
        )
    }

    @MainActor
    func testLegacyProviderSettingsFallbackToGoogle() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempURLs.append(directory)
        let path = directory.appending(path: "legacy.db").path
        let db = try SQLiteDatabase(path: path)
        try insertRawSetting(path: path, key: "translationProvider", value: "mock")
        XCTAssertEqual(try db.getSettings().translationProvider, .google)

        try insertRawSetting(path: path, key: "translationProvider", value: "unknown-provider")
        XCTAssertEqual(try db.getSettings().translationProvider, .google)
    }

    @MainActor
    func testFixtureAnalysisDictionaryAndWordDetection() async throws {
        XCTAssertTrue(isLikelyWord("learner"))
        XCTAssertTrue(isLikelyWord("reader's"))
        XCTAssertTrue(isLikelyWord("long-term"))
        XCTAssertFalse(isLikelyWord("long sentence"))

        let analysis = try await FixtureTranslationService().analyze("Context")
        XCTAssertEqual(analysis.kind, .word)
        XCTAssertEqual(analysis.translationProvider, "Fixture")
        XCTAssertFalse(analysis.translation.isEmpty)
        XCTAssertTrue(analysis.wordMeanings.isEmpty)
        let meanings = try await FixtureTranslationService().loadMoreMeanings(for: "Context")
        XCTAssertFalse(meanings.isEmpty)
    }

    func testGoogleAndDictionaryFixtureParsing() throws {
        let google = Data(#"[[["你好","hello",null,null,10]],null,"en"]"#.utf8)
        XCTAssertEqual(try parseGoogleTranslationPayload(google), "你好")

        let dictionary = Data("""
        [
          {
            "word": "context",
            "meanings": [
              {
                "partOfSpeech": "noun",
                "definitions": [
                  {
                    "definition": "The circumstances that form the setting for an event, statement, or idea.",
                    "example": "The decision was taken in context.",
                    "synonyms": ["setting", "background"]
                  },
                  {
                    "definition": "The parts of something written or spoken that immediately precede and follow a word.",
                    "synonyms": ["surroundings"]
                  },
                  {
                    "definition": "A situation in which something exists or happens."
                  },
                  {
                    "definition": "Information that helps explain why something happened."
                  },
                  {
                    "definition": "The larger text around a quoted passage."
                  },
                  {
                    "definition": "A set of conditions connected with an event."
                  }
                ]
              },
              {
                "partOfSpeech": "verb",
                "definitions": [
                  {
                    "definition": "To place something in context."
                  }
                ]
              }
            ]
          }
        ]
        """.utf8)
        let meanings = try parseDictionaryEntries(dictionary)
        XCTAssertEqual(meanings.count, 7)
        XCTAssertEqual(meanings[0].partOfSpeech, "noun")
        XCTAssertEqual(meanings[0].example, "The decision was taken in context.")
        XCTAssertEqual(meanings[0].synonyms, ["setting", "background"])
    }

    @MainActor
    func testTranslationProviderSwitchesWithoutRestartAndBatchesWordDefinitions() async throws {
        let db = InMemoryDatabase()
        let settingsStore = SettingsStore(database: db)
        let google = SpyRemoteTranslationService(providerName: "Google Spy", prefix: "G")
        let myMemory = SpyRemoteTranslationService(providerName: "MyMemory Spy", prefix: "M")
        let dictionary = FixtureDictionaryLookupService()
        let service = CompositeTranslationService(settingsStore: settingsStore, google: google, myMemory: myMemory, dictionary: dictionary)

        var analysis = try await service.analyze("Context")
        XCTAssertEqual(analysis.translationProvider, "Google Spy")
        XCTAssertEqual(analysis.translation, "G: Context")
        XCTAssertEqual(google.translateTextCallCount, 1)
        XCTAssertEqual(google.translateTextsCallCount, 0)
        XCTAssertEqual(dictionary.lookupCallCount, 0)
        XCTAssertTrue(analysis.wordMeanings.isEmpty)

        settingsStore.update { $0.translationProvider = .mymemory }
        analysis = try await service.analyze("Context")
        XCTAssertEqual(analysis.translationProvider, "MyMemory Spy")
        XCTAssertEqual(analysis.translation, "M: Context")
        XCTAssertEqual(myMemory.translateTextCallCount, 1)
        XCTAssertEqual(myMemory.translateTextsCallCount, 0)
        XCTAssertEqual(dictionary.lookupCallCount, 0)
        XCTAssertTrue(analysis.wordMeanings.isEmpty)

        let meanings = try await service.loadMoreMeanings(for: "Context")
        XCTAssertEqual(dictionary.lookupCallCount, 1)
        XCTAssertEqual(myMemory.translateTextsCallCount, 1)
        XCTAssertEqual(myMemory.translateTextCallCount, 1)
        XCTAssertEqual(meanings.count, 2)
        XCTAssertEqual(meanings[0].translatedDefinition, "M: First definition")
        XCTAssertEqual(meanings[1].translatedDefinition, "M: Second definition")
    }

    @MainActor
    func testSpeechServiceConfiguresPlaybackSession() throws {
        let speech = AVSpeechService()
        speech.speak("Context", rate: ReaderSettings.default.speechRate)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        speech.stop()
    }

    func testRSSAndAtomFixtureParsing() throws {
        let rss = """
        <rss><channel><title>Example RSS</title><link>https://example.com</link><item><title>One</title><link>https://example.com/one</link><guid>one-guid</guid><pubDate>Wed, 03 Jun 2026 12:00:00 +0800</pubDate><description><![CDATA[<p>Summary one.</p>]]></description><content:encoded><![CDATA[<p>Full one content.</p>]]></content:encoded></item></channel></rss>
        """
        let parsedRSS = try FeedXMLParser().parse(Data(rss.utf8))
        XCTAssertEqual(parsedRSS.title, "Example RSS")
        XCTAssertEqual(parsedRSS.items.count, 1)
        XCTAssertEqual(parsedRSS.items[0].link, "https://example.com/one")
        XCTAssertEqual(stripHTML(parsedRSS.items[0].contentHtml ?? ""), "Full one content.")

        let atom = """
        <feed><title>Example Atom</title><link href="https://example.com"/><entry><title>Two</title><id>two-id</id><link href="https://example.com/two"/><updated>2026-06-03T12:00:00Z</updated><summary>Summary two.</summary></entry></feed>
        """
        let parsedAtom = try FeedXMLParser().parse(Data(atom.utf8))
        XCTAssertEqual(parsedAtom.title, "Example Atom")
        XCTAssertEqual(parsedAtom.items[0].link, "https://example.com/two")
        XCTAssertEqual(parsedAtom.items[0].summary, "Summary two.")
    }

    @MainActor
    private func makeDatabase() throws -> SQLiteDatabase {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempURLs.append(directory)
        return try SQLiteDatabase(path: directory.appending(path: "test.db").path)
    }

    @MainActor
    private func sampleArticle(feedId: Int64, url: String, title: String) -> ArticleUpsert {
        ArticleUpsert(
            feedId: feedId,
            guid: url,
            url: url,
            title: title,
            author: nil,
            publishedAt: nil,
            excerpt: "Excerpt",
            contentHtml: "<p>Reading slowly helps learners notice grammar.</p>",
            contentText: "Reading slowly helps learners notice grammar.",
            difficulty: "B1"
        )
    }

    private func insertRawSetting(path: String, key: String, value: String) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value"
        XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    }
}

@MainActor
private final class SpyRemoteTranslationService: RemoteTranslationService {
    let providerName: String
    private let prefix: String
    private(set) var translateTextCallCount = 0
    private(set) var translateTextsCallCount = 0

    init(providerName: String, prefix: String) {
        self.providerName = providerName
        self.prefix = prefix
    }

    func analyze(_ text: String) async throws -> LearningAnalysis {
        buildAnalysis(text: text, translation: try await translateText(text), provider: providerName)
    }

    func translateText(_ text: String) async throws -> String {
        translateTextCallCount += 1
        return "\(prefix): \(text)"
    }

    func translateTexts(_ texts: [String]) async throws -> [String] {
        translateTextsCallCount += 1
        return texts.map { "\(prefix): \($0)" }
    }
}

@MainActor
private final class FixtureDictionaryLookupService: DictionaryLookupService {
    private(set) var lookupCallCount = 0

    func lookup(_ word: String) async throws -> [WordMeaning] {
        lookupCallCount += 1
        return [
            WordMeaning(partOfSpeech: "noun", definition: "First definition", translatedDefinition: nil, example: nil, synonyms: []),
            WordMeaning(partOfSpeech: "noun", definition: "Second definition", translatedDefinition: nil, example: nil, synonyms: [])
        ]
    }
}
