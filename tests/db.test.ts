import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";

const tempDbs: string[] = [];

async function loadDbModule() {
  const dbPath = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "magreader-test-")), "test.db");
  tempDbs.push(dbPath);
  vi.resetModules();
  process.env.MAGREADER_DB = dbPath;
  return import("@/lib/db");
}

afterEach(() => {
  delete process.env.MAGREADER_DB;
  for (const dbPath of tempDbs.splice(0)) {
    fs.rmSync(path.dirname(dbPath), { force: true, recursive: true });
  }
});

describe("saved item deletion", () => {
  it("archives feed articles missing from the latest refresh without deleting them", async () => {
    const { archiveMissingFeedArticles, createFeed, listArticles, upsertArticle } = await loadDbModule();
    const feed = createFeed({ title: "Example Feed", url: "https://example.com/rss.xml" })[0];
    upsertArticle({
      feedId: feed.id,
      guid: "fresh",
      url: "https://example.com/fresh",
      title: "Fresh Article",
      author: null,
      publishedAt: "2026-05-31T00:00:00.000Z",
      excerpt: "Fresh",
      contentHtml: "<p>Fresh article.</p>",
      contentText: "Fresh article.",
      difficulty: "A2"
    });
    upsertArticle({
      feedId: feed.id,
      guid: "stale",
      url: "https://example.com/stale",
      title: "Stale Article",
      author: null,
      publishedAt: "2026-05-30T00:00:00.000Z",
      excerpt: "Stale",
      contentHtml: "<p>Stale article.</p>",
      contentText: "Stale article.",
      difficulty: "A2"
    });

    const archived = archiveMissingFeedArticles(feed.id, ["https://example.com/fresh"]);

    expect(archived).toBe(1);
    expect(listArticles().map((article) => article.url)).toContain("https://example.com/fresh");
    expect(listArticles().map((article) => article.url)).not.toContain("https://example.com/stale");
  });

  it("unarchives a feed article when it appears again in a later refresh", async () => {
    const { archiveMissingFeedArticles, createFeed, listArticles, upsertArticle } = await loadDbModule();
    const feed = createFeed({ title: "Example Feed", url: "https://example.com/rss.xml" })[0];
    upsertArticle({
      feedId: feed.id,
      guid: "returning",
      url: "https://example.com/returning",
      title: "Returning Article",
      author: null,
      publishedAt: "2026-05-31T00:00:00.000Z",
      excerpt: "Returning",
      contentHtml: "<p>Returning article.</p>",
      contentText: "Returning article.",
      difficulty: "A2"
    });
    archiveMissingFeedArticles(feed.id, []);

    expect(listArticles().map((article) => article.url)).not.toContain("https://example.com/returning");

    upsertArticle({
      feedId: feed.id,
      guid: "returning",
      url: "https://example.com/returning",
      title: "Returning Article",
      author: null,
      publishedAt: "2026-05-31T00:00:00.000Z",
      excerpt: "Returning",
      contentHtml: "<p>Returning article.</p>",
      contentText: "Returning article.",
      difficulty: "A2"
    });

    expect(listArticles().map((article) => article.url)).toContain("https://example.com/returning");
  });

  it("clears articles that do not belong to a current feed", async () => {
    const { createFeed, getArticle, listArticles, upsertArticle } = await loadDbModule();
    const feed = createFeed({ title: "Example Feed", url: "https://example.com/rss.xml" })[0];
    upsertArticle({
      feedId: null,
      guid: "orphan",
      url: "https://example.com/orphan",
      title: "Orphan Article",
      author: null,
      publishedAt: "2026-05-31T00:00:00.000Z",
      excerpt: "No source",
      contentHtml: "<p>No source article.</p>",
      contentText: "No source article.",
      difficulty: "A2"
    });
    upsertArticle({
      feedId: null,
      guid: "author-source",
      url: "https://example.com/author-source",
      title: "Author Source Article",
      author: "Example Author",
      publishedAt: "2026-05-31T00:00:00.000Z",
      excerpt: "Has author",
      contentHtml: "<p>Author source article.</p>",
      contentText: "Author source article.",
      difficulty: "A2"
    });
    upsertArticle({
      feedId: feed.id,
      guid: "feed-source",
      url: "https://example.com/feed-source",
      title: "Feed Source Article",
      author: null,
      publishedAt: "2026-05-31T00:00:00.000Z",
      excerpt: "Has feed",
      contentHtml: "<p>Feed source article.</p>",
      contentText: "Feed source article.",
      difficulty: "A2"
    });

    const urls = listArticles().map((article) => article.url);

    expect(urls).not.toContain("https://example.com/orphan");
    expect(urls).not.toContain("https://example.com/author-source");
    expect(urls).toContain("https://example.com/feed-source");
    expect(getArticle(1)).toBeNull();
  });

  it("assigns an existing URL to the feed when RSS refresh sees it again", async () => {
    const { createFeed, listArticles, upsertArticle } = await loadDbModule();
    upsertArticle({
      feedId: null,
      guid: "orphan",
      url: "https://example.com/reclaimed",
      title: "Orphan Article",
      author: null,
      publishedAt: "2026-05-31T00:00:00.000Z",
      excerpt: "No source",
      contentHtml: "<p>No source article.</p>",
      contentText: "No source article.",
      difficulty: "A2"
    });
    const feed = createFeed({ title: "Example Feed", url: "https://example.com/rss.xml" })[0];

    upsertArticle({
      feedId: feed.id,
      guid: "reclaimed",
      url: "https://example.com/reclaimed",
      title: "Reclaimed Article",
      author: null,
      publishedAt: "2026-05-31T00:00:00.000Z",
      excerpt: "Has feed now",
      contentHtml: "<p>Feed article.</p>",
      contentText: "Feed article.",
      difficulty: "A2"
    });

    const articles = listArticles();

    expect(articles).toHaveLength(1);
    expect(articles[0].url).toBe("https://example.com/reclaimed");
    expect(articles[0].feedTitle).toBe("Example Feed");
  });

  it("persists reader settings without losing defaults", async () => {
    const { getSettings, saveSettings } = await loadDbModule();

    const updated = saveSettings({ theme: "dark", translationProvider: "mock", fontSize: 22 });

    expect(updated.theme).toBe("dark");
    expect(updated.translationProvider).toBe("google");
    expect(updated.fontSize).toBe(22);
    expect(updated.lineHeight).toBe(getSettings().lineHeight);
    expect(getSettings().theme).toBe("dark");
  });

  it("increments saved word count when the same word is saved again", async () => {
    const { saveWord } = await loadDbModule();
    saveWord({
      word: "context",
      displayWord: "context",
      translation: "语境",
      explanation: "Meaning depends on nearby words.",
      sourceSentence: "Context makes meaning clearer.",
      articleId: null
    });

    const afterSecondSave = saveWord({
      word: "context",
      displayWord: "Context",
      translation: "上下文",
      explanation: "Updated explanation.",
      sourceSentence: null,
      articleId: null
    });

    expect(afterSecondSave).toHaveLength(1);
    expect(afterSecondSave[0].count).toBe(2);
    expect(afterSecondSave[0].displayWord).toBe("Context");
    expect(afterSecondSave[0].sourceSentence).toBe("Context makes meaning clearer.");
  });

  it("updates review familiarity for words and sentences", async () => {
    const { listSavedSentences, listSavedWords, saveSentence, saveWord, updateReview } = await loadDbModule();
    const words = saveWord({
      word: "context",
      displayWord: "context",
      translation: "语境",
      explanation: "Meaning depends on nearby words.",
      sourceSentence: "Context makes meaning clearer.",
      articleId: null
    });
    const sentences = saveSentence({
      text: "A difficult sentence becomes easier when it is divided into clauses.",
      translation: "把难句拆成从句后会更容易。",
      explanation: "Split the sentence into clauses.",
      articleId: null
    });

    updateReview("word", words[0].id, "familiar");
    updateReview("sentence", sentences[0].id, "mastered");

    expect(listSavedWords()[0].familiarity).toBe("familiar");
    expect(listSavedSentences()[0].familiarity).toBe("mastered");
  });

  it("deletes a saved word from the returned list", async () => {
    const { deleteSavedWord, saveWord } = await loadDbModule();
    const words = saveWord({
      word: "context",
      displayWord: "context",
      translation: "语境",
      explanation: "Meaning depends on nearby words.",
      sourceSentence: "Context makes meaning clearer.",
      articleId: null
    });

    const afterDelete = deleteSavedWord(words[0].id);
    expect(afterDelete.some((word) => word.word === "context")).toBe(false);
  });

  it("deletes a saved sentence from the returned list", async () => {
    const { deleteSavedSentence, saveSentence } = await loadDbModule();
    const sentences = saveSentence({
      text: "A difficult sentence becomes easier when it is divided into clauses.",
      translation: "把难句拆成从句后会更容易。",
      explanation: "Split the sentence into clauses.",
      articleId: null
    });

    const afterDelete = deleteSavedSentence(sentences[0].id);
    expect(afterDelete.some((sentence) => sentence.text.includes("difficult sentence"))).toBe(false);
  });
});
