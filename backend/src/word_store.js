import crypto from 'node:crypto';

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
import { statusForRating, nextReviewForRating, normalizeWeekStart } from './store_utils.js';
import { seedWords } from './seed_data.js';
import { normalizeSuggestionType } from './vocabulary_validator.js';
import { normalizeSentenceText } from './workplace_sentence_validator.js';
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
  'speaking_self_rated_could_not_say',
  'speaking_drill_completed'
];

export const SPEAKING_SELF_RATINGS = ['clear', 'hesitated', 'could_not_say'];

export class WordStore {
  constructor({ seed = true, strictAttemptId = false } = {}) {
    this.strictAttemptId = strictAttemptId;
    this.words = new Map();
    this.studyEventsByClientId = new Map();
    this.userProficiencies = new Map();
    this.articlesById = new Map();
    this.vocabularyReviewItemsById = new Map();
    this.contentPacksById = new Map();
    this.articleProcessingJobsById = new Map();
    this.workplaceSentencesById = new Map();
    this.articleWorkplaceSentenceLinksById = new Map();
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
    this.userSubmittedWordsById = new Map();
    this.userSubmittedWordJobsById = new Map();
    // exam state
    this.examSessionsById = new Map();
    this.examQuestionsBySessionId = new Map();
    this.examAttemptsById = new Map();
    this.examAttemptsBySessionId = new Map();
    this.examCertificatesById = new Map();
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
    this.words.set(word.id, word);
    return { word, inserted: true };
  }

  recentWords({ targetLanguage = 'en', limit = 1000 }) {
    return [...this.words.values()]
      .filter((word) => word.language === targetLanguage)
      .sort((a, b) => b.updated_at.localeCompare(a.updated_at))
      .slice(0, Math.min(limit, 1000));
  }

  recentWorkplaceSentences({ targetLanguage = 'en', limit = 1000 }) {
    return [...this.workplaceSentencesById.values()]
      .filter((sentence) => sentence.language === targetLanguage)
      .map((sentence) => {
        const sourceLink = [...this.articleWorkplaceSentenceLinksById.values()].find((link) => {
          if (link.workplace_sentence_id !== sentence.id) {
            return false;
          }
          const article = this.articlesById.get(link.article_id);
          return article?.status === 'published' && article?.visibility === 'published';
        });
        if (!sourceLink) {
          return null;
        }
        const article = this.articlesById.get(sourceLink.article_id);
        return {
          ...sentence,
          source_article_id: article?.id ?? null,
          source_title: article?.title ?? null
        };
      })
      .filter(Boolean)
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

  createUserSubmittedWord({ deviceId, userId = null, term, language }) {
    const submittedTerm = String(term ?? '').trim();
    const normalizedTerm = normalizeTerm(submittedTerm);
    const now = new Date().toISOString();
    const ownerSubmissions = this.#submittedWordsForOwner({ deviceId, userId })
      .filter((submission) => submission.language === language && submission.normalized_term === normalizedTerm)
      .sort((left, right) => right.created_at.localeCompare(left.created_at));

    const active = ownerSubmissions.find((submission) => ['queued', 'processing'].includes(submission.status));
    if (active) {
      return { submission: this.#hydrateUserSubmittedWord(active), created: false };
    }

    const ready = ownerSubmissions.find((submission) => submission.status === 'ready' && submission.resolved_word_id);
    if (ready) {
      return { submission: this.#hydrateUserSubmittedWord(ready), created: false };
    }

    const existingWord = [...this.words.values()].find(
      (word) => word.language === language && word.normalized_term === normalizedTerm
    );
    if (existingWord) {
      const submission = {
        id: createId('submitted_word'),
        user_id: userId,
        device_id: deviceId,
        submitted_term: submittedTerm,
        normalized_term: normalizedTerm,
        language,
        status: 'ready',
        failure_reason: null,
        resolution_type: 'existing_word',
        resolved_word_id: existingWord.id,
        created_at: now,
        updated_at: now,
        resolved_at: now
      };
      this.userSubmittedWordsById.set(submission.id, submission);
      return { submission: this.#hydrateUserSubmittedWord(submission), created: false };
    }

    const submission = {
      id: createId('submitted_word'),
      user_id: userId,
      device_id: deviceId,
      submitted_term: submittedTerm,
      normalized_term: normalizedTerm,
      language,
      status: 'queued',
      failure_reason: null,
      resolution_type: null,
      resolved_word_id: null,
      created_at: now,
      updated_at: now,
      resolved_at: null
    };
    this.userSubmittedWordsById.set(submission.id, submission);

    const job = {
      id: createId('submitted_word_job'),
      submission_id: submission.id,
      status: 'queued',
      attempt_count: 0,
      queued_at: now,
      started_at: null,
      finished_at: null,
      error_message: null,
      created_at: now,
      updated_at: now
    };
    this.userSubmittedWordJobsById.set(job.id, job);

    return { submission: this.#hydrateUserSubmittedWord(submission), created: true };
  }

  listUserSubmittedWords({ deviceId, userId = null, limit = 50 }) {
    return this.#submittedWordsForOwner({ deviceId, userId })
      .sort((left, right) => right.updated_at.localeCompare(left.updated_at))
      .slice(0, Math.max(1, Math.min(limit, 100)))
      .map((submission) => this.#hydrateUserSubmittedWord(submission));
  }

  getUserSubmittedWordById({ submissionId }) {
    const submission = this.userSubmittedWordsById.get(submissionId);
    return submission ? this.#hydrateUserSubmittedWord(submission) : null;
  }

  claimNextSubmittedWordJob() {
    const job = [...this.userSubmittedWordJobsById.values()]
      .filter((item) => item.status === 'queued')
      .sort((left, right) => left.queued_at.localeCompare(right.queued_at))[0];
    if (!job) {
      return null;
    }
    const submission = this.userSubmittedWordsById.get(job.submission_id);
    const now = new Date().toISOString();
    job.status = 'processing';
    job.attempt_count += 1;
    job.started_at = now;
    job.updated_at = now;
    if (submission) {
      submission.status = 'processing';
      submission.updated_at = now;
      submission.failure_reason = null;
    }
    return job;
  }

  completeSubmittedWordJob({ jobId, resolvedWordId, resolutionType = 'generated_word' }) {
    const job = this.userSubmittedWordJobsById.get(jobId);
    if (!job) {
      return null;
    }
    const submission = this.userSubmittedWordsById.get(job.submission_id);
    const now = new Date().toISOString();
    job.status = 'completed';
    job.error_message = null;
    job.finished_at = now;
    job.updated_at = now;
    if (submission) {
      submission.status = 'ready';
      submission.failure_reason = null;
      submission.resolution_type = resolutionType;
      submission.resolved_word_id = resolvedWordId;
      submission.resolved_at = now;
      submission.updated_at = now;
    }
    return submission ? this.#hydrateUserSubmittedWord(submission) : null;
  }

  retrySubmittedWordJob({ jobId, errorMessage = null }) {
    const job = this.userSubmittedWordJobsById.get(jobId);
    if (!job) {
      return null;
    }
    const submission = this.userSubmittedWordsById.get(job.submission_id);
    const now = new Date().toISOString();
    job.status = 'queued';
    job.error_message = errorMessage;
    job.finished_at = null;
    job.updated_at = now;
    if (submission) {
      submission.status = 'queued';
      submission.failure_reason = null;
      submission.updated_at = now;
    }
    return submission ? this.#hydrateUserSubmittedWord(submission) : null;
  }

  failSubmittedWordJob({ jobId, errorMessage }) {
    const job = this.userSubmittedWordJobsById.get(jobId);
    if (!job) {
      return null;
    }
    const submission = this.userSubmittedWordsById.get(job.submission_id);
    const now = new Date().toISOString();
    job.status = 'failed';
    job.error_message = errorMessage;
    job.finished_at = now;
    job.updated_at = now;
    if (submission) {
      submission.status = 'failed';
      submission.failure_reason = errorMessage;
      submission.updated_at = now;
    }
    return submission ? this.#hydrateUserSubmittedWord(submission) : null;
  }

  wordStateFor({ deviceId, userId = null, wordId }) {
    return this.wordStatesByOwnerWord.get(this.#wordStateKey({ deviceId, userId, wordId })) ?? null;
  }

  learningCards({ deviceId, userId = null, targetLanguage = 'en', limit = 10, now = new Date().toISOString() }) {
    const cappedLimit = Math.max(1, Math.min(limit, 100));
    const ownerKeys = this.#selectionOwnerKeys({ deviceId, userId });
    const cachedWordIds = this.#cachedWordIdsForOwnerKeys(ownerKeys);

    // Collect all states for this owner+language
    const allStates = [...this.wordStatesByOwnerWord.entries()]
      .filter(([key, state]) => ownerKeys.has(this.#ownerKeyFromState(state)) && key.includes(':word:'))
      .filter(([, state]) => state.language === targetLanguage);

    const stateWordIds = new Set(allStates.map(([, state]) => state.word_id));

    // Due review items: next_review_at is set and <= now
    const targetReview = Math.floor(cappedLimit * 0.85);
    const dueStates = allStates
      .filter(([, state]) => state.next_review_at && state.next_review_at <= now)
      .sort(([, a], [, b]) => a.next_review_at.localeCompare(b.next_review_at));

    const reviewCards = dueStates
      .slice(0, targetReview)
      .map(([, state]) => {
        const word = this.words.get(state.word_id);
        return word ? { word, cardType: 'review', selectionReason: 'srs_due' } : null;
      })
      .filter(Boolean);

    const newCount = cappedLimit - reviewCards.length;
    const newCandidates = [...this.words.values()]
      .filter((word) => word.language === targetLanguage)
      .filter((word) => !cachedWordIds.has(word.id))
      .filter((word) => !stateWordIds.has(word.id))
      .sort((left, right) => bCompareCreated(left, right));

    const newCards = newCandidates
      .slice(0, newCount)
      .map((word) => ({ word, cardType: 'new', selectionReason: 'new_available' }));

    const cards = [...reviewCards, ...newCards];
    this.addCachedWordIds({
      deviceId,
      userId,
      wordIds: newCards.map((card) => card.word.id),
      observedAt: now
    });

    return {
      items: cards,
      target_mix: { new: cappedLimit - targetReview, review: targetReview },
      actual_mix: { new: newCards.length, review: reviewCards.length }
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

    this.logger?.info?.('sync_study_events_completed', {
      device_id: deviceId,
      accepted_count: accepted.length,
      duplicate_count: duplicates.length,
      rejected_count: rejected.length
    });

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
    const normalized = normalizeSpeakingEvent({ deviceId, event, language, userId, strict: this.strictAttemptId });
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
    const allEvents = [...this.speakingEventsByKey.values()]
      .filter((event) => event.language === language)
      .filter((event) => (userId ? event.user_id === userId : event.device_id === deviceId && !event.user_id));
    const weekEvents = allEvents.filter((event) => event.occurred_at >= start);
    const firstRecordingEvent =
      allEvents
        .filter((e) => e.event_type === 'speaking_recorded')
        .sort((a, b) => String(a.occurred_at).localeCompare(String(b.occurred_at)))[0] ?? null;
    return buildSpeakingSummary({
      deviceId,
      userId,
      language,
      weekStart: start,
      events: weekEvents,
      firstRecordingAt: firstRecordingEvent?.occurred_at ?? null
    });
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
    if (!user) {
      throw new InvalidCredentialsError({ reason: 'user_not_found' });
    }
    if (!verifyPassword(password, user.password_hash)) {
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
    const nextLevel =
      rating === 'too_easy' ? incrementLevel(previousLevel, { language }) : decrementLevel(previousLevel, { language });

    proficiency.level = nextLevel;
    proficiency.updated_at = new Date().toISOString();
    return {
      levelChanged: nextLevel !== previousLevel,
      previousLevel,
      triggeredBy: `${consecutiveCount}x consecutive ${rating}`
    };
  }

  #buildProficiencyResponse({
    deviceId,
    userId = null,
    language = 'en',
    levelChanged = false,
    previousLevel = null,
    triggeredBy = null
  } = {}) {
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

    // Delete existing vocabulary for this article to prevent duplicates on reprocess
    const articleTermEntries = [...this.articleTermsById.entries()].filter(([, at]) => at.article_id === articleId);
    const senseIds = new Set(articleTermEntries.map(([, at]) => at.word_sense_id));
    for (const [id] of articleTermEntries) {
      this.articleTermsById.delete(id);
    }
    for (const [id] of this.wordSensesById) {
      if (senseIds.has(id)) {
        this.wordSensesById.delete(id);
      }
    }
    for (const [id, item] of this.vocabularyReviewItemsById) {
      if (item.article_id === articleId) {
        this.vocabularyReviewItemsById.delete(id);
      }
    }
    for (const [id, link] of this.articleWorkplaceSentenceLinksById) {
      if (link.article_id === articleId) {
        this.articleWorkplaceSentenceLinksById.delete(id);
      }
    }
    this.#pruneOrphanWorkplaceSentences();

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
        return [
          {
            term_id: term.id,
            display_term: term.display_term,
            word_sense_id: sense.id,
            meaning_vi: sense.meaning_vi,
            part_of_speech: sense.part_of_speech,
            ipa: sense.ipa,
            level: sense.level,
            status: sense.status,
            classification: articleTerm.classification ?? null,
            suggestion_type: articleTerm.suggestion_type ?? null,
            speaking_prompt: speakingPrompt ? toApiSpeakingPrompt(speakingPrompt) : null
          }
        ];
      });

    return {
      article_id: article.id,
      items
    };
  }

  #approvedSpeakingPromptForSense(wordSenseId) {
    return (
      [...this.speakingPromptsById.values()]
        .filter((prompt) => prompt.word_sense_id === wordSenseId && prompt.status === 'approved')
        .sort((left, right) => right.updated_at.localeCompare(left.updated_at))[0] ?? null
    );
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

    // Sync the linked word sense status so getArticleVocabulary visibility filter works.
    const sense = this.wordSensesById.get(item.word_sense_id);
    if (sense) {
      sense.status = status === 'approved' ? 'approved' : 'rejected';
      sense.updated_at = item.updated_at;
    }

    return item;
  }

  listSpeakingPrompts({ status = null, missingRequired = false, limit = 100 } = {}) {
    return [...this.speakingPromptsById.values()]
      .filter((prompt) => (status ? prompt.status === status : true))
      .filter((prompt) => (missingRequired ? isPromptMissingRequiredFields(prompt) : true))
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

  countPendingArticleJobs() {
    return [...this.articleProcessingJobsById.values()].filter((item) => item.status === 'pending_processing').length;
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
    const seen = new Set();
    for (const item of items) {
      const normalized = normalizeTerm(item.term);
      const dedupeKey = `${item.language}:${normalized}`;
      if (seen.has(dedupeKey)) {
        continue;
      }
      seen.add(dedupeKey);
      // Stubs (fallback suggestions) are never auto-approved even for user articles
      const requiresReview = Boolean(article.created_by_admin_id) || Boolean(item.isStub);
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
        level: item.level ?? item.difficulty ?? 'A1',
        quality_score: Number(item.quality_score ?? item.confidence ?? 0.5),
        status: requiresReview ? 'pending_review' : 'approved',
        created_at: now,
        updated_at: now
      };
      this.wordSensesById.set(sense.id, sense);

      // Bridge approved sense into the words pool so learningCards can serve it
      if (!requiresReview) {
        this.insertWord({
          term: item.term,
          language: item.language,
          meaning_vi: item.meaning_vi ?? '',
          part_of_speech: item.part_of_speech ?? null,
          ipa: item.ipa ?? '',
          vietnamese_pronunciation: item.vietnamese_pronunciation ?? '',
          example: item.example ?? '',
          example_vi: '',
          difficulty: item.level ?? item.difficulty ?? 'A1',
          topics: [],
          generation_source: 'article_vocabulary'
        });
      }

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
        classification: item.classification ?? null,
        suggestion_type: normalizeSuggestionType(item.suggestion_type, item.term),
        created_at: now
      };
      this.articleTermsById.set(articleTerm.id, articleTerm);

      const reviewItem = {
        id: createId('review_item'),
        word_sense_id: sense.id,
        article_id: articleId,
        status: requiresReview ? 'pending' : 'approved',
        reviewer_user_id: null,
        review_note: null,
        reviewed_at: requiresReview ? null : now,
        created_at: now,
        updated_at: now
      };
      this.vocabularyReviewItemsById.set(reviewItem.id, reviewItem);
      persisted.push({ term, sense, articleTerm, reviewItem });
    }
    return { count: persisted.length, items: persisted };
  }

  persistArticleWorkplaceSentences({ articleId, items = [] }) {
    const article = this.articlesById.get(articleId);
    if (!article) {
      throw new Error('article_not_found');
    }

    for (const [id, link] of this.articleWorkplaceSentenceLinksById) {
      if (link.article_id === articleId) {
        this.articleWorkplaceSentenceLinksById.delete(id);
      }
    }
    this.#pruneOrphanWorkplaceSentences();

    const now = new Date().toISOString();
    const persisted = [];
    const seen = new Set();
    for (const item of items) {
      const normalizedText = normalizeSentenceText(item.text);
      const dedupeKey = `${item.language}:${normalizedText}`;
      if (!normalizedText || seen.has(dedupeKey)) {
        continue;
      }
      seen.add(dedupeKey);

      let sentence = [...this.workplaceSentencesById.values()].find(
        (sentence) => sentence.language === item.language && sentence.normalized_text === normalizedText
      );
      if (!sentence) {
        sentence = {
          id: createId('sentence'),
          text: item.text,
          normalized_text: normalizedText,
          language: item.language,
          meaning_vi: item.meaning_vi,
          topic: item.topic ?? null,
          generation_source: item.generation_source ?? 'article_workplace_sentence',
          created_at: now,
          updated_at: now
        };
        this.workplaceSentencesById.set(sentence.id, sentence);
      }

      const link = {
        id: createId('article_sentence'),
        article_id: articleId,
        workplace_sentence_id: sentence.id,
        created_at: now
      };
      this.articleWorkplaceSentenceLinksById.set(link.id, link);
      persisted.push({
        ...sentence,
        source_article_id: article.id,
        source_title: article.title ?? null
      });
    }

    return { count: persisted.length, items: persisted };
  }

  #pruneOrphanWorkplaceSentences() {
    const linkedSentenceIds = new Set(
      [...this.articleWorkplaceSentenceLinksById.values()].map((link) => link.workplace_sentence_id)
    );
    for (const [id] of this.workplaceSentencesById) {
      if (!linkedSentenceIds.has(id)) {
        this.workplaceSentencesById.delete(id);
      }
    }
  }

  // ─── Exam methods ────────────────────────────────────────────────────────

  /**
   * Returns distinct, normalized topics for which the user has studied at
   * least one word in the given language, sorted alphabetically.
   */
  examTopics({ userId, language = 'en' }) {
    const topicsSet = new Set();
    for (const state of this.wordStatesByOwnerWord.values()) {
      if (state.user_id !== userId || state.language !== language) {
        continue;
      }
      const word = this.words.get(state.word_id);
      if (!word) {
        continue;
      }
      for (const t of word.topics ?? []) {
        const norm = String(t).trim().toLowerCase();
        if (norm) {
          topicsSet.add(norm);
        }
      }
    }
    return [...topicsSet].sort();
  }

  /**
   * Generates a new exam session with MCQ questions.
   * Returns { error: 'INSUFFICIENT_WORDS', found } when fewer than 5 source
   * words exist for the requested language, otherwise returns the full session
   * payload.
   */
  startExamSession({ userId, language = 'en', now = new Date().toISOString(), sessionTtlMs = 7200000 }) {
    // Collect studied words for the active language.
    const sourceWords = [];
    const seenWordIds = new Set();
    for (const state of this.wordStatesByOwnerWord.values()) {
      if (state.user_id !== userId || state.language !== language) {
        continue;
      }
      if (seenWordIds.has(state.word_id)) {
        continue;
      }
      const word = this.words.get(state.word_id);
      if (!word) {
        continue;
      }
      sourceWords.push(word);
      seenWordIds.add(word.id);
    }

    if (sourceWords.length < 5) {
      return { error: 'INSUFFICIENT_WORDS', found: sourceWords.length };
    }

    // Cap at 20 questions (shuffle before slicing for variety)
    const shuffled = shuffleArray([...sourceWords]);
    const selected = shuffled.slice(0, 20);

    // Build distractor pool: same language, not a source word in this session
    const sourceIds = new Set(selected.map((w) => w.id));
    const allSameLang = [...this.words.values()].filter((w) => w.language === language && !sourceIds.has(w.id));

    const sessionId = createId('exam_sess');
    const expiresAt = new Date(new Date(now).getTime() + sessionTtlMs).toISOString();
    const session = {
      id: sessionId,
      user_id: userId,
      topic: 'language',
      language,
      difficulty_level: null,
      created_at: now,
      expires_at: expiresAt,
      submitted_at: null
    };
    this.examSessionsById.set(sessionId, session);

    const questions = [];
    for (let i = 0; i < selected.length; i++) {
      const src = selected[i];
      const distractors = selectDistractors({ source: src, pool: allSameLang, count: 3 });
      // Build choices: correct answer + distractors, then shuffle
      const correctMeaning = src.meaning_vi ?? src.term;
      const choicesRaw = [correctMeaning, ...distractors.map((d) => d.meaning_vi ?? d.term)];
      const { choices, correctIndex } = shuffleChoices(choicesRaw);

      // Assign question_type: 50/50 sentence_context if example is non-empty
      const hasExample = src.example && src.example.trim() !== '';
      const questionType = hasExample && Math.random() < 0.5 ? 'sentence_context' : 'meaning_choice';

      const question = {
        id: createId('exam_q'),
        session_id: sessionId,
        word_id: src.id,
        prompt_word: src.term,
        choices_json: JSON.stringify(choices),
        correct_index: correctIndex,
        ordinal: i,
        created_at: now,
        question_type: questionType,
        sentence: questionType === 'sentence_context' ? src.example : null,
        highlight: questionType === 'sentence_context' ? src.term : null
      };
      questions.push(question);
    }
    this.examQuestionsBySessionId.set(sessionId, questions);

    return {
      session_id: sessionId,
      topic: 'language',
      language,
      question_count: questions.length,
      expires_at: expiresAt,
      questions: questions.map((q) => {
        const item = {
          question_id: q.id,
          ordinal: q.ordinal,
          prompt_word: q.prompt_word,
          choices: JSON.parse(q.choices_json),
          question_type: q.question_type
        };
        if (q.question_type === 'sentence_context') {
          item.sentence = q.sentence;
          item.highlight = q.highlight;
        }
        return item;
      })
    };
  }

  /**
   * Submits answers for an exam session.
   * Returns error objects for known failure modes, or the full result payload.
   *
   * When [localAttemptId] is provided and the session has already been
   * submitted with the same id, the call is treated as an idempotent retry
   * and the existing attempt data is returned instead of ALREADY_SUBMITTED.
   */
  submitExamSession({
    sessionId,
    userId,
    answers,
    localAttemptId = null,
    now = new Date().toISOString(),
    passPct = 70,
    disclaimer = ''
  }) {
    const session = this.examSessionsById.get(sessionId);
    if (!session) {
      return { error: 'NOT_FOUND' };
    }
    if (session.submitted_at) {
      // Idempotent retry: if the caller provided the same local_attempt_id
      // that was recorded on first submission, return the existing result.
      if (localAttemptId !== null && session.local_attempt_id === localAttemptId) {
        const existing = this.examAttemptsBySessionId.get(sessionId);
        if (existing) {
          const certId = existing.certificate_id ?? null;
          return {
            attempt_id: existing.id,
            session_id: sessionId,
            topic: existing.topic,
            language: existing.language,
            difficulty_level: existing.difficulty_level,
            total_questions: existing.total_questions,
            correct_count: existing.correct_count,
            score_pct: existing.score_pct,
            passed: existing.passed === 1,
            certificate_id: certId,
            created_at: existing.created_at
          };
        }
      }
      return { error: 'ALREADY_SUBMITTED' };
    }
    if (now > session.expires_at) {
      return { error: 'SESSION_EXPIRED' };
    }
    const questions = this.examQuestionsBySessionId.get(sessionId) ?? [];
    if (answers.length !== questions.length) {
      return { error: 'ANSWER_COUNT_MISMATCH', expected: questions.length, received: answers.length };
    }

    // Score
    let correctCount = 0;
    for (let i = 0; i < questions.length; i++) {
      if (Number(answers[i]) === questions[i].correct_index) {
        correctCount += 1;
      }
    }
    const totalQuestions = questions.length;
    const scorePct = totalQuestions > 0 ? (correctCount / totalQuestions) * 100 : 0;
    const passed = scorePct >= passPct;

    // Mark submitted
    session.submitted_at = now;
    if (localAttemptId !== null) {
      session.local_attempt_id = localAttemptId;
    }

    const attemptId = createId('exam_att');
    const attempt = {
      id: attemptId,
      session_id: sessionId,
      user_id: userId,
      topic: session.topic,
      language: session.language,
      difficulty_level: session.difficulty_level,
      total_questions: totalQuestions,
      correct_count: correctCount,
      score_pct: scorePct,
      passed: passed ? 1 : 0,
      created_at: now
    };
    this.examAttemptsById.set(attemptId, attempt);
    this.examAttemptsBySessionId.set(sessionId, attempt);

    let certificateId = null;
    if (passed) {
      certificateId = crypto.randomUUID();
      const cert = {
        id: certificateId,
        attempt_id: attemptId,
        user_id: userId,
        topic: session.topic,
        language: session.language,
        difficulty_level: session.difficulty_level,
        score_pct: scorePct,
        issued_at: now,
        disclaimer
      };
      this.examCertificatesById.set(certificateId, cert);
    }

    return {
      attempt_id: attemptId,
      session_id: sessionId,
      topic: session.topic,
      language: session.language,
      difficulty_level: session.difficulty_level,
      total_questions: totalQuestions,
      correct_count: correctCount,
      score_pct: scorePct,
      passed,
      certificate_id: certificateId,
      created_at: now
    };
  }

  /**
   * Returns paginated exam attempt history for a user, newest first.
   */
  getExamResults({ userId, page = 1, limit = 20 }) {
    const all = [...this.examAttemptsById.values()]
      .filter((a) => a.user_id === userId)
      .sort((a, b) => b.created_at.localeCompare(a.created_at));

    const total = all.length;
    const offset = (page - 1) * limit;
    const items = all.slice(offset, offset + limit).map((a) => {
      const cert = [...this.examCertificatesById.values()].find((c) => c.attempt_id === a.id);
      return {
        attempt_id: a.id,
        topic: a.topic,
        language: a.language,
        difficulty_level: a.difficulty_level,
        score_pct: a.score_pct,
        passed: a.passed === 1,
        created_at: a.created_at,
        certificate_id: cert?.id ?? null
      };
    });

    return { items, total, page, limit };
  }

  /**
   * Returns a certificate by ID without user PII.
   * This is the public-facing endpoint response.
   */
  getExamCertificate({ id }) {
    const cert = this.examCertificatesById.get(id);
    if (!cert) {
      return null;
    }
    return {
      certificate_id: cert.id,
      topic: cert.topic,
      language: cert.language,
      difficulty_level: cert.difficulty_level,
      score_pct: cert.score_pct,
      issued_at: cert.issued_at,
      disclaimer: cert.disclaimer
    };
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

  #submittedWordsForOwner({ deviceId, userId = null }) {
    const ownerKey = this.#ownerKey({ deviceId, userId });
    return [...this.userSubmittedWordsById.values()].filter(
      (submission) => this.#ownerKey({ deviceId: submission.device_id, userId: submission.user_id }) === ownerKey
    );
  }

  #hydrateUserSubmittedWord(submission) {
    return {
      ...submission,
      resolved_word: submission.resolved_word_id ? this.words.get(submission.resolved_word_id) ?? null : null
    };
  }

  #wordStateKey({ deviceId, userId = null, wordId }) {
    return `${this.#ownerKey({ deviceId, userId })}:word:${wordId}`;
  }
}

function bCompareCreated(left, right) {
  return right.created_at.localeCompare(left.created_at);
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

export function normalizeSpeakingEvent({ deviceId, event, language = 'en', userId = null, strict = false }) {
  if (!isSpeakingEvent(event)) {
    throw new Error('invalid_speaking_event_type');
  }
  if (containsForbiddenAudioField(event)) {
    throw new Error('forbidden_audio_field');
  }
  const speaking = event.speaking ?? {};
  const attemptId = normalizeOptionalText(speaking.attempt_id ?? event.attempt_id) ?? null;
  if ((strict && !attemptId) || !event.occurred_at) {
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

  // drill_completed-specific fields
  let promptsAttempted = null;
  let promptsCompleted = null;
  let totalDurationMs = null;
  if (event.event_type === 'speaking_drill_completed') {
    promptsAttempted = normalizeOptionalInteger(speaking.prompts_attempted ?? event.prompts_attempted);
    promptsCompleted = normalizeOptionalInteger(speaking.prompts_completed ?? event.prompts_completed);
    totalDurationMs = normalizeOptionalInteger(speaking.total_duration_ms ?? event.total_duration_ms);
    if (promptsAttempted === null || totalDurationMs === null) {
      throw new Error('missing_required_field');
    }
    if (promptsAttempted < 0 || totalDurationMs < 0) {
      throw new Error('invalid_speaking_event');
    }
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
    prompts_attempted: promptsAttempted,
    prompts_completed: promptsCompleted,
    total_duration_ms: totalDurationMs,
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
    word_sense_id: prompt.word_sense_id ?? null,
    target_text: prompt.target_text,
    vi_hint: prompt.vi_hint,
    target_phrase: prompt.target_phrase,
    pronunciation_tip_vi: prompt.pronunciation_tip_vi,
    common_mistake_vi: prompt.common_mistake_vi,
    difficulty: prompt.difficulty,
    topic: prompt.topic
  };
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

function buildSpeakingSummary({ deviceId, userId = null, language, weekStart, events, firstRecordingAt = null }) {
  const selfRatingCounts = { clear: 0, hesitated: 0, could_not_say: 0 };
  let spokenSentenceCount = 0;
  let retryCount = 0;
  let approximateDurationMs = 0;
  let latestActivityAt = null;
  let drillSessionsCompleted = 0;
  for (const event of events) {
    if (event.event_type === 'speaking_recorded') {
      spokenSentenceCount += 1;
      approximateDurationMs += Number(event.duration_ms ?? 0);
    }
    if (event.event_type === 'speaking_retried') {
      retryCount += 1;
    }
    if (event.event_type === 'speaking_drill_completed') {
      drillSessionsCompleted += 1;
    }
    if (event.self_rating && selfRatingCounts[event.self_rating] !== undefined) {
      selfRatingCounts[event.self_rating] += 1;
    }
    if (!latestActivityAt || event.occurred_at > latestActivityAt) {
      latestActivityAt = event.occurred_at;
    }
  }
  const retryRate = spokenSentenceCount > 0 ? retryCount / spokenSentenceCount : 0;
  return {
    device_id: deviceId,
    user_id: userId,
    language,
    week_start: weekStart.slice(0, 10),
    spoken_sentence_count: spokenSentenceCount,
    recording_count: spokenSentenceCount,
    retry_count: retryCount,
    retry_rate: retryRate,
    drill_sessions_completed: drillSessionsCompleted,
    approximate_duration_ms: approximateDurationMs,
    self_rating_counts: selfRatingCounts,
    first_recording_at: firstRecordingAt ?? null,
    latest_activity_at: latestActivityAt
  };
}

function containsForbiddenAudioField(value) {
  if (!value || typeof value !== 'object') {
    return false;
  }
  for (const [key, nested] of Object.entries(value)) {
    const normalized = key.toLowerCase();
    if (
      [
        'audio',
        'audio_bytes',
        'audio_base64',
        'audio_blob',
        'local_audio_path',
        'local_file_path',
        'file_path'
      ].includes(normalized)
    ) {
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

// ─── Exam helpers ───────────────────────────────────────────────────────────

const DIFFICULTY_ORDER = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6', 'HSK7'];

export function selectDistractors({ source, pool, count = 3 }) {
  const srcIdx = DIFFICULTY_ORDER.indexOf(source.difficulty ?? '');
  // Try same difficulty ±1 first
  const nearPool =
    srcIdx >= 0
      ? pool.filter((w) => {
          const idx = DIFFICULTY_ORDER.indexOf(w.difficulty ?? '');
          return idx >= 0 && Math.abs(idx - srcIdx) <= 1;
        })
      : [];
  const candidates = nearPool.length >= count ? nearPool : pool;
  // Shuffle and take `count`
  const shuffled = shuffleArray([...candidates]);
  return shuffled.slice(0, count);
}

export function shuffleArray(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function shuffleChoices(choices) {
  const indexed = choices.map((c, i) => ({ c, i }));
  const shuffled = shuffleArray(indexed);
  const correctIndex = shuffled.findIndex((item) => item.i === 0); // original index 0 = correct
  return { choices: shuffled.map((item) => item.c), correctIndex };
}
