import AppKit
import SwiftUI

enum MacDesign {
    static let background = Color(red: 0.969, green: 0.976, blue: 0.973)
    static let panel = Color(nsColor: .textBackgroundColor)
    static let panelSubtle = Color(red: 0.949, green: 0.965, blue: 0.961)
    static let line = Color(red: 0.875, green: 0.906, blue: 0.894)
    static let accent = Color(red: 0.059, green: 0.561, blue: 0.518)
    static let accentStrong = Color(red: 0.031, green: 0.455, blue: 0.427)
    static let accentSoft = Color(red: 0.824, green: 0.925, blue: 0.906)
    static let muted = Color(red: 0.408, green: 0.467, blue: 0.463)
    static let shadow = Color.black.opacity(0.055)
}

enum MacSection: String, CaseIterable, Identifiable {
    case articles
    case feeds
    case words
    case sentences
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .articles: "Articles"
        case .feeds: "Feeds"
        case .words: "Saved Words"
        case .sentences: "Sentences"
        case .review: "Review"
        }
    }

    var systemImage: String {
        switch self {
        case .articles: "newspaper"
        case .feeds: "antenna.radiowaves.left.and.right"
        case .words: "bookmark"
        case .sentences: "text.quote"
        case .review: "rectangle.stack"
        }
    }

    var shortcut: Character {
        switch self {
        case .articles: "1"
        case .feeds: "2"
        case .words: "3"
        case .sentences: "4"
        case .review: "5"
        }
    }
}

struct MacRootView: View {
    @ObservedObject var container: MacAppContainer
    @ObservedObject private var settingsStore: SettingsStore
    @AppStorage("selectedMacSection") private var selectedSectionRaw = MacSection.articles.rawValue
    @AppStorage("macSidebarCollapsed") private var sidebarCollapsed = false
    @AppStorage("macArticleListCollapsed") private var articleListCollapsed = false
    @State private var articles: [Article] = []
    @State private var feeds: [Feed] = []
    @State private var words: [SavedWord] = []
    @State private var sentences: [SavedSentence] = []
    @State private var selectedArticleId: Article.ID?
    @State private var selectedAnalysis: LearningAnalysis?
    @State private var selectedText = ""
    @State private var isAnalyzing = false
    @State private var statusMessage = ""
    @State private var searchText = ""
    @State private var expandedFeeds = Set<Int64>()
    @State private var inspectorVisible = true
    @State private var addFeedPresented = false
    @State private var feedTitleInput = ""
    @State private var feedURLInput = ""
    @State private var feedFormMessage = ""
    @State private var isAddingFeed = false
    @State private var didApplyInitialSection = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var sidebarWidth: CGFloat = 184
    @State private var contentWidth: CGFloat = 360

    init(container: MacAppContainer) {
        self.container = container
        self.settingsStore = container.settingsStore
    }

    private var selectedSection: MacSection {
        get { MacSection(rawValue: selectedSectionRaw) ?? .articles }
        nonmutating set { selectedSectionRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let dividerWidth: CGFloat = 8
                let isArticleSection = selectedSection == .articles
                let isCompactWindow = proxy.size.width < 1080
                let shouldShowInspector = isArticleSection && !isCompactWindow && inspectorVisible
                let shouldShowArticleList = isArticleSection && !articleListCollapsed
                let sidebarTargetWidth: CGFloat = sidebarCollapsed ? 72 : sidebarWidth
                let readerMinWidth: CGFloat = isCompactWindow ? 420 : 620
                let inspectorWidth: CGFloat = shouldShowInspector ? 300 : 0
                let articleListDividerWidth: CGFloat = shouldShowArticleList ? dividerWidth : 0
                let maxSidebarWidth = min(240, max(168, proxy.size.width - contentWidth - readerMinWidth - inspectorWidth - articleListDividerWidth - dividerWidth))
                let actualSidebarWidth = sidebarCollapsed ? 72 : min(max(sidebarTargetWidth, 168), maxSidebarWidth)
                let maxContentWidth = max(280, proxy.size.width - actualSidebarWidth - readerMinWidth - inspectorWidth - articleListDividerWidth - dividerWidth)
                let actualContentWidth = min(max(contentWidth, 280), maxContentWidth)

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: actualSidebarWidth)

                    if sidebarCollapsed {
                        Rectangle()
                            .fill(MacDesign.line)
                            .frame(width: 1)
                    } else {
                        ResizableDivider(
                            width: Binding(
                                get: { sidebarWidth },
                                set: { sidebarWidth = min(max($0, 168), maxSidebarWidth) }
                            ),
                            minWidth: 168,
                            maxWidth: maxSidebarWidth
                        )
                    }

                    if isArticleSection {
                        if shouldShowArticleList {
                            content
                                .frame(width: actualContentWidth)

                            ResizableDivider(
                                width: Binding(
                                    get: { contentWidth },
                                    set: { contentWidth = min(max($0, 280), maxContentWidth) }
                                ),
                                minWidth: 280,
                                maxWidth: maxContentWidth
                            )
                        }

                        readerDetail(inspectorWidth: inspectorWidth, showInspector: shouldShowInspector)
                            .frame(minWidth: readerMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(MacDesign.background)
            .navigationTitle(selectedSection.title)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search articles, words, or sentences")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    sidebarCollapsed.toggle()
                } label: {
                    Label(sidebarCollapsed ? "Show Sidebar" : "Hide Sidebar", systemImage: sidebarCollapsed ? "sidebar.left" : "sidebar.leading")
                }
                if selectedSection == .articles {
                    Button {
                        articleListCollapsed.toggle()
                    } label: {
                        Label(articleListCollapsed ? "Show List" : "Hide List", systemImage: articleListCollapsed ? "list.bullet.rectangle" : "rectangle.leadinghalf.inset.filled")
                    }
                }
                Button {
                    refreshAll()
                } label: {
                    Label("Refresh RSS", systemImage: "arrow.clockwise")
                }
                Button {
                    addFeedPresented = true
                } label: {
                    Label("Add Feed", systemImage: "plus")
                }
                Button {
                    inspectorVisible.toggle()
                } label: {
                    Label("Inspector", systemImage: inspectorVisible ? "sidebar.right" : "sidebar.trailing")
                }
                Menu {
                    Button("CSV") { export(.csv) }
                    Button("JSON") { export(.json) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $addFeedPresented) {
            AddFeedSheet(container: container, reload: reloadAll)
        }
        .task {
            reloadAll()
            container.bindCommands { command in
                switch command {
                case .refreshAll: refreshAll()
                case .exportCSV: export(.csv)
                case .exportJSON: export(.json)
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: sidebarCollapsed ? .center : .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: MacDesign.shadow, radius: 4, x: 0, y: 2)
                if !sidebarCollapsed {
                    Text("MagReader")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Spacer()
                }
                Button {
                    sidebarCollapsed.toggle()
                } label: {
                    Image(systemName: sidebarCollapsed ? "chevron.right" : "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MacDesign.muted)
                .help(sidebarCollapsed ? "Expand navigation" : "Collapse navigation")
            }
            .padding(.horizontal, sidebarCollapsed ? 0 : 14)
            .padding(.top, 20)

            VStack(spacing: 4) {
                ForEach(MacSection.allCases) { item in
                    Button {
                        selectedSection = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.systemImage)
                                .frame(width: 18)
                            if !sidebarCollapsed {
                                Text(item.title)
                                    .font(.system(.body, design: .rounded, weight: selectedSection == item ? .semibold : .regular))
                                Spacer()
                            }
                        }
                        .foregroundStyle(selectedSection == item ? .primary : .secondary)
                        .padding(.horizontal, sidebarCollapsed ? 10 : 12)
                        .padding(.vertical, 9)
                        .background(selectedSection == item ? MacDesign.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selectedSection == item ? MacDesign.line : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent(item.shortcut), modifiers: [.command])
                    .accessibilityLabel(item.title)
                    .help(item.title)
                }
            }
            .padding(.horizontal, sidebarCollapsed ? 8 : 10)
            Spacer()
        }
        .background(MacDesign.panel.opacity(0.92))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MacDesign.line)
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .articles:
            articleList
        case .feeds:
            feedsView
        case .words:
            savedWordsView
        case .sentences:
            savedSentencesView
        case .review:
            reviewView
        }
    }

    private var articleList: some View {
        VStack(spacing: 0) {
            MacSectionHeader(
                title: "Articles",
                subtitle: "\(filteredArticles.count) unread and saved source items",
                trailing: {
                    HStack(spacing: 8) {
                        Button("Expand All") {
                            expandedFeeds = Set(groupedArticles.map(\.feedId))
                        }
                        .controlSize(.small)
                        Button("Collapse All") {
                            expandedFeeds.removeAll()
                        }
                        .controlSize(.small)
                    }
                }
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    if groupedArticles.isEmpty {
                        ContentUnavailableView("No Articles", systemImage: "newspaper", description: Text("Add a feed and refresh RSS to start reading."))
                            .frame(maxWidth: .infinity, minHeight: 360)
                    }
                    ForEach(groupedArticles) { group in
                        DisclosureGroup(isExpanded: Binding(
                            get: { expandedFeeds.contains(group.feedId) },
                            set: { isExpanded in
                                if isExpanded { expandedFeeds.insert(group.feedId) } else { expandedFeeds.remove(group.feedId) }
                            }
                        )) {
                            VStack(spacing: 8) {
                                ForEach(group.articles) { article in
                                    Button {
                                        selectedArticleId = article.id
                                    } label: {
                                        ArticleRow(article: article, isSelected: selectedArticleId == article.id)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: expandedFeeds.contains(group.feedId) ? "chevron.down" : "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MacDesign.muted)
                                Text(group.title)
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                                Spacer()
                                Text("\(group.articles.count)")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.quaternary, in: Capsule())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(MacDesign.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(MacDesign.background)
        .navigationTitle("Articles")
    }

    private var feedsView: some View {
        VStack(spacing: 0) {
            MacSectionHeader(
                title: "Feeds",
                subtitle: feeds.isEmpty ? "Add an RSS or Atom feed to begin" : "\(feeds.count) source\(feeds.count == 1 ? "" : "s")",
                trailing: {
                    Button {
                        refreshAll()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                }
            )

            ScrollView {
                VStack(spacing: 14) {
                    feedForm

                    if feeds.isEmpty {
                        ContentUnavailableView("No Feeds", systemImage: "antenna.radiowaves.left.and.right", description: Text("Paste an RSS or Atom URL above."))
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        ForEach(feeds) { feed in
                            FeedRow(feed: feed, refresh: {
                                refresh(feed)
                            }, toggle: { enabled in
                                try? container.database.updateFeed(feed.id, title: nil, url: nil, enabled: enabled, siteUrl: nil, lastFetchedAt: nil, lastError: nil)
                                reloadAll()
                            }, delete: {
                                try? container.database.deleteFeed(feed.id)
                                reloadAll()
                            })
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(MacDesign.background)
        .navigationTitle("Feeds")
    }

    private var feedForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Feed")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            TextField("Title (optional)", text: $feedTitleInput)
                .textFieldStyle(.roundedBorder)
            TextField("RSS or Atom URL", text: $feedURLInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addFeedInline)
            HStack {
                Button {
                    addFeedInline()
                } label: {
                    if isAddingFeed {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Add Feed", systemImage: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAddingFeed || feedURLInput.cleanedSelection.isEmpty)

                if !feedFormMessage.isEmpty {
                    Text(feedFormMessage)
                        .font(.caption)
                        .foregroundStyle(feedFormMessage == "Feed added." ? Color.secondary : Color.red)
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacDesign.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MacDesign.line)
        )
        .shadow(color: MacDesign.shadow, radius: 16, x: 0, y: 10)
    }

    private var savedWordsView: some View {
        learningListPage(
            title: "Saved Words",
            subtitle: "Showing \(filteredWords.count) of \(words.count). Pronounce, review, and manage saved vocabulary."
        ) {
            if filteredWords.isEmpty {
                EmptyCard(title: "No Saved Words", systemImage: "bookmark", message: "Save words while reading to build your review queue.")
            } else {
                ForEach(filteredWords) { word in
                    SavedWordCard(
                        word: word,
                        speak: { container.speech.speak(word.displayWord, rate: settingsStore.settings.speechRate) },
                        update: { status in
                            try? container.database.updateReview(kind: .word, id: word.id, familiarity: status)
                            reloadAll()
                        },
                        delete: {
                            _ = try? container.database.deleteSavedWord(word.id)
                            reloadAll()
                        }
                    )
                }
            }
        }
        .navigationTitle("Saved Words")
    }

    private var savedSentencesView: some View {
        learningListPage(
            title: "Saved Sentences",
            subtitle: "Showing \(filteredSentences.count) of \(sentences.count). Review translated sentences and source context."
        ) {
            if filteredSentences.isEmpty {
                EmptyCard(title: "No Saved Sentences", systemImage: "text.quote", message: "Save useful sentences from articles to review them here.")
            } else {
                ForEach(filteredSentences) { sentence in
                    SavedSentenceCard(
                        sentence: sentence,
                        speak: { container.speech.speak(sentence.text, rate: settingsStore.settings.speechRate) },
                        update: { status in
                            try? container.database.updateReview(kind: .sentence, id: sentence.id, familiarity: status)
                            reloadAll()
                        },
                        delete: {
                            _ = try? container.database.deleteSavedSentence(sentence.id)
                            reloadAll()
                        }
                    )
                }
            }
        }
        .navigationTitle("Sentences")
    }

    private var reviewView: some View {
        learningListPage(
            title: "Review",
            subtitle: "\(reviewItems.count) active item\(reviewItems.count == 1 ? "" : "s"). Reveal answers only when you need them."
        ) {
            if reviewItems.isEmpty {
                EmptyCard(title: "No Review Items", systemImage: "rectangle.stack", message: "Saved words and sentences that are not mastered will appear here.")
            } else {
                ForEach(reviewItems) { item in
                    ReviewRow(container: container, item: item, reload: reloadAll)
                }
            }
        }
        .navigationTitle("Review")
    }

    private func learningListPage<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            MacSectionHeader(title: title, subtitle: subtitle) {
                EmptyView()
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    content()
                }
                .padding(18)
                .frame(maxWidth: 880, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(MacDesign.background)
    }

    private func readerDetail(inspectorWidth: CGFloat, showInspector: Bool) -> some View {
        HStack(spacing: 0) {
            if let article = selectedArticle {
                ZStack {
                    MacDesign.background
                    MacReaderWebView(article: article, settings: settingsStore.settings) { text in
                        selectedText = text
                        selectedAnalysis = nil
                        analyze(text)
                    }
                    .id("\(article.id)-\(settingsStore.settings)")
                }
            } else {
                ContentUnavailableView("Select An Article", systemImage: "newspaper", description: Text("Choose an article from the list to start reading."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MacDesign.background)
            }

            if showInspector {
                Divider()
                LearningInspector(
                    container: container,
                    article: selectedArticle,
                    selectedText: selectedText,
                    analysis: selectedAnalysis,
                    isAnalyzing: isAnalyzing,
                    statusMessage: statusMessage,
                    analyze: { analyze(selectedText) },
                    loadMore: loadMoreMeanings,
                    save: saveSelection,
                    clear: {
                        selectedText = ""
                        selectedAnalysis = nil
                        statusMessage = ""
                    }
                )
                .frame(width: inspectorWidth)
            }
        }
        .background(MacDesign.background)
    }

    private var selectedArticle: Article? {
        guard let selectedArticleId else { return filteredArticles.first }
        return articles.first { $0.id == selectedArticleId }
    }

    private var filteredArticles: [Article] {
        guard !searchText.isEmpty else { return articles }
        return articles.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.contentText.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredWords: [SavedWord] {
        guard !searchText.isEmpty else { return words }
        return words.filter { $0.displayWord.localizedCaseInsensitiveContains(searchText) || $0.translation.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredSentences: [SavedSentence] {
        guard !searchText.isEmpty else { return sentences }
        return sentences.filter { $0.text.localizedCaseInsensitiveContains(searchText) || $0.translation.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedArticles: [ArticleGroup] {
        let groups = Dictionary(grouping: filteredArticles) { $0.feedId ?? -1 }
        return groups.map { feedId, values in
            ArticleGroup(feedId: feedId, title: values.first?.feedTitle ?? "Unknown Feed", articles: values)
        }
        .sorted { $0.title < $1.title }
    }

    private var reviewItems: [ReviewItem] {
        let wordItems = words.filter { $0.familiarity != .mastered }.map(ReviewItem.word)
        let sentenceItems = sentences.filter { $0.familiarity != .mastered }.map(ReviewItem.sentence)
        return wordItems + sentenceItems
    }

    private func reloadAll() {
        feeds = (try? container.database.listFeeds()) ?? []
        articles = (try? container.database.listArticles()) ?? []
        words = (try? container.database.listSavedWords()) ?? []
        sentences = (try? container.database.listSavedSentences()) ?? []
        if !didApplyInitialSection {
            didApplyInitialSection = true
            if feeds.isEmpty {
                selectedSection = .feeds
            }
        }
        if expandedFeeds.isEmpty {
            expandedFeeds = Set(groupedArticles.map(\.feedId))
        }
    }

    private func refreshAll() {
        refreshTask?.cancel()
        refreshTask = Task {
            _ = await container.feedRefresh.refreshAllFeeds()
            reloadAll()
        }
    }

    private func refresh(_ feed: Feed) {
        refreshTask?.cancel()
        refreshTask = Task {
            _ = await container.feedRefresh.refreshFeed(feed)
            reloadAll()
        }
    }

    private func addFeedInline() {
        let url = feedURLInput.cleanedSelection
        guard !url.isEmpty else { return }
        isAddingFeed = true
        feedFormMessage = ""
        do {
            try container.database.createFeed(title: feedTitleInput.cleanedSelection.nilIfBlank, url: url)
            feedTitleInput = ""
            feedURLInput = ""
            feedFormMessage = "Feed added."
            reloadAll()
        } catch {
            feedFormMessage = error.localizedDescription
        }
        isAddingFeed = false
    }

    private func analyze(_ text: String) {
        guard !text.cleanedSelection.isEmpty else { return }
        isAnalyzing = true
        statusMessage = ""
        Task {
            do {
                selectedAnalysis = try await container.translation.analyze(text)
                statusMessage = "Analyzed"
            } catch {
                statusMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    private func loadMoreMeanings() {
        guard let analysis = selectedAnalysis, analysis.kind == .word else { return }
        isAnalyzing = true
        Task {
            do {
                let meanings = try await container.translation.loadMoreMeanings(for: analysis.text)
                selectedAnalysis?.wordMeanings = meanings
                statusMessage = meanings.isEmpty ? "No dictionary meanings found." : "Loaded \(meanings.count) meaning(s)."
            } catch {
                statusMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    private func saveSelection() {
        guard let analysis = selectedAnalysis else { return }
        do {
            if analysis.kind == .word {
                _ = try container.database.saveWord(
                    word: analysis.text,
                    displayWord: analysis.text,
                    translation: analysis.translation,
                    meanings: analysis.wordMeanings,
                    explanation: analysis.explanation,
                    sourceSentence: selectedArticle?.contentText.nilIfBlank,
                    articleId: selectedArticle?.id
                )
                statusMessage = "Saved word."
            } else {
                _ = try container.database.saveSentence(text: analysis.text, translation: analysis.translation, explanation: analysis.explanation, articleId: selectedArticle?.id)
                statusMessage = "Saved sentence."
            }
            reloadAll()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func export(_ format: ExportFormat) {
        do {
            let file = try ExportService(database: container.database).exportSavedItems(format: format)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = file.filename
            panel.canCreateDirectories = true
            let response = panel.runModal()
            guard response == .OK, let url = panel.url else { return }
            try file.data.write(to: url)
            statusMessage = "Exported \(file.filename)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

struct ArticleGroup: Identifiable {
    var feedId: Int64
    var title: String
    var articles: [Article]
    var id: Int64 { feedId }
}

struct ResizableDivider: View {
    @Binding var width: CGFloat
    var minWidth: CGFloat
    var maxWidth: CGFloat
    @State private var dragStartWidth: CGFloat?
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? MacDesign.accent.opacity(0.16) : MacDesign.line.opacity(0.68))
            .frame(width: 8)
            .overlay(
                Capsule()
                    .fill(isHovering ? MacDesign.accent : MacDesign.line)
                    .frame(width: 2, height: 44)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartWidth == nil {
                            dragStartWidth = width
                        }
                        let upperBound = max(minWidth, maxWidth)
                        let proposedWidth = (dragStartWidth ?? width) + value.translation.width
                        width = min(max(proposedWidth, minWidth), upperBound)
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                    }
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .help("Drag to resize")
    }
}

struct MacSectionHeader<Trailing: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(MacDesign.background.opacity(0.94))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MacDesign.line)
                .frame(height: 1)
        }
    }
}

struct ArticleRow: View {
    var article: Article
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            HStack(spacing: 8) {
                Text(article.difficulty)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(MacDesign.panelSubtle, in: Capsule())
                if let published = article.publishedAt {
                    Text(published.formatted(date: .abbreviated, time: .omitted))
                }
                if let feedTitle = article.feedTitle {
                    Text(feedTitle)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let excerpt = article.excerpt, !excerpt.isEmpty {
                Text(excerpt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(isSelected ? MacDesign.accent.opacity(0.08) : MacDesign.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? MacDesign.accent.opacity(0.65) : MacDesign.line)
        )
        .shadow(color: isSelected ? MacDesign.accent.opacity(0.10) : MacDesign.shadow, radius: isSelected ? 10 : 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct FeedRow: View {
    var feed: Feed
    var refresh: () -> Void
    var toggle: (Bool) -> Void
    var delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Toggle("", isOn: Binding(
                    get: { feed.enabled },
                    set: { enabled in toggle(enabled) }
                ))
                .labelsHidden()
                VStack(alignment: .leading, spacing: 3) {
                    Text(feed.title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Text(feed.enabled ? "Enabled" : "Disabled")
                        .font(.caption)
                        .foregroundStyle(feed.enabled ? Color.secondary : Color.orange)
                }
                Spacer()
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                Button(role: .destructive) {
                    delete()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete")
            }
            Text(feed.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
            if let error = feed.lastError, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacDesign.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MacDesign.line)
        )
        .shadow(color: MacDesign.shadow, radius: 10, x: 0, y: 5)
    }
}

struct EmptyCard: View {
    var title: String
    var systemImage: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(MacDesign.muted.opacity(0.7))
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(MacDesign.muted)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(MacDesign.panel.opacity(0.56), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MacDesign.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }
}

struct SavedWordCard: View {
    var word: SavedWord
    var speak: () -> Void
    var update: (Familiarity) -> Void
    var delete: () -> Void
    @State private var detailsVisible = false
    @State private var confirmDelete = false

    var body: some View {
        LearningItemCardShell {
            LearningMetaRow(kind: "word", familiarity: word.familiarity, source: word.articleTitle, count: "\(word.count) save\(word.count == 1 ? "" : "s")")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(word.displayWord)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .lineLimit(2)
                Spacer()
                Button(action: speak) {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
                .controlSize(.small)
            }
            Text(word.translation)
                .font(.body.weight(.medium))
            if let meaning = word.meanings.first {
                WordMeaningPreview(meaning: meaning)
            }
            if detailsVisible {
                DetailBlock {
                    Text(word.explanation)
                    if let source = word.sourceSentence, !source.isEmpty {
                        Text("Source sentence: \(source)")
                    }
                    Text("Source article: \(word.articleTitle ?? "No source article")")
                    Text("Created: \(word.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("Updated: \(word.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    if word.meanings.count > 1 {
                        ForEach(word.meanings.dropFirst()) { meaning in
                            WordMeaningPreview(meaning: meaning)
                        }
                    }
                }
            }
            LearningCardActions(
                familiarity: word.familiarity,
                detailsVisible: detailsVisible,
                speak: speak,
                toggleDetails: { detailsVisible.toggle() },
                update: update,
                delete: { confirmDelete = true }
            )
        }
        .confirmationDialog("Delete saved word?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the word from Saved and Review.")
        }
    }
}

struct SavedSentenceCard: View {
    var sentence: SavedSentence
    var speak: () -> Void
    var update: (Familiarity) -> Void
    var delete: () -> Void
    @State private var detailsVisible = false
    @State private var confirmDelete = false

    var body: some View {
        LearningItemCardShell {
            LearningMetaRow(kind: "sentence", familiarity: sentence.familiarity, source: sentence.articleTitle, count: nil)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(sentence.text)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(detailsVisible ? nil : 3)
                Spacer()
                Button(action: speak) {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
                .controlSize(.small)
            }
            Text(sentence.translation)
                .font(.body.weight(.medium))
            if detailsVisible {
                DetailBlock {
                    Text(sentence.explanation)
                    Text("Source article: \(sentence.articleTitle ?? "No source article")")
                    Text("Created: \(sentence.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("Updated: \(sentence.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                }
            }
            LearningCardActions(
                familiarity: sentence.familiarity,
                detailsVisible: detailsVisible,
                speak: speak,
                toggleDetails: { detailsVisible.toggle() },
                update: update,
                delete: { confirmDelete = true }
            )
        }
        .confirmationDialog("Delete saved sentence?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the sentence from Saved and Review.")
        }
    }
}

struct LearningItemCardShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacDesign.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MacDesign.line)
        )
        .shadow(color: MacDesign.shadow, radius: 10, x: 0, y: 5)
    }
}

struct LearningMetaRow: View {
    var kind: String
    var familiarity: Familiarity
    var source: String?
    var count: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(MacDesign.accent)
                .frame(width: 8, height: 8)
            Text(kind)
            Text(familiarity.rawValue)
            Text(source ?? "No source article")
                .lineLimit(1)
            if let count {
                Text(count)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(MacDesign.muted)
    }
}

struct WordMeaningPreview: View {
    var meaning: WordMeaning

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(meaning.partOfSpeech)
                .font(.caption.weight(.bold))
                .foregroundStyle(MacDesign.accentStrong)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(MacDesign.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(meaning.translatedDefinition ?? meaning.definition)
                .font(.callout.weight(.medium))
            Text(meaning.definition)
                .font(.caption)
                .foregroundStyle(MacDesign.muted)
            if let example = meaning.example, !example.isEmpty {
                Text(example)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(MacDesign.muted)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacDesign.panelSubtle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MacDesign.line.opacity(0.8))
        )
    }
}

struct DetailBlock<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            content()
        }
        .font(.caption)
        .foregroundStyle(MacDesign.muted)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacDesign.panelSubtle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(MacDesign.accent.opacity(0.55))
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct LearningCardActions: View {
    var familiarity: Familiarity
    var detailsVisible: Bool
    var speak: () -> Void
    var toggleDetails: () -> Void
    var update: (Familiarity) -> Void
    var delete: () -> Void

    var body: some View {
        FlowLayout(spacing: 8, rowSpacing: 8) {
            Button(action: speak) {
                Label("Speak", systemImage: "speaker.wave.2")
            }
            Button(detailsVisible ? "Hide details" : "Details", action: toggleDetails)
            ForEach(Familiarity.allCases) { status in
                FamiliarityPillButton(
                    status: status,
                    isSelected: status == familiarity,
                    update: update
                )
            }
            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .controlSize(.small)
    }
}

struct FamiliarityPillButton: View {
    var status: Familiarity
    var isSelected: Bool
    var update: (Familiarity) -> Void

    var body: some View {
        if isSelected {
            Button(status.rawValue.capitalized) {
                update(status)
            }
            .buttonStyle(.borderedProminent)
            .tint(MacDesign.accent)
        } else {
            Button(status.rawValue.capitalized) {
                update(status)
            }
            .buttonStyle(.bordered)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 640
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct LearningInspector: View {
    var container: MacAppContainer
    var article: Article?
    var selectedText: String
    var analysis: LearningAnalysis?
    var isAnalyzing: Bool
    var statusMessage: String
    var analyze: () -> Void
    var loadMore: () -> Void
    var save: () -> Void
    var clear: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Learning")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(MacDesign.muted)
                if selectedText.isEmpty {
                    ContentUnavailableView("No Selection", systemImage: "text.viewfinder", description: Text("Highlight a word or sentence in the reader."))
                        .foregroundStyle(.secondary)
                } else {
                    Text(selectedText)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .lineLimit(4)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MacDesign.panelSubtle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(MacDesign.accent)
                                .frame(width: 3)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    if isAnalyzing {
                        ProgressView()
                    }
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(MacDesign.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MacDesign.panel, in: Capsule())
                            .overlay(Capsule().stroke(MacDesign.accent.opacity(0.35)))
                    }
                    HStack(spacing: 8) {
                        Button(action: analyze) {
                            Label("Translate", systemImage: "character.bubble")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MacDesign.accent)
                        Button {
                            container.speech.speak(selectedText, rate: container.settingsStore.settings.speechRate)
                        } label: {
                            Label("Speak", systemImage: "speaker.wave.2")
                        }
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(selectedText, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                    HStack(spacing: 8) {
                        Button(action: save) {
                            Label("Save", systemImage: "bookmark")
                        }
                        Button(action: clear) {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                    }
                    .controlSize(.small)
                    if let analysis {
                        AnalysisSummary(analysis: analysis, loadMore: loadMore)
                    }
                }
            }
            .padding(18)
        }
        .background(MacDesign.panel)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(MacDesign.line)
                .frame(width: 1)
        }
    }
}

struct AnalysisSummary: View {
    var analysis: LearningAnalysis
    var loadMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("Translation") {
                VStack(alignment: .leading) {
                    Text(analysis.translationProvider)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(analysis.translation)
                        .font(.body.weight(.medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if analysis.kind == .word {
                GroupBox("Dictionary") {
                    VStack(alignment: .leading, spacing: 10) {
                        if analysis.wordMeanings.isEmpty {
                            Text("Fast translation is shown above. Load dictionary meanings only when needed.")
                                .foregroundStyle(.secondary)
                            Button("Show More Meanings", action: loadMore)
                                .buttonStyle(.bordered)
                        } else {
                            ForEach(analysis.wordMeanings) { meaning in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(meaning.partOfSpeech)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(meaning.translatedDefinition ?? meaning.definition)
                                        .font(.body.weight(.medium))
                                    Text(meaning.definition)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let example = meaning.example {
                                        Text(example).font(.caption).italic()
                                    }
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            GroupBox("Explanation") {
                Text(analysis.explanation)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Difficulty") {
                Text("\(analysis.difficulty.level) · \(analysis.difficulty.score)/100 · \(analysis.difficulty.reason)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .groupBoxStyle(MacInspectorGroupBoxStyle())
    }
}

struct MacInspectorGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
                .font(.system(.headline, design: .rounded, weight: .semibold))
            configuration.content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacDesign.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MacDesign.line)
        )
    }
}

struct AddFeedSheet: View {
    var container: MacAppContainer
    var reload: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var url = ""
    @State private var error = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Feed").font(.title2).bold()
            TextField("Title", text: $title)
            TextField("RSS URL", text: $url)
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    do {
                        try container.database.createFeed(title: title, url: url)
                        reload()
                        dismiss()
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

enum ReviewItem: Identifiable {
    case word(SavedWord)
    case sentence(SavedSentence)

    var id: String {
        switch self {
        case .word(let word): "word-\(word.id)"
        case .sentence(let sentence): "sentence-\(sentence.id)"
        }
    }
}

struct ReviewRow: View {
    var container: MacAppContainer
    var item: ReviewItem
    var reload: () -> Void
    @State private var revealed = false
    @State private var confirmDelete = false

    var body: some View {
        LearningItemCardShell {
            LearningMetaRow(kind: kindLabel, familiarity: familiarity, source: sourceTitle, count: countLabel)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(revealed ? nil : 3)
                Spacer()
                Button {
                    container.speech.speak(title, rate: container.settingsStore.settings.speechRate)
                } label: {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
                .controlSize(.small)
            }
            if revealed {
                Text(translation)
                    .font(.body.weight(.medium))
                DetailBlock {
                    Text(explanation)
                    Text("Source article: \(sourceTitle)")
                }
            } else {
                Text("Answer hidden for review. Reveal it when you are ready.")
                    .font(.callout)
                    .foregroundStyle(MacDesign.muted)
            }
            FlowLayout(spacing: 8, rowSpacing: 8) {
                Button(revealed ? "Hide answer" : "Reveal answer") {
                    revealed.toggle()
                }
                ForEach(Familiarity.allCases) { status in
                    FamiliarityPillButton(status: status, isSelected: status == familiarity) { selected in
                        if selected == .mastered {
                            confirmDelete = true
                        } else {
                            update(selected)
                        }
                    }
                }
            }
            .controlSize(.small)
        }
        .confirmationDialog("Remove mastered item?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the item from Saved and Review.")
        }
    }

    private var kindLabel: String {
        switch item {
        case .word: "word"
        case .sentence: "sentence"
        }
    }

    private var sourceTitle: String {
        switch item {
        case .word(let word): word.articleTitle ?? "No source article"
        case .sentence(let sentence): sentence.articleTitle ?? "No source article"
        }
    }

    private var countLabel: String? {
        switch item {
        case .word(let word): "\(word.count) save\(word.count == 1 ? "" : "s")"
        case .sentence: nil
        }
    }

    private var title: String {
        switch item {
        case .word(let word): word.displayWord
        case .sentence(let sentence): sentence.text
        }
    }

    private var translation: String {
        switch item {
        case .word(let word): word.translation
        case .sentence(let sentence): sentence.translation
        }
    }

    private var explanation: String {
        switch item {
        case .word(let word): word.explanation
        case .sentence(let sentence): sentence.explanation
        }
    }

    private var familiarity: Familiarity {
        switch item {
        case .word(let word): word.familiarity
        case .sentence(let sentence): sentence.familiarity
        }
    }

    private func update(_ status: Familiarity) {
        switch item {
        case .word(let word): try? container.database.updateReview(kind: .word, id: word.id, familiarity: status)
        case .sentence(let sentence): try? container.database.updateReview(kind: .sentence, id: sentence.id, familiarity: status)
        }
        reload()
    }

    private func delete() {
        switch item {
        case .word(let word): _ = try? container.database.deleteSavedWord(word.id)
        case .sentence(let sentence): _ = try? container.database.deleteSavedSentence(sentence.id)
        }
        reload()
    }
}

struct FamiliarityButtons: View {
    var familiarity: Familiarity
    var update: (Familiarity) -> Void

    var body: some View {
        HStack {
            ForEach(Familiarity.allCases) { status in
                if status == familiarity {
                    Button(status.rawValue.capitalized) {
                        update(status)
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(status.rawValue.capitalized) {
                        update(status)
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct MacSettingsView: View {
    var container: MacAppContainer
    @ObservedObject private var settingsStore: SettingsStore

    init(container: MacAppContainer) {
        self.container = container
        self.settingsStore = container.settingsStore
    }

    var body: some View {
        Form {
            Picker("Theme", selection: binding(\.theme)) {
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Picker("Translation", selection: Binding(
                get: { settingsStore.settings.translationProvider },
                set: { provider in settingsStore.update { $0.translationProvider = provider } }
            )) {
                ForEach(TranslationProvider.allCases) { provider in
                    Text(provider.label).tag(provider)
                }
            }
            TextField("Font Family", text: binding(\.fontFamily))
            SliderRow(title: "Font Size", value: binding(\.fontSize), range: 15...30)
            SliderRow(title: "Line Height", value: binding(\.lineHeight), range: 1.2...2.2)
            SliderRow(title: "Paragraph Gap", value: binding(\.paragraphGap), range: 0.8...2.0)
            SliderRow(title: "Speech Rate", value: binding(\.speechRate), range: 0.55...1.25)
            Picker("Reader Background", selection: binding(\.readerBackground)) {
                Text("Paper").tag("paper")
                Text("White").tag("white")
                Text("Warm").tag("warm")
                Text("Green").tag("green")
                Text("Gray").tag("gray")
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func binding(_ keyPath: WritableKeyPath<ReaderSettings, String>) -> Binding<String> {
        Binding(
            get: { settingsStore.settings[keyPath: keyPath] },
            set: { value in settingsStore.update { $0[keyPath: keyPath] = value } }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<ReaderSettings, Double>) -> Binding<Double> {
        Binding(
            get: { settingsStore.settings[keyPath: keyPath] },
            set: { value in settingsStore.update { $0[keyPath: keyPath] = value } }
        )
    }
}

struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range)
            Text(value, format: .number.precision(.fractionLength(2)))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
    }
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
}
