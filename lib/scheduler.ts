import { refreshAllFeeds } from "@/lib/rss";

declare global {
  var magReaderSchedulerStarted: boolean | undefined;
}

export function ensureScheduler() {
  if (globalThis.magReaderSchedulerStarted) return;
  globalThis.magReaderSchedulerStarted = true;
  setInterval(() => {
    refreshAllFeeds().catch(() => {
      // Errors are captured per feed in ingestion logs.
    });
  }, 1000 * 60 * 30);
}
