import { createHash, randomUUID } from "crypto";

const BAIDU_TRANSLATE_URL = "https://fanyi-api.baidu.com/api/trans/vip/translate";

export async function baiduTranslate(text: string, source = "en", target = "zh") {
  const clean = text.trim().replace(/\s+/g, " ");
  if (!clean) return "";

  const appId = process.env.BAIDU_TRANSLATE_APP_ID;
  const secretKey = process.env.BAIDU_TRANSLATE_SECRET_KEY;
  if (!appId || !secretKey) {
    throw new Error("Baidu Translate is not configured. Set BAIDU_TRANSLATE_APP_ID and BAIDU_TRANSLATE_SECRET_KEY.");
  }

  const salt = randomUUID();
  const sign = md5(`${appId}${clean}${salt}${secretKey}`);
  const form = new URLSearchParams({
    q: clean,
    from: source,
    to: target,
    appid: appId,
    salt,
    sign
  });

  const response = await fetch(BAIDU_TRANSLATE_URL, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      "user-agent": "MagReader/0.1"
    },
    body: form,
    signal: AbortSignal.timeout(10000)
  });

  if (!response.ok) {
    throw new Error(`Baidu Translate request failed: ${response.status}`);
  }

  const payload = (await response.json()) as BaiduTranslateResponse;
  if (payload.error_code) {
    throw new Error(`Baidu Translate failed with error code ${payload.error_code}: ${payload.error_msg ?? "Unknown error"}.`);
  }

  const translated = payload.trans_result?.map((item) => item.dst).join("").trim();
  if (!translated) {
    throw new Error("Baidu Translate returned an empty translation.");
  }
  return translated;
}

function md5(text: string) {
  return createHash("md5").update(text).digest("hex");
}

type BaiduTranslateResponse = {
  trans_result?: Array<{ src: string; dst: string }>;
  error_code?: string;
  error_msg?: string;
};
