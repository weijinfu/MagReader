import { describe, expect, it } from "vitest";
import { analyzeText, rateArticleDifficulty } from "@/lib/ai";

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
});
