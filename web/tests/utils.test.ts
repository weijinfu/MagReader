import { describe, expect, it } from "vitest";
import { normalizeWord, sentenceAround, sentenceAtOffset, stripHtml, wordAtOffset } from "@/lib/utils";

describe("text utilities", () => {
  it("normalizes selected words", () => {
    expect(normalizeWord("Context,")).toBe("context");
  });

  it("strips html", () => {
    expect(stripHtml("<p>Hello <strong>world</strong>.</p>")).toBe("Hello world.");
  });

  it("finds source sentence", () => {
    expect(sentenceAround("First sentence. Second sentence has context. Third.", "context")).toBe("Second sentence has context.");
  });

  it("finds a sentence at a text offset", () => {
    const text = "First sentence. Second sentence asks why? Third sentence is emphatic!";
    expect(sentenceAtOffset(text, text.indexOf("asks"))?.text).toBe("Second sentence asks why?");
    expect(sentenceAtOffset(text, text.indexOf("emphatic"))?.text).toBe("Third sentence is emphatic!");
  });

  it("keeps common abbreviations inside the current sentence", () => {
    const text = "Dr. Smith moved to the U.S. in 2020. He now writes for learners.";
    expect(sentenceAtOffset(text, text.indexOf("moved"))?.text).toBe("Dr. Smith moved to the U.S. in 2020.");
    expect(sentenceAround(text, "U.S.")).toBe("Dr. Smith moved to the U.S. in 2020.");
  });

  it("does not split decimal numbers", () => {
    const text = "The rate rose by 2.5 points. Analysts were surprised.";
    expect(sentenceAtOffset(text, text.indexOf("2.5"))?.text).toBe("The rate rose by 2.5 points.");
  });

  it("keeps Latin abbreviations inside a sentence", () => {
    const text = "Some phrases, e.g. take over, need context. The next sentence starts here.";
    expect(sentenceAtOffset(text, text.indexOf("context"))?.text).toBe("Some phrases, e.g. take over, need context.");
  });

  it("finds a word at a text offset", () => {
    const text = "Strong readers notice collocations.";
    expect(wordAtOffset(text, text.indexOf("notice") + 2)?.text).toBe("notice");
    expect(wordAtOffset(text, text.indexOf("collocations") + 5)?.text).toBe("collocations");
  });

  it("keeps apostrophes and hyphens inside selected words", () => {
    const text = "Learners can't ignore context-rich examples.";
    expect(wordAtOffset(text, text.indexOf("can't") + 2)?.text).toBe("can't");
    expect(wordAtOffset(text, text.indexOf("context-rich") + 8)?.text).toBe("context-rich");
  });
});
