import { describe, expect, it } from "vitest";
import { analyzeText, rateArticleDifficulty } from "@/lib/ai";
import type { TranslationProvider } from "@/lib/types";
import { truncateForSign } from "@/lib/youdao-translate";

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
});
