import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';
import {
  decrementLevel,
  getDefaultProficiencyLevel,
  getProficiencyProfile,
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

export const SPEAKING_EVENT_TYPES = [
  'speaking_prompt_viewed',
  'speaking_sample_played',
  'speaking_recorded',
  'speaking_retried',
  'speaking_self_rated_clear',
  'speaking_self_rated_hesitated',
  'speaking_self_rated_could_not_say'
];

export const SPEAKING_SELF_RATINGS = ['clear', 'hesitated', 'could_not_say'];

export class WordStore {
  constructor({ seed = true } = {}) {
    this.words = new Map();
    this.studyEventsByClientId = new Map();
    this.userProficiencies = new Map();
    this.articlesById = new Map();
    this.vocabularyReviewItemsById = new Map();
    this.contentPacksById = new Map();
    this.articleProcessingJobsById = new Map();
    this.termsById = new Map();
    this.wordSensesById = new Map();
    this.articleTermsById = new Map();
    this.speakingPromptsById = new Map();
    this.speakingEventsByKey = new Map();
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

  addCachedWordIds({ deviceId, userId = null, wordIds = [], observedAt = new Date().toISOString() }) {
    const key = this.#ownerKey({ deviceId, userId });
    const existing = this.cachedWordIdsByOwner.get(key) ?? {
      wordIds: new Set(),
      observed_at: observedAt
    };
    const unknown = [];
    const seen = new Set();
    let storedCount = 0;

    for (const wordId of wordIds) {
      if (typeof wordId !== 'string' || wordId.length === 0 || seen.has(wordId)) {
        continue;
      }
      seen.add(wordId);
      if (!this.words.has(wordId)) {
        unknown.push(wordId);
        continue;
      }
      if (existing.wordIds.size < 1000 || existing.wordIds.has(wordId)) {
        existing.wordIds.add(wordId);
        storedCount += 1;
      }
    }

    existing.observed_at = observedAt;
    this.cachedWordIdsByOwner.set(key, existing);
    return {
      stored_count: storedCount,
      unknown_server_word_ids: unknown
    };
  }

  cachedWordIdsFor({ deviceId, userId = null }) {
    return new Set(this.cachedWordIdsByOwner.get(this.#ownerKey({ deviceId, userId }))?.wordIds ?? []);
  }

  wordStateFor({ deviceId, userId = null, wordId }) {
    return this.wordStatesByOwnerWord.get(this.#wordStateKey({ deviceId, userId, wordId })) ?? null;
  }

  learningCards({ deviceId, userId = null, targetLanguage = 'en', limit = 10, now = new Date().toISOString() }) {
    const cappedLimit = Math.max(1, Math.min(limit, 100));
    const ownerKeys = this.#selectionOwnerKeys({ deviceId, userId });
    const cachedWordIds = this.#cachedWordIdsForOwnerKeys(ownerKeys);
    const stateWordIds = new Set(
      [...this.wordStatesByOwnerWord.entries()]
        .filter(([key, state]) => ownerKeys.has(this.#ownerKeyFromState(state)) && key.includes(':word:'))
        .filter(([, state]) => state.language === targetLanguage)
        .map(([, state]) => state.word_id)
    );
    const newCandidates = [...this.words.values()]
      .filter((word) => word.language === targetLanguage)
      .filter((word) => !cachedWordIds.has(word.id))
      .filter((word) => !stateWordIds.has(word.id))
      .sort((left, right) => bCompareCreated(left, right));

    const cards = newCandidates
      .slice(0, cappedLimit)
      .map((word) => ({ word, cardType: 'new', selectionReason: 'new_available' }));
    this.addCachedWordIds({
      deviceId,
      userId,
      wordIds: cards.map((card) => card.word.id),
      observedAt: now
    });

    return {
      items: cards,
      target_mix: { new: cappedLimit, review: 0 },
      actual_mix: { new: cards.length, review: 0 }
    };
  }

  syncStudyEvents({ deviceId, events, language = 'en', userId = null }) {
    const accepted = [];
    const duplicates = [];
    const rejected = [];
    let latestProficiency = this.getProficiency({ deviceId, userId, language });

    const orderedEvents = [...events].sort(compareEventsForProjection);

    for (const event of orderedEvents) {
      const eventKey = resolveEventKey(event);
      if (isSpeakingEvent(event)) {
        if (!eventKey || !event.occurred_at) {
          rejected.push({
            client_event_id: event.client_event_id ?? null,
            event_id: event.event_id ?? null,
            reason: 'missing_required_field'
          });
          continue;
        }
        try {
          const result = this.recordSpeakingEvent({ deviceId, userId, event, language });
          if (result.idempotent) {
            duplicates.push(eventKey);
          } else {
            accepted.push(eventKey);
          }
        } catch (error) {
          rejected.push({
            client_event_id: event.client_event_id ?? null,
            event_id: event.event_id ?? null,
            reason: error.message === 'forbidden_audio_field' ? 'forbidden_audio_field' : 'invalid_speaking_event'
          });
        }
        continue;
      }
      if (isUnknownSpeakingEvent(event)) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          event_id: event.event_id ?? null,
          reason: 'invalid_speaking_event_type'
        });
        continue;
      }
      if (!eventKey || !event.rating || !event.occurred_at) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          event_id: event.event_id ?? null,
          reason: 'missing_required_field'
        });
        continue;
      }
      try {
        const result = this.recordStudyEvent({ deviceId, userId, event, language });
        latestProficiency = result.proficiency;
        if (result.idempotent) {
          duplicates.push(eventKey);
        } else {
          accepted.push(eventKey);
        }
      } catch (error) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          event_id: event.event_id ?? null,
          reason: error.name === 'InvalidStudyRatingError' ? 'invalid_rating' : 'invalid_event'
        });
        continue;
      }
    }

    return {
      accepted_event_ids: accepted,
      duplicates,
      rejected_events: rejected,
      proficiency: latestProficiency
    };
  }

  recordSpeakingEvent({ deviceId, event, language = 'en', userId = null }) {
    const eventKey = resolveEventKey(event);
    if (!eventKey) {
      throw new Error('missing_event_id');
    }
    const normalized = normalizeSpeakingEvent({ deviceId, event, language, userId });
    const existing = this.speakingEventsByKey.get(eventKey);
    if (existing) {
      return { eventId: existing.id, idempotent: true };
    }
    const stored = {
      id: createId('speaking_event'),
      ...normalized,
      event_id: event.event_id ?? eventKey,
      client_event_id: event.client_event_id ?? eventKey,
      received_at: new Date().toISOString()
    };
    this.speakingEventsByKey.set(eventKey, stored);
    return { eventId: stored.id, idempotent: false };
  }

  getSpeakingSummary({ deviceId, language = 'en', userId = null, weekStart = null }) {
    const start = normalizeWeekStart(weekStart);
    const events = [...this.speakingEventsByKey.values()]
      .filter((event) => event.language === language)
      .filter((event) => event.occurred_at >= start)
      .filter((event) => userId ? event.user_id === userId : event.device_id === deviceId && !event.user_id);
    return buildSpeakingSummary({ deviceId, userId, language, weekStart: start, events });
  }

  recordStudyEvent({ deviceId, event, language = 'en', userId = null }) {
    const rating = requireStudyRating(event.rating);
    const eventKey = resolveEventKey(event);
    if (!eventKey) {
      throw new Error('missing_event_id');
    }
    const existing = this.studyEventsByClientId.get(eventKey);
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
      event_id: event.event_id ?? eventKey,
      client_event_id: event.client_event_id ?? eventKey,
      device_id: deviceId,
      user_id: userId ?? event.user_id ?? null,
      word_id: event.server_word_id ?? null,
      local_word_id: event.local_word_id ?? null,
      rating,
      occurred_at: event.occurred_at,
      received_at: receivedAt
    };
    this.studyEventsByClientId.set(eventKey, storedEvent);
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
      ? incrementLevel(previousLevel, { language })
      : decrementLevel(previousLevel, { language });

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
    const profile = getProficiencyProfile({ language });

    return {
      scale: profile.scale,
      level: proficiency.level,
      level_index: profile.levels.indexOf(proficiency.level),
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
      level: getDefaultProficiencyLevel({ language }),
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
        if (occurred !== 0) {
          return occurred;
        }
        const received = right.received_at.localeCompare(left.received_at);
        if (received !== 0) {
          return received;
        }
        return right.id.localeCompare(left.id);
      })
      .slice(0, 10);
  }

  createArticle({ userId, title, sourceUrl = null, language, rawText, visibility = 'private' }) {
    const now = new Date().toISOString();
    const article = {
      id: createId('article'),
      owner_user_id: userId,
      created_by_admin_id: null,
      title,
      source_url: sourceUrl,
      language,
      raw_text: rawText,
      cleaned_text: null,
      visibility,
      status: 'pending_processing',
      processing_error: null,
      created_at: now,
      updated_at: now
    };
    this.articlesById.set(article.id, article);
    this.enqueueArticleProcessingJob({ articleId: article.id });
    return article;
  }

  listArticles({ userId, limit = 50 }) {
    return [...this.articlesById.values()]
      .filter((article) => article.owner_user_id === userId && article.status !== 'deleted')
      .sort((left, right) => right.created_at.localeCompare(left.created_at))
      .slice(0, Math.max(1, Math.min(limit, 100)));
  }

  getArticleByIdForUser({ articleId, userId }) {
    const article = this.articlesById.get(articleId);
    if (!article || article.owner_user_id !== userId || article.status === 'deleted') {
      return null;
    }
    return article;
  }

  getArticleById({ articleId }) {
    return this.articlesById.get(articleId) ?? null;
  }

  createAdminArticle({ adminUserId = null, title, sourceUrl = null, language, rawText, visibility = 'published' }) {
    const now = new Date().toISOString();
    const article = {
      id: createId('article'),
      owner_user_id: null,
      created_by_admin_id: adminUserId,
      title,
      source_url: sourceUrl,
      language,
      raw_text: rawText,
      cleaned_text: null,
      visibility,
      status: 'pending_processing',
      processing_error: null,
      created_at: now,
      updated_at: now
    };
    this.articlesById.set(article.id, article);
    this.enqueueArticleProcessingJob({ articleId: article.id });
    return article;
  }

  listAdminArticles({ limit = 50, status = null }) {
    return [...this.articlesById.values()]
      .filter((article) => (status ? article.status === status : true))
      .sort((left, right) => right.created_at.localeCompare(left.created_at))
      .slice(0, Math.max(1, Math.min(limit, 100)));
  }

  reprocessArticle({ articleId }) {
    const article = this.articlesById.get(articleId);
    if (!article) {
      return null;
    }
    article.status = 'pending_processing';
    article.processing_error = null;
    article.updated_at = new Date().toISOString();
    this.enqueueArticleProcessingJob({ articleId });
    return article;
  }

  publishArticle({ articleId }) {
    const article = this.articlesById.get(articleId);
    if (!article) {
      return null;
    }
    article.status = 'published';
    article.visibility = 'published';
    article.updated_at = new Date().toISOString();
    return article;
  }

  getArticleVocabulary({ articleId, userId }) {
    if (!userId) {
      return null;
    }
    const article = this.articlesById.get(articleId);
    if (!article || article.status === 'deleted') {
      return null;
    }
    const isOwner = article.owner_user_id === userId;
    if (!isOwner && article.visibility !== 'published') {
      return null;
    }

    const items = [...this.articleTermsById.values()]
      .filter((item) => item.article_id === articleId)
      .sort((left, right) => {
        const created = String(left.created_at).localeCompare(String(right.created_at));
        if (created !== 0) {
          return created;
        }
        return left.id.localeCompare(right.id);
      })
      .flatMap((articleTerm) => {
        const term = this.termsById.get(articleTerm.term_id);
        const sense = this.wordSensesById.get(articleTerm.word_sense_id);
        if (!term || !sense) {
          return [];
        }
        if (article.visibility === 'published' && sense.status !== 'approved') {
          return [];
        }
        const speakingPrompt = this.#approvedSpeakingPromptForSense(sense.id);
        return [{
          term_id: term.id,
          display_term: term.display_term,
          word_sense_id: sense.id,
          meaning_vi: sense.meaning_vi,
          part_of_speech: sense.part_of_speech,
          ipa: sense.ipa,
          level: sense.level,
          status: sense.status,
          speaking_prompt: speakingPrompt ? toApiSpeakingPrompt(speakingPrompt) : null
        }];
      });

    return {
      article_id: article.id,
      items
    };
  }

  #approvedSpeakingPromptForSense(wordSenseId) {
    return [...this.speakingPromptsById.values()]
      .filter((prompt) => prompt.word_sense_id === wordSenseId && prompt.status === 'approved')
      .sort((left, right) => right.updated_at.localeCompare(left.updated_at))[0] ?? null;
  }

  softDeleteArticle({ articleId, userId }) {
    const article = this.articlesById.get(articleId);
    if (!article || article.owner_user_id !== userId || article.status === 'deleted') {
      return null;
    }
    article.status = 'deleted';
    article.visibility = 'private';
    article.updated_at = new Date().toISOString();
    return article;
  }

  patchAdminArticle({ articleId, patch }) {
    const article = this.articlesById.get(articleId);
    if (!article) {
      return null;
    }

    for (const field of ['title', 'language', 'visibility', 'status']) {
      if (patch[field] !== undefined) {
        article[field] = patch[field];
      }
    }
    article.updated_at = new Date().toISOString();
    return article;
  }

  async healthCheck() {
    return true;
  }

  listVocabularyReviewItems({ status = 'pending', limit = 100 }) {
    return [...this.vocabularyReviewItemsById.values()]
      .filter((item) => (status ? item.status === status : true))
      .sort((left, right) => right.created_at.localeCompare(left.created_at))
      .slice(0, Math.max(1, Math.min(limit, 200)));
  }

  reviewVocabularyItem({ itemId, status, reviewNote = null, reviewerUserId = null }) {
    const item = this.vocabularyReviewItemsById.get(itemId);
    if (!item) {
      return null;
    }
    item.status = status;
    item.review_note = reviewNote;
    item.reviewer_user_id = reviewerUserId;
    item.reviewed_at = new Date().toISOString();
    item.updated_at = item.reviewed_at;
    return item;
  }

  listSpeakingPrompts({ status = null, missingRequired = false, limit = 100 } = {}) {
    return [...this.speakingPromptsById.values()]
      .filter((prompt) => status ? prompt.status === status : true)
      .filter((prompt) => missingRequired ? isPromptMissingRequiredFields(prompt) : true)
      .sort((left, right) => right.updated_at.localeCompare(left.updated_at))
      .slice(0, Math.max(1, Math.min(limit, 200)));
  }

  createSpeakingPrompt(input) {
    const now = new Date().toISOString();
    const prompt = normalizeSpeakingPromptInput({
      ...input,
      id: input.id ?? createId('speaking_prompt'),
      status: input.status ?? 'pending_review',
      created_at: now,
      updated_at: now
    });
    this.speakingPromptsById.set(prompt.id, prompt);
    return prompt;
  }

  updateSpeakingPrompt({ promptId, patch, reviewerUserId = null }) {
    const existing = this.speakingPromptsById.get(promptId);
    if (!existing) {
      return null;
    }
    const now = new Date().toISOString();
    const updated = normalizeSpeakingPromptInput({
      ...existing,
      ...patch,
      reviewer_user_id: patch.status ? reviewerUserId : existing.reviewer_user_id,
      reviewed_at: patch.status ? now : existing.reviewed_at,
      updated_at: now
    });
    this.speakingPromptsById.set(updated.id, updated);
    return updated;
  }

  listContentPacks({ language = 'en', afterVersion = null, limit = 100 }) {
    return [...this.contentPacksById.values()]
      .filter((pack) => pack.status === 'published')
      .filter((pack) => pack.language === language)
      .filter((pack) => (afterVersion == null ? true : pack.version > afterVersion))
      .sort((left, right) => right.version - left.version)
      .slice(0, Math.max(1, Math.min(limit, 200)));
  }

  getContentPackById({ id }) {
    const pack = this.contentPacksById.get(id);
    if (!pack || pack.status !== 'published') {
      return null;
    }
    return {
      ...pack,
      items: Array.isArray(pack.items) ? pack.items : []
    };
  }

  enqueueArticleProcessingJob({ articleId }) {
    const now = new Date().toISOString();
    const job = {
      id: createId('article_job'),
      article_id: articleId,
      status: 'pending_processing',
      attempt_count: 0,
      queued_at: now,
      started_at: null,
      finished_at: null,
      error_message: null,
      created_at: now,
      updated_at: now
    };
    this.articleProcessingJobsById.set(job.id, job);
    return job;
  }

  claimNextArticleProcessingJob() {
    const job = [...this.articleProcessingJobsById.values()]
      .filter((item) => item.status === 'pending_processing')
      .sort((left, right) => left.queued_at.localeCompare(right.queued_at))[0];
    if (!job) {
      return null;
    }
    const article = this.articlesById.get(job.article_id);
    const now = new Date().toISOString();
    job.status = 'processing';
    job.started_at = now;
    job.attempt_count += 1;
    job.updated_at = now;
    if (article) {
      if (article.status !== 'deleted') {
        article.status = 'processing';
      }
      article.updated_at = now;
    }
    return job;
  }

  completeArticleProcessingJob({ jobId, status = 'processed', errorMessage = null }) {
    const job = this.articleProcessingJobsById.get(jobId);
    if (!job) {
      return null;
    }
    const article = this.articlesById.get(job.article_id);
    const now = new Date().toISOString();
    job.status = status;
    job.error_message = errorMessage;
    job.finished_at = now;
    job.updated_at = now;
    if (article) {
      if (article.status !== 'deleted') {
        article.status = status;
      }
      article.processing_error = errorMessage;
      article.updated_at = now;
    }
    return job;
  }

  persistArticleVocabulary({ articleId, items = [] }) {
    const now = new Date().toISOString();
    const article = this.articlesById.get(articleId);
    if (!article) {
      throw new Error('article_not_found');
    }
    const persisted = [];
    for (const item of items) {
      const normalized = normalizeTerm(item.term);
      let term = [...this.termsById.values()].find(
        (entry) => entry.language === item.language && entry.normalized_term === normalized
      );
      if (!term) {
        term = {
          id: createId('term'),
          language: item.language,
          display_term: item.term,
          normalized_term: normalized,
          lemma: null,
          created_at: now
        };
        this.termsById.set(term.id, term);
      }

      const sense = {
        id: createId('sense'),
        term_id: term.id,
        part_of_speech: item.part_of_speech ?? null,
        meaning_vi: item.meaning_vi,
        short_definition: item.short_definition ?? null,
        pronunciation: item.vietnamese_pronunciation,
        ipa: item.ipa ?? null,
        pinyin: item.pinyin ?? null,
        level_scale: item.level_scale ?? 'cefr',
        level: item.difficulty ?? 'A1',
        quality_score: Number(item.quality_score ?? item.confidence ?? 0.5),
        status: article.created_by_admin_id ? 'pending_review' : 'approved',
        created_at: now,
        updated_at: now
      };
      this.wordSensesById.set(sense.id, sense);

      const articleTerm = {
        id: createId('article_term'),
        article_id: articleId,
        term_id: term.id,
        word_sense_id: sense.id,
        surface_text: item.term,
        sentence_context: item.example ?? null,
        start_offset: null,
        end_offset: null,
        frequency: Number(item.frequency ?? 1),
        extraction_confidence: Number(item.confidence ?? 0.5),
        created_at: now
      };
      this.articleTermsById.set(articleTerm.id, articleTerm);

      const reviewItem = {
        id: createId('review_item'),
        word_sense_id: sense.id,
        article_id: articleId,
        status: article.created_by_admin_id ? 'pending' : 'approved',
        reviewer_user_id: null,
        review_note: null,
        reviewed_at: article.created_by_admin_id ? null : now,
        created_at: now,
        updated_at: now
      };
      this.vocabularyReviewItemsById.set(reviewItem.id, reviewItem);
      persisted.push({ term, sense, articleTerm, reviewItem });
    }
    return { count: persisted.length, items: persisted };
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

  #ownerKeyFromState(state) {
    return this.#ownerKey({ deviceId: state.device_id, userId: state.user_id });
  }

  #selectionOwnerKeys({ deviceId, userId = null }) {
    const keys = new Set([this.#ownerKey({ deviceId })]);
    if (userId) {
      keys.add(this.#ownerKey({ deviceId, userId }));
    }
    return keys;
  }

  #cachedWordIdsForOwnerKeys(ownerKeys) {
    const wordIds = new Set();
    for (const key of ownerKeys) {
      const ownerCache = this.cachedWordIdsByOwner.get(key)?.wordIds ?? [];
      for (const wordId of ownerCache) {
        wordIds.add(wordId);
      }
    }
    return wordIds;
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

export function resolveEventKey(event) {
  if (event?.event_id && typeof event.event_id === 'string') {
    return event.event_id;
  }
  if (event?.client_event_id && typeof event.client_event_id === 'string') {
    return event.client_event_id;
  }
  return null;
}

export function compareEventsForProjection(left, right) {
  const occurred = String(left.occurred_at ?? '').localeCompare(String(right.occurred_at ?? ''));
  if (occurred !== 0) {
    return occurred;
  }
  const received = String(left.received_at ?? '').localeCompare(String(right.received_at ?? ''));
  if (received !== 0) {
    return received;
  }
  return resolveEventKey(left)?.localeCompare(resolveEventKey(right) ?? '') ?? -1;
}

export function isSpeakingEvent(event) {
  return SPEAKING_EVENT_TYPES.includes(event?.event_type);
}

export function isUnknownSpeakingEvent(event) {
  return typeof event?.event_type === 'string' && event.event_type.startsWith('speaking_') && !isSpeakingEvent(event);
}

export function normalizeSpeakingEvent({ deviceId, event, language = 'en', userId = null }) {
  if (!isSpeakingEvent(event)) {
    throw new Error('invalid_speaking_event_type');
  }
  if (containsForbiddenAudioField(event)) {
    throw new Error('forbidden_audio_field');
  }
  const speaking = event.speaking ?? {};
  const attemptId = normalizeOptionalText(speaking.attempt_id ?? event.attempt_id);
  if (!attemptId || !event.occurred_at) {
    throw new Error('missing_required_field');
  }
  const selfRating = normalizeOptionalText(speaking.self_rating ?? event.self_rating);
  if (selfRating && !SPEAKING_SELF_RATINGS.includes(selfRating)) {
    throw new Error('invalid_self_rating');
  }
  const durationMs = normalizeOptionalInteger(speaking.duration_ms ?? event.duration_ms);
  const retryCount = normalizeOptionalInteger(speaking.retry_count ?? event.retry_count) ?? 0;
  if ((durationMs !== null && durationMs < 0) || retryCount < 0) {
    throw new Error('invalid_speaking_event');
  }
  return {
    device_id: deviceId,
    user_id: userId,
    event_type: event.event_type,
    attempt_id: attemptId,
    prompt_id: normalizeOptionalText(speaking.prompt_id ?? event.prompt_id),
    word_sense_id: normalizeOptionalText(speaking.word_sense_id ?? event.word_sense_id),
    server_word_id: normalizeOptionalText(speaking.server_word_id ?? event.server_word_id),
    duration_ms: durationMs,
    retry_count: retryCount,
    self_rating: selfRating,
    language: normalizeOptionalText(event.language) ?? language,
    occurred_at: event.occurred_at
  };
}

export function toApiSpeakingPrompt(prompt) {
  if (!prompt) {
    return null;
  }
  return {
    id: prompt.id,
    target_text: prompt.target_text,
    vi_hint: prompt.vi_hint,
    target_phrase: prompt.target_phrase,
    pronunciation_tip_vi: prompt.pronunciation_tip_vi,
    common_mistake_vi: prompt.common_mistake_vi,
    difficulty: prompt.difficulty,
    topic: prompt.topic
  };
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
    created_at: word.created_at
  };
  if (word.speaking_prompt) {
    result.speaking_prompt = toApiSpeakingPrompt(word.speaking_prompt);
  }
  return result;
}

function buildSpeakingSummary({ deviceId, userId = null, language, weekStart, events }) {
  const selfRatingCounts = { clear: 0, hesitated: 0, could_not_say: 0 };
  let spokenSentenceCount = 0;
  let retryCount = 0;
  let approximateDurationMs = 0;
  let latestActivityAt = null;
  for (const event of events) {
    if (event.event_type === 'speaking_recorded') {
      spokenSentenceCount += 1;
      approximateDurationMs += Number(event.duration_ms ?? 0);
    }
    if (event.event_type === 'speaking_retried') {
      retryCount += 1;
    }
    if (event.self_rating && selfRatingCounts[event.self_rating] !== undefined) {
      selfRatingCounts[event.self_rating] += 1;
    }
    if (!latestActivityAt || event.occurred_at > latestActivityAt) {
      latestActivityAt = event.occurred_at;
    }
  }
  return {
    device_id: deviceId,
    user_id: userId,
    language,
    week_start: weekStart.slice(0, 10),
    spoken_sentence_count: spokenSentenceCount,
    recording_count: spokenSentenceCount,
    retry_count: retryCount,
    approximate_duration_ms: approximateDurationMs,
    self_rating_counts: selfRatingCounts,
    latest_activity_at: latestActivityAt
  };
}

function containsForbiddenAudioField(value) {
  if (!value || typeof value !== 'object') {
    return false;
  }
  for (const [key, nested] of Object.entries(value)) {
    const normalized = key.toLowerCase();
    if ([
      'audio',
      'audio_bytes',
      'audio_base64',
      'audio_blob',
      'local_audio_path',
      'local_file_path',
      'file_path'
    ].includes(normalized)) {
      return true;
    }
    if (typeof nested === 'object' && containsForbiddenAudioField(nested)) {
      return true;
    }
  }
  return false;
}

function normalizeOptionalText(value) {
  if (value === undefined || value === null) {
    return null;
  }
  const text = String(value).trim();
  return text ? text : null;
}

function normalizeOptionalInteger(value) {
  if (value === undefined || value === null || value === '') {
    return null;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? null : parsed;
}

function normalizeWeekStart(value) {
  if (typeof value === 'string' && value.trim()) {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }
  const now = new Date();
  const day = now.getUTCDay();
  const diff = day === 0 ? 6 : day - 1;
  now.setUTCDate(now.getUTCDate() - diff);
  now.setUTCHours(0, 0, 0, 0);
  return now.toISOString();
}

export function isPromptMissingRequiredFields(prompt) {
  if (!prompt) {
    return true;
  }
  const text = typeof prompt.target_text === 'string' ? prompt.target_text.trim() : '';
  const hint = typeof prompt.vi_hint === 'string' ? prompt.vi_hint.trim() : '';
  return !text || !hint;
}

export function normalizeSpeakingPromptInput(input) {
  return {
    id: input.id,
    word_sense_id: input.word_sense_id ?? null,
    article_term_id: input.article_term_id ?? null,
    target_text: input.target_text ?? null,
    vi_hint: input.vi_hint ?? null,
    target_phrase: input.target_phrase ?? null,
    pronunciation_tip_vi: input.pronunciation_tip_vi ?? null,
    common_mistake_vi: input.common_mistake_vi ?? null,
    difficulty: input.difficulty ?? null,
    topic: input.topic ?? null,
    status: input.status ?? 'pending_review',
    reviewer_user_id: input.reviewer_user_id ?? null,
    reviewed_at: input.reviewed_at ?? null,
    created_at: input.created_at,
    updated_at: input.updated_at
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
