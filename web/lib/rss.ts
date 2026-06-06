import { JSDOM } from "jsdom";
import { Readability } from "@mozilla/readability";
import http from "node:http";
import https from "node:https";
import { HttpProxyAgent } from "http-proxy-agent";
import { HttpsProxyAgent } from "https-proxy-agent";
import Parser from "rss-parser";
import { archiveMissingFeedArticles, listFeeds, logIngestion, updateFeed, upsertArticle } from "@/lib/db";
import { rateArticleDifficulty } from "@/lib/ai";
import { stripHtml } from "@/lib/utils";

const rssTimeoutMs = Number.parseInt(process.env.RSS_TIMEOUT_MS ?? "12000", 10);
const requestTimeoutMs = Number.isFinite(rssTimeoutMs) && rssTimeoutMs > 0 ? rssTimeoutMs : 12000;
const rssProxyUrl = process.env.RSS_PROXY_URL?.trim();
const httpProxyAgent = rssProxyUrl ? new HttpProxyAgent(rssProxyUrl) : null;
const httpsProxyAgent = rssProxyUrl ? new HttpsProxyAgent(rssProxyUrl) : null;

const parser = new Parser({
  timeout: requestTimeoutMs,
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
    const feedXml = await fetchText(url);
    const parsed = await parser.parseString(feedXml);
    let inserted = 0;
    const currentUrls: string[] = [];
    for (const item of parsed.items as ParserItem[]) {
      const articleUrl = item.link || item.guid;
      if (!articleUrl) continue;
      currentUrls.push(articleUrl);
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
    const archived = archiveMissingFeedArticles(feedId, currentUrls);
    updateFeed(feedId, {
      title: parsed.title || undefined,
      siteUrl: parsed.link ?? null,
      lastFetchedAt: new Date().toISOString(),
      lastError: null
    });
    logIngestion(feedId, "success", `Fetched ${inserted} item(s), archived ${archived} stale item(s).`);
    return { feedId, ok: true, count: inserted, archived };
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
    const html = await fetchText(url);
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

async function fetchText(url: string): Promise<string> {
  if (!rssProxyUrl) return fetchTextAttempt(url, false);

  try {
    return await fetchTextAttempt(url, true);
  } catch (error) {
    if (!isProxyConnectionError(error)) throw error;
    return fetchTextAttempt(url, false);
  }
}

async function fetchTextAttempt(url: string, useProxy: boolean, redirectCount = 0): Promise<string> {
  if (redirectCount > 5) throw new Error("Too many redirects");

  const target = new URL(url);
  const transport = target.protocol === "http:" ? http : https;
  const proxyAgent = useProxy ? (target.protocol === "http:" ? httpProxyAgent : httpsProxyAgent) : null;

  return new Promise((resolve, reject) => {
    const request = transport.get(
      {
        protocol: target.protocol,
        hostname: target.hostname,
        port: target.port,
        path: `${target.pathname}${target.search}`,
        headers: {
          "user-agent": "MagReader/0.1 (+local learning reader)",
          accept: "application/rss+xml, application/atom+xml, application/xml, text/xml, text/html;q=0.9, */*;q=0.8"
        },
        agent: proxyAgent ?? undefined,
        timeout: requestTimeoutMs
      },
      (response) => {
        const location = response.headers.location;
        if (response.statusCode && response.statusCode >= 300 && response.statusCode < 400 && location) {
          response.resume();
          fetchTextAttempt(new URL(location, target).toString(), useProxy, redirectCount + 1).then(resolve, reject);
          return;
        }

        if (response.statusCode && response.statusCode >= 300) {
          response.resume();
          reject(new Error(`Status code ${response.statusCode}`));
          return;
        }

        response.setEncoding("utf8");
        let body = "";
        response.on("data", (chunk) => {
          body += chunk;
        });
        response.on("end", () => resolve(body));
      }
    );

    request.on("timeout", () => {
      request.destroy(new Error(`Request timed out after ${requestTimeoutMs}ms`));
    });
    request.on("error", reject);
  });
}

function isProxyConnectionError(error: unknown) {
  if (!error || typeof error !== "object" || !("code" in error)) return false;
  return ["ECONNREFUSED", "ECONNRESET", "EHOSTUNREACH", "ENETUNREACH", "ETIMEDOUT"].includes(String(error.code));
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
