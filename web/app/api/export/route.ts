import { NextResponse } from "next/server";
import { listSavedSentences, listSavedWords } from "@/lib/db";

export const dynamic = "force-dynamic";

export function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const format = searchParams.get("format") ?? "json";
  const data = {
    words: listSavedWords(),
    sentences: listSavedSentences(),
    exportedAt: new Date().toISOString()
  };
  if (format === "csv") {
    const rows = [
      ["type", "text", "translation", "explanation", "familiarity", "source"],
      ...data.words.map((word) => ["word", word.displayWord, word.translation, word.explanation, word.familiarity, word.articleTitle ?? ""]),
      ...data.sentences.map((sentence) => ["sentence", sentence.text, sentence.translation, sentence.explanation, sentence.familiarity, sentence.articleTitle ?? ""])
    ];
    const csv = rows.map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(",")).join("\n");
    return new NextResponse(csv, {
      headers: {
        "content-type": "text/csv; charset=utf-8",
        "content-disposition": "attachment; filename=magreader-export.csv"
      }
    });
  }
  return NextResponse.json(data);
}
