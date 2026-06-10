import Foundation

enum ExportFormat: String {
    case json
    case csv
}

struct ExportedFile {
    var filename: String
    var contentType: String
    var data: Data
}

@MainActor
final class ExportService {
    private let database: DatabaseClient
    private let dateProvider: () -> Date

    init(database: DatabaseClient, dateProvider: @escaping () -> Date = Date.init) {
        self.database = database
        self.dateProvider = dateProvider
    }

    func exportSavedItems(format: ExportFormat) throws -> ExportedFile {
        let exportedAt = encodeDate(dateProvider()) ?? ISO8601DateFormatter().string(from: dateProvider())
        let words = try database.listSavedWords()
        let sentences = try database.listSavedSentences()
        switch format {
        case .json:
            let payload = SavedItemsExportPayload(words: words, sentences: sentences, exportedAt: exportedAt)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            return ExportedFile(filename: "magreader-export.json", contentType: "application/json", data: data)
        case .csv:
            var rows = [["type", "text", "translation", "explanation", "familiarity", "source", "exportedAt"]]
            rows += words.map { ["word", $0.displayWord, $0.translation, $0.explanation, $0.familiarity.rawValue, $0.articleTitle ?? "", exportedAt] }
            rows += sentences.map { ["sentence", $0.text, $0.translation, $0.explanation, $0.familiarity.rawValue, $0.articleTitle ?? "", exportedAt] }
            let csv = rows.map { row in row.map(csvEscape).joined(separator: ",") }.joined(separator: "\n")
            return ExportedFile(filename: "magreader-export.csv", contentType: "text/csv", data: Data(csv.utf8))
        }
    }
}

private struct SavedItemsExportPayload: Encodable {
    var words: [SavedWord]
    var sentences: [SavedSentence]
    var exportedAt: String
}

private func csvEscape(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
}
