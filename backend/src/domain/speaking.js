// Speaking practice rules shared by both stores: event validation, prompt
// shaping and the weekly summary.

export const SPEAKING_EVENT_TYPES = [
  'speaking_prompt_viewed',
  'speaking_sample_played',
  'speaking_recorded',
  'speaking_retried',
  'speaking_self_rated_clear',
  'speaking_self_rated_hesitated',
  'speaking_self_rated_could_not_say',
  'speaking_drill_completed',
  'loop_completed'
];

const SPEAKING_SELF_RATINGS = ['clear', 'hesitated', 'could_not_say'];

const FORBIDDEN_AUDIO_FIELDS = [
  'audio',
  'audio_bytes',
  'audio_base64',
  'audio_blob',
  'local_audio_path',
  'local_file_path',
  'file_path'
];

export function isSpeakingEvent(event) {
  return SPEAKING_EVENT_TYPES.includes(event?.event_type);
}

export function isUnknownSpeakingEvent(event) {
  return typeof event?.event_type === 'string' && event.event_type.startsWith('speaking_') && !isSpeakingEvent(event);
}

/** Monday 00:00 UTC of the current week unless a valid start is given. */
export function normalizeWeekStart(value) {
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

export function normalizeSpeakingEvent({ deviceId, event, language = 'en', userId = null, strict = false }) {
  if (!isSpeakingEvent(event)) {
    throw new Error('invalid_speaking_event_type');
  }
  if (containsForbiddenAudioField(event)) {
    throw new Error('forbidden_audio_field');
  }
  const speaking = event.speaking ?? {};
  const field = (name) => speaking[name] ?? event[name];
  const attemptId = normalizeOptionalText(field('attempt_id'));
  if ((strict && !attemptId) || !event.occurred_at) {
    throw new Error('missing_required_field');
  }
  const selfRating = normalizeOptionalText(field('self_rating'));
  if (selfRating && !SPEAKING_SELF_RATINGS.includes(selfRating)) {
    throw new Error('invalid_self_rating');
  }
  const durationMs = normalizeOptionalInteger(field('duration_ms'));
  const retryCount = normalizeOptionalInteger(field('retry_count')) ?? 0;
  if ((durationMs !== null && durationMs < 0) || retryCount < 0) {
    throw new Error('invalid_speaking_event');
  }

  // drill_completed-specific fields
  let promptsAttempted = null;
  let promptsCompleted = null;
  let totalDurationMs = null;
  if (event.event_type === 'speaking_drill_completed') {
    promptsAttempted = normalizeOptionalInteger(field('prompts_attempted'));
    promptsCompleted = normalizeOptionalInteger(field('prompts_completed'));
    totalDurationMs = normalizeOptionalInteger(field('total_duration_ms'));
    if (promptsAttempted === null || totalDurationMs === null) {
      throw new Error('missing_required_field');
    }
    if (promptsAttempted < 0 || totalDurationMs < 0) {
      throw new Error('invalid_speaking_event');
    }
  }

  let promptsCount = null;
  if (event.event_type === 'loop_completed') {
    promptsCount = normalizeOptionalInteger(field('prompts_count'));
    if (durationMs === null || promptsCount === null) {
      throw new Error('missing_required_field');
    }
    if (durationMs < 0 || promptsCount < 0) {
      throw new Error('invalid_speaking_event');
    }
  }

  return {
    device_id: deviceId,
    user_id: userId,
    event_type: event.event_type,
    attempt_id: attemptId,
    prompt_id: normalizeOptionalText(field('prompt_id')),
    word_sense_id: normalizeOptionalText(field('word_sense_id')),
    server_word_id: normalizeOptionalText(field('server_word_id')),
    duration_ms: durationMs,
    retry_count: retryCount,
    prompts_attempted: promptsAttempted,
    prompts_completed: promptsCompleted,
    total_duration_ms: totalDurationMs,
    prompts_count: promptsCount,
    self_rating: selfRating,
    language: normalizeOptionalText(event.language) ?? language,
    occurred_at: event.occurred_at
  };
}

export function buildSpeakingSummary({ deviceId, userId = null, language, weekStart, events, firstRecordingAt = null }) {
  const selfRatingCounts = { clear: 0, hesitated: 0, could_not_say: 0 };
  let spokenSentenceCount = 0;
  let retryCount = 0;
  let approximateDurationMs = 0;
  let latestActivityAt = null;
  let drillSessionsCompleted = 0;
  let loopCompletionCount = 0;
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
    if (event.event_type === 'loop_completed') {
      loopCompletionCount += 1;
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
    loop_completion_count: loopCompletionCount,
    approximate_duration_ms: approximateDurationMs,
    self_rating_counts: selfRatingCounts,
    first_recording_at: firstRecordingAt ?? null,
    latest_activity_at: latestActivityAt
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

/** Review fields to apply when an admin patches a prompt; a status change records the reviewer. */
export function applySpeakingPromptPatch(existing, patch, { reviewerUserId = null, now }) {
  return normalizeSpeakingPromptInput({
    ...existing,
    ...patch,
    reviewer_user_id: patch.status ? reviewerUserId : existing.reviewer_user_id,
    reviewed_at: patch.status ? now : existing.reviewed_at,
    updated_at: now
  });
}

function containsForbiddenAudioField(value) {
  if (!value || typeof value !== 'object') {
    return false;
  }
  for (const [key, nested] of Object.entries(value)) {
    if (FORBIDDEN_AUDIO_FIELDS.includes(key.toLowerCase())) {
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
