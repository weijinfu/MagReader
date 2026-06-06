import { NextResponse } from "next/server";
import { deleteSavedWord, listSavedWords, saveWord, updateReview, updateSavedWordMeanings } from "@/lib/db";
import { analyzeTextWithProvider } from "@/lib/ai";
import { normalizeWord } from "@/lib/utils";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json({ words: listSavedWords() });
}

export async function POST(request: Request) {
  const body = await request.json();
  const word = normalizeWord(body.word ?? body.text ?? "");
  if (!word) return NextResponse.json({ error: "Word is required." }, { status: 400 });
  const analysis = await analyzeTextWithProvider(word);
  const words = saveWord({
    word,
    displayWord: body.displayWord ?? body.word ?? word,
    translation: body.translation ?? analysis.translation,
    meanings: Array.isArray(body.meanings) ? body.meanings : analysis.wordMeanings,
    explanation: body.explanation ?? analysis.explanation,
    sourceSentence: body.sourceSentence ?? null,
    articleId: body.articleId ?? null
  });
  return NextResponse.json({ words });
}

export async function PATCH(request: Request) {
  const body = await request.json();
  if (body.action === "meanings") {
    return NextResponse.json({ words: updateSavedWordMeanings(Number(body.id), Array.isArray(body.meanings) ? body.meanings : []) });
  }
  updateReview("word", Number(body.id), body.familiarity);
  return NextResponse.json({ words: listSavedWords() });
}

export function DELETE(request: Request) {
  const id = Number(new URL(request.url).searchParams.get("id"));
  if (!Number.isFinite(id) || id <= 0) return NextResponse.json({ error: "Valid word id is required." }, { status: 400 });
  return NextResponse.json({ words: deleteSavedWord(id) });
}
