const DEFAULT_PLAYBACK_RATE = 1.0;
const DEFAULT_SEEK_BACK_MS = 5000;
const SUPPORTED_SOURCE_TYPES = new Set(['youtube']);

export class InvalidShadowingVideoSourceError extends Error {
  constructor(message = 'invalid_source_url') {
    super(message);
    this.name = 'InvalidShadowingVideoSourceError';
    this.code = 'invalid_source_url';
  }
}

export class ShadowingTranscriptUnavailableError extends Error {
  constructor(message = 'transcript_unavailable') {
    super(message);
    this.name = 'ShadowingTranscriptUnavailableError';
    this.code = 'transcript_unavailable';
  }
}

export class ShadowingImportFailedError extends Error {
  constructor(message = 'shadowing_import_failed') {
    super(message);
    this.name = 'ShadowingImportFailedError';
    this.code = 'shadowing_import_failed';
  }
}

export function normalizeResolvedShadowingVideo(input) {
  const sourceType = normalizeRequiredText(input?.sourceType, 'invalid_source_url');
  if (!SUPPORTED_SOURCE_TYPES.has(sourceType)) {
    throw new InvalidShadowingVideoSourceError();
  }

  const providerVideoId = normalizeRequiredText(input?.providerVideoId, 'invalid_source_url');
  const sourceUrl = normalizeRequiredText(input?.sourceUrl, 'invalid_source_url');
  const title = normalizeRequiredText(input?.title, 'invalid_source_url');
  const channelTitle = normalizeOptionalText(input?.channelTitle);
  const thumbnailUrl = normalizeOptionalText(input?.thumbnailUrl);
  const transcriptLanguage = normalizeOptionalText(input?.transcriptLanguage);
  const transcriptSource = normalizeOptionalText(input?.transcriptSource) ?? 'youtube_caption_track';
  const durationSeconds = normalizeOptionalInteger(input?.durationSeconds);
  const defaultPlaybackRate = normalizePositiveNumber(input?.defaultPlaybackRate) ?? DEFAULT_PLAYBACK_RATE;
  const defaultSeekBackMs = normalizePositiveInteger(input?.defaultSeekBackMs) ?? DEFAULT_SEEK_BACK_MS;

  const segments = Array.isArray(input?.segments)
    ? input.segments
        .map((segment, index) => normalizeShadowingSegment(segment, index))
        .filter(Boolean)
        .sort((left, right) => left.position - right.position)
        .map((segment, index) => ({ ...segment, position: index }))
    : [];

  if (segments.length === 0) {
    throw new ShadowingTranscriptUnavailableError();
  }

  return {
    sourceType,
    providerVideoId,
    sourceUrl,
    title,
    channelTitle,
    thumbnailUrl,
    durationSeconds,
    transcriptLanguage,
    transcriptSource,
    defaultPlaybackRate,
    defaultSeekBackMs,
    segments
  };
}

export function canAccessShadowingEntry(entry, { deviceId, userId = null }) {
  if (!entry) {
    return false;
  }
  if (entry.entry_type === 'curated') {
    return entry.visibility === 'published';
  }
  if (entry.owner_user_id) {
    return Boolean(userId) && entry.owner_user_id === userId;
  }
  return !userId && entry.owner_device_id === deviceId;
}

export function toApiShadowingEntry(entry, { includeSegments = false } = {}) {
  const result = {
    id: entry.id,
    entry_type: entry.entry_type,
    visibility: entry.visibility,
    source_type: entry.source_type,
    source_url: entry.source_url,
    youtube_video_id: entry.provider_video_id,
    title: entry.title,
    channel_title: entry.channel_title ?? null,
    thumbnail_url: entry.thumbnail_url ?? null,
    duration_seconds: entry.duration_seconds ?? null,
    transcript_language: entry.transcript_language ?? null,
    transcript_source: entry.transcript_source ?? null,
    segment_count: entry.segment_count ?? (Array.isArray(entry.segments) ? entry.segments.length : 0),
    playback_defaults: {
      initial_playback_rate: entry.default_playback_rate ?? DEFAULT_PLAYBACK_RATE,
      seek_back_ms: entry.default_seek_back_ms ?? DEFAULT_SEEK_BACK_MS
    },
    created_at: entry.created_at,
    updated_at: entry.updated_at
  };

  if (includeSegments) {
    result.segments = Array.isArray(entry.segments) ? entry.segments.map(toApiShadowingSegment) : [];
  }

  return result;
}

export function toApiShadowingSegment(segment) {
  return {
    id: segment.id,
    position: segment.position,
    start_ms: segment.start_ms,
    end_ms: segment.end_ms,
    text: segment.text
  };
}

function normalizeShadowingSegment(segment, index) {
  const text = normalizeRequiredText(segment?.text, null);
  if (!text) {
    return null;
  }

  const startMs = normalizeOptionalInteger(segment?.startMs ?? segment?.start_ms);
  if (startMs === null || startMs < 0) {
    return null;
  }

  const durationMs = normalizeOptionalInteger(segment?.durationMs ?? segment?.duration_ms);
  const rawEndMs = normalizeOptionalInteger(segment?.endMs ?? segment?.end_ms);
  const endMs = rawEndMs ?? (durationMs !== null ? startMs + durationMs : startMs + 1);
  if (endMs <= startMs) {
    return null;
  }

  return {
    position: normalizeOptionalInteger(segment?.position) ?? index,
    start_ms: startMs,
    end_ms: endMs,
    text
  };
}

function normalizeRequiredText(value, errorCode) {
  const text = normalizeOptionalText(value);
  if (text) {
    return text;
  }
  if (errorCode === null) {
    return null;
  }
  throw new InvalidShadowingVideoSourceError(errorCode);
}

function normalizeOptionalText(value) {
  if (value === undefined || value === null) {
    return null;
  }
  const text = String(value).trim();
  return text.length > 0 ? text : null;
}

function normalizeOptionalInteger(value) {
  if (value === undefined || value === null || value === '') {
    return null;
  }
  const parsed = Number.parseInt(String(value), 10);
  return Number.isNaN(parsed) ? null : parsed;
}

function normalizePositiveInteger(value) {
  const parsed = normalizeOptionalInteger(value);
  return parsed !== null && parsed > 0 ? parsed : null;
}

function normalizePositiveNumber(value) {
  if (value === undefined || value === null || value === '') {
    return null;
  }
  const parsed = Number.parseFloat(String(value));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}
