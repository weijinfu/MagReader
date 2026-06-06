import AVFoundation
import Combine
import Foundation

@MainActor
protocol FeedRefreshService: AnyObject {
    func refreshAllFeeds() async -> [FeedRefreshResult]
    func refreshFeed(_ feed: Feed) async -> FeedRefreshResult
}

@MainActor
protocol TranslationService: AnyObject {
    func analyze(_ text: String) async throws -> LearningAnalysis
    func loadMoreMeanings(for word: String) async throws -> [WordMeaning]
}

@MainActor
protocol SpeechService: AnyObject {
    func speak(_ text: String, rate: Double)
    func stop()
}

@MainActor
final class SettingsStore: ObservableObject {
    private let database: DatabaseClient
    @Published
    var settings: ReaderSettings

    init(database: DatabaseClient) {
        self.database = database
        self.settings = (try? database.getSettings()) ?? .default
    }

    func update(_ transform: (inout ReaderSettings) -> Void) {
        var draft = settings
        transform(&draft)
        settings = (try? database.saveSettings(draft)) ?? draft
    }
}

@MainActor
final class URLSessionFeedRefreshService: FeedRefreshService {
    private let database: DatabaseClient
    private let session: URLSession

    init(database: DatabaseClient, session: URLSession = .shared) {
        self.database = database
        self.session = session
    }

    func refreshAllFeeds() async -> [FeedRefreshResult] {
        let feeds = (try? database.listFeeds().filter(\.enabled)) ?? []
        var results: [FeedRefreshResult] = []
        for feed in feeds {
            results.append(await refreshFeed(feed))
        }
        return results
    }

    func refreshFeed(_ feed: Feed) async -> FeedRefreshResult {
        do {
            guard let url = URL(string: feed.url) else { throw MagReaderError.invalidURL }
            let data = try await fetch(url)
            let parsed = try FeedXMLParser().parse(data)
            var count = 0
            var currentUrls: [String] = []

            for item in parsed.items {
                guard let articleURL = item.link ?? item.guid else { continue }
                currentUrls.append(articleURL)
                let content = await articleContent(for: item, articleURL: articleURL)
                try database.upsertArticle(
                    ArticleUpsert(
                        feedId: feed.id,
                        guid: item.guid ?? articleURL,
                        url: articleURL,
                        title: item.title,
                        author: item.author,
                        publishedAt: item.publishedAt,
                        excerpt: item.summary.map { stripHTML($0).prefixString(220) },
                        contentHtml: content.html,
                        contentText: content.text,
                        difficulty: rateArticleDifficulty(content.text)
                    )
                )
                count += 1
            }

            let archived = try database.archiveMissingFeedArticles(feedId: feed.id, currentUrls: currentUrls)
            try database.updateFeed(feed.id, title: parsed.title, url: nil, enabled: nil, siteUrl: parsed.siteUrl, lastFetchedAt: Date(), lastError: "")
            try database.logIngestion(feedId: feed.id, status: "success", message: "Fetched \(count) item(s), archived \(archived) stale item(s).")
            return FeedRefreshResult(feedId: feed.id, ok: true, count: count, archived: archived, error: nil)
        } catch {
            let message = error.localizedDescription
            try? database.updateFeed(feed.id, title: nil, url: nil, enabled: nil, siteUrl: nil, lastFetchedAt: nil, lastError: message)
            try? database.logIngestion(feedId: feed.id, status: "error", message: message)
            return FeedRefreshResult(feedId: feed.id, ok: false, count: 0, archived: 0, error: message)
        }
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("MagReader-iOS/0.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml, text/html;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            throw MagReaderError.database("Status code \(http.statusCode)")
        }
        return data
    }

    private func articleContent(for item: ParsedFeedItem, articleURL: String) async -> (html: String, text: String) {
        let feedHtml = item.contentHtml ?? item.summary ?? ""
        let feedText = stripHTML(feedHtml)
        if feedText.count > 300 {
            return (sanitizeHTML(feedHtml), feedText)
        }

        if let url = URL(string: articleURL), let data = try? await fetch(url), let html = String(data: data, encoding: .utf8) {
            let body = extractReadableHTML(html)
            let text = stripHTML(body)
            if text.count > 300 {
                return (sanitizeHTML(body), text)
            }
        }

        let fallback = feedText.nilIfBlank ?? item.summary.map(stripHTML) ?? item.title
        let html = feedHtml.nilIfBlank ?? "<p>\(escapeHTML(fallback))</p>"
        return (sanitizeHTML(html), fallback)
    }

    private func extractReadableHTML(_ html: String) -> String {
        if let article = html.range(of: "<article[\\s\\S]*?</article>", options: .regularExpression) {
            return String(html[article])
        }
        if let main = html.range(of: "<main[\\s\\S]*?</main>", options: .regularExpression) {
            return String(html[main])
        }
        if let body = html.range(of: "<body[\\s\\S]*?</body>", options: .regularExpression) {
            return String(html[body])
        }
        return html
    }
}

@MainActor
final class CompositeTranslationService: TranslationService {
    private let settingsStore: SettingsStore
    private let google: RemoteTranslationService
    private let myMemory: RemoteTranslationService
    private let dictionary: DictionaryLookupService

    init(
        settingsStore: SettingsStore,
        google: RemoteTranslationService = GoogleTranslationService(),
        myMemory: RemoteTranslationService = MyMemoryTranslationService(),
        dictionary: DictionaryLookupService = DictionaryAPIService()
    ) {
        self.settingsStore = settingsStore
        self.google = google
        self.myMemory = myMemory
        self.dictionary = dictionary
    }

    func analyze(_ text: String) async throws -> LearningAnalysis {
        let clean = text.cleanedSelection
        let engine = translationEngine()
        return try await engine.analyze(clean)
    }

    func loadMoreMeanings(for word: String) async throws -> [WordMeaning] {
        let clean = normalizedWord(word)
        guard isLikelyWord(clean) else { return [] }
        let dictionaryMeanings = try await dictionary.lookup(clean)
        return await translateMeanings(dictionaryMeanings, engine: translationEngine())
    }

    private func translationEngine() -> RemoteTranslationService {
        switch settingsStore.settings.translationProvider {
        case .google:
            return google
        case .mymemory:
            return myMemory
        }
    }

    private func translateMeanings(_ meanings: [WordMeaning], engine: RemoteTranslationService) async -> [WordMeaning] {
        guard !meanings.isEmpty else { return [] }
        var output = meanings
        let batchSize = 12
        var start = output.startIndex
        while start < output.endIndex {
            let end = output.index(start, offsetBy: batchSize, limitedBy: output.endIndex) ?? output.endIndex
            let definitions = output[start..<end].map(\.definition)
            if let translatedDefinitions = try? await engine.translateTexts(Array(definitions)), translatedDefinitions.count == definitions.count {
                for (offset, translatedDefinition) in translatedDefinitions.enumerated() {
                    output[output.index(start, offsetBy: offset)].translatedDefinition = translatedDefinition.nilIfBlank
                }
            }
            start = end
        }
        return output
    }
}

@MainActor
protocol RemoteTranslationService: TranslationService {
    var providerName: String { get }
    func translateText(_ text: String) async throws -> String
    func translateTexts(_ texts: [String]) async throws -> [String]
}

@MainActor
protocol DictionaryLookupService: AnyObject {
    func lookup(_ word: String) async throws -> [WordMeaning]
}

extension RemoteTranslationService {
    func loadMoreMeanings(for word: String) async throws -> [WordMeaning] {
        []
    }

    func translateTexts(_ texts: [String]) async throws -> [String] {
        var output: [String] = []
        for text in texts {
            output.append(try await translateText(text))
        }
        return output
    }
}

@MainActor
final class FixtureTranslationService: TranslationService {
    func analyze(_ text: String) async throws -> LearningAnalysis {
        let clean = text.cleanedSelection
        let translation = isLikelyWord(clean) ? fixtureWordTranslation(clean) : "测试翻译：\(clean)"
        return buildAnalysis(text: clean, translation: translation, provider: "Fixture")
    }

    func loadMoreMeanings(for word: String) async throws -> [WordMeaning] {
        guard isLikelyWord(word.cleanedSelection) else { return [] }
        return [
            WordMeaning(
                partOfSpeech: "noun",
                definition: "The circumstances that form the setting for an event, statement, or idea.",
                translatedDefinition: "事件、陈述或想法所处的背景。",
                example: "The word is easier to understand in context.",
                synonyms: ["background", "setting"]
            )
        ]
    }
}

@MainActor
final class GoogleTranslationService: RemoteTranslationService {
    let providerName = "Google Translate"

    func analyze(_ text: String) async throws -> LearningAnalysis {
        let clean = text.cleanedSelection
        let translated = try await translateText(clean)
        return buildAnalysis(text: clean, translation: translated, provider: providerName)
    }

    func translateText(_ text: String) async throws -> String {
        let clean = text.cleanedSelection
        guard var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single") else {
            throw MagReaderError.translationFailed("Invalid translation endpoint.")
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "en"),
            URLQueryItem(name: "tl", value: "zh-CN"),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: clean)
        ]
        guard let url = components.url else { throw MagReaderError.translationFailed("Invalid translation request.") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            throw MagReaderError.translationFailed("Translation status code \(http.statusCode).")
        }
        return try parseGoogleTranslationPayload(data).nilIfBlank ?? "翻译为空。"
    }

    func loadMoreMeanings(for word: String) async throws -> [WordMeaning] {
        []
    }

    func translateTexts(_ texts: [String]) async throws -> [String] {
        guard !texts.isEmpty else { return [] }
        let separator = "\n<<<MAGREADER_DEFINITION_BREAK>>>\n"
        let translated = try await translateText(texts.joined(separator: separator))
        let parts = translated
            .components(separatedBy: "<<<MAGREADER_DEFINITION_BREAK>>>")
            .map { $0.cleanedSelection }
        guard parts.count == texts.count else {
            return try await defaultSerialTranslate(texts)
        }
        return parts
    }

    private func defaultSerialTranslate(_ texts: [String]) async throws -> [String] {
        var output: [String] = []
        for text in texts {
            output.append(try await translateText(text))
        }
        return output
    }
}

@MainActor
final class MyMemoryTranslationService: RemoteTranslationService {
    let providerName = "MyMemory Translate"

    func analyze(_ text: String) async throws -> LearningAnalysis {
        let clean = text.cleanedSelection
        let translated = try await translateText(clean)
        return buildAnalysis(text: clean, translation: translated, provider: providerName)
    }

    func translateText(_ text: String) async throws -> String {
        let clean = text.cleanedSelection
        guard var components = URLComponents(string: "https://api.mymemory.translated.net/get") else {
            throw MagReaderError.translationFailed("Invalid translation endpoint.")
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: clean),
            URLQueryItem(name: "langpair", value: "en|zh-CN")
        ]
        guard let url = components.url else { throw MagReaderError.translationFailed("Invalid translation request.") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            throw MagReaderError.translationFailed("Translation status code \(http.statusCode).")
        }
        let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
        return decoded.responseData.translatedText.nilIfBlank ?? "翻译为空。"
    }

    func loadMoreMeanings(for word: String) async throws -> [WordMeaning] {
        []
    }
}

@MainActor
final class DictionaryAPIService: DictionaryLookupService {
    func lookup(_ word: String) async throws -> [WordMeaning] {
        let clean = normalizedWord(word)
        guard !clean.isEmpty else { throw MagReaderError.translationFailed("Empty word.") }
        guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
            throw MagReaderError.translationFailed("Invalid dictionary request.")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            throw MagReaderError.translationFailed("Dictionary status code \(http.statusCode).")
        }
        let meanings = try parseDictionaryEntries(data)
        guard !meanings.isEmpty else {
            throw MagReaderError.translationFailed("No dictionary meanings found.")
        }
        return meanings
    }
}

@MainActor
final class AVSpeechService: NSObject, SpeechService, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Double) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = Float(max(0.35, min(0.65, rate * 0.55)))
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

private struct MyMemoryResponse: Decodable {
    struct ResponseData: Decodable {
        var translatedText: String
    }
    var responseData: ResponseData
}

private struct DictionaryEntry: Decodable {
    struct Meaning: Decodable {
        struct Definition: Decodable {
            var definition: String
            var example: String?
            var synonyms: [String]?
        }

        var partOfSpeech: String
        var definitions: [Definition]
        var synonyms: [String]?
    }

    var meanings: [Meaning]
}

func parseDictionaryEntries(_ data: Data) throws -> [WordMeaning] {
    let entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
    var output: [WordMeaning] = []
    var seen = Set<String>()
    for entry in entries {
        for meaning in entry.meanings {
            for definition in meaning.definitions {
                let cleanDefinition = definition.definition.cleanedSelection
                guard !cleanDefinition.isEmpty else { continue }
                let key = "\(meaning.partOfSpeech)|\(cleanDefinition)"
                guard seen.insert(key).inserted else { continue }
                let synonyms = Array(((definition.synonyms ?? []) + (meaning.synonyms ?? [])).prefix(6))
                output.append(
                    WordMeaning(
                        partOfSpeech: meaning.partOfSpeech,
                        definition: cleanDefinition,
                        translatedDefinition: nil,
                        example: definition.example?.cleanedSelection.nilIfBlank,
                        synonyms: synonyms
                    )
                )
            }
        }
    }
    return output
}

func parseGoogleTranslationPayload(_ data: Data) throws -> String {
    let payload = try JSONSerialization.jsonObject(with: data)
    guard let root = payload as? [Any], let segments = root.first as? [Any] else {
        throw MagReaderError.translationFailed("Unexpected Google translation response.")
    }
    let translated = segments.compactMap { segment -> String? in
        guard let values = segment as? [Any], let text = values.first as? String else { return nil }
        return text
    }.joined()
    return translated
}

func buildAnalysis(text clean: String, translation: String, provider: String, wordMeanings: [WordMeaning] = []) -> LearningAnalysis {
    let words = clean.matches(pattern: #"[A-Za-z][A-Za-z'-]*"#)
    let wordMode = isLikelyWord(clean)
    let average = words.isEmpty ? 0 : Double(words.reduce(0) { $0 + $1.count }) / Double(words.count)
    let score = min(95, max(32, Int((Double(words.count) * 2.2 + average * 7).rounded())))
    let level = score > 82 ? "C1" : score > 68 ? "B2" : score > 52 ? "B1" : "A2"

    return LearningAnalysis(
        kind: wordMode ? .word : .sentence,
        text: clean,
        translation: translation,
        translationProvider: provider,
        wordMeanings: wordMeanings,
        explanation: wordMode
            ? "\(clean) is explained as a useful context word. Notice its part of speech and the phrase it appears in before memorizing a Chinese equivalent."
            : "这句话可以先找主句，再看从句、插入语或介词短语如何补充时间、原因、转折或条件信息。",
        phrases: extractPhrases(words),
        structure: wordMode ? ["Check the source sentence.", "Identify the word form.", "Save one natural collocation."] : splitStructure(clean),
        difficulty: Difficulty(
            level: level,
            score: score,
            reason: score > 70 ? "句子较长或包含多层修饰，适合做长难句拆解。" : "词汇和结构较直接，适合快速阅读后积累搭配。"
        )
    )
}

private func fixtureWordTranslation(_ word: String) -> String {
    let dictionary = [
        "manageable": "可处理的；可应对的",
        "clause": "从句；分句",
        "collocation": "搭配；词语组合",
        "intimidating": "令人畏惧的",
        "context": "语境；上下文",
        "relationship": "关系；关联"
    ]
    return dictionary[word.lowercased()] ?? "模拟释义：\(word)"
}

private func extractPhrases(_ words: [String]) -> [PhraseHint] {
    var phrases: [PhraseHint] = []
    var index = 0
    while index + 1 < words.count && phrases.count < 3 {
        phrases.append(PhraseHint(phrase: "\(words[index]) \(words[index + 1])", meaning: "在原句中作为一个意义单元理解，而不是逐词翻译。"))
        index += 2
    }
    return phrases.isEmpty ? [PhraseHint(phrase: "source context", meaning: "结合原句保存，复习时更容易想起用法。")] : phrases
}

private func splitStructure(_ text: String) -> [String] {
    let separators = #",\s+|;\s+|\s+(while|because|although|when|once|that|which)\s+"#
    guard let regex = try? NSRegularExpression(pattern: separators, options: [.caseInsensitive]) else { return [text] }
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    let replaced = regex.stringByReplacingMatches(in: text, range: nsRange, withTemplate: "|")
    return replaced
        .split(separator: "|")
        .prefix(5)
        .enumerated()
        .map { "\($0.offset + 1). \($0.element.trimmingCharacters(in: .whitespacesAndNewlines))" }
}

private extension String {
    var cleanedSelection: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func prefixString(_ maxLength: Int) -> String {
        String(prefix(maxLength))
    }
}
