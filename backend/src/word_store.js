import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';
import { getDefaultProficiencyLevel, requireStudyRating } from './proficiency.js';
import { seedWords } from './seed_data.js';
import { normalizeSuggestionType } from './vocabulary_validator.js';
import { normalizeSentenceText } from './workplace_sentence_validator.js';
import { isGameSource, normalizeEventSource } from './game_rounds.js';
import {
  DuplicateUserError,
  InvalidCredentialsError,
  createPasswordHashSync,
  createSessionToken,
  hashSessionToken,
  normalizeUserIdentifier,
  requireRegistrationInput,
  verifyPasswordSync
} from './user_identity.js';
import {
  ADMIN_ARTICLE_PATCH_FIELDS,
  buildArticle,
  isArticleReadableBy,
  staleArticleJobCutoff
} from './domain/articles.js';
import { composeLearningCards, newCardWordIds } from './domain/learning_cards.js';
import { replaySrsState } from './domain/srs.js';
import { isAfterReviewCursor } from './domain/review_states.js';
import { clampLimit } from './domain/pagination.js';
import { planLevelChange, toProficiencyResponse } from './domain/proficiency_progress.js';
import { toApiSpeakingPrompt } from './domain/speaking.js';
import { resolveEventKey, routeStudyEventsSync, toSyncResponse } from './domain/study_events.js';
import { buildSubmittedWord, normalizeSubmittedTerm, submittedWordFailureReason } from './domain/submitted_words.js';
import {
  bridgedWordInput,
  buildWordRecord,
  pickTermSample,
  releasableItems,
  senseFieldsFromItem,
  tallyWordLevels,
  toApiWord
} from './domain/vocabulary.js';
import { MAX_CACHED_WORD_IDS, distinctWordIds } from './domain/word_cache.js';
import { mixinMethods } from './stores/mixin.js';
import { MemoryExamMethods } from './stores/memory/exam.js';
import { MemoryGameMethods } from './stores/memory/games.js';
import { MemoryMemorizationMethods, deletePassageVocabularyLinks } from './stores/memory/memorization.js';
import { MemoryShadowingMethods } from './stores/memory/shadowing.js';
import { MemorySpeakingMethods } from './stores/memory/speaking.js';
import { MemoryUserAdminMethods } from './stores/memory/user_admin.js';

/**
 * In-memory store used by tests and local development. Implements the same
 * interface as PostgresWordStore; shared business rules live in `domain/`.
 */
export class WordStore {
  constructor({ seed = true, strictAttemptId = false } = {}) {
    this.strictAttemptId = strictAttemptId;
    this.words = new Map();
    this.studyEventsByClientId = new Map();
    this.userProficiencies = new Map();
    this.articlesById = new Map();
    this.contentPacksById = new Map();
    this.articleProcessingJobsById = new Map();
    this.workplaceSentencesById = new Map();
    this.articleWorkplaceSentenceLinksById = new Map();
    this.termsById = new Map();
    this.wordSensesById = new Map();
    this.articleTermsById = new Map();
    this.speakingPromptsById = new Map();
    this.speakingEventsByKey = new Map();
    this.gameRoundsByClientId = new Map();
    this.usersById = new Map();
    this.usersByIdentifier = new Map();
    this.userSessionsByTokenHash = new Map();
    this.generationRuns = [];
    this.crawledUrls = new Map();
    this.generationLocks = new Map();
    this.cachedWordIdsByOwner = new Map();
    this.wordStatesByOwnerWord = new Map();
    this.userSubmittedWordsById = new Map();
    this.userSubmittedWordJobsById = new Map();
    this.shadowingVideosById = new Map();
    this.shadowingVideoIdByProviderKey = new Map();
    this.shadowingVideoSegmentsByVideoId = new Map();
    this.shadowingVideoEntriesById = new Map();
    // exam state
    this.examSessionsById = new Map();
    this.examQuestionsBySessionId = new Map();
    this.examAttemptsById = new Map();
    this.examAttemptsBySessionId = new Map();
    this.examCertificatesById = new Map();
    // memorization state
    this.memorizationPassagesById = new Map();
    this.memorizationSegmentsById = new Map();
    this.memorizationSegmentProgressById = new Map();
    this.memorizationSegmentTermsById = new Map();
    if (seed) {
      seedWords().forEach((word) => this.insertWord(word));
    }
  }

  insertWord(input) {
    const existing = this.#findWord(input.language, normalizeTerm(input.term));
    if (existing) {
      return { word: existing, inserted: false };
    }
    const word = buildWordRecord(input);
    this.words.set(word.id, word);
    return { word, inserted: true };
  }

  #findWord(language, normalizedTerm) {
    return [...this.words.values()].find((word) => word.language === language && word.normalized_term === normalizedTerm);
  }

  recentWords({ targetLanguage = 'en', limit = 1000 }) {
    return this.#wordsInLanguage(targetLanguage)
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
    return this.#wordsInLanguage(targetLanguage).length;
  }

  hasCrawledUrl({ url }) {
    return this.crawledUrls.has(url);
  }

  recordCrawledUrl({ url, feedUrl = null, status, reason = null, level = null, quality = null, articleId = null }) {
    this.crawledUrls.set(url, {
      url,
      feed_url: feedUrl,
      status,
      reason,
      cefr_level: level,
      quality,
      article_id: articleId,
      created_at: new Date().toISOString()
    });
  }

  /** Progress of the curated collection: articles queued so far and when the latest was queued. */
  curatedStats() {
    const queued = [...this.crawledUrls.values()].filter(
      (row) => row.status === 'queued' && String(row.feed_url ?? '').startsWith('curated:')
    );
    const lastQueuedAt = queued.map((row) => row.created_at).sort().at(-1) ?? null;
    return { queued: queued.length, lastQueuedAt };
  }

  countWordsByLevel({ targetLanguage = 'en' } = {}) {
    return tallyWordLevels(this.#wordsInLanguage(targetLanguage), targetLanguage);
  }

  sampleWordTerms({ targetLanguage = 'en', level = null, limit = 150 } = {}) {
    return pickTermSample(this.#wordsInLanguage(targetLanguage), { targetLanguage, level, limit });
  }

  #wordsInLanguage(language) {
    return [...this.words.values()].filter((word) => word.language === language);
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
    const ids = distinctWordIds(wordIds);
    const known = ids.filter((wordId) => this.words.has(wordId)).slice(0, MAX_CACHED_WORD_IDS);
    this.cachedWordIdsByOwner.set(this.#ownerKey({ deviceId, userId }), {
      wordIds: new Set(known),
      observed_at: observedAt
    });
    return {
      stored_count: known.length,
      unknown_server_word_ids: ids.filter((wordId) => !this.words.has(wordId))
    };
  }

  addCachedWordIds({ deviceId, userId = null, wordIds = [], observedAt = new Date().toISOString() }) {
    const key = this.#ownerKey({ deviceId, userId });
    const existing = this.cachedWordIdsByOwner.get(key) ?? {
      wordIds: new Set(),
      observed_at: observedAt
    };
    const ids = distinctWordIds(wordIds);
    let storedCount = 0;
    for (const wordId of ids.filter((id) => this.words.has(id))) {
      if (existing.wordIds.size < MAX_CACHED_WORD_IDS || existing.wordIds.has(wordId)) {
        existing.wordIds.add(wordId);
        storedCount += 1;
      }
    }
    const unknown = ids.filter((wordId) => !this.words.has(wordId));

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

  async createUserSubmittedWord({ deviceId, userId = null, term, language, generationService = null }) {
    const { submittedTerm, normalizedTerm } = normalizeSubmittedTerm(term);
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

    const save = (fields) => {
      const submission = buildSubmittedWord({ deviceId, userId, submittedTerm, normalizedTerm, language, now, ...fields });
      this.userSubmittedWordsById.set(submission.id, submission);
      return submission;
    };
    const respond = (submission, created) => ({ submission: this.#hydrateUserSubmittedWord(submission), created });

    const existingWord = this.#findWord(language, normalizedTerm);
    if (existingWord) {
      return respond(save({ status: 'ready', resolutionType: 'existing_word', resolvedWordId: existingWord.id }), false);
    }

    if (generationService?.generateSubmittedWord) {
      try {
        const generated = await generationService.generateSubmittedWord({
          targetLanguage: language,
          term: submittedTerm
        });
        const resolutionType = generated.resolutionType ?? 'generated_word';
        return respond(save({ status: 'ready', resolutionType, resolvedWordId: generated.word.id }), true);
      } catch (error) {
        return respond(save({ status: 'failed', failureReason: submittedWordFailureReason(error) }), true);
      }
    }

    const submission = save({ status: 'queued' });
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
    return respond(submission, true);
  }

  listUserSubmittedWords({ deviceId, userId = null, limit = 50 }) {
    return this.#submittedWordsForOwner({ deviceId, userId })
      .sort((left, right) => right.updated_at.localeCompare(left.updated_at))
      .slice(0, clampLimit(limit, 100))
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

  /** The owner's states for `language` changed after `cursor`, oldest first, each with its word. */
  listWordStatesSince({ deviceId, userId = null, language, cursor = null, limit }) {
    const ownerKey = this.#ownerKey({ deviceId, userId });
    return [...this.wordStatesByOwnerWord.values()]
      .filter(
        (state) =>
          this.#ownerKeyFromState(state) === ownerKey &&
          state.language === language &&
          isAfterReviewCursor(state, cursor)
      )
      .sort((left, right) => left.updated_at.localeCompare(right.updated_at) || left.id.localeCompare(right.id))
      .slice(0, limit)
      .map((state) => ({ state, word: this.words.get(state.word_id) ?? null }));
  }

  learningCards({
    deviceId,
    userId = null,
    targetLanguage = 'en',
    limit = 10,
    level: levelOverride = null,
    now = new Date().toISOString()
  }) {
    const ownerKeys = this.#selectionOwnerKeys({ deviceId, userId });
    const states = [...this.wordStatesByOwnerWord.values()].filter(
      (state) => ownerKeys.has(this.#ownerKeyFromState(state)) && state.language === targetLanguage
    );
    const batch = composeLearningCards({
      wordById: this.words,
      candidateWords: this.#wordsInLanguage(targetLanguage),
      states,
      cachedWordIds: this.#cachedWordIdsForOwnerKeys(ownerKeys),
      level: levelOverride ?? this.getProficiency({ deviceId, userId, language: targetLanguage }).level,
      language: targetLanguage,
      limit,
      now
    });
    this.addCachedWordIds({ deviceId, userId, wordIds: newCardWordIds(batch), observedAt: now });
    return batch;
  }

  syncStudyEvents({ deviceId, events, language = 'en', userId = null }) {
    return toSyncResponse(
      routeStudyEventsSync({
        events,
        initialProficiency: this.getProficiency({ deviceId, userId, language }),
        recordSpeakingEvent: (event) => this.recordSpeakingEvent({ deviceId, userId, event, language }),
        recordStudyEvent: (event) => this.recordStudyEvent({ deviceId, userId, event, language })
      })
    );
  }

  getContentPipelineHealth() {
    const articleJobs = [...this.articleProcessingJobsById.values()];
    const passages = [...this.memorizationPassagesById.values()];
    const videos = [...this.shadowingVideosById.values()];

    const articles = buildPipelineHealthSection({
      pendingCount: articleJobs.filter((job) => job.status === 'pending_processing').length,
      failedCount: articleJobs.filter((job) => job.status === 'failed').length,
      processedAtValues: articleJobs.map((job) => job.finished_at ?? job.updated_at)
    });
    const memorization = buildPipelineHealthSection({
      pendingCount: passages.filter((passage) => passage.status === 'pending_segmentation' || passage.status === 'segmenting').length,
      failedCount: passages.filter((passage) => passage.status === 'failed' || passage.enrichment_status === 'failed').length,
      processedAtValues: passages.map((passage) => passage.updated_at)
    });
    const shadowing = buildPipelineHealthSection({
      pendingCount: 0,
      failedCount: 0,
      processedAtValues: videos.map((video) => video.updated_at)
    });

    return { articles, memorization, shadowing };
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
      received_at: receivedAt,
      source: normalizeEventSource(event.source)
    };
    this.studyEventsByClientId.set(eventKey, storedEvent);
    this.#upsertWordState({ deviceId, userId: storedEvent.user_id, language, event: storedEvent });

    // Practice games review words but never move the CEFR/HSK ladder.
    const levelChange = isGameSource(storedEvent.source)
      ? null
      : this.#applyProficiencyChange({
          deviceId,
          userId: storedEvent.user_id,
          language,
          rating,
          occurredAt: storedEvent.occurred_at
        });

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
      password_hash: createPasswordHashSync(input.password),
      created_at: now,
      updated_at: now
    };
    this.usersById.set(user.id, user);
    this.usersByIdentifier.set(user.identifier, user);
    // Claim device-only word states and cached words for the new user
    this.#claimDeviceWordStates({ userId: user.id, deviceId });
    this.#claimDeviceCachedWords({ userId: user.id, deviceId });
    this.#claimDeviceActivity({ userId: user.id, deviceId });
    const session = this.#createSessionForUser({ user, deviceId });
    return { user, ...session };
  }

  createUserSession({ identifier, password, deviceId = null }) {
    const normalizedIdentifier = normalizeUserIdentifier(identifier);
    const user = this.usersByIdentifier.get(normalizedIdentifier);
    if (!user) {
      throw new InvalidCredentialsError({ reason: 'user_not_found' });
    }
    if (!verifyPasswordSync(password, user.password_hash)) {
      throw new InvalidCredentialsError();
    }
    // Claim device-only word states and cached words for the signing-in user
    this.#claimDeviceWordStates({ userId: user.id, deviceId });
    this.#claimDeviceCachedWords({ userId: user.id, deviceId });
    this.#claimDeviceActivity({ userId: user.id, deviceId });
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

  #claimDeviceWordStates({ userId, deviceId }) {
    if (!deviceId) return { claimed: 0, conflicts: 0 };

    const deviceOwnerKey = `device:${deviceId}`;
    const userOwnerKey = `user:${userId}`;
    let claimed = 0;
    let conflicts = 0;

    // Find all device-only word states for this device
    const deviceStateEntries = [];
    for (const [key, state] of this.wordStatesByOwnerWord.entries()) {
      if (key.startsWith(deviceOwnerKey + ':word:') && state.user_id === null) {
        deviceStateEntries.push([key, state]);
      }
    }

    for (const [deviceKey, deviceState] of deviceStateEntries) {
      const wordId = deviceState.word_id;
      const userKey = `${userOwnerKey}:word:${wordId}`;
      const existingUserState = this.wordStatesByOwnerWord.get(userKey);

      if (existingUserState) {
        // Conflict: decide which state wins
        conflicts++;
        const deviceWins =
          deviceState.review_count > existingUserState.review_count ||
          (deviceState.review_count === existingUserState.review_count &&
            (deviceState.last_studied_at ?? '') > (existingUserState.last_studied_at ?? ''));

        if (deviceWins) {
          // Device state wins: replace user state with claimed device state
          this.wordStatesByOwnerWord.delete(deviceKey);
          const claimedState = { ...deviceState, user_id: userId };
          this.wordStatesByOwnerWord.set(userKey, claimedState);
        } else {
          // User state wins: just delete the device state
          this.wordStatesByOwnerWord.delete(deviceKey);
        }
      } else {
        // No conflict: claim the device state
        this.wordStatesByOwnerWord.delete(deviceKey);
        const claimedState = { ...deviceState, user_id: userId };
        this.wordStatesByOwnerWord.set(userKey, claimedState);
        claimed++;
      }
    }

    return { claimed, conflicts };
  }

  // Attach study/speaking history and proficiency recorded on this device
  // before sign-in (including offline events synced anonymously) to the user.
  #claimDeviceActivity({ userId, deviceId }) {
    if (!deviceId) return;
    for (const event of this.studyEventsByClientId.values()) {
      if (event.device_id === deviceId && !event.user_id) event.user_id = userId;
    }
    for (const event of this.speakingEventsByKey.values()) {
      if (event.device_id === deviceId && !event.user_id) event.user_id = userId;
    }
    for (const round of this.gameRoundsByClientId.values()) {
      if (round.device_id === deviceId && !round.user_id) round.user_id = userId;
    }
    for (const [key, proficiency] of [...this.userProficiencies.entries()]) {
      if (!key.startsWith(`device:${deviceId}:`) || proficiency.user_id) continue;
      const userKey = `user:${userId}:${proficiency.language}`;
      if (!this.userProficiencies.has(userKey)) {
        this.userProficiencies.delete(key);
        this.userProficiencies.set(userKey, { ...proficiency, user_id: userId });
      }
    }
  }

  #claimDeviceCachedWords({ userId, deviceId }) {
    if (!deviceId) return { claimed: 0, duplicatesRemoved: 0 };

    const deviceOwnerKey = `device:${deviceId}`;
    const userOwnerKey = `user:${userId}`;

    const deviceCache = this.cachedWordIdsByOwner.get(deviceOwnerKey);
    if (!deviceCache || deviceCache.wordIds.size === 0) {
      return { claimed: 0, duplicatesRemoved: 0 };
    }

    const userCache = this.cachedWordIdsByOwner.get(userOwnerKey) ?? {
      wordIds: new Set(),
      observed_at: deviceCache.observed_at
    };

    let claimed = 0;
    let duplicatesRemoved = 0;

    for (const wordId of deviceCache.wordIds) {
      if (userCache.wordIds.has(wordId)) {
        duplicatesRemoved++;
      } else {
        userCache.wordIds.add(wordId);
        claimed++;
      }
    }

    this.cachedWordIdsByOwner.set(userOwnerKey, userCache);
    this.cachedWordIdsByOwner.delete(deviceOwnerKey);

    return { claimed, duplicatesRemoved };
  }

  #applyProficiencyChange({ deviceId, userId = null, language, rating, occurredAt }) {
    const proficiency = this.#getOrCreateProficiency({ deviceId, userId, language });
    const change = planLevelChange({
      rating,
      recentEvents: this.#recentEvents({ deviceId, userId }),
      levelChangedAt: proficiency.level_changed_at ?? null,
      currentLevel: proficiency.level,
      language
    });
    if (change) {
      proficiency.level = change.nextLevel;
      proficiency.level_changed_at = occurredAt;
      proficiency.updated_at = new Date().toISOString();
    }
    return change;
  }

  #buildProficiencyResponse({ deviceId, userId = null, language = 'en', ...levelChange }) {
    return toProficiencyResponse({
      proficiency: this.#getOrCreateProficiency({ deviceId, userId, language }),
      recentEvents: this.#recentEvents({ deviceId, userId }),
      userId,
      language,
      ...levelChange
    });
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
      .filter((event) => !isGameSource(event.source))
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
    return this.#insertArticle(
      buildArticle({ ownerUserId: userId, adminUserId: null, title, sourceUrl, language, rawText, visibility })
    );
  }

  #insertArticle(article) {
    this.articlesById.set(article.id, article);
    this.enqueueArticleProcessingJob({ articleId: article.id });
    return article;
  }

  listArticles({ userId, limit = 50 }) {
    return [...this.articlesById.values()]
      .filter((article) => isArticleReadableBy(article, userId))
      .sort((left, right) => right.created_at.localeCompare(left.created_at))
      .slice(0, clampLimit(limit, 100));
  }

  getArticleByIdForUser({ articleId, userId }) {
    const article = this.articlesById.get(articleId);
    if (!article || !isArticleReadableBy(article, userId)) {
      return null;
    }
    return article;
  }

  getArticleById({ articleId }) {
    return this.articlesById.get(articleId) ?? null;
  }

  createAdminArticle({ adminUserId = null, title, sourceUrl = null, language, rawText, visibility = 'published' }) {
    return this.#insertArticle(
      buildArticle({ ownerUserId: null, adminUserId, title, sourceUrl, language, rawText, visibility })
    );
  }

  listAdminArticles({ limit = 50, status = null }) {
    return [...this.articlesById.values()]
      .filter((article) => (status ? article.status === status : true))
      .sort((left, right) => right.created_at.localeCompare(left.created_at))
      .slice(0, clampLimit(limit, 100));
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
        const word = this.#findWord(term.language, term.normalized_term);
        return [
          {
            term_id: term.id,
            display_term: term.display_term,
            word: word ? toApiWord(word) : null,
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

    for (const field of ADMIN_ARTICLE_PATCH_FIELDS) {
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

  listContentPacks({ language = 'en', afterVersion = null, limit = 100 }) {
    return [...this.contentPacksById.values()]
      .filter((pack) => pack.status === 'published')
      .filter((pack) => pack.language === language)
      .filter((pack) => (afterVersion == null ? true : pack.version > afterVersion))
      .sort((left, right) => right.version - left.version)
      .slice(0, clampLimit(limit, 200));
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
    // Jobs left in 'processing' by a worker that died (deploy/restart) are reclaimed after a timeout.
    const staleBefore = staleArticleJobCutoff();
    const job = [...this.articleProcessingJobsById.values()]
      .filter(
        (item) =>
          item.status === 'pending_processing' || (item.status === 'processing' && item.started_at < staleBefore)
      )
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
    for (const item of releasableItems(items)) {
      const normalized = normalizeTerm(item.term);
      const dedupeKey = `${item.language}:${normalized}`;
      if (seen.has(dedupeKey)) {
        continue;
      }
      seen.add(dedupeKey);
      const { term, sense } = this.#persistExtractedTerm({
        item,
        normalized,
        bridgedWord: { example: item.example ?? '', topics: [], generationSource: 'article_vocabulary' },
        now
      });
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
      persisted.push({ term, sense, articleTerm });
    }
    return { count: persisted.length, items: persisted };
  }

  /** Stores the term and a new approved sense for an extracted item, and bridges it into the words pool. */
  #persistExtractedTerm({ item, normalized, bridgedWord, now }) {
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
      ...senseFieldsFromItem(item),
      status: 'approved',
      created_at: now,
      updated_at: now
    };
    this.wordSensesById.set(sense.id, sense);
    this.insertWord(bridgedWordInput(item, bridgedWord));
    return { term, sense };
  }

  persistPassageVocabulary({ passageId, items = [] }) {
    const now = new Date().toISOString();
    const passage = this.memorizationPassagesById.get(passageId);
    if (!passage) {
      throw new Error('passage_not_found');
    }

    deletePassageVocabularyLinks(this, passageId);

    const persisted = [];
    const seen = new Set();
    for (const item of releasableItems(items)) {
      const segment = this.memorizationSegmentsById.get(item.segment_id);
      if (!segment || segment.passage_id !== passageId) {
        continue;
      }
      const normalized = normalizeTerm(item.term);
      if (!normalized) {
        continue;
      }
      const dedupeKey = `${item.segment_id}:${item.language}:${normalized}`;
      if (seen.has(dedupeKey)) {
        continue;
      }
      seen.add(dedupeKey);

      const { term, sense } = this.#persistExtractedTerm({
        item,
        normalized,
        bridgedWord: {
          example: item.example ?? segment.text,
          topics: ['memorization'],
          generationSource: 'memorization_passage_vocabulary'
        },
        now
      });
      const segmentTerm = {
        id: createId('segment_term'),
        passage_id: passageId,
        segment_id: item.segment_id,
        term_id: term.id,
        word_sense_id: sense.id,
        surface_text: item.term,
        sentence_context: item.example ?? segment.text,
        frequency: Number(item.frequency ?? 1),
        extraction_confidence: Number(item.confidence ?? 0.5),
        classification: item.classification ?? null,
        suggestion_type: normalizeSuggestionType(item.suggestion_type, item.term),
        created_at: now
      };
      this.memorizationSegmentTermsById.set(segmentTerm.id, segmentTerm);
      persisted.push({ term, sense, segmentTerm });
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
    for (const item of releasableItems(items)) {
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

  // Rebuilds the owner's SRS state for the word from all its events (see PostgresWordStore).
  #upsertWordState({ deviceId, userId = null, language, event }) {
    if (!event.word_id) {
      return;
    }
    const events = [...this.studyEventsByClientId.values()].filter(
      (candidate) =>
        candidate.word_id === event.word_id &&
        (userId ? candidate.user_id === userId : candidate.device_id === deviceId && !candidate.user_id)
    );
    const state = replaySrsState(events);
    if (!state) {
      return;
    }
    const key = this.#wordStateKey({ deviceId, userId, wordId: event.word_id });
    this.wordStatesByOwnerWord.set(key, {
      id: this.wordStatesByOwnerWord.get(key)?.id ?? createId('word_state'),
      user_id: userId,
      device_id: deviceId,
      word_id: event.word_id,
      language,
      ...state,
      updated_at: new Date().toISOString()
    });
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

mixinMethods(WordStore, MemorySpeakingMethods, MemoryGameMethods, MemoryExamMethods, MemoryShadowingMethods, MemoryMemorizationMethods, MemoryUserAdminMethods);

function buildPipelineHealthSection({ pendingCount, failedCount, processedAtValues }) {
  const validProcessedAtValues = processedAtValues.filter(Boolean).sort((a, b) => String(b).localeCompare(String(a)));
  return {
    pending_count: pendingCount,
    failed_count: failedCount,
    last_processed_at: validProcessedAtValues[0] ?? null
  };
}
