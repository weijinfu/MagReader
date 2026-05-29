import { NextResponse } from "next/server";
import { listArticles, markArticle } from "@/lib/db";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json({ articles: listArticles() });
}

export async function PATCH(request: Request) {
  const body = await request.json();
  if (!body.id || !body.status) return NextResponse.json({ error: "Article id and status are required." }, { status: 400 });
  markArticle(Number(body.id), body.status);
  return NextResponse.json({ articles: listArticles() });
}
