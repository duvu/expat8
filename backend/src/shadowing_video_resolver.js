import {
  InvalidShadowingVideoSourceError,
  ShadowingImportFailedError,
  ShadowingTranscriptUnavailableError
} from './shadowing_videos.js';

export class UnavailableShadowingVideoResolver {
  async resolve() {
    throw new ShadowingImportFailedError('shadowing_import_unavailable');
  }
}

export class YouTubeShadowingVideoResolver {
  constructor({ fetchImpl = globalThis.fetch, logger = console } = {}) {
    this.fetchImpl = fetchImpl;
    this.logger = logger;
  }

  async resolve({ sourceUrl }) {
    const videoId = extractYouTubeVideoId(sourceUrl);
    if (!videoId) {
      throw new InvalidShadowingVideoSourceError();
    }

    const normalizedUrl = `https://www.youtube.com/watch?v=${videoId}`;
    const metadata = await fetchOEmbedMetadata({ fetchImpl: this.fetchImpl, url: normalizedUrl });
    const playerResponse = await fetchPlayerResponse({ fetchImpl: this.fetchImpl, videoId });
    const captionTrack = pickCaptionTrack(playerResponse);
    if (!captionTrack?.baseUrl) {
      throw new ShadowingTranscriptUnavailableError();
    }

    const transcript = await fetchCaptionTrack({ fetchImpl: this.fetchImpl, baseUrl: captionTrack.baseUrl });
    const segments = buildSegmentsFromTranscript(transcript?.events ?? []);
    if (segments.length === 0) {
      throw new ShadowingTranscriptUnavailableError();
    }

    return {
      sourceType: 'youtube',
      providerVideoId: videoId,
      sourceUrl: normalizedUrl,
      title: metadata.title ?? playerResponse?.videoDetails?.title ?? `YouTube ${videoId}`,
      channelTitle: metadata.author_name ?? playerResponse?.videoDetails?.author ?? null,
      thumbnailUrl: metadata.thumbnail_url ?? null,
      durationSeconds: Number.parseInt(playerResponse?.videoDetails?.lengthSeconds ?? '', 10) || null,
      transcriptLanguage: captionTrack.languageCode ?? null,
      transcriptSource: captionTrack.kind === 'asr' ? 'youtube_auto_caption' : 'youtube_caption_track',
      segments
    };
  }
}

export function extractYouTubeVideoId(value) {
  try {
    const input = String(value ?? '').trim();
    if (!input) {
      return null;
    }

    const url = new URL(input.startsWith('http') ? input : `https://${input}`);
    const hostname = url.hostname.replace(/^www\./, '').toLowerCase();
    if (hostname === 'youtu.be') {
      return normalizeVideoId(url.pathname.slice(1));
    }
    if (hostname !== 'youtube.com' && hostname !== 'm.youtube.com') {
      return null;
    }

    if (url.pathname === '/watch') {
      return normalizeVideoId(url.searchParams.get('v'));
    }
    if (url.pathname.startsWith('/embed/')) {
      return normalizeVideoId(url.pathname.slice('/embed/'.length));
    }
    if (url.pathname.startsWith('/shorts/')) {
      return normalizeVideoId(url.pathname.slice('/shorts/'.length));
    }
    return null;
  } catch {
    return null;
  }
}

async function fetchOEmbedMetadata({ fetchImpl, url }) {
  const oEmbedUrl = new URL('https://www.youtube.com/oembed');
  oEmbedUrl.searchParams.set('url', url);
  oEmbedUrl.searchParams.set('format', 'json');
  const response = await fetchImpl(oEmbedUrl, {
    headers: {
      'accept-language': 'en-US,en;q=0.9'
    }
  });
  if (response.status === 404) {
    throw new InvalidShadowingVideoSourceError();
  }
  if (!response.ok) {
    throw new ShadowingImportFailedError(`oembed_fetch_failed:${response.status}`);
  }
  try {
    return await response.json();
  } catch {
    throw new ShadowingImportFailedError('oembed_parse_failed');
  }
}

async function fetchPlayerResponse({ fetchImpl, videoId }) {
  const response = await fetchImpl(`https://www.youtube.com/watch?v=${videoId}&hl=en`, {
    headers: {
      'accept-language': 'en-US,en;q=0.9',
      'user-agent': 'Mozilla/5.0 (compatible; expat8-shadowing-import/1.0)'
    }
  });
  if (!response.ok) {
    throw new ShadowingImportFailedError(`watch_page_fetch_failed:${response.status}`);
  }
  const html = await response.text();
  const rawJson =
    extractAssignedJson(html, 'ytInitialPlayerResponse') ??
    extractAssignedJson(html, 'window["ytInitialPlayerResponse"]');
  if (!rawJson) {
    throw new ShadowingTranscriptUnavailableError();
  }
  try {
    return JSON.parse(rawJson);
  } catch {
    throw new ShadowingImportFailedError('player_response_parse_failed');
  }
}

function pickCaptionTrack(playerResponse) {
  const tracks = playerResponse?.captions?.playerCaptionsTracklistRenderer?.captionTracks;
  if (!Array.isArray(tracks) || tracks.length === 0) {
    return null;
  }

  return (
    tracks.find((track) => track.languageCode === 'en' && track.kind !== 'asr') ??
    tracks.find((track) => track.kind !== 'asr') ??
    tracks.find((track) => track.languageCode === 'en') ??
    tracks[0]
  );
}

async function fetchCaptionTrack({ fetchImpl, baseUrl }) {
  const absoluteUrl = baseUrl.startsWith('/') ? `https://www.youtube.com${baseUrl}` : baseUrl;
  const url = new URL(absoluteUrl);
  url.searchParams.set('fmt', 'json3');
  const response = await fetchImpl(url, {
    headers: {
      'accept-language': 'en-US,en;q=0.9'
    }
  });
  if (!response.ok) {
    throw new ShadowingTranscriptUnavailableError();
  }
  try {
    return await response.json();
  } catch {
    throw new ShadowingImportFailedError('caption_track_parse_failed');
  }
}

function buildSegmentsFromTranscript(events) {
  const segments = [];
  for (const event of events) {
    const startMs = Number.parseInt(String(event?.tStartMs ?? ''), 10);
    if (!Number.isFinite(startMs) || startMs < 0 || !Array.isArray(event?.segs)) {
      continue;
    }
    const text = event.segs
      .map((segment) => String(segment?.utf8 ?? ''))
      .join('')
      .replace(/\s+/g, ' ')
      .trim();
    if (!text) {
      continue;
    }
    const durationMs = Number.parseInt(String(event?.dDurationMs ?? ''), 10);
    segments.push({
      position: segments.length,
      startMs,
      endMs: startMs + (Number.isFinite(durationMs) && durationMs > 0 ? durationMs : 1),
      text
    });
  }
  return segments;
}

function extractAssignedJson(source, variableName) {
  const marker = `${variableName} = `;
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) {
    return null;
  }
  const objectStart = source.indexOf('{', markerIndex + marker.length);
  if (objectStart < 0) {
    return null;
  }
  return extractBalancedJson(source, objectStart);
}

function extractBalancedJson(source, startIndex) {
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = startIndex; index < source.length; index += 1) {
    const char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === '\\') {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }
    if (char === '{') {
      depth += 1;
      continue;
    }
    if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        return source.slice(startIndex, index + 1);
      }
    }
  }

  return null;
}

function normalizeVideoId(value) {
  const candidate = String(value ?? '').trim();
  return /^[A-Za-z0-9_-]{6,}$/.test(candidate) ? candidate : null;
}
