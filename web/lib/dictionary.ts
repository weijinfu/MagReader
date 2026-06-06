import type { WordMeaning } from "@/lib/types";

type DictionaryEntry = {
  meanings?: Array<{
    partOfSpeech?: string;
    synonyms?: string[];
    definitions?: Array<{
      definition?: string;
      example?: string;
      synonyms?: string[];
    }>;
  }>;
};

export async function lookupDictionaryMeanings(word: string): Promise<WordMeaning[]> {
  const clean = word.trim().toLowerCase().replace(/^[^a-z]+|[^a-z]+$/g, "");
  if (!clean) return [];

  const response = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(clean)}`, {
    headers: { "user-agent": "MagReader/0.1" },
    signal: AbortSignal.timeout(6000)
  });
  if (!response.ok) {
    throw new Error(`Dictionary request failed: ${response.status}`);
  }

  const payload = (await response.json()) as DictionaryEntry[];
  return parseDictionaryPayload(payload);
}

export function parseDictionaryPayload(entries: DictionaryEntry[]): WordMeaning[] {
  const output: WordMeaning[] = [];
  const seen = new Set<string>();

  for (const entry of entries) {
    for (const meaning of entry.meanings ?? []) {
      for (const definition of meaning.definitions ?? []) {
        const cleanDefinition = definition.definition?.trim().replace(/\s+/g, " ");
        if (!cleanDefinition) continue;
        const partOfSpeech = meaning.partOfSpeech?.trim() || "word";
        const key = `${partOfSpeech}|${cleanDefinition}`;
        if (seen.has(key)) continue;
        seen.add(key);
        output.push({
          partOfSpeech,
          definition: cleanDefinition,
          translatedDefinition: null,
          example: definition.example?.trim().replace(/\s+/g, " ") || null,
          synonyms: [...(definition.synonyms ?? []), ...(meaning.synonyms ?? [])].filter(Boolean).slice(0, 6)
        });
      }
    }
  }

  return output;
}
