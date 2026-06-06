import SwiftUI

@main
struct MagReaderApp: App {
    private let container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}

@MainActor
final class AppContainer {
    let database: DatabaseClient
    let feedRefresh: FeedRefreshService
    let translation: TranslationService
    let speech: SpeechService
    let settingsStore: SettingsStore

    init(
        database: DatabaseClient,
        feedRefresh: FeedRefreshService,
        translation: TranslationService,
        speech: SpeechService,
        settingsStore: SettingsStore
    ) {
        self.database = database
        self.feedRefresh = feedRefresh
        self.translation = translation
        self.speech = speech
        self.settingsStore = settingsStore
    }

    static func live() -> AppContainer {
        if ProcessInfo.processInfo.arguments.contains("-UITestSeedData") {
            return uiTestSeeded()
        }

        do {
            let database = try SQLiteDatabase.default()
            let settingsStore = SettingsStore(database: database)
            let translation = CompositeTranslationService(settingsStore: settingsStore)
            let refresh = URLSessionFeedRefreshService(database: database)
            return AppContainer(
                database: database,
                feedRefresh: refresh,
                translation: translation,
                speech: AVSpeechService(),
                settingsStore: settingsStore
            )
        } catch {
            let fallback = InMemoryDatabase()
            let settingsStore = SettingsStore(database: fallback)
            return AppContainer(
                database: fallback,
                feedRefresh: URLSessionFeedRefreshService(database: fallback),
                translation: CompositeTranslationService(settingsStore: settingsStore),
                speech: AVSpeechService(),
                settingsStore: settingsStore
            )
        }
    }

    private static func uiTestSeeded() -> AppContainer {
        let database = InMemoryDatabase()
        try? database.createFeed(title: "BBC Learning", url: "https://example.com/bbc.xml")
        try? database.createFeed(title: "Tech Review", url: "https://example.com/tech.xml")
        let feeds = (try? database.listFeeds()) ?? []
        let bbc = feeds.first { $0.title == "BBC Learning" }
        let tech = feeds.first { $0.title == "Tech Review" }

        if let bbc {
            try? database.upsertArticle(
                ArticleUpsert(
                    feedId: bbc.id,
                    guid: "bbc-1",
                    url: "https://example.com/bbc/reader-habits",
                    title: "Reader habits improve vocabulary",
                    author: "MagReader",
                    publishedAt: Date().addingTimeInterval(-600),
                    excerpt: "Daily reading helps learners notice vocabulary in context.",
                    contentHtml: "<p>Daily reading helps learners notice vocabulary in context.</p><p>Context makes difficult words more manageable.</p>",
                    contentText: "Daily reading helps learners notice vocabulary in context. Context makes difficult words more manageable.",
                    difficulty: "B1"
                )
            )
        }

        if let tech {
            try? database.upsertArticle(
                ArticleUpsert(
                    feedId: tech.id,
                    guid: "tech-1",
                    url: "https://example.com/tech/local-first",
                    title: "Local-first apps keep study data private",
                    author: "MagReader",
                    publishedAt: Date().addingTimeInterval(-1200),
                    excerpt: "A local database can keep review data available offline.",
                    contentHtml: "<p>A local database can keep review data available offline.</p>",
                    contentText: "A local database can keep review data available offline.",
                    difficulty: "B2"
                )
            )
        }

        let articles = (try? database.listArticles()) ?? []
        let sourceArticle = articles.first
        _ = try? database.saveWord(
            word: "Context",
            displayWord: "Context",
            translation: "语境；上下文",
            meanings: [
                WordMeaning(
                    partOfSpeech: "noun",
                    definition: "The circumstances that form the setting for an event, statement, or idea.",
                    translatedDefinition: "事件、陈述或想法所处的背景。",
                    example: "Context makes difficult words more manageable.",
                    synonyms: ["background", "setting"]
                ),
                WordMeaning(
                    partOfSpeech: "noun",
                    definition: "The words before and after a selected word that help explain its meaning.",
                    translatedDefinition: "所选单词前后的、帮助解释其含义的词语。",
                    example: "Read the sentence around the word for context.",
                    synonyms: ["surrounding text"]
                )
            ],
            explanation: "Context is the surrounding information that helps explain meaning.",
            sourceSentence: "Context makes difficult words more manageable.",
            articleId: sourceArticle?.id
        )
        _ = try? database.saveSentence(
            text: "Daily reading helps learners notice vocabulary in context.",
            translation: "日常阅读帮助学习者在语境中注意词汇。",
            explanation: "Subject plus verb phrase, followed by an object and prepositional phrase.",
            articleId: sourceArticle?.id
        )

        var settings = ReaderSettings.default
        settings.translationProvider = .google
        _ = try? database.saveSettings(settings)

        let settingsStore = SettingsStore(database: database)
        return AppContainer(
            database: database,
            feedRefresh: StaticFeedRefreshService(database: database),
            translation: FixtureTranslationService(),
            speech: NoopSpeechService(),
            settingsStore: settingsStore
        )
    }
}

@MainActor
final class StaticFeedRefreshService: FeedRefreshService {
    private let database: DatabaseClient

    init(database: DatabaseClient) {
        self.database = database
    }

    func refreshAllFeeds() async -> [FeedRefreshResult] {
        ((try? database.listFeeds()) ?? []).map {
            FeedRefreshResult(feedId: $0.id, ok: true, count: 0, archived: 0, error: nil)
        }
    }

    func refreshFeed(_ feed: Feed) async -> FeedRefreshResult {
        FeedRefreshResult(feedId: feed.id, ok: true, count: 0, archived: 0, error: nil)
    }
}

@MainActor
final class NoopSpeechService: SpeechService {
    func speak(_ text: String, rate: Double) {}
    func stop() {}
}
