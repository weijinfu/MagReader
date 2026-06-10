import SwiftUI

@main
struct MagReaderMacApp: App {
    @StateObject private var container = MacAppContainer.live()

    var body: some Scene {
        WindowGroup {
            MacRootView(container: container)
                .tint(MacDesign.accent)
                .frame(minWidth: 900, minHeight: 680)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh RSS") {
                    container.send(.refreshAll)
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Export CSV") {
                    container.send(.exportCSV)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Export JSON") {
                    container.send(.exportJSON)
                }
            }

            CommandMenu("Reader") {
                Button("Increase Text Size") {
                    container.settingsStore.update { $0.fontSize = min(30, $0.fontSize + 1) }
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Decrease Text Size") {
                    container.settingsStore.update { $0.fontSize = max(15, $0.fontSize - 1) }
                }
                .keyboardShortcut("-", modifiers: [.command])

                Button("Stop Speaking") {
                    container.speech.stop()
                }
                .keyboardShortcut(".", modifiers: [.command])
            }
        }

        Settings {
            MacSettingsView(container: container)
        }
    }
}

enum MacCommand {
    case refreshAll
    case exportCSV
    case exportJSON
}

@MainActor
final class MacAppContainer: ObservableObject {
    let database: DatabaseClient
    let feedRefresh: FeedRefreshService
    let translation: TranslationService
    let speech: SpeechService
    let settingsStore: SettingsStore
    private var commandHandler: ((MacCommand) -> Void)?

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

    static func live() -> MacAppContainer {
        do {
            let database = try macDatabase()
            let settingsStore = SettingsStore(database: database)
            return MacAppContainer(
                database: database,
                feedRefresh: URLSessionFeedRefreshService(database: database),
                translation: CompositeTranslationService(settingsStore: settingsStore),
                speech: MacSpeechService(),
                settingsStore: settingsStore
            )
        } catch {
            let fallback = InMemoryDatabase()
            let settingsStore = SettingsStore(database: fallback)
            return MacAppContainer(
                database: fallback,
                feedRefresh: URLSessionFeedRefreshService(database: fallback),
                translation: CompositeTranslationService(settingsStore: settingsStore),
                speech: MacSpeechService(),
                settingsStore: settingsStore
            )
        }
    }

    func bindCommands(_ handler: @escaping (MacCommand) -> Void) {
        commandHandler = handler
    }

    func send(_ command: MacCommand) {
        commandHandler?(command)
    }

    private static func macDatabase() throws -> SQLiteDatabase {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appending(path: "MagReaderMac", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try SQLiteDatabase(path: directory.appending(path: "magreader-macos.db").path)
    }
}
