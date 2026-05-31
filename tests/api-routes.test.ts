import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";

const tempDbs: string[] = [];

async function loadApiRoutes() {
  const dbPath = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "magreader-api-test-")), "test.db");
  tempDbs.push(dbPath);
  vi.resetModules();
  process.env.MAGREADER_DB = dbPath;

  const settingsRoute = await import("@/app/api/settings/route");
  await settingsRoute.PATCH(jsonRequest("/api/settings", { translationProvider: "mock" }));

  return {
    settingsRoute,
    wordsRoute: await import("@/app/api/words/route"),
    sentencesRoute: await import("@/app/api/sentences/route")
  };
}

function jsonRequest(pathname: string, body: unknown) {
  return new Request(`http://127.0.0.1:3000${pathname}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });
}

async function json<T>(response: Response) {
  return (await response.json()) as T;
}

afterEach(() => {
  delete process.env.MAGREADER_DB;
  for (const dbPath of tempDbs.splice(0)) {
    fs.rmSync(path.dirname(dbPath), { force: true, recursive: true });
  }
});

describe("API route behavior", () => {
  it("persists settings through GET and PATCH", async () => {
    const { settingsRoute } = await loadApiRoutes();

    const patchResponse = await settingsRoute.PATCH(jsonRequest("/api/settings", { theme: "dark", fontSize: 23 }));
    const patched = await json<{ settings: { theme: string; fontSize: number; translationProvider: string } }>(patchResponse);
    const getResponse = settingsRoute.GET();
    const current = await json<{ settings: { theme: string; fontSize: number; translationProvider: string } }>(getResponse);

    expect(patched.settings.theme).toBe("dark");
    expect(patched.settings.fontSize).toBe(23);
    expect(current.settings.theme).toBe("dark");
    expect(current.settings.translationProvider).toBe("mock");
  });

  it("creates, updates, and deletes words through the route", async () => {
    const { wordsRoute } = await loadApiRoutes();

    const createResponse = await wordsRoute.POST(jsonRequest("/api/words", { word: "Context,", sourceSentence: "Context makes meaning clearer." }));
    const created = await json<{ words: Array<{ id: number; word: string; translation: string; familiarity: string }> }>(createResponse);
    const id = created.words[0].id;

    expect(created.words[0].word).toBe("context");
    expect(created.words[0].translation.length).toBeGreaterThan(0);

    const patchResponse = await wordsRoute.PATCH(jsonRequest("/api/words", { id, familiarity: "familiar" }));
    const patched = await json<{ words: Array<{ id: number; familiarity: string }> }>(patchResponse);
    expect(patched.words.find((word) => word.id === id)?.familiarity).toBe("familiar");

    const invalidDelete = wordsRoute.DELETE(new Request("http://127.0.0.1:3000/api/words?id=bad"));
    expect(invalidDelete.status).toBe(400);

    const deleteResponse = wordsRoute.DELETE(new Request(`http://127.0.0.1:3000/api/words?id=${id}`));
    const afterDelete = await json<{ words: Array<{ id: number }> }>(deleteResponse);
    expect(afterDelete.words.some((word) => word.id === id)).toBe(false);
  });

  it("creates, updates, and deletes sentences through the route", async () => {
    const { sentencesRoute } = await loadApiRoutes();

    const createResponse = await sentencesRoute.POST(jsonRequest("/api/sentences", { text: "Reading slowly helps learners notice grammar." }));
    const created = await json<{ sentences: Array<{ id: number; text: string; translation: string; familiarity: string }> }>(createResponse);
    const id = created.sentences[0].id;

    expect(created.sentences[0].text).toBe("Reading slowly helps learners notice grammar.");
    expect(created.sentences[0].translation).toContain("Reading slowly");

    const patchResponse = await sentencesRoute.PATCH(jsonRequest("/api/sentences", { id, familiarity: "mastered" }));
    const patched = await json<{ sentences: Array<{ id: number; familiarity: string }> }>(patchResponse);
    expect(patched.sentences.find((sentence) => sentence.id === id)?.familiarity).toBe("mastered");

    const invalidDelete = sentencesRoute.DELETE(new Request("http://127.0.0.1:3000/api/sentences?id=bad"));
    expect(invalidDelete.status).toBe(400);

    const deleteResponse = sentencesRoute.DELETE(new Request(`http://127.0.0.1:3000/api/sentences?id=${id}`));
    const afterDelete = await json<{ sentences: Array<{ id: number }> }>(deleteResponse);
    expect(afterDelete.sentences.some((sentence) => sentence.id === id)).toBe(false);
  });
});
