export function nowIso() {
  return new Date().toISOString();
}

export function toBoolean(value: unknown) {
  return value === 1 || value === true;
}

export function stripHtml(input: string) {
  return input
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+([,.;:!?])/g, "$1")
    .replace(/\s+/g, " ")
    .trim();
}

export function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

export function isLikelyWord(text: string) {
  return /^[A-Za-z][A-Za-z'-]{0,48}$/.test(text.trim());
}

export function normalizeWord(text: string) {
  return text.trim().toLowerCase().replace(/^[^a-z]+|[^a-z]+$/g, "");
}

export type SentenceRange = {
  text: string;
  start: number;
  end: number;
};

export type WordRange = {
  text: string;
  start: number;
  end: number;
};

const commonAbbreviations = new Set([
  "mr",
  "mrs",
  "ms",
  "dr",
  "prof",
  "sr",
  "jr",
  "st",
  "vs",
  "etc",
  "e.g",
  "i.e",
  "u.s",
  "u.k",
  "u.n"
]);

export function sentenceAtOffset(text: string, offset: number): SentenceRange | null {
  if (!text.trim()) return null;
  const index = clamp(offset, 0, Math.max(0, text.length - 1));
  const ranges = sentenceRanges(text);
  return ranges.find((range) => index >= range.start && index <= range.end) ?? ranges.find((range) => index < range.end) ?? ranges.at(-1) ?? null;
}

export function wordAtOffset(text: string, offset: number): WordRange | null {
  if (!text.trim()) return null;
  const index = clamp(offset, 0, Math.max(0, text.length - 1));
  const ranges = Array.from(text.matchAll(/[A-Za-z][A-Za-z'-]{0,48}/g)).map((match) => ({
    text: match[0],
    start: match.index ?? 0,
    end: (match.index ?? 0) + match[0].length
  }));
  return ranges.find((range) => index >= range.start && index <= range.end) ?? null;
}

export function sentenceAround(text: string, selected: string) {
  const clean = text.replace(/\s+/g, " ").trim();
  const index = clean.toLowerCase().indexOf(selected.toLowerCase());
  if (index < 0) return selected;
  return sentenceAtOffset(clean, index + Math.floor(selected.length / 2))?.text ?? selected;
}

function sentenceRanges(text: string): SentenceRange[] {
  const ranges: SentenceRange[] = [];
  let start = firstContentIndex(text, 0);

  for (let i = start; i < text.length; i += 1) {
    if (!isSentenceTerminator(text, i)) continue;
    const end = includeClosingMarks(text, i + 1);
    const sentence = text.slice(start, end).trim();
    if (sentence) ranges.push({ text: sentence, start, end });
    start = firstContentIndex(text, end);
    i = start;
  }

  if (start < text.length) {
    const sentence = text.slice(start).trim();
    if (sentence) ranges.push({ text: sentence, start, end: text.length });
  }

  return ranges;
}

function firstContentIndex(text: string, start: number) {
  let index = start;
  while (index < text.length && /\s/.test(text[index])) index += 1;
  return index;
}

function includeClosingMarks(text: string, end: number) {
  let index = end;
  while (index < text.length && /["')\]}]/.test(text[index])) index += 1;
  return index;
}

function isSentenceTerminator(text: string, index: number) {
  const char = text[index];
  if (!/[.!?]/.test(char)) return false;
  if (char === "." && isProtectedPeriod(text, index)) return false;
  return true;
}

function isProtectedPeriod(text: string, index: number) {
  const previous = text[index - 1] ?? "";
  const next = text[index + 1] ?? "";
  if (/\d/.test(previous) && /\d/.test(next)) return true;

  const prefix = text.slice(0, index + 1);
  const token = prefix.match(/[A-Za-z](?:\.?[A-Za-z])*\.$/)?.[0]?.slice(0, -1).toLowerCase();
  if (!token) return false;
  if (commonAbbreviations.has(token)) return true;
  if (/^(?:[a-z]\.)+[a-z]?$/.test(token)) return true;
  if (/^[a-z]$/.test(token) && /[A-Za-z]/.test(next)) return true;
  return false;
}
