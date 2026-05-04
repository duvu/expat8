import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';

export class WordStore {
  constructor({ seed = true } = {}) {
    this.words = new Map();
    this.studyEventsByClientId = new Map();
    if (seed) {
      seedWords().forEach((word) => this.insertWord(word));
    }
  }

  insertWord(input) {
    const normalizedTerm = normalizeTerm(input.term);
    const existing = [...this.words.values()].find(
      (word) => word.language === input.language && word.normalized_term === normalizedTerm
    );
    if (existing) {
      return { word: existing, inserted: false };
    }
    const now = new Date().toISOString();
    const word = {
      id: input.id ?? createId('word'),
      term: input.term,
      normalized_term: normalizedTerm,
      language: input.language,
      meaning_vi: input.meaning_vi,
      part_of_speech: input.part_of_speech ?? null,
      ipa: input.ipa,
      vietnamese_pronunciation: input.vietnamese_pronunciation,
      example: input.example,
      example_vi: input.example_vi,
      difficulty: input.difficulty,
      topics: input.topics ?? [],
      generation_source: input.generation_source ?? 'seed',
      created_at: input.created_at ?? now,
      updated_at: input.updated_at ?? now
    };
    this.words.set(word.id, word);
    return { word, inserted: true };
  }

  findNewWords({ targetLanguage = 'en', limit = 1, excludeWordIds = [] }) {
    return [...this.words.values()]
      .filter(
        (word) => word.language === targetLanguage && !excludeWordIds.includes(word.id)
      )
      .sort((a, b) => b.created_at.localeCompare(a.created_at))
      .slice(0, limit);
  }

  recentWords({ targetLanguage = 'en', limit = 1000 }) {
    return [...this.words.values()]
      .filter((word) => word.language === targetLanguage)
      .sort((a, b) => b.updated_at.localeCompare(a.updated_at))
      .slice(0, Math.min(limit, 1000));
  }

  syncStudyEvents({ deviceId, events }) {
    const accepted = [];
    const rejected = [];
    const receivedAt = new Date().toISOString();

    for (const event of events) {
      if (!event.client_event_id || !event.rating || !event.occurred_at) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          reason: 'missing_required_field'
        });
        continue;
      }
      if (this.studyEventsByClientId.has(event.client_event_id)) {
        accepted.push(event.client_event_id);
        continue;
      }
      this.studyEventsByClientId.set(event.client_event_id, {
        id: createId('study_event'),
        client_event_id: event.client_event_id,
        device_id: deviceId,
        user_id: event.user_id ?? null,
        word_id: event.server_word_id ?? null,
        local_word_id: event.local_word_id ?? null,
        rating: event.rating,
        occurred_at: event.occurred_at,
        received_at: receivedAt
      });
      accepted.push(event.client_event_id);
    }

    return {
      accepted_event_ids: accepted,
      rejected_events: rejected
    };
  }
}

export function toApiWord(word) {
  return {
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
    created_at: word.created_at
  };
}

function seedWords() {
  const now = new Date().toISOString();
  return [
    {
      id: 'word_reliable',
      term: 'reliable',
      language: 'en',
      meaning_vi: 'dang tin cay',
      part_of_speech: 'adjective',
      ipa: '/rɪˈlaɪəbl/',
      vietnamese_pronunciation: 'ri-lai-uh-bol',
      example: 'She is a reliable teammate.',
      example_vi: 'Co ay la mot dong doi dang tin cay.',
      difficulty: 'B1',
      topics: ['work', 'people'],
      generation_source: 'seed',
      created_at: now,
      updated_at: now
    },
    {
      id: 'word_adjust',
      term: 'adjust',
      language: 'en',
      meaning_vi: 'dieu chinh',
      part_of_speech: 'verb',
      ipa: '/əˈdʒʌst/',
      vietnamese_pronunciation: 'uh-just',
      example: 'Please adjust the schedule.',
      example_vi: 'Vui long dieu chinh lich trinh.',
      difficulty: 'B1',
      topics: ['work', 'daily'],
      generation_source: 'seed',
      created_at: now,
      updated_at: now
    }
  ];
}
