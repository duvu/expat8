import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';
import {
  DEFAULT_PROFICIENCY_LEVEL,
  decrementLevel,
  getFallbackDifficultyLevels,
  incrementLevel,
  isProgressionRating,
  normalizeDifficultyLevel,
  requireStudyRating
} from './proficiency.js';
import {
  DuplicateUserError,
  InvalidCredentialsError,
  createPasswordHash,
  createSessionToken,
  hashSessionToken,
  normalizeUserIdentifier,
  requireRegistrationInput,
  verifyPassword
} from './user_identity.js';

export class WordStore {
  constructor({ seed = true } = {}) {
    this.words = new Map();
    this.studyEventsByClientId = new Map();
    this.userProficiencies = new Map();
    this.usersById = new Map();
    this.usersByIdentifier = new Map();
    this.userSessionsByTokenHash = new Map();
    this.generationRuns = [];
    this.generationLocks = new Map();
    this.cachedWordIdsByOwner = new Map();
    this.wordStatesByOwnerWord = new Map();
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
      difficulty: normalizeDifficultyLevel(input.difficulty) ?? input.difficulty,
      topics: input.topics ?? [],
      generation_source: input.generation_source ?? 'seed',
      created_at: input.created_at ?? now,
      updated_at: input.updated_at ?? now
    };
    this.words.set(word.id, word);
    return { word, inserted: true };
  }

  findNewWords({ targetLanguage = 'en', limit = 1, excludeWordIds = [], proficiencyLevel, deviceId, userId }) {
    const learnedWordIds = this.#learnedWordIds({ deviceId, userId });
    const availableWords = [...this.words.values()]
      .filter(
        (word) =>
          word.language === targetLanguage &&
          !excludeWordIds.includes(word.id) &&
          !learnedWordIds.has(word.id)
      )
      .sort((a, b) => b.created_at.localeCompare(a.created_at));

    const resolvedLevel = proficiencyLevel
      ? normalizeDifficultyLevel(proficiencyLevel)
      : deviceId || userId
        ? this.#getOrCreateProficiency({ deviceId, userId, language: targetLanguage }).level
        : null;

    if (!resolvedLevel) {
      return availableWords.slice(0, limit);
    }

    for (const level of getFallbackDifficultyLevels(resolvedLevel)) {
      const matches = availableWords.filter(
        (word) => normalizeDifficultyLevel(word.difficulty) === level
      );
      if (matches.length > 0) {
        return matches.slice(0, limit);
      }
    }

    return [];
  }

  recentWords({ targetLanguage = 'en', limit = 1000 }) {
    return [...this.words.values()]
      .filter((word) => word.language === targetLanguage)
      .sort((a, b) => b.updated_at.localeCompare(a.updated_at))
      .slice(0, Math.min(limit, 1000));
  }

  countUsableWords({ targetLanguage = 'en' } = {}) {
    return [...this.words.values()].filter((word) => word.language === targetLanguage).length;
  }

  recordGenerationRun(input) {
    const now = new Date().toISOString();
    const run = {
      id: input.id ?? createId('generation_run'),
      target_language: input.targetLanguage,
      mode: input.mode,
      status: input.status,
      requested_count: input.requestedCount ?? 0,
      inserted_count: input.insertedCount ?? 0,
      error_message: input.errorMessage ?? null,
      run_date: input.runDate ?? now.slice(0, 10),
      started_at: input.startedAt ?? now,
      finished_at: input.finishedAt ?? now
    };
    this.generationRuns.push(run);
    return run;
  }

  hasGenerationRun({ targetLanguage = 'en', mode, runDate }) {
    return this.generationRuns.some(
      (run) =>
        run.target_language === targetLanguage &&
        run.mode === mode &&
        run.run_date === runDate &&
        run.status === 'success'
    );
  }

  acquireGenerationLock({ targetLanguage = 'en', ownerId, now = new Date(), ttlSeconds = 120 } = {}) {
    const existing = this.generationLocks.get(targetLanguage);
    if (existing && new Date(existing.expires_at) > now && existing.owner_id !== ownerId) {
      return false;
    }
    this.generationLocks.set(targetLanguage, {
      owner_id: ownerId,
      expires_at: new Date(now.getTime() + ttlSeconds * 1000).toISOString()
    });
    return true;
  }

  releaseGenerationLock({ targetLanguage = 'en', ownerId } = {}) {
    const existing = this.generationLocks.get(targetLanguage);
    if (existing?.owner_id === ownerId) {
      this.generationLocks.delete(targetLanguage);
    }
  }

  replaceCachedWordIds({ deviceId, userId = null, wordIds = [], observedAt = new Date().toISOString() }) {
    const known = [];
    const unknown = [];
    const seen = new Set();
    for (const wordId of wordIds) {
      if (typeof wordId !== 'string' || wordId.length === 0 || seen.has(wordId)) {
        continue;
      }
      seen.add(wordId);
      if (!this.words.has(wordId)) {
        unknown.push(wordId);
        continue;
      }
      if (known.length < 1000) {
        known.push(wordId);
      }
    }
    const key = this.#ownerKey({ deviceId, userId });
    this.cachedWordIdsByOwner.set(key, {
      wordIds: new Set(known),
      observed_at: observedAt
    });
    return {
      stored_count: known.length,
      unknown_server_word_ids: unknown
    };
  }

  cachedWordIdsFor({ deviceId, userId = null }) {
    return new Set(this.cachedWordIdsByOwner.get(this.#ownerKey({ deviceId, userId }))?.wordIds ?? []);
  }

  wordStateFor({ deviceId, userId = null, wordId }) {
    return this.wordStatesByOwnerWord.get(this.#wordStateKey({ deviceId, userId, wordId })) ?? null;
  }

  learningCards({ deviceId, userId = null, targetLanguage = 'en', limit = 20, now = new Date().toISOString() }) {
    const cappedLimit = Math.max(1, Math.min(limit, 50));
    const targetNew = Math.round(cappedLimit * 0.15);
    const targetReview = cappedLimit - targetNew;
    const cachedWordIds = this.cachedWordIdsFor({ deviceId, userId });
    const nowDate = new Date(now);
    const ownerStates = [...this.wordStatesByOwnerWord.values()].filter((state) =>
      userId ? state.user_id === userId : state.device_id === deviceId
    );
    const stateByWordId = new Map(ownerStates.map((state) => [state.word_id, state]));
    const reviewCandidates = ownerStates
      .filter((state) => state.language === targetLanguage && state.status !== 'completed')
      .filter((state) => !state.next_review_at || new Date(state.next_review_at) <= nowDate)
      .map((state) => this.words.get(state.word_id))
      .filter(Boolean)
      .sort((left, right) => left.updated_at.localeCompare(right.updated_at));
    const newCandidates = [...this.words.values()]
      .filter((word) => word.language === targetLanguage)
      .filter((word) => !cachedWordIds.has(word.id))
      .filter((word) => !stateByWordId.has(word.id) || stateByWordId.get(word.id)?.status !== 'completed')
      .filter((word) => !stateByWordId.has(word.id))
      .sort((left, right) => bCompareCreated(left, right));

    const cards = [];
    const take = (candidates, count, cardType, reason) => {
      for (const word of candidates) {
        if (cards.length >= cappedLimit || count <= 0) {
          break;
        }
        if (cards.some((card) => card.word.id === word.id)) {
          continue;
        }
        cards.push({ word, cardType, selectionReason: reason });
        count -= 1;
      }
    };

    take(reviewCandidates, targetReview, 'review', 'due_review');
    take(newCandidates, targetNew, 'new', 'new_available');
    if (cards.length < cappedLimit) {
      take(newCandidates, cappedLimit - cards.length, 'new', 'review_shortage_fallback');
    }
    if (cards.length < cappedLimit) {
      take(reviewCandidates, cappedLimit - cards.length, 'review', 'new_shortage_fallback');
    }

    const actualNew = cards.filter((card) => card.cardType === 'new').length;
    const actualReview = cards.filter((card) => card.cardType === 'review').length;
    return {
      items: cards,
      target_mix: { new: targetNew, review: targetReview },
      actual_mix: { new: actualNew, review: actualReview }
    };
  }

  syncStudyEvents({ deviceId, events, language = 'en', userId = null }) {
    const accepted = [];
    const rejected = [];
    let latestResult = this.getProficiency({ deviceId, userId, language });

    for (const event of events) {
      if (!event.client_event_id || !event.rating || !event.occurred_at) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          reason: 'missing_required_field'
        });
        continue;
      }
      try {
        latestResult = this.recordStudyEvent({ deviceId, userId, event, language });
      } catch (error) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          reason: error.name === 'InvalidStudyRatingError' ? 'invalid_rating' : 'invalid_event'
        });
        continue;
      }
      if (latestResult.idempotent) {
        accepted.push(event.client_event_id);
        continue;
      }
      accepted.push(event.client_event_id);
    }

    return {
      accepted_event_ids: accepted,
      rejected_events: rejected,
      proficiency: latestResult.proficiency
    };
  }

  recordStudyEvent({ deviceId, event, language = 'en', userId = null }) {
    const rating = requireStudyRating(event.rating);
    const existing = this.studyEventsByClientId.get(event.client_event_id);
    if (existing) {
      return {
        eventId: existing.id,
        idempotent: true,
        proficiency: this.#buildProficiencyResponse({ deviceId, userId: existing.user_id ?? userId, language })
      };
    }

    const receivedAt = new Date().toISOString();
    const storedEvent = {
      id: createId('study_event'),
      client_event_id: event.client_event_id,
      device_id: deviceId,
      user_id: userId ?? event.user_id ?? null,
      word_id: event.server_word_id ?? null,
      local_word_id: event.local_word_id ?? null,
      rating,
      occurred_at: event.occurred_at,
      received_at: receivedAt
    };
    this.studyEventsByClientId.set(event.client_event_id, storedEvent);
    this.#upsertWordState({ deviceId, userId: storedEvent.user_id, language, event: storedEvent });

    const levelChange = this.#applyProficiencyChange({ deviceId, userId: storedEvent.user_id, language, rating });

    return {
      eventId: storedEvent.id,
      idempotent: false,
      proficiency: this.#buildProficiencyResponse({
        deviceId,
        userId: storedEvent.user_id,
        language,
        ...levelChange
      })
    };
  }

  getProficiency({ deviceId, language = 'en', userId = null }) {
    return this.#buildProficiencyResponse({ deviceId, userId, language });
  }

  countConsecutiveRatings({ deviceId, rating, userId = null }) {
    const recentEvents = this.#recentEvents({ deviceId, userId });
    let count = 0;
    for (const event of recentEvents) {
      if (event.rating === rating) {
        count += 1;
      } else {
        break;
      }
    }
    return count;
  }

  getLastRatingType({ deviceId, userId = null }) {
    return this.#recentEvents({ deviceId, userId })[0]?.rating ?? null;
  }

  registerUser({ identifier, password, displayName = null, deviceId = null }) {
    const input = requireRegistrationInput({ identifier, password });
    if (this.usersByIdentifier.has(input.identifier)) {
      throw new DuplicateUserError(input.identifier);
    }
    const now = new Date().toISOString();
    const user = {
      id: createId('user'),
      identifier: input.identifier,
      display_name: displayName,
      password_hash: createPasswordHash(input.password),
      created_at: now,
      updated_at: now
    };
    this.usersById.set(user.id, user);
    this.usersByIdentifier.set(user.identifier, user);
    const session = this.#createSessionForUser({ user, deviceId });
    return { user, ...session };
  }

  createUserSession({ identifier, password, deviceId = null }) {
    const normalizedIdentifier = normalizeUserIdentifier(identifier);
    const user = this.usersByIdentifier.get(normalizedIdentifier);
    if (!user || !verifyPassword(password, user.password_hash)) {
      throw new InvalidCredentialsError();
    }
    const session = this.#createSessionForUser({ user, deviceId });
    return { user, ...session };
  }

  resolveUserSession({ sessionToken }) {
    if (!sessionToken) {
      return null;
    }
    const session = this.userSessionsByTokenHash.get(hashSessionToken(sessionToken));
    if (!session || session.revoked_at) {
      return null;
    }
    const user = this.usersById.get(session.user_id);
    return user ? { user, session } : null;
  }

  revokeUserSession({ sessionToken }) {
    const session = this.userSessionsByTokenHash.get(hashSessionToken(sessionToken));
    if (!session || session.revoked_at) {
      return { revoked: false };
    }
    session.revoked_at = new Date().toISOString();
    return { revoked: true };
  }

  #createSessionForUser({ user, deviceId = null }) {
    const now = new Date().toISOString();
    const token = createSessionToken();
    const session = {
      id: createId('session'),
      user_id: user.id,
      token_hash: hashSessionToken(token),
      device_id: deviceId,
      created_at: now,
      revoked_at: null
    };
    this.userSessionsByTokenHash.set(session.token_hash, session);
    return { session, sessionToken: token };
  }

  #applyProficiencyChange({ deviceId, userId = null, language, rating }) {
    const proficiency = this.#getOrCreateProficiency({ deviceId, userId, language });
    const consecutiveCount = this.countConsecutiveRatings({ deviceId, userId, rating });
    if (!isProgressionRating(rating) || consecutiveCount === 0 || consecutiveCount % 5 !== 0) {
      return null;
    }

    const previousLevel = proficiency.level;
    const nextLevel = rating === 'too_easy'
      ? incrementLevel(previousLevel)
      : decrementLevel(previousLevel);

    proficiency.level = nextLevel;
    proficiency.updated_at = new Date().toISOString();
    return {
      levelChanged: nextLevel !== previousLevel,
      previousLevel,
      triggeredBy: `${consecutiveCount}x consecutive ${rating}`
    };
  }

  #buildProficiencyResponse({ deviceId, userId = null, language = 'en', levelChanged = false, previousLevel = null, triggeredBy = null } = {}) {
    const proficiency = this.#getOrCreateProficiency({ deviceId, userId, language });
    const currentRatingType = this.getLastRatingType({ deviceId, userId });
    const consecutiveCount = currentRatingType
      ? this.countConsecutiveRatings({ deviceId, userId, rating: currentRatingType })
      : 0;

    return {
      level: proficiency.level,
      level_changed: levelChanged,
      previous_level: previousLevel,
      triggered_by: triggeredBy,
      consecutive_count: levelChanged ? 0 : consecutiveCount,
      consecutive_rating_type: levelChanged ? null : currentRatingType,
      user_id: userId,
      language,
      last_updated: proficiency.updated_at
    };
  }

  #getOrCreateProficiency({ deviceId, userId = null, language }) {
    const key = `${userId ? `user:${userId}` : `device:${deviceId}`}:${language}`;
    const existing = this.userProficiencies.get(key);
    if (existing) {
      return existing;
    }
    const now = new Date().toISOString();
    const created = {
      id: createId('proficiency'),
      user_id: userId,
      device_id: deviceId,
      language,
      level: DEFAULT_PROFICIENCY_LEVEL,
      created_at: now,
      updated_at: now
    };
    this.userProficiencies.set(key, created);
    return created;
  }

  #recentEvents({ deviceId, userId = null }) {
    return [...this.studyEventsByClientId.values()]
      .filter((event) => (userId ? event.user_id === userId : event.device_id === deviceId))
      .sort((left, right) => {
        const occurred = right.occurred_at.localeCompare(left.occurred_at);
        return occurred !== 0 ? occurred : right.received_at.localeCompare(left.received_at);
      })
      .slice(0, 10);
  }

  #learnedWordIds({ deviceId, userId = null }) {
    return new Set(
      [...this.studyEventsByClientId.values()]
        .filter((event) => (userId ? event.user_id === userId : event.device_id === deviceId))
        .map((event) => event.word_id)
        .filter(Boolean)
    );
  }

  #upsertWordState({ deviceId, userId = null, language, event }) {
    if (!event.word_id) {
      return;
    }
    const occurredAt = new Date(event.occurred_at);
    const nextReviewAt = nextReviewForRating(event.rating, occurredAt);
    const state = {
      user_id: userId,
      device_id: deviceId,
      word_id: event.word_id,
      language,
      status: statusForRating(event.rating),
      last_rating: event.rating,
      last_studied_at: event.occurred_at,
      next_review_at: nextReviewAt?.toISOString() ?? null,
      updated_at: new Date().toISOString()
    };
    this.wordStatesByOwnerWord.set(this.#wordStateKey({ deviceId, userId, wordId: event.word_id }), state);
  }

  #ownerKey({ deviceId, userId = null }) {
    return userId ? `user:${userId}` : `device:${deviceId}`;
  }

  #wordStateKey({ deviceId, userId = null, wordId }) {
    return `${this.#ownerKey({ deviceId, userId })}:word:${wordId}`;
  }
}

function bCompareCreated(left, right) {
  return right.created_at.localeCompare(left.created_at);
}

function statusForRating(rating) {
  if (rating === 'easy' || rating === 'too_easy') {
    return 'completed';
  }
  return rating === 'too_hard' ? 'learning' : 'review';
}

function nextReviewForRating(rating, occurredAt) {
  if (rating === 'easy' || rating === 'too_easy') {
    return null;
  }
  if (rating === 'too_hard') {
    return new Date(occurredAt.getTime() + 5 * 60 * 1000);
  }
  return new Date(occurredAt.getTime() + 24 * 60 * 60 * 1000);
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
