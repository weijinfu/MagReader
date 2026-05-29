import { JSDOM } from "jsdom";
import { Readability } from "@mozilla/readability";
import Parser from "rss-parser";
import { listFeeds, logIngestion, updateFeed, upsertArticle } from "@/lib/db";
import { rateArticleDifficulty } from "@/lib/ai";
import { stripHtml } from "@/lib/utils";

const parser = new Parser({
  timeout: 12000,
  customFields: {
    item: ["content:encoded", "content"]
  }
});

type ParserItem = Parser.Item & {
  "content:encoded"?: string;
  content?: string;
  author?: string;
  summary?: string;
};

export async function refreshAllFeeds() {
  const feeds = listFeeds().filter((feed) => feed.enabled);
  const results = [];
  for (const feed of feeds) {
    results.push(await refreshFeed(feed.id, feed.url));
  }
  return results;
}

export async function refreshFeed(feedId: number, url: string) {
  try {
    const parsed = await parser.parseURL(url);
    let inserted = 0;
    for (const item of parsed.items as ParserItem[]) {
      const articleUrl = item.link || item.guid;
      if (!articleUrl) continue;
      const extracted = await extractArticle(articleUrl, item);
      upsertArticle({
        feedId,
        guid: item.guid ?? articleUrl,
        url: articleUrl,
        title: item.title?.trim() || "Untitled Article",
        author: item.creator ?? item.author ?? null,
        publishedAt: item.isoDate ?? item.pubDate ?? null,
        excerpt: item.contentSnippet ?? stripHtml(item.content ?? item["content:encoded"] ?? "").slice(0, 220),
        contentHtml: extracted.html,
        contentText: extracted.text,
        difficulty: rateArticleDifficulty(extracted.text)
      });
      inserted += 1;
    }
    updateFeed(feedId, {
      title: parsed.title || undefined,
      siteUrl: parsed.link ?? null,
      lastFetchedAt: new Date().toISOString(),
      lastError: null
    });
    logIngestion(feedId, "success", `Fetched ${inserted} item(s).`);
    return { feedId, ok: true, count: inserted };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown RSS error";
    updateFeed(feedId, { lastError: message });
    logIngestion(feedId, "error", message);
    return { feedId, ok: false, count: 0, error: message };
  }
}

async function extractArticle(url: string, item: ParserItem) {
  const feedHtml = item["content:encoded"] || item.content || item.summary || "";
  try {
    const response = await fetch(url, {
      headers: {
        "user-agent": "MagReader/0.1 (+local learning reader)"
      },
      signal: AbortSignal.timeout(12000)
    });
    const html = await response.text();
    const dom = new JSDOM(html, { url });
    const readable = new Readability(dom.window.document).parse();
    if (readable?.content && readable.textContent.trim().length > 300) {
      return {
        html: sanitizeReadableHtml(readable.content),
        text: readable.textContent.trim()
      };
    }
  } catch {
    // RSS summaries are a valid fallback for sources that block article extraction.
  }

  const fallbackText = stripHtml(feedHtml || item.contentSnippet || item.title || "");
  return {
    html: feedHtml || `<p>${escapeHtml(fallbackText)}</p>`,
    text: fallbackText
  };
}

function sanitizeReadableHtml(html: string) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/\son\w+="[^"]*"/gi, "");
}

function escapeHtml(text: string) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
