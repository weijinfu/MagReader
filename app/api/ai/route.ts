import { NextResponse } from "next/server";
import { analyzeTextWithGoogle } from "@/lib/ai";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const body = await request.json();
  if (!body.text || typeof body.text !== "string") {
    return NextResponse.json({ error: "Text is required." }, { status: 400 });
  }
  try {
    return NextResponse.json({ analysis: await analyzeTextWithGoogle(body.text) });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Google Translate failed." },
      { status: 502 }
    );
  }
}
