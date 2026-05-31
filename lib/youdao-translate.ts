import { createHash, randomUUID } from "crypto";

const YOUDAO_API_URL = "https://openapi.youdao.com/api";

export async function youdaoTranslate(text: string, source = "en", target = "zh-CHS") {
  const clean = text.trim().replace(/\s+/g, " ");
  if (!clean) return "";

  const appKey = process.env.YOUDAO_APP_KEY;
  const appSecret = process.env.YOUDAO_APP_SECRET;
  if (!appKey || !appSecret) {
    throw new Error("Youdao Translate is not configured. Set YOUDAO_APP_KEY and YOUDAO_APP_SECRET.");
  }

  const salt = randomUUID();
  const curtime = Math.floor(Date.now() / 1000).toString();
  const sign = sha256(`${appKey}${truncateForSign(clean)}${salt}${curtime}${appSecret}`);
  const form = new URLSearchParams({
    q: clean,
    from: source,
    to: target,
    appKey,
    salt,
    sign,
    signType: "v3",
    curtime
  });

  const response = await fetch(YOUDAO_API_URL, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      "user-agent": "MagReader/0.1"
    },
    body: form,
    signal: AbortSignal.timeout(10000)
  });

  if (!response.ok) {
    throw new Error(`Youdao Translate request failed: ${response.status}`);
  }

  const payload = (await response.json()) as YoudaoTranslateResponse;
  if (payload.errorCode !== "0") {
    throw new Error(`Youdao Translate failed with error code ${payload.errorCode}.`);
  }

  const translated = payload.translation?.join("").trim();
  if (!translated) {
    throw new Error("Youdao Translate returned an empty translation.");
  }
  return translated;
}

export function truncateForSign(text: string) {
  return text.length <= 20 ? text : `${text.slice(0, 10)}${text.length}${text.slice(-10)}`;
}

function sha256(text: string) {
  return createHash("sha256").update(text).digest("hex");
}

type YoudaoTranslateResponse = {
  errorCode?: string;
  translation?: string[];
};
