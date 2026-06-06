import { NextResponse } from "next/server";
import { getSettings, saveSettings } from "@/lib/db";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json({ settings: getSettings() });
}

export async function PATCH(request: Request) {
  const body = await request.json();
  return NextResponse.json({ settings: saveSettings(body) });
}
