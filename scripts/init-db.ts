import { getDashboard } from "@/lib/db";

const dashboard = getDashboard();
console.log(`MagReader database ready: ${dashboard.articles.length} article(s), ${dashboard.feeds.length} feed(s).`);
