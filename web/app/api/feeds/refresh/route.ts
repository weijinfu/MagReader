import { NextResponse } from "next/server";
import { refreshAllFeeds } from "@/lib/rss";

export const dynamic = "force-dynamic";

export async function POST() {
  const results = await refreshAllFeeds();
  return NextResponse.json({ results });
}
