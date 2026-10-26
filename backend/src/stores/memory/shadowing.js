// In-memory shadowing video entries (saved and curated videos with transcript segments).

import { createId } from '../../ids.js';
import { normalizeResolvedShadowingVideo } from '../../shadowing_videos.js';
import { clampLimit } from '../../domain/pagination.js';
import { compareShadowingEntries, shadowingEntryOwnership } from '../../domain/shadowing.js';

export class MemoryShadowingMethods {
  createShadowingVideoEntry({ deviceId = null, userId = null, resolvedVideo, entryType = 'saved', visibility = 'private' }) {
    const normalized = normalizeResolvedShadowingVideo(resolvedVideo);
    const now = new Date().toISOString();
    const providerKey = `${normalized.sourceType}:${normalized.providerVideoId}`;
    let video = this.shadowingVideosById.get(this.shadowingVideoIdByProviderKey.get(providerKey));

    if (!video) {
      video = {
        id: createId('shadow_video'),
        source_type: normalized.sourceType,
        provider_video_id: normalized.providerVideoId,
        source_url: normalized.sourceUrl,
        title: normalized.title,
        channel_title: normalized.channelTitle,
        thumbnail_url: normalized.thumbnailUrl,
        duration_seconds: normalized.durationSeconds,
        transcript_language: normalized.transcriptLanguage,
        transcript_source: normalized.transcriptSource,
        default_playback_rate: normalized.defaultPlaybackRate,
        default_seek_back_ms: normalized.defaultSeekBackMs,
        created_at: now,
        updated_at: now
      };
      this.shadowingVideosById.set(video.id, video);
      this.shadowingVideoIdByProviderKey.set(providerKey, video.id);
      this.shadowingVideoSegmentsByVideoId.set(
        video.id,
        normalized.segments.map((segment) => ({
          id: createId('shadow_seg'),
          video_id: video.id,
          position: segment.position,
          start_ms: segment.start_ms,
          end_ms: segment.end_ms,
          text: segment.text,
          created_at: now
        }))
      );
    }

    const existing = findShadowingVideoEntry(this, { videoId: video.id, deviceId, userId, entryType });
    if (existing) {
      return { entry: hydrateShadowingVideoEntry(this, existing), created: false };
    }

    const entry = {
      id: createId('shadow_entry'),
      video_id: video.id,
      entry_type: entryType,
      ...shadowingEntryOwnership({ entryType, visibility, userId, deviceId }),
      created_at: now,
      updated_at: now
    };
    this.shadowingVideoEntriesById.set(entry.id, entry);
    return { entry: hydrateShadowingVideoEntry(this, entry), created: true };
  }

  listShadowingVideoEntries({ deviceId, userId = null, limit = 50 }) {
    return [...this.shadowingVideoEntriesById.values()]
      .filter((entry) => isShadowingEntryVisibleToOwner(entry, { deviceId, userId }))
      .sort(compareShadowingEntries)
      .slice(0, clampLimit(limit, 100))
      .map((entry) => hydrateShadowingVideoEntry(this, entry));
  }

  getShadowingVideoEntryDetail({ entryId }) {
    const entry = this.shadowingVideoEntriesById.get(entryId);
    if (!entry) {
      return null;
    }
    const hydrated = hydrateShadowingVideoEntry(this, entry);
    return {
      ...hydrated,
      segments: (this.shadowingVideoSegmentsByVideoId.get(entry.video_id) ?? []).map((segment) => ({ ...segment }))
    };
  }
}

// The caller's existing entry for a video: the curated one, or the user's/device's saved one.
function findShadowingVideoEntry(store, { videoId, deviceId = null, userId = null, entryType = 'saved' }) {
  return [...store.shadowingVideoEntriesById.values()].find((entry) => {
    if (entry.video_id !== videoId || entry.entry_type !== entryType) {
      return false;
    }
    if (entryType === 'curated') {
      return true;
    }
    if (userId) {
      return entry.owner_user_id === userId;
    }
    return !entry.owner_user_id && entry.owner_device_id === deviceId;
  });
}

function isShadowingEntryVisibleToOwner(entry, { deviceId, userId = null }) {
  if (entry.entry_type === 'curated') {
    return entry.visibility === 'published';
  }
  if (userId) {
    return entry.owner_user_id === userId;
  }
  return !entry.owner_user_id && entry.owner_device_id === deviceId;
}

// Entry joined with its video fields and segment count.
function hydrateShadowingVideoEntry(store, entry) {
  const video = store.shadowingVideosById.get(entry.video_id);
  if (!video) {
    return null;
  }
  return {
    ...entry,
    source_type: video.source_type,
    provider_video_id: video.provider_video_id,
    source_url: video.source_url,
    title: video.title,
    channel_title: video.channel_title,
    thumbnail_url: video.thumbnail_url,
    duration_seconds: video.duration_seconds,
    transcript_language: video.transcript_language,
    transcript_source: video.transcript_source,
    default_playback_rate: video.default_playback_rate,
    default_seek_back_ms: video.default_seek_back_ms,
    segment_count: (store.shadowingVideoSegmentsByVideoId.get(entry.video_id) ?? []).length
  };
}
