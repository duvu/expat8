// Vocabulary rules shared by both stores: word records, extracted-term senses,
// review gating, level statistics and API shaping.

import { createId } from '../ids.js';
import { normalizeTerm } from '../normalize.js';
import { normalizeDifficultyLevel } from '../proficiency.js';
import { toApiSpeakingPrompt } from './speaking.js';

const DEFAULT_SENSE_LEVEL = 'A1';

/** A complete `words` record from insert input (defaults applied, difficulty normalized). */
export function buildWordRecord(input, now = new Date().toISOString()) {
  return {
    id: input.id ?? createId('word'),
    term: input.term,
    normalized_term: normalizeTerm(input.term),
    language: input.language,
    meaning_vi: input.meaning_vi,
    part_of_speech: input.part_of_speech ?? null,
    ipa: input.ipa ?? '',
    vietnamese_pronunciation: input.vietnamese_pronunciation ?? '',
    example: input.example ?? '',
    example_vi: input.example_vi ?? '',
    difficulty: normalizeDifficultyLevel(input.difficulty) ?? input.difficulty,
    topics: input.topics ?? [],
    entry_type: input.entry_type ?? 'word',
    blank_word: input.blank_word ?? null,
    explanation: input.explanation ?? '',
    generation_source: input.generation_source ?? 'seed',
    created_at: input.created_at ?? now,
    updated_at: input.updated_at ?? now
  };
}

/** Level of an extracted vocabulary item (falls back to A1). */
function itemLevel(item) {
  return item.level ?? item.difficulty ?? DEFAULT_SENSE_LEVEL;
}

/** `word_senses` fields of an extracted vocabulary item (without id/term/status/timestamps). */
export function senseFieldsFromItem(item) {
  return {
    part_of_speech: item.part_of_speech ?? null,
    meaning_vi: item.meaning_vi,
    short_definition: item.short_definition ?? null,
    pronunciation: item.vietnamese_pronunciation ?? null,
    ipa: item.ipa ?? null,
    pinyin: item.pinyin ?? null,
    level_scale: item.level_scale ?? 'cefr',
    level: itemLevel(item),
    quality_score: Number(item.quality_score ?? item.confidence ?? 0.5)
  };
}

/** Statuses for a new sense and its review item; approved items skip the admin queue. */
export function reviewStatuses(requiresReview, now) {
  return {
    senseStatus: requiresReview ? 'pending_review' : 'approved',
    reviewStatus: requiresReview ? 'pending' : 'approved',
    reviewedAt: requiresReview ? null : now
  };
}

/** Admin-created articles and fallback stubs need review; user article vocabulary is auto-approved. */
export function articleItemRequiresReview(article, item) {
  return Boolean(article.created_by_admin_id) || Boolean(item.isStub);
}

/** Only vocabulary of user-owned memorization passages is auto-approved. */
export function passageRequiresReview(passage) {
  return passage.owner_type !== 'user';
}

/**
 * Word-insert input for an approved extracted item, bridging it into the
 * `words` pool so learning cards can serve it.
 */
export function bridgedWordInput(item, { example, topics, generationSource }) {
  return {
    term: item.term,
    language: item.language,
    meaning_vi: item.meaning_vi ?? '',
    part_of_speech: item.part_of_speech ?? null,
    ipa: item.ipa ?? '',
    vietnamese_pronunciation: item.vietnamese_pronunciation ?? '',
    example,
    example_vi: '',
    difficulty: itemLevel(item),
    topics,
    generation_source: generationSource
  };
}

/** Word counts keyed by normalized level (legacy labels like "beginner" fold into CEFR). */
export function tallyWordLevels(words, language) {
  const counts = {};
  for (const word of words) {
    const level = normalizeDifficultyLevel(word.difficulty, { language }) ?? 'unknown';
    counts[level] = (counts[level] ?? 0) + Number(word.count ?? 1);
  }
  return counts;
}

/** Terms to steer generation away from: same-level terms first, then any others, newest first. */
export function pickTermSample(words, { targetLanguage, level, limit }) {
  const wanted = level ? normalizeDifficultyLevel(level, { language: targetLanguage }) : null;
  const newestFirst = [...words].sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
  const sameLevel = newestFirst.filter(
    (word) => wanted && normalizeDifficultyLevel(word.difficulty, { language: targetLanguage }) === wanted
  );
  const others = newestFirst.filter((word) => !sameLevel.includes(word));
  return [...sameLevel, ...others].slice(0, limit).map((word) => word.term);
}

/** Distinct lower-cased topics across the given topic lists, sorted. */
export function collectTopics(topicLists) {
  const topics = new Set();
  for (const list of topicLists) {
    for (const topic of list ?? []) {
      const normalized = String(topic).trim().toLowerCase();
      if (normalized) {
        topics.add(normalized);
      }
    }
  }
  return [...topics].sort();
}

export function toApiWord(word) {
  const result = {
    server_word_id: word.id,
    term: word.term,
    language: word.language,
    meaning_vi: word.meaning_vi,
    part_of_speech: word.part_of_speech,
    ipa: word.ipa,
    vietnamese_pronunciation: word.vietnamese_pronunciation,
    example: word.example,
    example_vi: word.example_vi,
    difficulty: word.difficulty,
    topics: word.topics,
    entry_type: word.entry_type ?? 'word',
    blank_word: word.blank_word ?? null,
    explanation: word.explanation ?? '',
    created_at: word.created_at
  };
  if (word.speaking_prompt) {
    result.speaking_prompt = toApiSpeakingPrompt(word.speaking_prompt);
  }
  return result;
}

export function toApiWorkplaceSentence(sentence) {
  return {
    sentence_id: sentence.id,
    text: sentence.text,
    language: sentence.language,
    meaning_vi: sentence.meaning_vi,
    topic: sentence.topic ?? null,
    source_article_id: sentence.source_article_id ?? null,
    source_title: sentence.source_title ?? null,
    generation_source: sentence.generation_source ?? 'article_workplace_sentence',
    created_at: sentence.created_at
  };
}
