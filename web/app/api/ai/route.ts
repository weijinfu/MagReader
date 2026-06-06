import { NextResponse } from "next/server";
import { analyzeTextWithProvider, loadMoreWordMeanings } from "@/lib/ai";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const body = await request.json();
  if (!body.text || typeof body.text !== "string") {
    return NextResponse.json({ error: "Text is required." }, { status: 400 });
  }
  try {
    if (body.mode === "meanings") {
      return NextResponse.json({ meanings: await loadMoreWordMeanings(body.text) });
    }
    return NextResponse.json({ analysis: await analyzeTextWithProvider(body.text) });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Translation failed." },
      { status: 502 }
    );
  }
}
