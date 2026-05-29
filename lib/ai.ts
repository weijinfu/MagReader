import type { LearningAnalysis } from "@/lib/types";
import { googleTranslate } from "@/lib/google-translate";
import { isLikelyWord } from "@/lib/utils";

export function analyzeText(text: string): LearningAnalysis {
  const clean = text.trim().replace(/\s+/g, " ");
  return buildAnalysis(clean, wordOrSentenceMockTranslation(clean), "Mock");
}

export async function analyzeTextWithGoogle(text: string): Promise<LearningAnalysis> {
  const clean = text.trim().replace(/\s+/g, " ");
  const translation = await googleTranslate(clean);
  return buildAnalysis(clean, translation, "Google Translate");
}

function buildAnalysis(clean: string, translation: string, translationProvider: string): LearningAnalysis {
  const wordMode = isLikelyWord(clean);
  const words = clean.match(/[A-Za-z][A-Za-z'-]*/g) ?? [];
  const score = Math.min(95, Math.max(32, Math.round(words.length * 2.2 + averageWordLength(words) * 7)));
  const level = score > 82 ? "C1" : score > 68 ? "B2" : score > 52 ? "B1" : "A2";

  return {
    kind: wordMode ? "word" : "sentence",
    text: clean,
    translation,
    translationProvider,
    explanation: wordMode
      ? `${clean} is explained as a useful context word. Notice its part of speech and the phrase it appears in before memorizing a Chinese equivalent.`
      : "这句话可以先找主句，再看从句、插入语或介词短语如何补充时间、原因、转折或条件信息。",
    phrases: extractPhrases(words),
    structure: wordMode
      ? ["Check the source sentence.", "Identify the word form.", "Save one natural collocation."]
      : splitStructure(clean),
    difficulty: {
      level,
      score,
      reason:
        score > 70
          ? "句子较长或包含多层修饰，适合做长难句拆解。"
          : "词汇和结构较直接，适合快速阅读后积累搭配。"
    }
  };
}

function wordOrSentenceMockTranslation(text: string) {
  return isLikelyWord(text) ? mockWordTranslation(text) : `模拟翻译：${text}`;
}

export function rateArticleDifficulty(text: string) {
  const words = text.match(/[A-Za-z][A-Za-z'-]*/g) ?? [];
  const avg = averageWordLength(words);
  const sentenceCount = Math.max(1, text.split(/[.!?]+/).filter(Boolean).length);
  const averageSentenceLength = words.length / sentenceCount;
  if (averageSentenceLength > 28 || avg > 6.2) return "C1";
  if (averageSentenceLength > 22 || avg > 5.6) return "B2";
  if (averageSentenceLength > 15) return "B1";
  return "A2";
}

function mockWordTranslation(word: string) {
  const lower = word.toLowerCase();
  const dictionary: Record<string, string> = {
    manageable: "可处理的；可应对的",
    clause: "从句；分句",
    collocation: "搭配；词语组合",
    intimidating: "令人畏惧的",
    context: "语境；上下文",
    relationship: "关系；关联"
  };
  return dictionary[lower] ?? `模拟释义：${word}`;
}

function extractPhrases(words: string[]) {
  const phrases = [];
  for (let i = 0; i < Math.min(words.length - 1, 6); i += 2) {
    phrases.push({
      phrase: `${words[i]} ${words[i + 1]}`,
      meaning: "在原句中作为一个意义单元理解，而不是逐词翻译。"
    });
  }
  return phrases.length ? phrases : [{ phrase: "source context", meaning: "结合原句保存，复习时更容易想起用法。" }];
}

function splitStructure(text: string) {
  const parts = text.split(/,\s+|;\s+|\s+(while|because|although|when|once|that|which)\s+/i).filter(Boolean);
  return parts.slice(0, 5).map((part, index) => `${index + 1}. ${part.trim()}`);
}

function averageWordLength(words: string[]) {
  if (!words.length) return 0;
  return words.reduce((sum, word) => sum + word.length, 0) / words.length;
}
