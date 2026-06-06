import SwiftUI
import UIKit

struct RootView: View {
    let container: AppContainer
    @ObservedObject private var settingsStore: SettingsStore
    @State private var selectedTab: ViewTab = .articles

    init(container: AppContainer) {
        self.container = container
        self.settingsStore = container.settingsStore
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(ViewTab.allCases) { tab in
                NavigationStack {
                    content(for: tab)
                }
                .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                .tag(tab)
            }
        }
        .preferredColorScheme(settingsStore.settings.isDark ? .dark : .light)
    }

    @ViewBuilder
    private func content(for tab: ViewTab) -> some View {
        switch tab {
        case .articles:
            ArticlesView(container: container)
        case .feeds:
            FeedsView(container: container)
        case .saved:
            SavedView(container: container)
        case .review:
            ReviewView(container: container)
        case .settings:
            SettingsView(container: container)
        }
    }
}

struct ArticlesView: View {
    let container: AppContainer
    @State private var articles: [Article] = []
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var collapsedFeedKeys: Set<String> = []

    var filteredArticles: [Article] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return articles }
        return articles.filter { article in
            article.title.localizedCaseInsensitiveContains(searchText) ||
            (article.feedTitle ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedArticles: [ArticleFeedGroup] {
        var groups: [ArticleFeedGroup] = []
        for article in filteredArticles {
            let key = article.feedId.map(String.init) ?? article.feedTitle ?? "unknown"
            if let index = groups.firstIndex(where: { $0.key == key }) {
                groups[index].articles.append(article)
            } else {
                groups.append(
                    ArticleFeedGroup(
                        key: key,
                        title: article.feedTitle ?? "Unknown Feed",
                        articles: [article]
                    )
                )
            }
        }
        return groups
    }

    var body: some View {
        Group {
            if filteredArticles.isEmpty {
                ContentUnavailableView("No Articles", systemImage: "newspaper", description: Text("Add a feed and refresh RSS to start reading."))
            } else {
                List {
                    ForEach(groupedArticles) { group in
                        DisclosureGroup(isExpanded: expansionBinding(for: group.key)) {
                            ForEach(group.articles) { article in
                                NavigationLink(value: article.id) {
                                    ArticleRow(article: article, showsFeed: false)
                                }
                            }
                        } label: {
                            ArticleFeedHeader(title: group.title, count: group.articles.count)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationDestination(for: Int64.self) { id in
                    if let article = articles.first(where: { $0.id == id }) {
                        ArticleDetailView(container: container, article: article)
                    } else {
                        ContentUnavailableView("Article Missing", systemImage: "exclamationmark.triangle")
                    }
                }
            }
        }
        .navigationTitle("Articles")
        .searchable(text: $searchText, prompt: "Search articles")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        collapsedFeedKeys.removeAll()
                    } label: {
                        Label("Expand All", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                    Button {
                        collapsedFeedKeys = Set(groupedArticles.map(\.key))
                    } label: {
                        Label("Collapse All", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                } label: {
                    Label("Groups", systemImage: "rectangle.3.group")
                }
                .disabled(groupedArticles.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshFeeds() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
        }
        .task { load() }
        .alert("Refresh Failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() {
        articles = (try? container.database.listArticles()) ?? []
        let visibleKeys = Set(groupedArticles.map(\.key))
        collapsedFeedKeys = collapsedFeedKeys.intersection(visibleKeys)
    }

    private func expansionBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedFeedKeys.contains(key) },
            set: { isExpanded in
                if isExpanded {
                    collapsedFeedKeys.remove(key)
                } else {
                    collapsedFeedKeys.insert(key)
                }
            }
        )
    }

    private func refreshFeeds() async {
        isRefreshing = true
        let results = await container.feedRefresh.refreshAllFeeds()
        isRefreshing = false
        load()
        if let failure = results.first(where: { !$0.ok }) {
            errorMessage = failure.error ?? "One or more feeds failed."
        }
    }
}

struct ArticleFeedGroup: Identifiable {
    var key: String
    var title: String
    var articles: [Article]

    var id: String { key }
}

struct ArticleFeedHeader: View {
    var title: String
    var count: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count) articles")
    }
}

struct ArticleRow: View {
    var article: Article
    var showsFeed = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.headline)
                .lineLimit(2)
            HStack {
                if showsFeed {
                    Text(article.feedTitle ?? "Feed")
                }
                Text(article.difficulty)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let excerpt = article.excerpt, !excerpt.isEmpty {
                Text(excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

struct FeedsView: View {
    let container: AppContainer
    @State private var feeds: [Feed] = []
    @State private var url = ""
    @State private var title = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Add Feed") {
                TextField("RSS URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                TextField("Title (optional)", text: $title)
                Button {
                    addFeed()
                } label: {
                    Label("Add Feed", systemImage: "plus")
                }
                .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Feeds") {
                ForEach(feeds) { feed in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(feed.title)
                                    .font(.headline)
                                Text(feed.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Toggle("Enabled", isOn: Binding(
                                get: { feed.enabled },
                                set: { enabled in updateFeed(feed, enabled: enabled) }
                            ))
                            .labelsHidden()
                        }
                        if let error = feed.lastError, !error.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .onDelete { offsets in
                    for offset in offsets {
                        try? container.database.deleteFeed(feeds[offset].id)
                    }
                    load()
                }
            }
        }
        .navigationTitle("Feeds")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshAll() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing || feeds.isEmpty)
            }
        }
        .task { load() }
        .alert("Feed Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() {
        feeds = (try? container.database.listFeeds()) ?? []
    }

    private func addFeed() {
        do {
            try container.database.createFeed(title: title, url: url.trimmingCharacters(in: .whitespacesAndNewlines))
            title = ""
            url = ""
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateFeed(_ feed: Feed, enabled: Bool) {
        try? container.database.updateFeed(feed.id, title: nil, url: nil, enabled: enabled, siteUrl: nil, lastFetchedAt: nil, lastError: nil)
        load()
    }

    private func refreshAll() async {
        isRefreshing = true
        _ = await container.feedRefresh.refreshAllFeeds()
        isRefreshing = false
        load()
    }
}

struct ArticleDetailView: View {
    let container: AppContainer
    var article: Article
    @ObservedObject private var settingsStore: SettingsStore
    @State private var selectedText: SelectedText?
    @State private var lastSelectionText = ""
    @State private var lastSelectionAt = Date.distantPast

    init(container: AppContainer, article: Article) {
        self.container = container
        self.article = article
        self.settingsStore = container.settingsStore
    }

    var body: some View {
        ReaderWebView(article: article, settings: settingsStore.settings) { text in
            handleSelection(text)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(article.feedTitle ?? "Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    container.speech.speak(article.title, rate: settingsStore.settings.speechRate)
                } label: {
                    Label("Speak Title", systemImage: "speaker.wave.2")
                }
            }
        }
        .task {
            try? container.database.markArticle(article.id, status: .read)
        }
        .sheet(item: $selectedText) { selection in
            SelectionSheet(container: container, article: article, selection: selection)
                .presentationDetents([.height(340), .medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func handleSelection(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard selectedText == nil else { return }
        let now = Date()
        if clean == lastSelectionText, now.timeIntervalSince(lastSelectionAt) < 1.2 {
            return
        }
        lastSelectionText = clean
        lastSelectionAt = now
        selectedText = SelectedText(text: clean)
    }
}

struct SelectedText: Identifiable, Hashable {
    var id: String { text }
    var text: String
}

struct SelectionSheet: View {
    let container: AppContainer
    var article: Article
    var selection: SelectedText
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsStore: SettingsStore
    @State private var analysis: LearningAnalysis?
    @State private var isLoading = false
    @State private var isLoadingMoreMeanings = false
    @State private var message: String?

    init(container: AppContainer, article: Article, selection: SelectedText) {
        self.container = container
        self.article = article
        self.selection = selection
        self.settingsStore = container.settingsStore
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(selection.text)
                        .font(.headline.weight(.semibold))
                        .lineLimit(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: 10)], alignment: .leading, spacing: 10) {
                        Button {
                            Task { await translate() }
                        } label: {
                            Label("Translate", systemImage: "character.book.closed")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            container.speech.speak(selection.text, rate: settingsStore.settings.speechRate)
                        } label: {
                            Label("Speak", systemImage: "speaker.wave.2")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            UIPasteboard.general.string = selection.text
                            message = "Copied."
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await save() }
                        } label: {
                            Label("Save", systemImage: "bookmark")
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.small)

                    if isLoading {
                        ProgressView("Analyzing...")
                            .font(.callout)
                    }

                    if let message {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if let analysis {
                        AnalysisView(
                            analysis: analysis,
                            isLoadingMoreMeanings: isLoadingMoreMeanings,
                            onShowMoreMeanings: analysis.kind == .word ? {
                                Task { await loadMoreMeanings() }
                            } : nil
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle(isLikelyWord(selection.text) ? "Word" : "Sentence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: selection.text) {
            await translateIfNeeded()
        }
    }

    private func translate() async {
        analysis = nil
        message = nil
        isLoadingMoreMeanings = false
        isLoading = true
        defer { isLoading = false }
        do {
            analysis = try await container.translation.analyze(selection.text)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func translateIfNeeded() async {
        guard analysis == nil, !isLoading else { return }
        await translate()
    }

    private func loadMoreMeanings() async {
        guard var current = analysis, current.kind == .word, current.wordMeanings.isEmpty, !isLoadingMoreMeanings else { return }
        isLoadingMoreMeanings = true
        defer { isLoadingMoreMeanings = false }
        do {
            let meanings = try await container.translation.loadMoreMeanings(for: selection.text)
            current.wordMeanings = meanings
            if !meanings.isEmpty, !current.translationProvider.contains("Dictionary") {
                current.translationProvider += " + Dictionary"
            }
            analysis = current
            message = meanings.isEmpty ? "No dictionary meanings found." : nil
        } catch {
            message = "Dictionary lookup failed. \(error.localizedDescription)"
        }
    }

    private func save() async {
        if analysis == nil {
            await translateIfNeeded()
        }
        guard let analysis else { return }
        do {
            if analysis.kind == .word {
                _ = try container.database.saveWord(
                    word: selection.text,
                    displayWord: selection.text,
                    translation: analysis.translation,
                    meanings: analysis.wordMeanings,
                    explanation: analysis.explanation,
                    sourceSentence: sentenceAround(article.contentText, selectedText: selection.text),
                    articleId: article.id
                )
                message = "Saved as word."
            } else {
                _ = try container.database.saveSentence(
                    text: selection.text,
                    translation: analysis.translation,
                    explanation: analysis.explanation,
                    articleId: article.id
                )
                message = "Saved as sentence."
            }
        } catch {
            message = error.localizedDescription
        }
    }
}

struct AnalysisView: View {
    var analysis: LearningAnalysis
    var isLoadingMoreMeanings = false
    var onShowMoreMeanings: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(analysis.translationProvider)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(analysis.translation)
                    .font(.title3)
                    .textSelection(.enabled)
            }

            LabeledContent("Difficulty") {
                Text("\(analysis.difficulty.level) · \(analysis.difficulty.score)")
            }

            if analysis.kind == .word {
                SectionLabel("Dictionary")
                if analysis.wordMeanings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use the fast translation above, or load dictionary meanings when needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            onShowMoreMeanings?()
                        } label: {
                            Label(isLoadingMoreMeanings ? "Loading..." : "Show More Meanings", systemImage: "text.book.closed")
                        }
                        .disabled(isLoadingMoreMeanings || onShowMoreMeanings == nil)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    WordMeaningsView(meanings: analysis.wordMeanings, limit: nil)
                }
            }

            Text(analysis.explanation)
                .textSelection(.enabled)

            if !analysis.phrases.isEmpty {
                SectionLabel("Phrases")
                ForEach(analysis.phrases) { phrase in
                    VStack(alignment: .leading) {
                        Text(phrase.phrase).font(.headline)
                        Text(phrase.meaning).foregroundStyle(.secondary)
                    }
                }
            }

            if !analysis.structure.isEmpty {
                SectionLabel("Structure")
                ForEach(analysis.structure, id: \.self) { line in
                    Text(line)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct WordMeaningsView: View {
    var meanings: [WordMeaning]
    var limit: Int?
    @State private var showsAll = false

    private var visibleMeanings: [WordMeaning] {
        if let limit, !showsAll {
            return Array(meanings.prefix(limit))
        }
        return meanings
    }

    private var canToggle: Bool {
        guard let limit else { return false }
        return meanings.count > limit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(visibleMeanings) { meaning in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(meaning.partOfSpeech)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Text(meaning.translatedDefinition?.trimmedNonEmpty ?? meaning.definition)
                            .font(.callout.weight(.semibold))
                    }
                    Text(meaning.definition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    if let example = meaning.example?.trimmedNonEmpty {
                        Text(example)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                    if !meaning.synonyms.isEmpty {
                        Text("Synonyms: \(meaning.synonyms.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            if canToggle {
                Button {
                    showsAll.toggle()
                } label: {
                    Label(showsAll ? "Show Less" : "Show More Meanings", systemImage: showsAll ? "chevron.up" : "chevron.down")
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

struct SavedView: View {
    let container: AppContainer
    @State private var mode: LearningKind = .word
    @State private var words: [SavedWord] = []
    @State private var sentences: [SavedSentence] = []
    @State private var detail: SavedDetailItem?

    var body: some View {
        List {
            Picker("Saved Type", selection: $mode) {
                Text("Words").tag(LearningKind.word)
                Text("Sentences").tag(LearningKind.sentence)
            }
            .pickerStyle(.segmented)

            if mode == .word {
                ForEach(words) { word in
                    Button {
                        detail = .word(word)
                    } label: {
                        SavedWordCard(word: word)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for offset in offsets { _ = try? container.database.deleteSavedWord(words[offset].id) }
                    load()
                }
            } else {
                ForEach(sentences) { sentence in
                    Button {
                        detail = .sentence(sentence)
                    } label: {
                        SavedSentenceCard(sentence: sentence)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for offset in offsets { _ = try? container.database.deleteSavedSentence(sentences[offset].id) }
                    load()
                }
            }
        }
        .navigationTitle("Saved")
        .task { load() }
        .refreshable { load() }
        .sheet(item: $detail) { item in
            NavigationStack {
                switch item {
                case .word(let word):
                    SavedWordDetailView(container: container, word: word, reload: load)
                case .sentence(let sentence):
                    SavedSentenceDetailView(container: container, sentence: sentence, reload: load)
                }
            }
        }
    }

    private func load() {
        words = (try? container.database.listSavedWords()) ?? []
        sentences = (try? container.database.listSavedSentences()) ?? []
    }
}

enum SavedDetailItem: Identifiable {
    case word(SavedWord)
    case sentence(SavedSentence)

    var id: String {
        switch self {
        case .word(let word): "word-\(word.id)"
        case .sentence(let sentence): "sentence-\(sentence.id)"
        }
    }
}

struct ReviewView: View {
    let container: AppContainer
    @State private var items: [SavedReviewItem] = []

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView("Nothing To Review", systemImage: "rectangle.stack", description: Text("Saved words and sentences that are not mastered appear here."))
            } else {
                ForEach(items) { item in
                    ReviewCard(container: container, item: item, reload: load)
                }
            }
        }
        .navigationTitle("Review")
        .task { load() }
        .refreshable { load() }
    }

    private func load() {
        let words = ((try? container.database.listSavedWords()) ?? []).filter { $0.familiarity != .mastered }.map(SavedReviewItem.word)
        let sentences = ((try? container.database.listSavedSentences()) ?? []).filter { $0.familiarity != .mastered }.map(SavedReviewItem.sentence)
        items = words + sentences
    }
}

struct SettingsView: View {
    let container: AppContainer
    @ObservedObject private var settingsStore: SettingsStore

    init(container: AppContainer) {
        self.container = container
        self.settingsStore = container.settingsStore
    }

    var body: some View {
        Form {
            Section("Reading") {
                Toggle("Dark Mode", isOn: Binding(
                    get: { settingsStore.settings.isDark },
                    set: { enabled in settingsStore.update { $0.theme = enabled ? "dark" : "light" } }
                ))

                Picker("Font", selection: Binding(
                    get: { settingsStore.settings.fontFamily },
                    set: { value in settingsStore.update { $0.fontFamily = value } }
                )) {
                    Text("Editorial Serif").tag("Georgia")
                    Text("Clean Sans").tag("-apple-system")
                    Text("Charter").tag("Charter")
                }

                Picker("Background", selection: Binding(
                    get: { settingsStore.settings.readerBackground },
                    set: { value in settingsStore.update { $0.readerBackground = value } }
                )) {
                    Text("Paper").tag("paper")
                    Text("White").tag("white")
                    Text("Warm").tag("warm")
                    Text("Green").tag("green")
                    Text("Gray").tag("gray")
                }

                SliderRow(title: "Font Size", value: Binding(
                    get: { settingsStore.settings.fontSize },
                    set: { value in settingsStore.update { $0.fontSize = value } }
                ), range: 16...28, step: 1)

                SliderRow(title: "Line Height", value: Binding(
                    get: { settingsStore.settings.lineHeight },
                    set: { value in settingsStore.update { $0.lineHeight = value } }
                ), range: 1.35...2.2, step: 0.05)

                SliderRow(title: "Paragraph Gap", value: Binding(
                    get: { settingsStore.settings.paragraphGap },
                    set: { value in settingsStore.update { $0.paragraphGap = value } }
                ), range: 0.8...1.8, step: 0.05)
            }

            Section("Learning") {
                Picker("Translation", selection: Binding(
                    get: { settingsStore.settings.translationProvider },
                    set: { value in settingsStore.update { $0.translationProvider = value } }
                )) {
                    ForEach(TranslationProvider.allCases) { provider in
                        Text(provider.label).tag(provider)
                    }
                }

                SliderRow(title: "Speech Rate", value: Binding(
                    get: { settingsStore.settings.speechRate },
                    set: { value in settingsStore.update { $0.speechRate = value } }
                ), range: 0.7...1.2, step: 0.05)
            }
        }
        .navigationTitle("Settings")
    }
}

struct SavedWordCard: View {
    var word: SavedWord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(word.displayWord).font(.headline)
            Text(word.translation)
                .lineLimit(2)
            if word.count > 1 {
                Text("Saved \(word.count) times")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !word.meanings.isEmpty {
                Text("\(word.meanings.count) dictionary meaning(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SavedWordDetailView: View {
    let container: AppContainer
    var word: SavedWord
    var reload: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var meanings: [WordMeaning]
    @State private var isLoadingMoreMeanings = false
    @State private var message: String?

    init(container: AppContainer, word: SavedWord, reload: @escaping () -> Void) {
        self.container = container
        self.word = word
        self.reload = reload
        _meanings = State(initialValue: word.meanings)
    }

    var body: some View {
        List {
            Section {
                Text(word.displayWord).font(.title2.weight(.semibold))
                Text(word.translation)
                if word.count > 1 {
                    Text("Saved \(word.count) times")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Dictionary") {
                if meanings.isEmpty {
                    Text("Fast translation is saved. Load dictionary meanings when you need details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await loadMoreMeanings() }
                    } label: {
                        Label(isLoadingMoreMeanings ? "Loading..." : "Show More Meanings", systemImage: "text.book.closed")
                    }
                    .disabled(isLoadingMoreMeanings)
                } else {
                    WordMeaningsView(meanings: meanings, limit: word.meanings.isEmpty ? nil : 1)
                }
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Notes") {
                Text(word.explanation)
                if let source = word.sourceSentence?.trimmedNonEmpty {
                    Text(source)
                        .foregroundStyle(.secondary)
                }
                if let title = word.articleTitle?.trimmedNonEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Review") {
                FamiliarityPicker(value: word.familiarity) { status in
                    try? container.database.updateReview(kind: .word, id: word.id, familiarity: status)
                    reload()
                }
            }
        }
        .navigationTitle("Word Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    container.speech.speak(word.displayWord, rate: container.settingsStore.settings.speechRate)
                } label: {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
            }
        }
    }

    private func loadMoreMeanings() async {
        guard meanings.isEmpty, !isLoadingMoreMeanings else { return }
        isLoadingMoreMeanings = true
        defer { isLoadingMoreMeanings = false }
        do {
            let loaded = try await container.translation.loadMoreMeanings(for: word.displayWord)
            meanings = loaded
            if loaded.isEmpty {
                message = "No dictionary meanings found."
            } else {
                _ = try container.database.updateSavedWordMeanings(word.id, meanings: loaded)
                reload()
                message = nil
            }
        } catch {
            message = "Dictionary lookup failed. \(error.localizedDescription)"
        }
    }
}

struct SavedSentenceDetailView: View {
    let container: AppContainer
    var sentence: SavedSentence
    var reload: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text(sentence.text)
                    .font(.headline)
                    .textSelection(.enabled)
                Text(sentence.translation)
                    .textSelection(.enabled)
            }
            Section("Notes") {
                Text(sentence.explanation)
                if let title = sentence.articleTitle?.trimmedNonEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Review") {
                FamiliarityPicker(value: sentence.familiarity) { status in
                    try? container.database.updateReview(kind: .sentence, id: sentence.id, familiarity: status)
                    reload()
                }
            }
        }
        .navigationTitle("Sentence Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    container.speech.speak(sentence.text, rate: container.settingsStore.settings.speechRate)
                } label: {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
            }
        }
    }
}

struct SavedSentenceCard: View {
    var sentence: SavedSentence

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sentence.text)
                .font(.headline)
                .lineLimit(2)
            Text(sentence.translation)
                .lineLimit(2)
            Text(sentence.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct ReviewCard: View {
    let container: AppContainer
    var item: SavedReviewItem
    var reload: () -> Void
    @State private var revealed = false
    @State private var confirmsMasteredDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.text).font(.headline)
            if revealed {
                Text(item.translation)
                if case .word(let word) = item, !word.meanings.isEmpty {
                    WordMeaningsView(meanings: word.meanings, limit: 1)
                }
                Text(item.explanation).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Answer hidden").foregroundStyle(.secondary)
            }
            HStack {
                Button(revealed ? "Hide" : "Reveal") { revealed.toggle() }
                    .buttonStyle(.bordered)
                Button {
                    container.speech.speak(item.text, rate: container.settingsStore.settings.speechRate)
                } label: {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
                .buttonStyle(.bordered)
            }
            FamiliarityPicker(value: item.familiarity) { status in
                if status == .mastered {
                    confirmsMasteredDelete = true
                } else {
                    updateFamiliarity(status)
                }
            }
        }
        .alert("Mark as mastered?", isPresented: $confirmsMasteredDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("This will remove the saved item from Review and Saved.")
        }
    }

    private func updateFamiliarity(_ status: Familiarity) {
        switch item {
        case .word(let word):
            try? container.database.updateReview(kind: .word, id: word.id, familiarity: status)
        case .sentence(let sentence):
            try? container.database.updateReview(kind: .sentence, id: sentence.id, familiarity: status)
        }
        reload()
    }

    private func deleteItem() {
        switch item {
        case .word(let word):
            _ = try? container.database.deleteSavedWord(word.id)
        case .sentence(let sentence):
            _ = try? container.database.deleteSavedSentence(sentence.id)
        }
        reload()
    }
}

struct FamiliarityPicker: View {
    var value: Familiarity
    var onChange: (Familiarity) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Familiarity.allCases) { status in
                Button(status.rawValue) {
                    onChange(status)
                }
                .font(.caption.weight(status == value ? .semibold : .regular))
                .buttonStyle(.bordered)
                .tint(status == value ? .accentColor : .secondary)
            }
        }
    }
}

struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(step < 1 ? 2 : 0))))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct SectionLabel: View {
    var title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
