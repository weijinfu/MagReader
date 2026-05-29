import { NextResponse } from "next/server";
import { createFeed, deleteFeed, listFeeds } from "@/lib/db";
import { refreshFeed } from "@/lib/rss";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json({ feeds: listFeeds() });
}

export async function POST(request: Request) {
  const body = await request.json();
  if (!body.url || typeof body.url !== "string") {
    return NextResponse.json({ error: "Feed URL is required." }, { status: 400 });
  }
  try {
    new URL(body.url);
    const feeds = createFeed({ title: body.title, url: body.url });
    return NextResponse.json({ feeds });
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : "Invalid feed." }, { status: 400 });
  }
}

export async function DELETE(request: Request) {
  const { searchParams } = new URL(request.url);
  const id = Number(searchParams.get("id"));
  if (!id) return NextResponse.json({ error: "Feed id is required." }, { status: 400 });
  deleteFeed(id);
  return NextResponse.json({ feeds: listFeeds() });
}

export async function PATCH(request: Request) {
  const body = await request.json();
  if (!body.id || !body.url) return NextResponse.json({ error: "Feed id and url are required." }, { status: 400 });
  const result = await refreshFeed(Number(body.id), body.url);
  return NextResponse.json(result);
}
