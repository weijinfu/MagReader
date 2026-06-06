export async function myMemoryTranslate(text: string, source = "en", target = "zh-CN") {
  const clean = text.trim().replace(/\s+/g, " ");
  if (!clean) return "";

  const url = new URL("https://api.mymemory.translated.net/get");
  url.searchParams.set("q", clean);
  url.searchParams.set("langpair", `${source}|${target}`);

  const response = await fetch(url, {
    headers: {
      "user-agent": "MagReader/0.1"
    },
    signal: AbortSignal.timeout(12000)
  });

  if (!response.ok) {
    throw new Error(`MyMemory Translate request failed: ${response.status}`);
  }

  const payload = (await response.json()) as MyMemoryTranslateResponse;
  if (payload.responseStatus !== 200) {
    throw new Error(payload.responseDetails || `MyMemory Translate failed: ${payload.responseStatus}`);
  }

  const translated = payload.responseData?.translatedText?.trim();
  if (!translated) {
    throw new Error("MyMemory Translate returned an empty translation.");
  }
  return translated;
}

type MyMemoryTranslateResponse = {
  responseStatus?: number;
  responseDetails?: string;
  responseData?: {
    translatedText?: string;
  };
};
