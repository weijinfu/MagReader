import Foundation

enum ViewTab: String, CaseIterable, Identifiable {
    case articles
    case feeds
    case saved
    case review
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .articles: "Articles"
        case .feeds: "Feeds"
        case .saved: "Saved"
        case .review: "Review"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .articles: "newspaper"
        case .feeds: "antenna.radiowaves.left.and.right"
        case .saved: "bookmark"
        case .review: "rectangle.stack"
        case .settings: "gearshape"
        }
    }
}

enum Familiarity: String, CaseIterable, Codable, Identifiable {
    case new
    case learning
    case familiar
    case mastered

    var id: String { rawValue }
}

enum TranslationProvider: String, CaseIterable, Codable, Identifiable {
    case google
    case mymemory

    var id: String { rawValue }

    var label: String {
        switch self {
        case .google: "Google"
        case .mymemory: "MyMemory"
        }
    }
}

enum ArticleStatus: String, Codable {
    case unread
    case read
    case archived
}

enum LearningKind: String, Codable {
    case word
    case sentence
}

struct Feed: Identifiable, Hashable {
    var id: Int64
    var title: String
    var url: String
    var siteUrl: String?
    var enabled: Bool
    var lastFetchedAt: Date?
    var lastError: String?
    var createdAt: Date
}

struct Article: Identifiable, Hashable {
    var id: Int64
    var feedId: Int64?
    var feedTitle: String?
    var guid: String?
    var url: String
    var title: String
    var author: String?
    var publishedAt: Date?
    var excerpt: String?
    var contentHtml: String
    var contentText: String
    var difficulty: String
    var status: ArticleStatus
    var favorite: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct SavedWord: Identifiable, Hashable, Codable {
    var id: Int64
    var word: String
    var displayWord: String
    var translation: String
    var meanings: [WordMeaning]
    var explanation: String
    var sourceSentence: String?
    var articleId: Int64?
    var articleTitle: String?
    var familiarity: Familiarity
    var count: Int
    var createdAt: Date
    var updatedAt: Date
}

struct SavedSentence: Identifiable, Hashable, Codable {
    var id: Int64
    var text: String
    var translation: String
    var explanation: String
    var articleId: Int64?
    var articleTitle: String?
    var familiarity: Familiarity
    var createdAt: Date
    var updatedAt: Date
}

struct ReaderSettings: Equatable {
    var theme: String
    var translationProvider: TranslationProvider
    var fontFamily: String
    var fontSize: Double
    var lineHeight: Double
    var paragraphGap: Double
    var speechRate: Double
    var readerBackground: String

    static let `default` = ReaderSettings(
        theme: "light",
        translationProvider: .google,
        fontFamily: "Georgia",
        fontSize: 20,
        lineHeight: 1.75,
        paragraphGap: 1.25,
        speechRate: 0.92,
        readerBackground: "paper"
    )

    var isDark: Bool { theme == "dark" }
}

struct PhraseHint: Identifiable, Hashable, Codable {
    var id: String { phrase }
    var phrase: String
    var meaning: String
}

struct Difficulty: Hashable, Codable {
    var level: String
    var score: Int
    var reason: String
}

struct WordMeaning: Identifiable, Hashable, Codable {
    var id: String {
        "\(partOfSpeech)|\(definition)|\(translatedDefinition ?? "")"
    }

    var partOfSpeech: String
    var definition: String
    var translatedDefinition: String?
    var example: String?
    var synonyms: [String]
}

struct LearningAnalysis: Identifiable, Hashable {
    var id: String { "\(kind.rawValue):\(text)" }
    var kind: LearningKind
    var text: String
    var translation: String
    var translationProvider: String
    var wordMeanings: [WordMeaning]
    var explanation: String
    var phrases: [PhraseHint]
    var structure: [String]
    var difficulty: Difficulty
}

struct FeedRefreshResult: Identifiable, Hashable {
    var id: Int64 { feedId }
    var feedId: Int64
    var ok: Bool
    var count: Int
    var archived: Int
    var error: String?
}

struct ParsedFeed {
    var title: String?
    var siteUrl: String?
    var items: [ParsedFeedItem]
}

struct ParsedFeedItem: Hashable {
    var title: String
    var link: String?
    var guid: String?
    var author: String?
    var publishedAt: Date?
    var summary: String?
    var contentHtml: String?
}

struct ArticleUpsert {
    var feedId: Int64?
    var guid: String?
    var url: String
    var title: String
    var author: String?
    var publishedAt: Date?
    var excerpt: String?
    var contentHtml: String
    var contentText: String
    var difficulty: String
}

enum SavedReviewItem: Identifiable, Hashable {
    case word(SavedWord)
    case sentence(SavedSentence)

    var id: String {
        switch self {
        case .word(let word): "word-\(word.id)"
        case .sentence(let sentence): "sentence-\(sentence.id)"
        }
    }

    var text: String {
        switch self {
        case .word(let word): word.displayWord
        case .sentence(let sentence): sentence.text
        }
    }

    var translation: String {
        switch self {
        case .word(let word): word.translation
        case .sentence(let sentence): sentence.translation
        }
    }

    var explanation: String {
        switch self {
        case .word(let word): word.explanation
        case .sentence(let sentence): sentence.explanation
        }
    }

    var familiarity: Familiarity {
        switch self {
        case .word(let word): word.familiarity
        case .sentence(let sentence): sentence.familiarity
        }
    }
}
