"use client";

import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import type { MouseEvent as ReactMouseEvent, KeyboardEvent as ReactKeyboardEvent } from "react";
import type { Article, DashboardPayload, Familiarity, Feed, LearningAnalysis, ReaderSettings, SavedSentence, SavedWord, ViewKey } from "@/lib/types";
import { clamp, isLikelyWord, sentenceAround, sentenceAtOffset, wordAtOffset } from "@/lib/utils";

type IconName = "articles" | "feeds" | "words" | "sentences" | "review" | "settings" | "refresh" | "list" | "moon" | "sun" | "export";

const navItems: Array<{ key: ViewKey; label: string; shortLabel: string; icon: IconName }> = [
  { key: "articles", label: "Articles", shortLabel: "Articles", icon: "articles" },
  { key: "feeds", label: "Feeds", shortLabel: "Feeds", icon: "feeds" },
  { key: "words", label: "Saved Words", shortLabel: "Words", icon: "words" },
  { key: "sentences", label: "Sentences", shortLabel: "Sents", icon: "sentences" },
  { key: "review", label: "Review", shortLabel: "Review", icon: "review" },
  { key: "settings", label: "Settings", shortLabel: "Settings", icon: "settings" }
];

const familiarityOptions: Familiarity[] = ["new", "learning", "familiar", "mastered"];
const readerTextBlockSelector = "p, li, blockquote, figcaption, h2, h3, h4";

type SelectionKind = "word" | "phrase" | "sentence";
type SelectionStatus = "ready" | "loading" | "analyzed" | "saved" | "error";

type ActiveSelection = {
  text: string;
  kind: SelectionKind;
  x: number;
  y: number;
  status: SelectionStatus;
  savedAs?: "word" | "sentence";
  message?: string;
  highlight?: SelectionHighlight;
};

type SelectionHighlight = {
  containerText: string;
  start: number;
  end: number;
  kind: SelectionKind;
  text: string;
  startPath?: number[];
  startOffset?: number;
  endPath?: number[];
  endOffset?: number;
};

export function MagReaderApp() {
  const [view, setView] = useState<ViewKey>("articles");
  const [feeds, setFeeds] = useState<Feed[]>([]);
  const [articles, setArticles] = useState<Article[]>([]);
  const [words, setWords] = useState<SavedWord[]>([]);
  const [sentences, setSentences] = useState<SavedSentence[]>([]);
  const [settings, setSettings] = useState<ReaderSettings | null>(null);
  const [selectedArticleId, setSelectedArticleId] = useState<number | null>(null);
  const [selectedText, setSelectedText] = useState("");
  const [activeSelection, setActiveSelection] = useState<ActiveSelection | null>(null);
  const [toolbarVisible, setToolbarVisible] = useState(false);
  const [analysis, setAnalysis] = useState<LearningAnalysis | null>(null);
  const [query, setQuery] = useState("");
  const [toast, setToast] = useState("");
  const [loading, setLoading] = useState(true);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [articleListCollapsed, setArticleListCollapsed] = useState(false);
  const [mobileSheetOpen, setMobileSheetOpen] = useState(false);
  const [mobileDetailsOpen, setMobileDetailsOpen] = useState(false);
  const learningPanelRef = useRef<HTMLElement | null>(null);

  const selectedArticle = articles.find((article) => article.id === selectedArticleId) ?? articles[0] ?? null;

  const loadDashboard = useCallback(async () => {
    const response = await fetch("/api/dashboard", { cache: "no-store" });
    const data = (await response.json()) as DashboardPayload;
    setFeeds(data.feeds);
    setArticles(data.articles);
    setWords(data.words);
    setSentences(data.sentences);
    setSettings(data.settings);
    setSelectedArticleId((current) => current ?? data.articles[0]?.id ?? null);
    setLoading(false);
  }, []);

  useEffect(() => {
    loadDashboard().catch(() => {
      setToast("Could not load local data.");
      setLoading(false);
    });
  }, [loadDashboard]);

  useEffect(() => {
    if (!settings) return;
    document.body.classList.toggle("dark", settings.theme === "dark");
  }, [settings]);

  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(""), 2600);
    return () => clearTimeout(timer);
  }, [toast]);

  const clearSelection = useCallback(() => {
    setSelectedText("");
    setActiveSelection(null);
    setToolbarVisible(false);
    setMobileSheetOpen(false);
    setMobileDetailsOpen(false);
    setAnalysis(null);
    clearReaderHighlight();
    window.getSelection()?.removeAllRanges();
  }, []);

  useEffect(() => {
    clearSelection();
  }, [selectedArticleId, view, clearSelection]);

  useEffect(() => {
    function handleGlobalPointerDown(event: PointerEvent) {
      const target = event.target;
      if (!(target instanceof Element)) return;
      if (target.closest(".article-body, .selection-toolbar, .learning-panel, .mobile-learning-sheet")) return;
      clearSelection();
    }

    function handleEscape(event: KeyboardEvent) {
      if (event.key === "Escape") clearSelection();
    }

    document.addEventListener("pointerdown", handleGlobalPointerDown);
    document.addEventListener("keydown", handleEscape);
    return () => {
      document.removeEventListener("pointerdown", handleGlobalPointerDown);
      document.removeEventListener("keydown", handleEscape);
    };
  }, [clearSelection]);

  async function updateSettings(patch: Partial<ReaderSettings>) {
    const response = await fetch("/api/settings", {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(patch)
    });
    const data = await response.json();
    setSettings(data.settings);
  }

  function selectText(selection: Omit<ActiveSelection, "status" | "savedAs" | "message">) {
    const clean = selection.text.trim();
    if (!clean) return;
    if (clean.length > 700) {
      setToast("Selection is too long. Choose a shorter sentence or phrase.");
      return;
    }
    const sameSelection = clean === selectedText;
    setSelectedText(clean);
    if (!sameSelection) setAnalysis(null);
    setToolbarVisible(true);
    setMobileSheetOpen(true);
    if (!sameSelection) setMobileDetailsOpen(false);
    setActiveSelection((current) => ({
      ...selection,
      text: clean,
      status: sameSelection && analysis ? current?.status === "saved" ? "saved" : "analyzed" : "ready",
      savedAs: sameSelection ? current?.savedAs : undefined,
      message: sameSelection && analysis ? current?.message ?? "Analyzed" : "Ready"
    }));
  }

  function focusLearningPanel() {
    if (window.matchMedia("(max-width: 1180px)").matches) {
      setMobileSheetOpen(true);
      setMobileDetailsOpen(true);
      return;
    }
    learningPanelRef.current?.scrollIntoView({ behavior: "smooth", block: "nearest" });
    learningPanelRef.current?.focus({ preventScroll: true });
  }

  async function requestAnalysis(text = selectedText) {
    const clean = text.trim();
    if (!clean) return null;
    if (analysis && selectedText === clean) {
      setToolbarVisible(true);
      setActiveSelection((current) => (current && current.text === clean ? { ...current, status: "analyzed", message: "Analyzed" } : current));
      return analysis;
    }
    setSelectedText(clean);
    setToolbarVisible(true);
    setMobileSheetOpen(true);
    setActiveSelection((current) => (current && current.text === clean ? { ...current, status: "loading", message: "Analyzing..." } : current));
    try {
      const response = await fetch("/api/ai", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ text: clean })
      });
      const data = await response.json();
      if (!response.ok) {
        const message = data.error ?? "Translation failed.";
        setToast(message);
        setActiveSelection((current) => (current && current.text === clean ? { ...current, status: "error", message } : current));
        return null;
      }
      setAnalysis(data.analysis);
      setActiveSelection((current) => (current && current.text === clean ? { ...current, status: "analyzed", message: "Analyzed" } : current));
      return data.analysis as LearningAnalysis;
    } catch {
      const message = "Translation failed.";
      setToast(message);
      setActiveSelection((current) => (current && current.text === clean ? { ...current, status: "error", message } : current));
      return null;
    }
  }

  async function saveSelection(kind?: "word" | "sentence") {
    if (!selectedText) return;
    const word = isLikelyWord(selectedText);
    const saveAs = kind ?? (word ? "word" : "sentence");
    if (saveAs === "word" && !word) {
      const message = "Select one word before saving as a word.";
      setToast(message);
      setToolbarVisible(true);
      setActiveSelection((current) => (current ? { ...current, status: "error", message } : current));
      return;
    }
    const currentAnalysis = analysis ?? (await requestAnalysis(selectedText));
    if (!currentAnalysis) return;
    setToolbarVisible(true);
    setMobileSheetOpen(true);
    setActiveSelection((current) => (current && current.text === selectedText ? { ...current, status: "loading", message: "Saving..." } : current));
    if (saveAs === "word") {
      try {
        const response = await fetch("/api/words", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            word: selectedText,
            displayWord: selectedText,
            translation: currentAnalysis.translation,
            explanation: currentAnalysis.explanation,
            sourceSentence: selectedArticle ? sentenceAround(selectedArticle.contentText, selectedText) : null,
            articleId: selectedArticle?.id ?? null
          })
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error ?? "Could not save word.");
        setWords(data.words);
        setToast("Word saved.");
        setActiveSelection((current) => (current && current.text === selectedText ? { ...current, status: "saved", savedAs: "word", message: "Saved as word" } : current));
      } catch (error) {
        const message = error instanceof Error ? error.message : "Could not save word.";
        setToast(message);
        setActiveSelection((current) => (current && current.text === selectedText ? { ...current, status: "error", message } : current));
      }
    } else {
      try {
        const response = await fetch("/api/sentences", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            text: selectedText,
            translation: currentAnalysis.translation,
            explanation: currentAnalysis.explanation,
            articleId: selectedArticle?.id ?? null
          })
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error ?? "Could not save sentence.");
        setSentences(data.sentences);
        setToast("Sentence saved.");
        setActiveSelection((current) => (current && current.text === selectedText ? { ...current, status: "saved", savedAs: "sentence", message: "Saved as sentence" } : current));
      } catch (error) {
        const message = error instanceof Error ? error.message : "Could not save sentence.";
        setToast(message);
        setActiveSelection((current) => (current && current.text === selectedText ? { ...current, status: "error", message } : current));
      }
    }
  }

  function speak(text: string) {
    if (!("speechSynthesis" in window)) {
      setToast("Speech synthesis is not available in this browser.");
      return;
    }
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = "en-US";
    utterance.rate = settings?.speechRate ?? 0.92;
    window.speechSynthesis.speak(utterance);
  }

  async function refreshFeeds() {
    setToast("Refreshing RSS feeds...");
    const response = await fetch("/api/feeds/refresh", { method: "POST" });
    const data = await response.json();
    await loadDashboard();
    const count = data.results?.reduce((sum: number, item: { count: number }) => sum + item.count, 0) ?? 0;
    setToast(`RSS refresh complete. ${count} item(s) checked.`);
  }

  const counts = {
    articles: articles.length,
    feeds: feeds.length,
    words: words.length,
    sentences: sentences.length,
    review: words.filter((word) => word.familiarity !== "mastered").length + sentences.filter((sentence) => sentence.familiarity !== "mastered").length,
    settings: 0
  };

  if (loading || !settings) {
    return <div className="empty">Loading MagReader...</div>;
  }

  return (
    <div className={`app-shell ${sidebarCollapsed ? "nav-collapsed" : ""} ${mobileSheetOpen ? "mobile-sheet-active" : ""}`}>
      <aside className={`sidebar ${sidebarCollapsed ? "collapsed" : ""}`}>
        <div className="brand">
          <div className="brand-mark">M</div>
          <span>MagReader</span>
          <button
            className="collapse-button"
            onClick={() => setSidebarCollapsed((collapsed) => !collapsed)}
            title={sidebarCollapsed ? "Expand navigation" : "Collapse navigation"}
            aria-label={sidebarCollapsed ? "Expand navigation" : "Collapse navigation"}
          >
            {sidebarCollapsed ? ">" : "<"}
          </button>
        </div>
        <nav className="nav-list" aria-label="Primary">
          {navItems.map((item) => (
            <button key={item.key} className={`nav-button ${view === item.key ? "active" : ""}`} onClick={() => setView(item.key)} aria-label={item.label}>
              <MenuIcon name={item.icon} className="nav-icon" />
              <span className="nav-abbrev" aria-hidden="true">
                {item.label.slice(0, 1)}
              </span>
              <span className="nav-label nav-label-full">{item.label}</span>
              <span className="nav-label nav-label-short">{item.shortLabel}</span>
              {counts[item.key] > 0 ? <span className="nav-count">{counts[item.key]}</span> : null}
            </button>
          ))}
        </nav>
        <div className="sidebar-section">
          <div className="sidebar-title">Learning Loop</div>
          <p className="muted">Read, select, explain, save, review. Mock AI is wired through replaceable APIs.</p>
        </div>
      </aside>

      <main className="main">
        <Topbar
          query={query}
          setQuery={setQuery}
          settings={settings}
          updateSettings={updateSettings}
          refreshFeeds={refreshFeeds}
          articleListCollapsed={articleListCollapsed}
          setArticleListCollapsed={setArticleListCollapsed}
          exportUrl="/api/export?format=csv"
        />
        {view === "articles" ? (
          <ArticleWorkspace
            articles={articles}
            query={query}
            selectedArticle={selectedArticle}
            setSelectedArticleId={setSelectedArticleId}
            settings={settings}
            activeHighlight={activeSelection?.highlight ?? null}
            onSelectText={selectText}
            speak={speak}
            articleListCollapsed={articleListCollapsed}
          />
        ) : null}
        {view === "feeds" ? <FeedsView feeds={feeds} reload={loadDashboard} setToast={setToast} /> : null}
        {view === "words" ? <WordsView words={words} query={query} speak={speak} update={setWords} setToast={setToast} /> : null}
        {view === "sentences" ? <SentencesView sentences={sentences} query={query} speak={speak} update={setSentences} setToast={setToast} /> : null}
        {view === "review" ? <ReviewView words={words} sentences={sentences} speak={speak} setWords={setWords} setSentences={setSentences} setToast={setToast} /> : null}
        {view === "settings" ? <SettingsView settings={settings} updateSettings={updateSettings} /> : null}
      </main>

      <SelectionToolbar
        activeSelection={activeSelection}
        visible={toolbarVisible}
        requestAnalysis={requestAnalysis}
        speak={speak}
        saveSelection={saveSelection}
        focusLearningPanel={focusLearningPanel}
      />
      <LearningPanel refElement={learningPanelRef} selectedText={selectedText} activeSelection={activeSelection} analysis={analysis} requestAnalysis={requestAnalysis} speak={speak} saveSelection={saveSelection} />
      <MobileLearningSheet
        open={mobileSheetOpen}
        selectedText={selectedText}
        activeSelection={activeSelection}
        analysis={analysis}
        detailsOpen={mobileDetailsOpen}
        setDetailsOpen={setMobileDetailsOpen}
        close={() => setMobileSheetOpen(false)}
        requestAnalysis={requestAnalysis}
        speak={speak}
        saveSelection={saveSelection}
      />
      {toast ? <div className="toast">{toast}</div> : null}
    </div>
  );
}

function Topbar({
  query,
  setQuery,
  settings,
  updateSettings,
  refreshFeeds,
  articleListCollapsed,
  setArticleListCollapsed,
  exportUrl
}: {
  query: string;
  setQuery: (query: string) => void;
  settings: ReaderSettings;
  updateSettings: (patch: Partial<ReaderSettings>) => void;
  refreshFeeds: () => void;
  articleListCollapsed: boolean;
  setArticleListCollapsed: (collapsed: boolean) => void;
  exportUrl: string;
}) {
  return (
    <header className="topbar">
      <input className="input" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search articles, saved words, or sentences" />
      <div className="toolbar">
        <button className="toolbar-button" onClick={refreshFeeds}>
          <MenuIcon name="refresh" className="button-icon" />
          Refresh RSS
        </button>
        <button className="toolbar-button" onClick={() => setArticleListCollapsed(!articleListCollapsed)}>
          <MenuIcon name="list" className="button-icon" />
          {articleListCollapsed ? "Show list" : "Hide list"}
        </button>
        <button className="toolbar-button" onClick={() => updateSettings({ theme: settings.theme === "dark" ? "light" : "dark" })}>
          <MenuIcon name={settings.theme === "dark" ? "sun" : "moon"} className="button-icon" />
          {settings.theme === "dark" ? "Light" : "Dark"}
        </button>
        <button className="icon-button" title="Smaller font" onClick={() => updateSettings({ fontSize: Math.max(16, settings.fontSize - 1) })}>
          A-
        </button>
        <button className="icon-button" title="Larger font" onClick={() => updateSettings({ fontSize: Math.min(28, settings.fontSize + 1) })}>
          A+
        </button>
        <a className="toolbar-button" href={exportUrl}>
          <MenuIcon name="export" className="button-icon" />
          Export
        </a>
      </div>
    </header>
  );
}

function MenuIcon({ name, className = "" }: { name: IconName; className?: string }) {
  const common = {
    className,
    width: 18,
    height: 18,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 2,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    "aria-hidden": true
  };

  switch (name) {
    case "articles":
      return (
        <svg {...common}>
          <path d="M4 19.5V5a2 2 0 0 1 2-2h10.5A3.5 3.5 0 0 1 20 6.5V21H6a2 2 0 0 1-2-1.5Z" />
          <path d="M8 7h8" />
          <path d="M8 11h8" />
          <path d="M8 15h5" />
        </svg>
      );
    case "feeds":
      return (
        <svg {...common}>
          <path d="M4 11a9 9 0 0 1 9 9" />
          <path d="M4 5a15 15 0 0 1 15 15" />
          <circle cx="6" cy="18" r="2" />
        </svg>
      );
    case "words":
      return (
        <svg {...common}>
          <path d="M4 19V5h6a4 4 0 0 1 0 8H4" />
          <path d="M14 19V9" />
          <path d="M14 13h2a3 3 0 0 1 0 6h-2" />
        </svg>
      );
    case "sentences":
      return (
        <svg {...common}>
          <path d="M5 6h14" />
          <path d="M5 10h14" />
          <path d="M5 14h9" />
          <path d="M5 18h6" />
        </svg>
      );
    case "review":
      return (
        <svg {...common}>
          <path d="M6 3v4" />
          <path d="M18 3v4" />
          <path d="M4 9h16" />
          <rect x="4" y="5" width="16" height="16" rx="2" />
          <path d="m9 15 2 2 4-5" />
        </svg>
      );
    case "settings":
      return (
        <svg {...common}>
          <path d="M12 15.5A3.5 3.5 0 1 0 12 8a3.5 3.5 0 0 0 0 7.5Z" />
          <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 0 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6V21a2 2 0 0 1-4 0v-.1a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1A2 2 0 0 1 4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.6-1H3a2 2 0 0 1 0-4h.1a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9l-.1-.1A2 2 0 0 1 7 4.2l.1.1a1.7 1.7 0 0 0 1.9.3 1.7 1.7 0 0 0 1-1.6V3a2 2 0 0 1 4 0v.1a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1A2 2 0 0 1 19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.1a2 2 0 0 1 0 4H21a1.7 1.7 0 0 0-1.6 1Z" />
        </svg>
      );
    case "refresh":
      return (
        <svg {...common}>
          <path d="M20 12a8 8 0 0 1-13.7 5.6" />
          <path d="M4 12A8 8 0 0 1 17.7 6.4" />
          <path d="M17 2v5h5" />
          <path d="M7 22v-5H2" />
        </svg>
      );
    case "list":
      return (
        <svg {...common}>
          <path d="M8 6h13" />
          <path d="M8 12h13" />
          <path d="M8 18h13" />
          <path d="M3 6h.01" />
          <path d="M3 12h.01" />
          <path d="M3 18h.01" />
        </svg>
      );
    case "moon":
      return (
        <svg {...common}>
          <path d="M20 14.5A7.5 7.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5Z" />
        </svg>
      );
    case "sun":
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2" />
          <path d="M12 20v2" />
          <path d="m4.9 4.9 1.4 1.4" />
          <path d="m17.7 17.7 1.4 1.4" />
          <path d="M2 12h2" />
          <path d="M20 12h2" />
          <path d="m4.9 19.1 1.4-1.4" />
          <path d="m17.7 6.3 1.4-1.4" />
        </svg>
      );
    case "export":
      return (
        <svg {...common}>
          <path d="M12 3v12" />
          <path d="m7 8 5-5 5 5" />
          <path d="M5 15v4a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-4" />
        </svg>
      );
  }
}

function ArticleWorkspace({
  articles,
  query,
  selectedArticle,
  setSelectedArticleId,
  settings,
  activeHighlight,
  onSelectText,
  speak,
  articleListCollapsed
}: {
  articles: Article[];
  query: string;
  selectedArticle: Article | null;
  setSelectedArticleId: (id: number) => void;
  settings: ReaderSettings;
  activeHighlight: SelectionHighlight | null;
  onSelectText: (selection: Omit<ActiveSelection, "status" | "savedAs" | "message">) => void;
  speak: (text: string) => void;
  articleListCollapsed: boolean;
}) {
  const filtered = useMemo(() => {
    const q = query.toLowerCase();
    return articles.filter((article) => !q || article.title.toLowerCase().includes(q) || article.contentText.toLowerCase().includes(q) || article.feedTitle?.toLowerCase().includes(q));
  }, [articles, query]);

  return (
    <div className={`content-grid ${articleListCollapsed ? "list-collapsed" : ""}`}>
      {!articleListCollapsed ? (
        <section className="article-list-panel" aria-label="Article list">
          <div className="list-header">
            <span className="section-label">{filtered.length} Articles</span>
          </div>
          <div className="article-list">
            {filtered.map((article) => {
              const sourceLabel = articleSourceLabel(article.feedTitle) ?? articleSourceLabel(article.author);

              return (
                <button key={article.id} className={`article-row ${selectedArticle?.id === article.id ? "active" : ""}`} onClick={() => setSelectedArticleId(article.id)}>
                  <h3 className="row-title">{article.title}</h3>
                  <div className="row-meta">
                    {sourceLabel ? <span>{sourceLabel}</span> : null}
                    <span>{article.difficulty}</span>
                    <span>{article.publishedAt ? new Date(article.publishedAt).toLocaleDateString() : "No date"}</span>
                  </div>
                  {article.excerpt ? <p className="muted">{article.excerpt}</p> : null}
                </button>
              );
            })}
            {!filtered.length ? <div className="empty">No articles match this search.</div> : null}
          </div>
        </section>
      ) : null}

      <section className="reader-wrap">
        {selectedArticle ? (
          <Reader article={selectedArticle} settings={settings} activeHighlight={activeHighlight} onSelectText={onSelectText} speak={speak} wide={articleListCollapsed} />
        ) : (
          <div className="empty">Add an RSS feed or use the sample article to start reading.</div>
        )}
      </section>
    </div>
  );
}

function Reader({
  article,
  settings,
  activeHighlight,
  onSelectText,
  speak,
  wide = false
}: {
  article: Article;
  settings: ReaderSettings;
  activeHighlight: SelectionHighlight | null;
  onSelectText: (selection: Omit<ActiveSelection, "status" | "savedAs" | "message">) => void;
  speak: (text: string) => void;
  wide?: boolean;
}) {
  const articleBodyRef = useRef<HTMLDivElement | null>(null);
  const clickTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const sourceLabel = articleSourceLabel(article.author) ?? articleSourceLabel(article.feedTitle);

  useLayoutEffect(() => {
    const body = articleBodyRef.current;
    if (!body) return;
    clearReaderHighlight(body);
    if (activeHighlight) applyReaderHighlight(body, activeHighlight);
    return () => clearReaderHighlight(body);
  });

  useEffect(() => {
    return () => {
      if (clickTimerRef.current) clearTimeout(clickTimerRef.current);
    };
  }, []);

  function handleManualSelection() {
    if (clickTimerRef.current) clearTimeout(clickTimerRef.current);
    const selection = window.getSelection();
    if (!selection || selection.isCollapsed || selection.rangeCount === 0) return;
    const range = selection.getRangeAt(0);
    const body = articleBodyRef.current;
    if (!body || !containsSelection(body, range)) return;
    const text = selection.toString().trim();
    if (!text) return;
    const kind = classifySelection(text);
    const block = textBlockForNode(range.startContainer, body);
    const highlight =
      block && block.contains(range.endContainer)
        ? highlightFromRange(
            body,
            range,
            text,
            kind,
            block.textContent ?? "",
            textOffsetIn(block, range.startContainer, range.startOffset),
            textOffsetIn(block, range.endContainer, range.endOffset)
          )
        : undefined;
    const toolbarPoint = toolbarPointFromRange(range);
    if (highlight) {
      clearReaderHighlight(body);
      window.getSelection()?.removeAllRanges();
    }
    onSelectText({ text, kind, highlight, ...toolbarPoint });
  }

  function handleKeyboardSelection(event: ReactKeyboardEvent<HTMLDivElement>) {
    if (event.key.startsWith("Arrow") || event.key === "Shift" || event.key === "Meta" || event.key === "Control") {
      handleManualSelection();
    }
  }

  function handleSentenceClick(event: ReactMouseEvent<HTMLDivElement>) {
    if (event.detail >= 2) {
      event.preventDefault();
      if (clickTimerRef.current) clearTimeout(clickTimerRef.current);
      selectWordAtPoint(event.currentTarget, event.target, event.clientX, event.clientY);
      return;
    }

    const selection = window.getSelection();
    if (selection && !selection.isCollapsed && selection.toString().trim()) return;

    if (clickTimerRef.current) clearTimeout(clickTimerRef.current);
    const root = event.currentTarget;
    const target = event.target;
    const x = event.clientX;
    const y = event.clientY;
    clickTimerRef.current = setTimeout(() => {
      selectSentenceAtPoint(root, target, x, y);
    }, 220);
  }

  function selectSentenceAtPoint(root: HTMLDivElement, target: EventTarget, x: number, y: number) {
    if (isIgnoredReaderTarget(target)) return;
    const targetElement = target as Element;
    const selection = window.getSelection();
    if (selection && !selection.isCollapsed && selection.toString().trim()) return;

    const caret = caretRangeFromPoint(x, y);
    const fallbackBlock = targetElement.closest(readerTextBlockSelector);
    if (!caret) {
      if (fallbackBlock && root.contains(fallbackBlock)) selectWholeTextBlock(root, fallbackBlock);
      return;
    }

    const block = textBlockForNode(caret.startContainer, root);
    if (!block || !(root.contains(block))) {
      if (fallbackBlock && root.contains(fallbackBlock)) selectWholeTextBlock(root, fallbackBlock);
      return;
    }

    const text = block.textContent ?? "";
    if (!block.contains(caret.startContainer)) return;

    const offset = textOffsetIn(block, caret.startContainer, caret.startOffset);
    const sentence = sentenceAtOffset(text, offset);
    if (!sentence) return;

    const range = rangeForTextOffsets(block, sentence.start, sentence.end);
    if (!range) return;

    const toolbarPoint = toolbarPointFromRange(range);
    clearReaderHighlight(root);
    window.getSelection()?.removeAllRanges();
    onSelectText({ text: sentence.text, kind: "sentence", highlight: highlightFromRange(root, range, sentence.text, "sentence", text, sentence.start, sentence.end), ...toolbarPoint });
  }

  function selectWholeTextBlock(root: HTMLDivElement, block: Element) {
    const text = block.textContent?.trim() ?? "";
    if (!text) return;
    const range = document.createRange();
    range.selectNodeContents(block);
    const toolbarPoint = toolbarPointFromRange(range);
    clearReaderHighlight(root);
    window.getSelection()?.removeAllRanges();
    onSelectText({ text, kind: classifySelection(text), highlight: highlightFromRange(root, range, text, classifySelection(text), block.textContent ?? "", 0, block.textContent?.length ?? text.length), ...toolbarPoint });
  }

  function handleWordDoubleClick(event: ReactMouseEvent<HTMLDivElement>) {
    event.preventDefault();
    event.stopPropagation();
    if (clickTimerRef.current) clearTimeout(clickTimerRef.current);
    selectWordAtPoint(event.currentTarget, event.target, event.clientX, event.clientY);
  }

  function selectWordAtPoint(root: HTMLDivElement, target: EventTarget, x: number, y: number) {
    if (isIgnoredReaderTarget(target)) return;

    const caret = caretRangeFromPoint(x, y);
    if (!caret) return;

    const block = textBlockForNode(caret.startContainer, root);
    if (!block || !(root.contains(block))) return;

    const text = block.textContent ?? "";
    if (!block.contains(caret.startContainer)) return;

    const offset = textOffsetIn(block, caret.startContainer, caret.startOffset);
    const word = wordAtOffset(text, offset);
    if (!word) return;

    const range = rangeForTextOffsets(block, word.start, word.end);
    if (!range) return;

    const toolbarPoint = toolbarPointFromRange(range);
    clearReaderHighlight(root);
    window.getSelection()?.removeAllRanges();
    onSelectText({ text: word.text, kind: "word", highlight: highlightFromRange(root, range, word.text, "word", text, word.start, word.end), ...toolbarPoint });
  }

  return (
    <article
      className="reader"
      style={
        {
          "--reader-font": settings.fontFamily,
          "--reader-size": `${settings.fontSize}px`,
          "--reader-line": settings.lineHeight,
          "--reader-width": `${wide ? Math.max(settings.contentWidth, 920) : settings.contentWidth}px`,
          "--paragraph-gap": `${settings.paragraphGap}em`
        } as React.CSSProperties
      }
    >
      <h1>{article.title}</h1>
      <div className="reader-meta">
        {sourceLabel ? <span>{sourceLabel}</span> : null}
        <span>{article.difficulty}</span>
        <button className="small-button" onClick={() => speak(article.title)}>
          Pronounce title
        </button>
      </div>
      <div
        ref={articleBodyRef}
        className="article-body"
        onClick={handleSentenceClick}
        onDoubleClick={handleWordDoubleClick}
        onMouseUp={handleManualSelection}
        onKeyUp={handleKeyboardSelection}
        dangerouslySetInnerHTML={{ __html: article.contentHtml }}
      />
    </article>
  );
}

function articleSourceLabel(source: string | null | undefined) {
  const label = source?.trim();
  if (!label || label.toLowerCase() === "unknown source") return null;
  return label;
}

function SelectionToolbar({
  activeSelection,
  visible,
  requestAnalysis,
  speak,
  saveSelection,
  focusLearningPanel
}: {
  activeSelection: ActiveSelection | null;
  visible: boolean;
  requestAnalysis: (text?: string) => Promise<LearningAnalysis | null>;
  speak: (text: string) => void;
  saveSelection: (kind?: "word" | "sentence") => void;
  focusLearningPanel: () => void;
}) {
  if (!activeSelection || !visible) return null;
  const canSaveWord = isLikelyWord(activeSelection.text);
  const isLoading = activeSelection.status === "loading";
  const saveKind = canSaveWord ? "word" : "sentence";

  return (
    <div
      className={`selection-toolbar ${activeSelection.status}`}
      style={{ left: activeSelection.x, top: activeSelection.y }}
      role="toolbar"
      aria-label="Selection actions"
    >
      <span className="selection-status">{activeSelection.message ?? statusLabel(activeSelection.status)}</span>
      <button disabled={isLoading} onClick={() => requestAnalysis(activeSelection.text)}>
        Translate
      </button>
      <button disabled={isLoading} onClick={() => speak(activeSelection.text)}>
        Speak
      </button>
      <button disabled={isLoading} onClick={() => saveSelection(saveKind)}>
        Save
      </button>
      <button onClick={focusLearningPanel}>More</button>
    </div>
  );
}

function statusLabel(status: SelectionStatus) {
  const labels: Record<SelectionStatus, string> = {
    ready: "Ready",
    loading: "Analyzing...",
    analyzed: "Analyzed",
    saved: "Saved",
    error: "Failed"
  };
  return labels[status];
}

function classifySelection(text: string): SelectionKind {
  if (isLikelyWord(text)) return "word";
  const words = text.match(/[A-Za-z][A-Za-z'-]*/g) ?? [];
  return /[.!?]["')\]}]?$/.test(text.trim()) || words.length > 6 ? "sentence" : "phrase";
}

function containsSelection(container: Element, range: Range) {
  return container.contains(range.commonAncestorContainer.nodeType === Node.TEXT_NODE ? range.commonAncestorContainer.parentElement : range.commonAncestorContainer);
}

function toolbarPointFromRange(range: Range) {
  const rect = range.getBoundingClientRect();
  const panel = document.querySelector(".learning-panel");
  const panelRect = panel?.getBoundingClientRect();
  const rightLimit = panelRect && panelRect.left < window.innerWidth ? Math.max(150, panelRect.left - 170) : Math.max(150, window.innerWidth - 150);
  const left = clamp(rect.left + rect.width / 2, 150, rightLimit);
  const top = clamp(rect.top - 10, 72, Math.max(72, window.innerHeight - 96));
  return { x: left, y: top };
}

function caretRangeFromPoint(x: number, y: number) {
  const doc = document as Document & {
    caretRangeFromPoint?: (x: number, y: number) => Range | null;
    caretPositionFromPoint?: (x: number, y: number) => { offsetNode: Node; offset: number } | null;
  };
  if (doc.caretRangeFromPoint) {
    return doc.caretRangeFromPoint(x, y);
  }
  if (doc.caretPositionFromPoint) {
    const position = doc.caretPositionFromPoint(x, y);
    if (!position) return null;
    const range = doc.createRange();
    range.setStart(position.offsetNode, position.offset);
    range.collapse(true);
    return range;
  }
  return null;
}

function textOffsetIn(root: Element, node: Node, nodeOffset: number) {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let offset = 0;
  let current = walker.nextNode();
  while (current) {
    if (current === node) return offset + nodeOffset;
    offset += current.textContent?.length ?? 0;
    current = walker.nextNode();
  }
  return offset;
}

function rangeForTextOffsets(root: Element, start: number, end: number) {
  const range = document.createRange();
  const startPoint = textNodeAtOffset(root, start);
  const endPoint = textNodeAtOffset(root, end);
  if (!startPoint || !endPoint) return null;
  range.setStart(startPoint.node, startPoint.offset);
  range.setEnd(endPoint.node, endPoint.offset);
  return range;
}

function textNodeAtOffset(root: Element, targetOffset: number) {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let offset = 0;
  let current = walker.nextNode();
  while (current) {
    const textLength = current.textContent?.length ?? 0;
    if (targetOffset <= offset + textLength) {
      return { node: current, offset: Math.max(0, targetOffset - offset) };
    }
    offset += textLength;
    current = walker.nextNode();
  }
  return null;
}

function textBlockForNode(node: Node, root: Element) {
  const element = node.nodeType === Node.TEXT_NODE ? node.parentElement : node instanceof Element ? node : null;
  const block = element?.closest(readerTextBlockSelector);
  return block && root.contains(block) ? block : null;
}

function isIgnoredReaderTarget(target: EventTarget) {
  if (!(target instanceof Element)) return true;
  if (target.closest("figcaption")) return false;
  return !!target.closest("a, button, input, textarea, select, img, video, iframe");
}

function nodePathFrom(root: Node, node: Node) {
  const path: number[] = [];
  let current: Node | null = node;
  while (current && current !== root) {
    const parent: Node | null = current.parentNode;
    if (!parent) return null;
    path.unshift(Array.prototype.indexOf.call(parent.childNodes, current));
    current = parent;
  }
  return current === root ? path : null;
}

function nodeFromPath(root: Node, path: number[]) {
  let current: Node | null = root;
  for (const index of path) {
    current = current?.childNodes[index] ?? null;
    if (!current) return null;
  }
  return current;
}

function highlightFromRange(root: Element, range: Range, text: string, kind: SelectionKind, containerText: string, start: number, end: number): SelectionHighlight {
  return {
    containerText,
    start,
    end,
    kind,
    text,
    startPath: nodePathFrom(root, range.startContainer) ?? undefined,
    startOffset: range.startOffset,
    endPath: nodePathFrom(root, range.endContainer) ?? undefined,
    endOffset: range.endOffset
  };
}

function clearReaderHighlight(root: ParentNode = document) {
  root.querySelectorAll("mark[data-reader-highlight='true']").forEach((mark) => {
    const parent = mark.parentNode;
    if (!parent) return;
    while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
    parent.removeChild(mark);
    parent.normalize();
  });
}

function applyReaderHighlight(root: Element, highlight: SelectionHighlight) {
  if (highlight.startPath && highlight.endPath && highlight.startOffset !== undefined && highlight.endOffset !== undefined) {
    const startNode = nodeFromPath(root, highlight.startPath);
    const endNode = nodeFromPath(root, highlight.endPath);
    if (startNode && endNode) {
      try {
        const range = document.createRange();
        range.setStart(startNode, highlight.startOffset);
        range.setEnd(endNode, highlight.endOffset);
        const mark = document.createElement("mark");
        mark.className = `reader-selection-highlight ${highlight.kind}`;
        mark.dataset.readerHighlight = "true";
        range.surroundContents(mark);
        return;
      } catch {
        // Fall through to text matching when the original range crossed inline nodes.
      }
    }
  }

  if (applyBlockOffsetHighlight(root, highlight)) return;

  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let current = walker.nextNode();
  while (current) {
    const text = current.textContent ?? "";
    const containerIndex = text.indexOf(highlight.containerText);
    const fallbackIndex = containerIndex >= 0 ? -1 : text.indexOf(highlight.text);
    if (containerIndex >= 0 || fallbackIndex >= 0) {
      const range = document.createRange();
      const start = containerIndex >= 0 ? containerIndex + highlight.start : fallbackIndex;
      const end = containerIndex >= 0 ? containerIndex + highlight.end : fallbackIndex + highlight.text.length;
      range.setStart(current, start);
      range.setEnd(current, end);
      const mark = document.createElement("mark");
      mark.className = `reader-selection-highlight ${highlight.kind}`;
      mark.dataset.readerHighlight = "true";
      range.surroundContents(mark);
      return;
    }
    current = walker.nextNode();
  }
}

function applyBlockOffsetHighlight(root: Element, highlight: SelectionHighlight) {
  const blocks = root.querySelectorAll(readerTextBlockSelector);
  for (const block of blocks) {
    const text = block.textContent ?? "";
    const containerIndex = text === highlight.containerText ? 0 : text.indexOf(highlight.containerText);
    if (containerIndex >= 0 && wrapTextOffsets(block, containerIndex + highlight.start, containerIndex + highlight.end, highlight.kind)) return true;

    const selectedIndex = text.indexOf(highlight.text);
    if (selectedIndex >= 0 && wrapTextOffsets(block, selectedIndex, selectedIndex + highlight.text.length, highlight.kind)) return true;
  }
  return false;
}

function wrapTextOffsets(root: Element, start: number, end: number, kind: SelectionKind) {
  if (end <= start) return false;
  const segments: Array<{ node: Node; start: number; end: number }> = [];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let offset = 0;
  let current = walker.nextNode();

  while (current) {
    const length = current.textContent?.length ?? 0;
    const segmentStart = Math.max(0, start - offset);
    const segmentEnd = Math.min(length, end - offset);
    if (segmentStart < segmentEnd) {
      segments.push({ node: current, start: segmentStart, end: segmentEnd });
    }
    offset += length;
    if (offset >= end) break;
    current = walker.nextNode();
  }

  for (const segment of segments.reverse()) {
    const range = document.createRange();
    range.setStart(segment.node, segment.start);
    range.setEnd(segment.node, segment.end);
    const mark = document.createElement("mark");
    mark.className = `reader-selection-highlight ${kind}`;
    mark.dataset.readerHighlight = "true";
    range.surroundContents(mark);
  }

  return segments.length > 0;
}

function LearningPanel({
  refElement,
  selectedText,
  activeSelection,
  analysis,
  requestAnalysis,
  speak,
  saveSelection
}: {
  refElement: React.RefObject<HTMLElement | null>;
  selectedText: string;
  activeSelection: ActiveSelection | null;
  analysis: LearningAnalysis | null;
  requestAnalysis: (text?: string) => Promise<LearningAnalysis | null>;
  speak: (text: string) => void;
  saveSelection: (kind?: "word" | "sentence") => void;
}) {
  return (
    <aside className="learning-panel" ref={refElement} tabIndex={-1}>
      <div className="panel-title">Learning Panel</div>
      {!selectedText ? (
        <div className="panel-card">
          <p className="muted">Click a sentence or drag over a word or phrase in the article to translate, explain, pronounce, and save it.</p>
        </div>
      ) : !analysis ? (
        <>
          <div className="selected-text">{selectedText}</div>
          <SelectionStateNote activeSelection={activeSelection} />
          <div className="action-grid">
            <button className="primary-button" onClick={() => requestAnalysis(selectedText)}>
              Translate
            </button>
            <button className="toolbar-button" onClick={() => requestAnalysis(selectedText)}>
              Explain
            </button>
            <button className="toolbar-button" onClick={() => speak(selectedText)}>
              Pronounce
            </button>
            <button className="toolbar-button" onClick={() => saveSelection()}>
              Save
            </button>
          </div>
          <div className="panel-card">
            <p className="muted">Selection is ready. Choose Translate or Explain to load the learning notes.</p>
          </div>
        </>
      ) : (
        <>
          <div className="selected-text">{selectedText}</div>
          <SelectionStateNote activeSelection={activeSelection} />
          <div className="action-grid">
            <button className="primary-button" onClick={() => speak(selectedText)}>
              Pronounce
            </button>
            <button className="toolbar-button" onClick={() => saveSelection()}>
              Save
            </button>
            <button className="toolbar-button" onClick={() => saveSelection("word")}>
              Save word
            </button>
            <button className="toolbar-button" onClick={() => saveSelection("sentence")}>
              Save sentence
            </button>
          </div>
          <div className="panel-card analysis-block">
            <h4>Translation</h4>
            <p className="muted">{analysis.translationProvider}</p>
            <p>{analysis.translation}</p>
          </div>
          <div className="panel-card analysis-block">
            <h4>Explanation</h4>
            <p>{analysis.explanation}</p>
          </div>
          <div className="panel-card analysis-block">
            <h4>Difficulty</h4>
            <p>
              {analysis.difficulty.level} · {analysis.difficulty.score}/100 · {analysis.difficulty.reason}
            </p>
          </div>
          <div className="panel-card analysis-block">
            <h4>Phrase Notes</h4>
            <div className="pill-row">
              {analysis.phrases.map((phrase) => (
                <span className="pill" key={phrase.phrase} title={phrase.meaning}>
                  {phrase.phrase}
                </span>
              ))}
            </div>
          </div>
          <div className="panel-card analysis-block">
            <h4>Structure</h4>
            <ul>
              {analysis.structure.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </div>
        </>
      )}
    </aside>
  );
}

function MobileLearningSheet({
  open,
  selectedText,
  activeSelection,
  analysis,
  detailsOpen,
  setDetailsOpen,
  close,
  requestAnalysis,
  speak,
  saveSelection
}: {
  open: boolean;
  selectedText: string;
  activeSelection: ActiveSelection | null;
  analysis: LearningAnalysis | null;
  detailsOpen: boolean;
  setDetailsOpen: (open: boolean) => void;
  close: () => void;
  requestAnalysis: (text?: string) => Promise<LearningAnalysis | null>;
  speak: (text: string) => void;
  saveSelection: (kind?: "word" | "sentence") => void;
}) {
  if (!open || !selectedText || !activeSelection) return null;
  const isLoading = activeSelection.status === "loading";
  const isError = activeSelection.status === "error";

  return (
    <section className={`mobile-learning-sheet ${activeSelection.status}`} aria-label="Mobile learning panel">
      <div className="mobile-sheet-handle" aria-hidden="true" />
      <div className="mobile-sheet-header">
        <div>
          <div className="panel-title">Selection</div>
          <p className={`mobile-selected-text ${detailsOpen ? "expanded" : ""}`}>{selectedText}</p>
        </div>
        <button className="mobile-sheet-close" onClick={close} aria-label="Close learning panel">
          ×
        </button>
      </div>
      <SelectionStateNote activeSelection={activeSelection} />

      {!analysis ? (
        <>
          <div className="mobile-sheet-actions">
            <button className="primary-button" disabled={isLoading} onClick={() => requestAnalysis(selectedText)}>
              Translate
            </button>
            <button className="toolbar-button" disabled={isLoading} onClick={() => speak(selectedText)}>
              Speak
            </button>
            <button className="toolbar-button" disabled={isLoading} onClick={() => saveSelection()}>
              Save
            </button>
          </div>
          <p className={`mobile-sheet-message ${isError ? "error" : ""}`}>{activeSelection.message ?? "Ready"}</p>
        </>
      ) : (
        <>
          <div className="mobile-translation-card">
            <div className="row-meta">
              <span>{analysis.translationProvider}</span>
            </div>
            <p>{analysis.translation}</p>
          </div>
          <div className="mobile-sheet-actions">
            <button className="primary-button" onClick={() => speak(selectedText)}>
              Speak
            </button>
            <button className="toolbar-button" onClick={() => saveSelection()}>
              Save
            </button>
            <button className="toolbar-button" onClick={() => setDetailsOpen(!detailsOpen)}>
              {detailsOpen ? "Hide" : "Details"}
            </button>
          </div>
          {detailsOpen ? (
            <div className="mobile-sheet-details">
              <div className="analysis-block">
                <h4>Explanation</h4>
                <p>{analysis.explanation}</p>
              </div>
              <div className="analysis-block">
                <h4>Difficulty</h4>
                <p>
                  {analysis.difficulty.level} · {analysis.difficulty.score}/100 · {analysis.difficulty.reason}
                </p>
              </div>
              <div className="analysis-block">
                <h4>Phrase Notes</h4>
                <div className="pill-row">
                  {analysis.phrases.map((phrase) => (
                    <span className="pill" key={phrase.phrase} title={phrase.meaning}>
                      {phrase.phrase}
                    </span>
                  ))}
                </div>
              </div>
              <div className="analysis-block">
                <h4>Structure</h4>
                <ul>
                  {analysis.structure.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </div>
            </div>
          ) : null}
        </>
      )}
    </section>
  );
}

function SelectionStateNote({ activeSelection }: { activeSelection: ActiveSelection | null }) {
  if (!activeSelection) return null;
  const savedMessage = activeSelection.savedAs ? `Saved as ${activeSelection.savedAs}` : "";
  const extraMessage = activeSelection.message && activeSelection.message !== statusLabel(activeSelection.status) && activeSelection.message !== savedMessage ? activeSelection.message : "";
  return (
    <div className={`selection-note ${activeSelection.status}`}>
      <span>{statusLabel(activeSelection.status)}</span>
      {savedMessage ? <span>{savedMessage}</span> : null}
      {extraMessage ? <span>{extraMessage}</span> : null}
    </div>
  );
}

function FeedsView({ feeds, reload, setToast }: { feeds: Feed[]; reload: () => Promise<void>; setToast: (toast: string) => void }) {
  const [url, setUrl] = useState("");

  async function addFeed() {
    if (!url.trim()) return;
    const response = await fetch("/api/feeds", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ url })
    });
    const data = await response.json();
    if (!response.ok) {
      setToast(data.error ?? "Could not add feed.");
      return;
    }
    setUrl("");
    await reload();
    setToast("Feed added.");
  }

  async function deleteFeed(id: number) {
    await fetch(`/api/feeds?id=${id}`, { method: "DELETE" });
    await reload();
    setToast("Feed removed.");
  }

  async function pasteFeedUrl() {
    try {
      const text = await navigator.clipboard?.readText();
      if (!text?.trim()) {
        setToast("Clipboard is empty.");
        return;
      }
      setUrl(text.trim());
      setToast("RSS URL pasted.");
    } catch {
      setToast("Clipboard paste is unavailable. Long-press the field and choose Paste.");
    }
  }

  return (
    <section className="page-panel">
      <div className="page-header">
        <div>
          <h1>Feeds</h1>
          <p className="muted">Add RSS sources for English articles. The server checks enabled feeds every 30 minutes while running.</p>
        </div>
      </div>
      <form
        className="feed-form"
        onSubmit={(event) => {
          event.preventDefault();
          void addFeed();
        }}
      >
        <input
          className="input feed-url-input"
          type="url"
          inputMode="url"
          enterKeyHint="done"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          value={url}
          onChange={(event) => setUrl(event.target.value)}
          onPaste={(event) => {
            event.preventDefault();
            setUrl(event.clipboardData.getData("text").trim());
          }}
          placeholder="https://example.com/rss.xml"
          aria-label="RSS feed URL"
        />
        <div className="feed-form-actions">
          <button className="small-button" type="button" onClick={pasteFeedUrl}>
            Paste
          </button>
          <button className="primary-button" type="submit">
            Add Feed
          </button>
        </div>
      </form>
      <div className="feed-grid" style={{ marginTop: 16 }}>
        {feeds.map((feed) => (
          <div className="feed-row" key={feed.id}>
            <h3 className="row-title">{feed.title}</h3>
            <div className="row-meta">
              <span>{feed.url}</span>
              <span>{feed.lastFetchedAt ? `Fetched ${new Date(feed.lastFetchedAt).toLocaleString()}` : "Not fetched yet"}</span>
            </div>
            {feed.lastError ? <p className="muted" style={{ color: "var(--danger)" }}>{feed.lastError}</p> : null}
            <button className="small-button" onClick={() => deleteFeed(feed.id)}>
              Remove
            </button>
          </div>
        ))}
        {!feeds.length ? <div className="empty">No feeds yet. Add one to start automatic ingestion.</div> : null}
      </div>
    </section>
  );
}

type SavedKind = "word" | "sentence";
type SavedItem = SavedWord | SavedSentence;
type StatusFilter = Familiarity | "all";
type SourceFilter = string;
type WordSort = "updated" | "created" | "count" | "alpha";
type SentenceSort = "updated" | "created" | "length";
type ReviewTypeFilter = SavedKind | "all";
type ReviewStatusFilter = Exclude<StatusFilter, "mastered">;

function WordsView({
  words,
  query,
  speak,
  update,
  setToast
}: {
  words: SavedWord[];
  query: string;
  speak: (text: string) => void;
  update: (words: SavedWord[]) => void;
  setToast: (toast: string) => void;
}) {
  return <SavedList title="Saved Words" items={words} kind="word" query={query} speak={speak} updateWords={update} setToast={setToast} />;
}

function SentencesView({
  sentences,
  query,
  speak,
  update,
  setToast
}: {
  sentences: SavedSentence[];
  query: string;
  speak: (text: string) => void;
  update: (sentences: SavedSentence[]) => void;
  setToast: (toast: string) => void;
}) {
  return <SavedList title="Saved Sentences" items={sentences} kind="sentence" query={query} speak={speak} updateSentences={update} setToast={setToast} />;
}

function ReviewView({
  words,
  sentences,
  speak,
  setWords,
  setSentences,
  setToast
}: {
  words: SavedWord[];
  sentences: SavedSentence[];
  speak: (text: string) => void;
  setWords: (words: SavedWord[]) => void;
  setSentences: (sentences: SavedSentence[]) => void;
  setToast: (toast: string) => void;
}) {
  const [typeFilter, setTypeFilter] = useState<ReviewTypeFilter>("all");
  const [statusFilter, setStatusFilter] = useState<ReviewStatusFilter>("all");
  const dueWords = words.filter((word) => word.familiarity !== "mastered" && (typeFilter === "all" || typeFilter === "word") && (statusFilter === "all" || word.familiarity === statusFilter));
  const dueSentences = sentences.filter(
    (sentence) => sentence.familiarity !== "mastered" && (typeFilter === "all" || typeFilter === "sentence") && (statusFilter === "all" || sentence.familiarity === statusFilter)
  );
  const totalDue = words.filter((word) => word.familiarity !== "mastered").length + sentences.filter((sentence) => sentence.familiarity !== "mastered").length;
  return (
    <section className="page-panel">
      <div className="page-header">
        <div>
          <h1>Review</h1>
          <p className="muted">{totalDue} item(s) in the active review queue. Reveal answers only when you need them.</p>
        </div>
      </div>
      <div className="filter-bar">
        <label>
          <span>Type</span>
          <select className="select" value={typeFilter} onChange={(event) => setTypeFilter(event.target.value as ReviewTypeFilter)}>
            <option value="all">All</option>
            <option value="word">Words</option>
            <option value="sentence">Sentences</option>
          </select>
        </label>
        <label>
          <span>Status</span>
          <select className="select" value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as ReviewStatusFilter)}>
            <option value="all">All active</option>
            <option value="new">New</option>
            <option value="learning">Learning</option>
            <option value="familiar">Familiar</option>
          </select>
        </label>
      </div>
      <div className="review-grid">
        {dueWords.map((word) => (
          <LearningItemCard key={`w-${word.id}`} item={word} kind="word" mode="review" speak={speak} updateWords={setWords} updateSentences={setSentences} setToast={setToast} />
        ))}
        {dueSentences.map((sentence) => (
          <LearningItemCard key={`s-${sentence.id}`} item={sentence} kind="sentence" mode="review" speak={speak} updateWords={setWords} updateSentences={setSentences} setToast={setToast} />
        ))}
        {!dueWords.length && !dueSentences.length ? <div className="empty">No review items due. Save words or sentences while reading.</div> : null}
      </div>
    </section>
  );
}

function SavedList({
  title,
  items,
  kind,
  query,
  speak,
  updateWords,
  updateSentences,
  setToast
}: {
  title: string;
  items: SavedItem[];
  kind: SavedKind;
  query: string;
  speak: (text: string) => void;
  updateWords?: (words: SavedWord[]) => void;
  updateSentences?: (sentences: SavedSentence[]) => void;
  setToast: (toast: string) => void;
}) {
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [sourceFilter, setSourceFilter] = useState<SourceFilter>("all");
  const [sort, setSort] = useState<WordSort | SentenceSort>("updated");
  const sources = useMemo(() => uniqueSources(items), [items]);
  const filtered = useMemo(() => {
    return sortSavedItems(
      items.filter((item) => {
        const text = itemText(item);
        const values = [text, item.translation, item.explanation, item.articleTitle ?? "", "sourceSentence" in item ? item.sourceSentence ?? "" : ""];
        return matchesQuery(values, query) && (statusFilter === "all" || item.familiarity === statusFilter) && (sourceFilter === "all" || (item.articleTitle ?? "No source article") === sourceFilter);
      }),
      kind,
      sort
    );
  }, [items, kind, query, sort, sourceFilter, statusFilter]);

  return (
    <section className="page-panel">
      <div className="page-header">
        <div>
          <h1>{title}</h1>
          <p className="muted">
            Showing {filtered.length} of {items.length}. Search, filter, sort, pronounce, review, and delete saved items.
          </p>
        </div>
      </div>
      <div className="filter-bar">
        <label>
          <span>Status</span>
          <select className="select" value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as StatusFilter)}>
            <option value="all">All</option>
            {familiarityOptions.map((status) => (
              <option value={status} key={status}>
                {status}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span>Source</span>
          <select className="select" value={sourceFilter} onChange={(event) => setSourceFilter(event.target.value)}>
            <option value="all">All sources</option>
            {sources.map((source) => (
              <option value={source} key={source}>
                {source}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span>Sort</span>
          <select className="select" value={sort} onChange={(event) => setSort(event.target.value as WordSort | SentenceSort)}>
            <option value="updated">Recently updated</option>
            <option value="created">Created time</option>
            {kind === "word" ? (
              <>
                <option value="count">Save count</option>
                <option value="alpha">Alphabetical</option>
              </>
            ) : (
              <option value="length">Sentence length</option>
            )}
          </select>
        </label>
      </div>
      <div className="saved-grid">
        {filtered.map((item) => (
          <LearningItemCard key={item.id} item={item} kind={kind} mode="saved" speak={speak} updateWords={updateWords} updateSentences={updateSentences} setToast={setToast} />
        ))}
        {!filtered.length ? <div className="empty">Nothing matches the current filters.</div> : null}
      </div>
    </section>
  );
}

function LearningItemCard({
  item,
  kind,
  mode,
  speak,
  updateWords,
  updateSentences,
  setToast
}: {
  item: SavedItem;
  kind: SavedKind;
  mode: "saved" | "review";
  speak: (text: string) => void;
  updateWords?: (words: SavedWord[]) => void;
  updateSentences?: (sentences: SavedSentence[]) => void;
  setToast: (toast: string) => void;
}) {
  const [expanded, setExpanded] = useState(mode === "saved" ? false : false);
  const text = itemText(item);
  const answerVisible = mode === "saved" || expanded;

  async function setStatus(familiarity: Familiarity) {
    const response = await fetch(kind === "word" ? "/api/words" : "/api/sentences", {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ id: item.id, familiarity })
    });
    const data = await response.json();
    if (kind === "word") updateWords?.(data.words);
    else updateSentences?.(data.sentences);
  }

  async function deleteItem() {
    const label = kind === "word" ? "word" : "sentence";
    const confirmed = window.confirm(`Delete this saved ${label} permanently from local MagReader?`);
    if (!confirmed) return;
    const response = await fetch(`${kind === "word" ? "/api/words" : "/api/sentences"}?id=${item.id}`, { method: "DELETE" });
    const data = await response.json();
    if (!response.ok) {
      setToast(data.error ?? `Could not delete ${label}.`);
      return;
    }
    if (kind === "word") updateWords?.(data.words);
    else updateSentences?.(data.sentences);
    setToast(kind === "word" ? "Word deleted." : "Sentence deleted.");
  }

  return (
    <div className={`review-row learning-card ${mode}`}>
      <div className="row-meta">
        <span className="status-dot" />
        <span>{kind}</span>
        <span>{item.familiarity}</span>
        <span>{item.articleTitle ?? "No source article"}</span>
        {"count" in item ? <span>{item.count} save(s)</span> : null}
      </div>
      <h3 className="row-title" style={{ marginTop: 8 }}>
        {text}
      </h3>
      {answerVisible ? (
        <>
          <p className="muted">{item.translation}</p>
          {mode === "saved" || expanded ? <p className="muted">{item.explanation}</p> : null}
        </>
      ) : (
        <p className="muted">Answer hidden for review. Reveal it when you are ready.</p>
      )}
      {expanded ? (
        <div className="detail-block">
          {"sourceSentence" in item && item.sourceSentence ? <p>Source sentence: {item.sourceSentence}</p> : null}
          <p>Source article: {item.articleTitle ?? "No source article"}</p>
          <p>Created: {new Date(item.createdAt).toLocaleString()}</p>
          <p>Updated: {new Date(item.updatedAt).toLocaleString()}</p>
          {"count" in item ? <p>Saved count: {item.count}</p> : null}
        </div>
      ) : null}
      <div className="toolbar" style={{ justifyContent: "flex-start" }}>
        <button className="small-button" onClick={() => speak(text)}>
          Speak
        </button>
        <button className="small-button" onClick={() => setExpanded((value) => !value)}>
          {expanded ? "Hide details" : mode === "review" ? "Reveal answer" : "Details"}
        </button>
        {familiarityOptions.map((status) => (
          <button key={status} className={`small-button ${item.familiarity === status ? "active" : ""}`} onClick={() => setStatus(status)}>
            {status}
          </button>
        ))}
        <button className="small-button danger-button" onClick={deleteItem}>
          Delete
        </button>
      </div>
    </div>
  );
}

function itemText(item: SavedItem) {
  return "displayWord" in item ? item.displayWord : item.text;
}

function uniqueSources(items: SavedItem[]) {
  return Array.from(new Set(items.map((item) => item.articleTitle ?? "No source article"))).sort((a, b) => a.localeCompare(b));
}

function sortSavedItems(items: SavedItem[], kind: SavedKind, sort: WordSort | SentenceSort) {
  const copy = [...items];
  if (sort === "created") return copy.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  if (sort === "updated") return copy.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  if (kind === "word" && sort === "count") return (copy as SavedWord[]).sort((a, b) => b.count - a.count);
  if (kind === "word" && sort === "alpha") return copy.sort((a, b) => itemText(a).localeCompare(itemText(b)));
  if (kind === "sentence" && sort === "length") return copy.sort((a, b) => itemText(b).length - itemText(a).length);
  return copy;
}

function SettingsView({ settings, updateSettings }: { settings: ReaderSettings; updateSettings: (patch: Partial<ReaderSettings>) => void }) {
  return (
    <section className="page-panel">
      <div className="page-header">
        <div>
          <h1>Settings</h1>
          <p className="muted">Tune reading comfort and pronunciation playback.</p>
        </div>
      </div>
      <div className="saved-grid">
        <label className="saved-row">
          <span className="section-label">Translation engine</span>
          <select
            className="select"
            value={settings.translationProvider}
            onChange={(event) => updateSettings({ translationProvider: event.target.value as ReaderSettings["translationProvider"] })}
          >
            <option value="mymemory">MyMemory Free</option>
            <option value="baidu">Baidu API</option>
            <option value="netease">NetEase Youdao API</option>
            <option value="microsoft">Microsoft Translator</option>
            <option value="google">Google Public</option>
            <option value="mock">Mock</option>
          </select>
        </label>
        <label className="saved-row">
          <span className="section-label">Font</span>
          <select className="select" value={settings.fontFamily} onChange={(event) => updateSettings({ fontFamily: event.target.value })}>
            <option value={`Georgia, 'Times New Roman', serif`}>Editorial Serif</option>
            <option value={`Inter, ui-sans-serif, system-ui, sans-serif`}>Clean Sans</option>
            <option value={`Charter, Georgia, serif`}>Charter</option>
          </select>
        </label>
        <RangeSetting label="Font size" value={settings.fontSize} min={16} max={28} step={1} onChange={(fontSize) => updateSettings({ fontSize })} />
        <RangeSetting label="Line height" value={settings.lineHeight} min={1.35} max={2.2} step={0.05} onChange={(lineHeight) => updateSettings({ lineHeight })} />
        <RangeSetting label="Content width" value={settings.contentWidth} min={620} max={920} step={20} onChange={(contentWidth) => updateSettings({ contentWidth })} />
        <RangeSetting label="Paragraph gap" value={settings.paragraphGap} min={0.8} max={1.8} step={0.05} onChange={(paragraphGap) => updateSettings({ paragraphGap })} />
        <RangeSetting label="Speech rate" value={settings.speechRate} min={0.7} max={1.2} step={0.05} onChange={(speechRate) => updateSettings({ speechRate })} />
      </div>
    </section>
  );
}

function RangeSetting({ label, value, min, max, step, onChange }: { label: string; value: number; min: number; max: number; step: number; onChange: (value: number) => void }) {
  return (
    <label className="saved-row">
      <span className="section-label">{label}</span>
      <div className="row-meta">
        <input className="input" type="range" value={value} min={min} max={max} step={step} onChange={(event) => onChange(Number(event.target.value))} />
        <span>{value}</span>
      </div>
    </label>
  );
}

function matchesQuery(values: string[], query: string) {
  const q = query.toLowerCase().trim();
  return !q || values.some((value) => value.toLowerCase().includes(q));
}
