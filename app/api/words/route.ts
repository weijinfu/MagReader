import { NextResponse } from "next/server";
import { deleteSavedWord, listSavedWords, saveWord, updateReview } from "@/lib/db";
import { analyzeTextWithGoogle } from "@/lib/ai";
import { normalizeWord } from "@/lib/utils";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json({ words: listSavedWords() });
}

export async function POST(request: Request) {
  const body = await request.json();
  const word = normalizeWord(body.word ?? body.text ?? "");
  if (!word) return NextResponse.json({ error: "Word is required." }, { status: 400 });
  const analysis = await analyzeTextWithGoogle(word);
  const words = saveWord({
    word,
    displayWord: body.displayWord ?? body.word ?? word,
    translation: body.translation ?? analysis.translation,
    explanation: body.explanation ?? analysis.explanation,
    sourceSentence: body.sourceSentence ?? null,
    articleId: body.articleId ?? null
  });
  return NextResponse.json({ words });
}

export async function PATCH(request: Request) {
  const body = await request.json();
  updateReview("word", Number(body.id), body.familiarity);
  return NextResponse.json({ words: listSavedWords() });
}

export function DELETE(request: Request) {
  const id = Number(new URL(request.url).searchParams.get("id"));
  if (!Number.isFinite(id) || id <= 0) return NextResponse.json({ error: "Valid word id is required." }, { status: 400 });
  return NextResponse.json({ words: deleteSavedWord(id) });
}
