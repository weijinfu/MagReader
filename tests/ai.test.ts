import { describe, expect, it } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, vi } from "vitest";
import { analyzeText, rateArticleDifficulty } from "@/lib/ai";
import type { TranslationProvider } from "@/lib/types";
import { truncateForSign } from "@/lib/youdao-translate";

const tempDbs: string[] = [];

async function loadAiWithDbSettings(settings: { translationProvider: TranslationProvider }) {
  const dbPath = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "magreader-ai-test-")), "test.db");
  tempDbs.push(dbPath);
  vi.resetModules();
  process.env.MAGREADER_DB = dbPath;
  const db = await import("@/lib/db");
  db.saveSettings(settings);
  return import("@/lib/ai");
}

afterEach(() => {
  delete process.env.MAGREADER_DB;
  for (const dbPath of tempDbs.splice(0)) {
    fs.rmSync(path.dirname(dbPath), { force: true, recursive: true });
  }
});

describe("mock AI provider", () => {
  it("returns word analysis", () => {
    const result = analyzeText("manageable");
    expect(result.kind).toBe("word");
    expect(result.translation).toContain("可");
    expect(result.translationProvider).toBe("Mock");
    expect(result.difficulty.score).toBeGreaterThan(0);
  });

  it("rates longer text as at least intermediate", () => {
    const result = rateArticleDifficulty(
      "Although the committee acknowledged the proposal, it postponed implementation because several unresolved fiscal assumptions remained under review."
    );
    expect(["B1", "B2", "C1"]).toContain(result);
  });

  it("uses the Youdao v3 signing truncation format", () => {
    expect(truncateForSign("short text")).toBe("short text");
    expect(truncateForSign("abcdefghijklmnopqrstuvwxyz")).toBe("abcdefghij26qrstuvwxyz");
  });

  it("defines selectable translation providers", () => {
    const providers: TranslationProvider[] = ["mymemory", "baidu", "netease", "youdao", "microsoft", "google", "mock"];
    expect(providers).toEqual(expect.arrayContaining(["baidu", "netease", "microsoft", "google"]));
  });

  it("honors the persisted mock provider without network access", async () => {
    const { analyzeTextWithProvider } = await loadAiWithDbSettings({ translationProvider: "mock" });
    const result = await analyzeTextWithProvider("Context helps readers.");

    expect(result.translationProvider).toBe("Mock");
    expect(result.translation).toBe("模拟翻译：Context helps readers.");
  });
});
