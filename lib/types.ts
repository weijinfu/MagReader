export type ViewKey = "articles" | "feeds" | "words" | "sentences" | "review" | "settings";

export type Familiarity = "new" | "learning" | "familiar" | "mastered";

export type Feed = {
  id: number;
  title: string;
  url: string;
  siteUrl: string | null;
  enabled: boolean;
  lastFetchedAt: string | null;
  lastError: string | null;
  createdAt: string;
};

export type Article = {
  id: number;
  feedId: number | null;
  feedTitle: string | null;
  guid: string | null;
  url: string;
  title: string;
  author: string | null;
  publishedAt: string | null;
  excerpt: string | null;
  contentHtml: string;
  contentText: string;
  difficulty: string;
  status: "unread" | "read" | "archived";
  favorite: boolean;
  createdAt: string;
  updatedAt: string;
};

export type SavedWord = {
  id: number;
  word: string;
  displayWord: string;
  translation: string;
  explanation: string;
  sourceSentence: string | null;
  articleId: number | null;
  articleTitle: string | null;
  familiarity: Familiarity;
  count: number;
  createdAt: string;
  updatedAt: string;
};

export type SavedSentence = {
  id: number;
  text: string;
  translation: string;
  explanation: string;
  articleId: number | null;
  articleTitle: string | null;
  familiarity: Familiarity;
  createdAt: string;
  updatedAt: string;
};

export type ReaderSettings = {
  theme: "light" | "dark";
  translationProvider: TranslationProvider;
  fontFamily: string;
  fontSize: number;
  lineHeight: number;
  contentWidth: number;
  paragraphGap: number;
  speechRate: number;
};

export type TranslationProvider = "mymemory" | "baidu" | "netease" | "youdao" | "microsoft" | "google" | "mock";

export type LearningAnalysis = {
  kind: "word" | "sentence";
  text: string;
  translation: string;
  translationProvider: string;
  explanation: string;
  phrases: Array<{ phrase: string; meaning: string }>;
  structure: string[];
  difficulty: {
    level: "A2" | "B1" | "B2" | "C1" | "C2";
    score: number;
    reason: string;
  };
};

export type DashboardPayload = {
  feeds: Feed[];
  articles: Article[];
  words: SavedWord[];
  sentences: SavedSentence[];
  settings: ReaderSettings;
};
