const MICROSOFT_TRANSLATE_ENDPOINT = "https://api.cognitive.microsofttranslator.com";

export async function microsoftTranslate(text: string, source = "en", target = "zh-Hans") {
  const clean = text.trim().replace(/\s+/g, " ");
  if (!clean) return "";

  const key = process.env.MICROSOFT_TRANSLATOR_KEY;
  if (!key) {
    throw new Error("Microsoft Translator is not configured. Set MICROSOFT_TRANSLATOR_KEY and, when required, MICROSOFT_TRANSLATOR_REGION.");
  }

  const endpoint = process.env.MICROSOFT_TRANSLATOR_ENDPOINT ?? MICROSOFT_TRANSLATE_ENDPOINT;
  const url = new URL("/translate", endpoint);
  url.searchParams.set("api-version", "3.0");
  url.searchParams.set("from", source);
  url.searchParams.set("to", target);

  const headers: Record<string, string> = {
    "content-type": "application/json",
    "user-agent": "MagReader/0.1",
    "Ocp-Apim-Subscription-Key": key
  };
  if (process.env.MICROSOFT_TRANSLATOR_REGION) {
    headers["Ocp-Apim-Subscription-Region"] = process.env.MICROSOFT_TRANSLATOR_REGION;
  }

  const response = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify([{ text: clean }]),
    signal: AbortSignal.timeout(10000)
  });

  if (!response.ok) {
    throw new Error(`Microsoft Translator request failed: ${response.status}`);
  }

  const payload = (await response.json()) as MicrosoftTranslateResponse;
  const translated = payload[0]?.translations?.[0]?.text?.trim();
  if (!translated) {
    throw new Error("Microsoft Translator returned an empty translation.");
  }
  return translated;
}

type MicrosoftTranslateResponse = Array<{
  translations?: Array<{ text?: string; to?: string }>;
}>;
