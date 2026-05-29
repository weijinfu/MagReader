import { NextResponse } from "next/server";
import { deleteSavedSentence, listSavedSentences, saveSentence, updateReview } from "@/lib/db";
import { analyzeTextWithGoogle } from "@/lib/ai";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json({ sentences: listSavedSentences() });
}

export async function POST(request: Request) {
  const body = await request.json();
  const text = String(body.text ?? "").trim();
  if (!text) return NextResponse.json({ error: "Sentence is required." }, { status: 400 });
  const analysis = await analyzeTextWithGoogle(text);
  const sentences = saveSentence({
    text,
    translation: body.translation ?? analysis.translation,
    explanation: body.explanation ?? analysis.explanation,
    articleId: body.articleId ?? null
  });
  return NextResponse.json({ sentences });
}

export async function PATCH(request: Request) {
  const body = await request.json();
  updateReview("sentence", Number(body.id), body.familiarity);
  return NextResponse.json({ sentences: listSavedSentences() });
}

export function DELETE(request: Request) {
  const id = Number(new URL(request.url).searchParams.get("id"));
  if (!Number.isFinite(id) || id <= 0) return NextResponse.json({ error: "Valid sentence id is required." }, { status: 400 });
  return NextResponse.json({ sentences: deleteSavedSentence(id) });
}
