export async function googleTranslate(text: string, source = "en", target = "zh-CN") {
  const clean = text.trim().replace(/\s+/g, " ");
  if (!clean) return "";

  const url = new URL("https://translate.googleapis.com/translate_a/single");
  url.searchParams.set("client", "gtx");
  url.searchParams.set("sl", source);
  url.searchParams.set("tl", target);
  url.searchParams.set("dt", "t");
  url.searchParams.set("q", clean);

  const response = await fetch(url, {
    headers: {
      "user-agent": "MagReader/0.1"
    },
    signal: AbortSignal.timeout(10000)
  });

  if (!response.ok) {
    throw new Error(`Google Translate request failed: ${response.status}`);
  }

  const payload = (await response.json()) as GoogleTranslateResponse;
  const translated = payload[0]?.map((segment) => segment[0]).join("").trim();
  if (!translated) {
    throw new Error("Google Translate returned an empty translation.");
  }
  return translated;
}

type GoogleTranslateResponse = [
  Array<[translatedText: string, sourceText: string, unknownA?: unknown, unknownB?: unknown, unknownC?: unknown]>,
  ...unknown[]
];
