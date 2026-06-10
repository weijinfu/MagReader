import XCTest
@testable import MagReaderCore

final class MagReaderCoreTests: XCTestCase {
    private var tempURLs: [URL] = []

    override func tearDown() {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        super.tearDown()
    }

    @MainActor
    func testDatabaseMigrationDedupeAndArchive() throws {
        let db = try makeDatabase()
        try db.createFeed(title: "Feed", url: "https://example.com/rss.xml")
        XCTAssertThrowsError(try db.createFeed(title: "Duplicate", url: "https://example.com/rss.xml"))
        let feed = try XCTUnwrap(db.listFeeds().first)

        try db.upsertArticle(sampleArticle(feedId: feed.id, url: "https://example.com/a", title: "First"))
        try db.upsertArticle(sampleArticle(feedId: feed.id, url: "https://example.com/a", title: "Updated"))
        XCTAssertEqual(try db.listArticles().count, 1)
        XCTAssertEqual(try db.listArticles().first?.title, "Updated")
        XCTAssertEqual(try db.archiveMissingFeedArticles(feedId: feed.id, currentUrls: []), 1)
        XCTAssertTrue(try db.listArticles().isEmpty)
    }

    @MainActor
    func testSavedWordSentenceAndExport() throws {
        let db = try makeDatabase()
        let meanings = [
            WordMeaning(partOfSpeech: "noun", definition: "Words around a selected word.", translatedDefinition: "所选单词周围的词语。", example: nil, synonyms: ["context"])
        ]
        _ = try db.saveWord(word: "Context,", displayWord: "Context", translation: "语境", meanings: meanings, explanation: "Meaning.", sourceSentence: nil, articleId: nil)
        let words = try db.saveWord(word: "context", displayWord: "context", translation: "上下文", meanings: [], explanation: "Updated.", sourceSentence: nil, articleId: nil)
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].count, 2)
        XCTAssertEqual(words[0].meanings.count, 1)

        _ = try db.saveSentence(text: "Reading slowly helps.", translation: "慢慢阅读有帮助。", explanation: "Simple.", articleId: nil)
        _ = try db.saveSentence(text: "Reading slowly helps.", translation: "慢读有帮助。", explanation: "Updated.", articleId: nil)
        XCTAssertEqual(try db.listSavedSentences().count, 1)

        let service = ExportService(database: db, dateProvider: { Date(timeIntervalSince1970: 0) })
        let csv = try service.exportSavedItems(format: .csv)
        XCTAssertEqual(csv.filename, "magreader-export.csv")
        let csvText = try XCTUnwrap(String(data: csv.data, encoding: .utf8))
        XCTAssertTrue(csvText.contains(#""type","text","translation","explanation","familiarity","source","exportedAt""#))
        XCTAssertTrue(csvText.contains(#""word","context","上下文""#))
        XCTAssertTrue(csvText.contains("1970-01-01T00:00:00"))

        let json = try service.exportSavedItems(format: .json)
        XCTAssertEqual(json.filename, "magreader-export.json")
        XCTAssertTrue(String(data: json.data, encoding: .utf8)?.contains(#""exportedAt""#) == true)
    }

    func testDictionaryParsingUtilitiesAndGoogleFixture() throws {
        XCTAssertTrue(isLikelyWord("reader's"))
        XCTAssertTrue(isLikelyWord("long-term"))
        XCTAssertFalse(isLikelyWord("long sentence"))
        XCTAssertEqual(stripHTML(#"<p onclick="x()">Safe &amp; sound</p><script>bad()</script>"#), "Safe & sound")

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
                  {"definition": "The circumstances that form the setting for an event.", "example": "The decision was taken in context.", "synonyms": ["setting"]},
                  {"definition": "The parts of something written that immediately precede and follow a word."}
                ]
              },
              {
                "partOfSpeech": "verb",
                "definitions": [
                  {"definition": "To place something in context."}
                ]
              }
            ]
          }
        ]
        """.utf8)
        let meanings = try parseDictionaryEntries(dictionary)
        XCTAssertEqual(meanings.count, 3)
        XCTAssertEqual(meanings[0].partOfSpeech, "noun")
        XCTAssertEqual(meanings[0].example, "The decision was taken in context.")
    }

    @MainActor
    private func makeDatabase() throws -> SQLiteDatabase {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempURLs.append(directory)
        return try SQLiteDatabase(path: directory.appending(path: "test.db").path)
    }

    private func sampleArticle(feedId: Int64, url: String, title: String) -> ArticleUpsert {
        ArticleUpsert(
            feedId: feedId,
            guid: url,
            url: url,
            title: title,
            author: nil,
            publishedAt: Date(),
            excerpt: "Excerpt",
            contentHtml: "<p>Context helps readers.</p>",
            contentText: "Context helps readers.",
            difficulty: "A2"
        )
    }
}
