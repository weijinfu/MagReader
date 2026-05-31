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
  it("persists reader settings without losing defaults", async () => {
    const { getSettings, saveSettings } = await loadDbModule();

    const updated = saveSettings({ theme: "dark", translationProvider: "mock", fontSize: 22 });

    expect(updated.theme).toBe("dark");
    expect(updated.translationProvider).toBe("mock");
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
