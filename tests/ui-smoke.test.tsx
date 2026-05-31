import { JSDOM } from "jsdom";
import React, { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MagReaderApp } from "@/components/mag-reader-app";
import type { DashboardPayload, ReaderSettings } from "@/lib/types";

let dom: JSDOM;
let root: Root | null = null;
let container: HTMLDivElement;

const baseSettings: ReaderSettings = {
  theme: "light",
  translationProvider: "mock",
  fontFamily: "Georgia, 'Times New Roman', serif",
  fontSize: 20,
  lineHeight: 1.75,
  contentWidth: 760,
  paragraphGap: 1.25,
  speechRate: 0.92
};

function dashboard(settings: ReaderSettings = baseSettings): DashboardPayload {
  return {
    feeds: [
      {
        id: 1,
        title: "BBC News",
        url: "https://feeds.bbci.co.uk/news/world/rss.xml",
        siteUrl: null,
        enabled: true,
        lastFetchedAt: null,
        lastError: null,
        createdAt: "2026-05-31T00:00:00.000Z"
      }
    ],
    articles: [
      {
        id: 1,
        feedId: 1,
        feedTitle: "BBC News",
        guid: "article-1",
        url: "https://example.com/article-1",
        title: "Reading slowly helps learners notice grammar",
        author: "MagReader",
        publishedAt: "2026-05-31T00:00:00.000Z",
        excerpt: "A compact article for UI smoke tests.",
        contentHtml:
          "<p>Reading slowly helps learners notice grammar.</p><p>Long sentences become easier when readers divide them into clauses.</p>",
        contentText: "Reading slowly helps learners notice grammar. Long sentences become easier when readers divide them into clauses.",
        difficulty: "B1",
        status: "unread",
        favorite: false,
        createdAt: "2026-05-31T00:00:00.000Z",
        updatedAt: "2026-05-31T00:00:00.000Z"
      }
    ],
    words: [
      {
        id: 1,
        word: "grammar",
        displayWord: "grammar",
        translation: "语法",
        explanation: "Language structure.",
        sourceSentence: "Reading slowly helps learners notice grammar.",
        articleId: 1,
        articleTitle: "Reading slowly helps learners notice grammar",
        familiarity: "new",
        count: 1,
        createdAt: "2026-05-31T00:00:00.000Z",
        updatedAt: "2026-05-31T00:00:00.000Z"
      }
    ],
    sentences: [],
    settings
  };
}

beforeEach(() => {
  dom = new JSDOM("<!doctype html><html><body><div id=\"root\"></div></body></html>", {
    url: "http://127.0.0.1:3000/",
    pretendToBeVisual: true
  });
  globalThis.window = dom.window as unknown as Window & typeof globalThis;
  globalThis.document = dom.window.document;
  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: dom.window.navigator
  });
  Object.defineProperty(globalThis, "React", {
    configurable: true,
    value: React
  });
  Object.defineProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT", {
    configurable: true,
    value: true
  });
  globalThis.HTMLElement = dom.window.HTMLElement;
  globalThis.Element = dom.window.Element;
  globalThis.PointerEvent = dom.window.PointerEvent;
  globalThis.KeyboardEvent = dom.window.KeyboardEvent;
  globalThis.SpeechSynthesisUtterance = vi.fn() as unknown as typeof SpeechSynthesisUtterance;
  Object.defineProperty(dom.window, "speechSynthesis", {
    configurable: true,
    value: { cancel: vi.fn(), speak: vi.fn() }
  });
  Object.defineProperty(dom.window, "matchMedia", {
    configurable: true,
    value: vi.fn().mockImplementation((query: string) => ({
      matches: query.includes("1180"),
      media: query,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    }))
  });

  container = dom.window.document.querySelector("#root") as HTMLDivElement;
  let currentSettings = { ...baseSettings };
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      if (url === "/api/dashboard") return Response.json(dashboard(currentSettings));
      if (url === "/api/settings" && init?.method === "PATCH") {
        currentSettings = { ...currentSettings, ...(JSON.parse(String(init.body)) as Partial<ReaderSettings>) };
        return Response.json({ settings: currentSettings });
      }
      if (url === "/api/feeds/refresh") return Response.json({ results: [{ count: 0 }] });
      if (url === "/api/ai") {
        return Response.json({
          analysis: {
            kind: "sentence",
            text: "Reading slowly helps learners notice grammar.",
            translation: "慢慢阅读可以帮助学习者注意语法。",
            translationProvider: "Mock",
            explanation: "Split the sentence into useful parts.",
            phrases: [{ phrase: "Reading slowly", meaning: "read at a careful pace" }],
            structure: ["1. Reading slowly helps learners notice grammar."],
            difficulty: { level: "B1", score: 58, reason: "Clear structure." }
          }
        });
      }
      return Response.json({});
    })
  );
});

afterEach(() => {
  act(() => root?.unmount());
  root = null;
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  dom.window.close();
});

async function renderApp() {
  root = createRoot(container);
  await act(async () => {
    root?.render(<MagReaderApp />);
  });
  await waitFor(() => Boolean(container.querySelector(".app-shell")));
}

async function waitFor(assertion: () => boolean) {
  for (let i = 0; i < 30; i += 1) {
    if (assertion()) return;
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 10));
    });
  }
  throw new Error("Timed out waiting for UI state.");
}

describe("MagReader UI smoke", () => {
  it("renders navigation and toolbar icons with the reader visible", async () => {
    await renderApp();

    expect(container.querySelectorAll(".nav-button .nav-icon")).toHaveLength(6);
    expect(container.querySelectorAll(".toolbar .button-icon")).toHaveLength(4);
    expect(container.querySelector(".reader h1")?.textContent).toBe("Reading slowly helps learners notice grammar");
    expect(container.querySelector(".nav-label-short")?.textContent).toBe("Articles");
  });

  it("updates theme and collapses the article list from toolbar actions", async () => {
    await renderApp();

    const darkButton = Array.from(container.querySelectorAll("button")).find((button) => button.textContent?.includes("Dark"));
    const listButton = Array.from(container.querySelectorAll("button")).find((button) => button.textContent?.includes("Hide list"));
    expect(darkButton).toBeDefined();
    expect(listButton).toBeDefined();

    await act(async () => {
      darkButton?.dispatchEvent(new dom.window.MouseEvent("click", { bubbles: true }));
    });
    await waitFor(() => dom.window.document.body.classList.contains("dark"));
    expect(dom.window.document.body.classList.contains("dark")).toBe(true);

    await act(async () => {
      listButton?.dispatchEvent(new dom.window.MouseEvent("click", { bubbles: true }));
    });
    await waitFor(() => container.querySelector(".content-grid")?.classList.contains("list-collapsed") ?? false);
    expect(container.querySelector(".content-grid")?.classList.contains("list-collapsed")).toBe(true);
  });
});
