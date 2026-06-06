import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";
import type { Article, DashboardPayload, Feed, ReaderSettings, SavedSentence, SavedWord, WordMeaning } from "@/lib/types";
import { nowIso, toBoolean } from "@/lib/utils";

const dataDir = path.join(process.cwd(), "data");
const dbPath = process.env.MAGREADER_DB ?? path.join(dataDir, "magreader.db");

let db: Database.Database | null = null;

export function getDb() {
  if (!db) {
    fs.mkdirSync(dataDir, { recursive: true });
    db = new Database(dbPath);
    db.pragma("journal_mode = WAL");
    db.pragma("foreign_keys = ON");
    migrate(db);
  }
  return db;
}

function migrate(database: Database.Database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS feeds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      url TEXT NOT NULL UNIQUE,
      site_url TEXT,
      enabled INTEGER NOT NULL DEFAULT 1,
      last_fetched_at TEXT,
      last_error TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS articles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      feed_id INTEGER REFERENCES feeds(id) ON DELETE SET NULL,
      guid TEXT,
      url TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      author TEXT,
      published_at TEXT,
      excerpt TEXT,
      content_html TEXT NOT NULL,
      content_text TEXT NOT NULL,
      difficulty TEXT NOT NULL DEFAULT 'B2',
      status TEXT NOT NULL DEFAULT 'unread',
      favorite INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS saved_words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT NOT NULL UNIQUE,
      display_word TEXT NOT NULL,
      translation TEXT NOT NULL,
      meanings_json TEXT NOT NULL DEFAULT '[]',
      explanation TEXT NOT NULL,
      source_sentence TEXT,
      article_id INTEGER REFERENCES articles(id) ON DELETE SET NULL,
      familiarity TEXT NOT NULL DEFAULT 'new',
      count INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS saved_sentences (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      text TEXT NOT NULL UNIQUE,
      translation TEXT NOT NULL,
      explanation TEXT NOT NULL,
      article_id INTEGER REFERENCES articles(id) ON DELETE SET NULL,
      familiarity TEXT NOT NULL DEFAULT 'new',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS annotations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
      kind TEXT NOT NULL,
      text TEXT NOT NULL,
      note TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS ingestion_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      feed_id INTEGER REFERENCES feeds(id) ON DELETE CASCADE,
      status TEXT NOT NULL,
      message TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  `);
  addColumnIfNeeded(database, "saved_words", "meanings_json", "TEXT NOT NULL DEFAULT '[]'");
}

function addColumnIfNeeded(database: Database.Database, table: string, column: string, definition: string) {
  const columns = database.prepare(`PRAGMA table_info(${table})`).all() as Array<{ name: string }>;
  if (!columns.some((item) => item.name === column)) {
    database.prepare(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`).run();
  }
}

const defaultSettings: ReaderSettings = {
  theme: "light",
  translationProvider: "google",
  fontFamily: "Georgia, 'Times New Roman', serif",
  fontSize: 20,
  lineHeight: 1.75,
  contentWidth: 760,
  paragraphGap: 1.25,
  speechRate: 0.92
};

export function getSettings(): ReaderSettings {
  const rows = getDb().prepare("SELECT key, value FROM settings").all() as Array<{ key: string; value: string }>;
  const saved = Object.fromEntries(rows.map((row) => [row.key, JSON.parse(row.value)]));
  const settings = { ...defaultSettings, ...saved };
  if (!["google", "mymemory"].includes(settings.translationProvider)) {
    settings.translationProvider = "google";
  }
  return settings;
}

export function saveSettings(settings: Partial<ReaderSettings>) {
  const database = getDb();
  const stmt = database.prepare("INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");
  for (const [key, value] of Object.entries(settings)) {
    stmt.run(key, JSON.stringify(value));
  }
  return getSettings();
}

export function getDashboard(): DashboardPayload {
  return {
    feeds: listFeeds(),
    articles: listArticles(),
    words: listSavedWords(),
    sentences: listSavedSentences(),
    settings: getSettings()
  };
}

export function listFeeds(): Feed[] {
  const rows = getDb().prepare("SELECT * FROM feeds ORDER BY created_at DESC").all() as DbFeed[];
  return rows.map(mapFeed);
}

export function createFeed(input: { title?: string; url: string }) {
  const now = nowIso();
  getDb()
    .prepare("INSERT INTO feeds (title, url, enabled, created_at) VALUES (?, ?, 1, ?)")
    .run(input.title || new URL(input.url).hostname, input.url, now);
  return listFeeds();
}

export function updateFeed(id: number, input: Partial<{ title: string; url: string; enabled: boolean; siteUrl: string | null; lastFetchedAt: string | null; lastError: string | null }>) {
  const existing = getDb().prepare("SELECT * FROM feeds WHERE id = ?").get(id) as DbFeed | undefined;
  if (!existing) throw new Error("Feed not found");
  getDb()
    .prepare("UPDATE feeds SET title = ?, url = ?, site_url = ?, enabled = ?, last_fetched_at = ?, last_error = ? WHERE id = ?")
    .run(
      input.title ?? existing.title,
      input.url ?? existing.url,
      input.siteUrl === undefined ? existing.site_url : input.siteUrl,
      input.enabled === undefined ? existing.enabled : input.enabled ? 1 : 0,
      input.lastFetchedAt === undefined ? existing.last_fetched_at : input.lastFetchedAt,
      input.lastError === undefined ? existing.last_error : input.lastError,
      id
    );
}

export function deleteFeed(id: number) {
  getDb().prepare("DELETE FROM feeds WHERE id = ?").run(id);
}

export function listArticles(): Article[] {
  clearUnsubscribedArticles();
  const rows = getDb()
    .prepare(
      `SELECT articles.*, feeds.title AS feed_title
       FROM articles
       INNER JOIN feeds ON feeds.id = articles.feed_id
       WHERE articles.status != 'archived'
       ORDER BY COALESCE(articles.published_at, articles.created_at) DESC`
    )
    .all() as DbArticle[];
  return rows.map(mapArticle);
}

export function getArticle(id: number): Article | null {
  const row = getDb()
    .prepare(
      `SELECT articles.*, feeds.title AS feed_title
       FROM articles
       LEFT JOIN feeds ON feeds.id = articles.feed_id
       WHERE articles.id = ?`
    )
    .get(id) as DbArticle | undefined;
  return row ? mapArticle(row) : null;
}

export function upsertArticle(input: {
  feedId: number | null;
  guid: string | null;
  url: string;
  title: string;
  author: string | null;
  publishedAt: string | null;
  excerpt: string | null;
  contentHtml: string;
  contentText: string;
  difficulty: string;
}) {
  const now = nowIso();
  getDb()
    .prepare(
      `INSERT INTO articles
      (feed_id, guid, url, title, author, published_at, excerpt, content_html, content_text, difficulty, status, favorite, created_at, updated_at)
      VALUES (@feedId, @guid, @url, @title, @author, @publishedAt, @excerpt, @contentHtml, @contentText, @difficulty, 'unread', 0, @now, @now)
      ON CONFLICT(url) DO UPDATE SET
        title = excluded.title,
        feed_id = excluded.feed_id,
        guid = excluded.guid,
        author = excluded.author,
        published_at = excluded.published_at,
        excerpt = excluded.excerpt,
        content_html = excluded.content_html,
        content_text = excluded.content_text,
        difficulty = excluded.difficulty,
        status = CASE WHEN articles.status = 'archived' THEN 'unread' ELSE articles.status END,
        updated_at = excluded.updated_at`
    )
    .run({ ...input, now });
}

export function clearUnsubscribedArticles() {
  return getDb()
    .prepare(
      `DELETE FROM articles
       WHERE feed_id IS NULL
          OR NOT EXISTS (
            SELECT 1
            FROM feeds
            WHERE feeds.id = articles.feed_id
          )`
    )
    .run().changes;
}

export function archiveMissingFeedArticles(feedId: number, currentUrls: string[]) {
  const database = getDb();
  const now = nowIso();
  if (!currentUrls.length) {
    return database
      .prepare("UPDATE articles SET status = 'archived', updated_at = ? WHERE feed_id = ? AND status != 'archived'")
      .run(now, feedId).changes;
  }

  const placeholders = currentUrls.map(() => "?").join(", ");
  return database
    .prepare(`UPDATE articles SET status = 'archived', updated_at = ? WHERE feed_id = ? AND status != 'archived' AND url NOT IN (${placeholders})`)
    .run(now, feedId, ...currentUrls).changes;
}

export function markArticle(id: number, status: Article["status"]) {
  getDb().prepare("UPDATE articles SET status = ?, updated_at = ? WHERE id = ?").run(status, nowIso(), id);
}

export function saveWord(input: {
  word: string;
  displayWord: string;
  translation: string;
  meanings?: WordMeaning[];
  explanation: string;
  sourceSentence: string | null;
  articleId: number | null;
}) {
  const now = nowIso();
  const meaningsJson = encodeMeanings(input.meanings ?? []);
  getDb()
    .prepare(
      `INSERT INTO saved_words
      (word, display_word, translation, meanings_json, explanation, source_sentence, article_id, familiarity, count, created_at, updated_at)
      VALUES (@word, @displayWord, @translation, @meaningsJson, @explanation, @sourceSentence, @articleId, 'new', 1, @now, @now)
      ON CONFLICT(word) DO UPDATE SET
        display_word = excluded.display_word,
        translation = excluded.translation,
        meanings_json = CASE WHEN excluded.meanings_json != '[]' THEN excluded.meanings_json ELSE saved_words.meanings_json END,
        explanation = excluded.explanation,
        source_sentence = COALESCE(excluded.source_sentence, saved_words.source_sentence),
        article_id = COALESCE(excluded.article_id, saved_words.article_id),
        count = saved_words.count + 1,
        updated_at = excluded.updated_at`
    )
    .run({ ...input, meaningsJson, now });
  return listSavedWords();
}

export function updateSavedWordMeanings(id: number, meanings: WordMeaning[]) {
  getDb().prepare("UPDATE saved_words SET meanings_json = ?, updated_at = ? WHERE id = ?").run(encodeMeanings(meanings), nowIso(), id);
  return listSavedWords();
}

export function saveSentence(input: { text: string; translation: string; explanation: string; articleId: number | null }) {
  const now = nowIso();
  getDb()
    .prepare(
      `INSERT INTO saved_sentences
      (text, translation, explanation, article_id, familiarity, created_at, updated_at)
      VALUES (@text, @translation, @explanation, @articleId, 'new', @now, @now)
      ON CONFLICT(text) DO UPDATE SET
        translation = excluded.translation,
        explanation = excluded.explanation,
        article_id = COALESCE(excluded.article_id, saved_sentences.article_id),
        updated_at = excluded.updated_at`
    )
    .run({ ...input, now });
  return listSavedSentences();
}

export function listSavedWords(): SavedWord[] {
  const rows = getDb()
    .prepare(
      `SELECT saved_words.*, articles.title AS article_title
       FROM saved_words
       LEFT JOIN articles ON articles.id = saved_words.article_id
       ORDER BY saved_words.updated_at DESC`
    )
    .all() as DbSavedWord[];
  return rows.map(mapSavedWord);
}

export function listSavedSentences(): SavedSentence[] {
  const rows = getDb()
    .prepare(
      `SELECT saved_sentences.*, articles.title AS article_title
       FROM saved_sentences
       LEFT JOIN articles ON articles.id = saved_sentences.article_id
       ORDER BY saved_sentences.updated_at DESC`
    )
    .all() as DbSavedSentence[];
  return rows.map(mapSavedSentence);
}

export function updateReview(kind: "word" | "sentence", id: number, familiarity: string) {
  const table = kind === "word" ? "saved_words" : "saved_sentences";
  getDb().prepare(`UPDATE ${table} SET familiarity = ?, updated_at = ? WHERE id = ?`).run(familiarity, nowIso(), id);
}

export function deleteSavedWord(id: number) {
  getDb().prepare("DELETE FROM saved_words WHERE id = ?").run(id);
  return listSavedWords();
}

export function deleteSavedSentence(id: number) {
  getDb().prepare("DELETE FROM saved_sentences WHERE id = ?").run(id);
  return listSavedSentences();
}

export function logIngestion(feedId: number, status: "success" | "error", message: string) {
  getDb().prepare("INSERT INTO ingestion_logs (feed_id, status, message, created_at) VALUES (?, ?, ?, ?)").run(feedId, status, message, nowIso());
}

type DbFeed = {
  id: number;
  title: string;
  url: string;
  site_url: string | null;
  enabled: number;
  last_fetched_at: string | null;
  last_error: string | null;
  created_at: string;
};

type DbArticle = {
  id: number;
  feed_id: number | null;
  feed_title: string | null;
  guid: string | null;
  url: string;
  title: string;
  author: string | null;
  published_at: string | null;
  excerpt: string | null;
  content_html: string;
  content_text: string;
  difficulty: string;
  status: Article["status"];
  favorite: number;
  created_at: string;
  updated_at: string;
};

type DbSavedWord = {
  id: number;
  word: string;
  display_word: string;
  translation: string;
  meanings_json: string | null;
  explanation: string;
  source_sentence: string | null;
  article_id: number | null;
  article_title: string | null;
  familiarity: SavedWord["familiarity"];
  count: number;
  created_at: string;
  updated_at: string;
};

type DbSavedSentence = {
  id: number;
  text: string;
  translation: string;
  explanation: string;
  article_id: number | null;
  article_title: string | null;
  familiarity: SavedSentence["familiarity"];
  created_at: string;
  updated_at: string;
};

function mapFeed(row: DbFeed): Feed {
  return {
    id: row.id,
    title: row.title,
    url: row.url,
    siteUrl: row.site_url,
    enabled: toBoolean(row.enabled),
    lastFetchedAt: row.last_fetched_at,
    lastError: row.last_error,
    createdAt: row.created_at
  };
}

function mapArticle(row: DbArticle): Article {
  return {
    id: row.id,
    feedId: row.feed_id,
    feedTitle: row.feed_title,
    guid: row.guid,
    url: row.url,
    title: row.title,
    author: row.author,
    publishedAt: row.published_at,
    excerpt: row.excerpt,
    contentHtml: row.content_html,
    contentText: row.content_text,
    difficulty: row.difficulty,
    status: row.status,
    favorite: toBoolean(row.favorite),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function mapSavedWord(row: DbSavedWord): SavedWord {
  return {
    id: row.id,
    word: row.word,
    displayWord: row.display_word,
    translation: row.translation,
    meanings: decodeMeanings(row.meanings_json),
    explanation: row.explanation,
    sourceSentence: row.source_sentence,
    articleId: row.article_id,
    articleTitle: row.article_title,
    familiarity: row.familiarity,
    count: row.count,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function encodeMeanings(meanings: WordMeaning[]) {
  return JSON.stringify(meanings);
}

function decodeMeanings(value: string | null): WordMeaning[] {
  if (!value) return [];
  try {
    const parsed = JSON.parse(value) as WordMeaning[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function mapSavedSentence(row: DbSavedSentence): SavedSentence {
  return {
    id: row.id,
    text: row.text,
    translation: row.translation,
    explanation: row.explanation,
    articleId: row.article_id,
    articleTitle: row.article_title,
    familiarity: row.familiarity,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}
