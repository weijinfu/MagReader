import { NextResponse } from "next/server";
import { getDashboard } from "@/lib/db";
import { ensureScheduler } from "@/lib/scheduler";

export const dynamic = "force-dynamic";

export function GET() {
  ensureScheduler();
  return NextResponse.json(getDashboard());
}
