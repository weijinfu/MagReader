import Foundation

enum MagReaderError: LocalizedError {
    case database(String)
    case invalidURL
    case feedParseFailed
    case translationFailed(String)

    var errorDescription: String? {
        switch self {
        case .database(let message): message
        case .invalidURL: "Invalid URL."
        case .feedParseFailed: "Could not parse the feed."
        case .translationFailed(let message): message
        }
    }
}

func now() -> Date {
    Date()
}

func encodeDate(_ date: Date?) -> String? {
    guard let date else { return nil }
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return isoFormatter.string(from: date)
}

func decodeDate(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let fallbackISOFormatter = ISO8601DateFormatter()
    fallbackISOFormatter.formatOptions = [.withInternetDateTime]
    return isoFormatter.date(from: value) ?? fallbackISOFormatter.date(from: value) ?? parseRFC822Date(value)
}

func parseRFC822Date(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return formatter.date(from: value)
}

func stripHTML(_ html: String) -> String {
    html
        .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func sanitizeHTML(_ html: String) -> String {
    html
        .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: "", options: .regularExpression)
        .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\son\\w+\\s*=\\s*\"[^\"]*\"", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\son\\w+\\s*=\\s*'[^']*'", with: "", options: .regularExpression)
}

func escapeHTML(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

func isLikelyWord(_ text: String) -> Bool {
    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return false }
    return clean.range(of: #"^[A-Za-z][A-Za-z'-]*$"#, options: .regularExpression) != nil
}

func normalizedWord(_ text: String) -> String {
    text
        .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        .lowercased()
}

func rateArticleDifficulty(_ text: String) -> String {
    let words = text.matches(pattern: #"[A-Za-z][A-Za-z'-]*"#)
    guard !words.isEmpty else { return "A2" }
    let averageWordLength = Double(words.reduce(0) { $0 + $1.count }) / Double(words.count)
    let sentenceCount = max(1, text.split { ".!?".contains($0) }.count)
    let averageSentenceLength = Double(words.count) / Double(sentenceCount)
    if averageSentenceLength > 28 || averageWordLength > 6.2 { return "C1" }
    if averageSentenceLength > 22 || averageWordLength > 5.6 { return "B2" }
    if averageSentenceLength > 15 { return "B1" }
    return "A2"
}

func sentenceAround(_ articleText: String, selectedText: String) -> String? {
    guard let range = articleText.range(of: selectedText) else { return nil }
    let prefix = articleText[..<range.lowerBound]
    let suffix = articleText[range.upperBound...]
    let start = prefix.lastIndex(where: { ".!?".contains($0) }).map { articleText.index(after: $0) } ?? articleText.startIndex
    let end = suffix.firstIndex(where: { ".!?".contains($0) }).map { articleText.index(after: $0) } ?? articleText.endIndex
    return String(articleText[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
}

extension String {
    func matches(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: self) else { return nil }
            return String(self[swiftRange])
        }
    }
}
