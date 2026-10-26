// PostgreSQL shadowing video entries (saved and curated videos with transcript segments).

import { createId } from '../../ids.js';
import { normalizeResolvedShadowingVideo } from '../../shadowing_videos.js';
import { clampLimit } from '../../domain/pagination.js';
import { shadowingEntryOwnership } from '../../domain/shadowing.js';
import { withOptionalTransaction } from './transaction.js';

export class PostgresShadowingMethods {
  async createShadowingVideoEntry({ deviceId = null, userId = null, resolvedVideo, entryType = 'saved', visibility = 'private' }) {
    const normalized = normalizeResolvedShadowingVideo(resolvedVideo);
    return withOptionalTransaction(this, async (client) => {
      const now = new Date().toISOString();
      let videoResult = await client.query(
        shadowingEntryVideoSql('sv.source_type = $1 AND sv.provider_video_id = $2 LIMIT 1'),
        [normalized.sourceType, normalized.providerVideoId]
      );

      if (!videoResult.rows[0]) {
        const insertedVideo = await client.query(
          `INSERT INTO shadowing_videos (
            id,
            source_type,
            provider_video_id,
            source_url,
            title,
            channel_title,
            thumbnail_url,
            duration_seconds,
            transcript_language,
            transcript_source,
            default_playback_rate,
            default_seek_back_ms,
            created_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $13)
          RETURNING *`,
          [
            createId('shadow_video'),
            normalized.sourceType,
            normalized.providerVideoId,
            normalized.sourceUrl,
            normalized.title,
            normalized.channelTitle,
            normalized.thumbnailUrl,
            normalized.durationSeconds,
            normalized.transcriptLanguage,
            normalized.transcriptSource,
            normalized.defaultPlaybackRate,
            normalized.defaultSeekBackMs,
            now
          ]
        );

        const videoId = insertedVideo.rows[0].id;
        for (const segment of normalized.segments) {
          await client.query(
            `INSERT INTO shadowing_video_segments (
              id,
              video_id,
              position,
              start_ms,
              end_ms,
              text,
              created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [createId('shadow_seg'), videoId, segment.position, segment.start_ms, segment.end_ms, segment.text, now]
          );
        }

        videoResult = await client.query(shadowingEntryVideoSql('sv.id = $1 LIMIT 1'), [videoId]);
      }

      const video = rowToShadowingVideo(videoResult.rows[0]);
      const ownerWhere = buildShadowingEntryOwnerWhere({ entryType, userId });
      const ownerParams = buildShadowingEntryOwnerParams({ videoId: video.id, deviceId, userId, entryType });
      const existingEntryResult = await client.query(
        `${shadowingEntrySelectSql(`sve.video_id = $1 AND sve.entry_type = $2 AND ${ownerWhere}`)} LIMIT 1`,
        ownerParams
      );
      if (existingEntryResult.rows[0]) {
        return {
          entry: rowToShadowingEntry(existingEntryResult.rows[0]),
          created: false
        };
      }

      const ownership = shadowingEntryOwnership({ entryType, visibility, userId, deviceId });
      const insertedEntry = await client.query(
        `INSERT INTO shadowing_video_entries (
          id,
          video_id,
          entry_type,
          visibility,
          owner_user_id,
          owner_device_id,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
        RETURNING id`,
        [
          createId('shadow_entry'),
          video.id,
          entryType,
          ownership.visibility,
          ownership.owner_user_id,
          ownership.owner_device_id,
          now
        ]
      );

      const hydratedEntryResult = await client.query(
        `${shadowingEntrySelectSql('sve.id = $1')} LIMIT 1`,
        [insertedEntry.rows[0].id]
      );
      return {
        entry: rowToShadowingEntry(hydratedEntryResult.rows[0]),
        created: true
      };
    });
  }

  async listShadowingVideoEntries({ deviceId, userId = null, limit = 50 }) {
    const boundedLimit = clampLimit(limit, 100);
    const whereSql = userId
      ? `(sve.entry_type = 'curated' AND sve.visibility = 'published') OR (sve.entry_type = 'saved' AND sve.owner_user_id = $1)`
      : `(sve.entry_type = 'curated' AND sve.visibility = 'published') OR (sve.entry_type = 'saved' AND sve.owner_user_id IS NULL AND sve.owner_device_id = $1)`;
    const params = [userId ?? deviceId, boundedLimit];
    const result = await this.pool.query(
      `${shadowingEntrySelectSql(whereSql)}
       ORDER BY CASE WHEN sve.entry_type = 'curated' THEN 0 ELSE 1 END, sve.updated_at DESC
       LIMIT $2`,
      params
    );
    return result.rows.map(rowToShadowingEntry);
  }

  async getShadowingVideoEntryDetail({ entryId }) {
    const entryResult = await this.pool.query(`${shadowingEntrySelectSql('sve.id = $1')} LIMIT 1`, [entryId]);
    if (!entryResult.rows[0]) {
      return null;
    }

    const segmentsResult = await this.pool.query(
      `SELECT * FROM shadowing_video_segments WHERE video_id = $1 ORDER BY position ASC`,
      [entryResult.rows[0].video_id]
    );
    return {
      ...rowToShadowingEntry(entryResult.rows[0]),
      segments: segmentsResult.rows.map(rowToShadowingSegment)
    };
  }
}

function rowToShadowingVideo(row) {
  return {
    id: row.id,
    source_type: row.source_type,
    provider_video_id: row.provider_video_id,
    source_url: row.source_url,
    title: row.title,
    channel_title: row.channel_title,
    thumbnail_url: row.thumbnail_url,
    duration_seconds: row.duration_seconds,
    transcript_language: row.transcript_language,
    transcript_source: row.transcript_source,
    default_playback_rate: Number(row.default_playback_rate ?? 1),
    default_seek_back_ms: Number(row.default_seek_back_ms ?? 5000),
    segment_count: Number(row.segment_count ?? 0),
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function rowToShadowingEntry(row) {
  return {
    id: row.id,
    video_id: row.video_id,
    entry_type: row.entry_type,
    visibility: row.visibility,
    owner_user_id: row.owner_user_id,
    owner_device_id: row.owner_device_id,
    source_type: row.source_type,
    provider_video_id: row.provider_video_id,
    source_url: row.source_url,
    title: row.title,
    channel_title: row.channel_title,
    thumbnail_url: row.thumbnail_url,
    duration_seconds: row.duration_seconds,
    transcript_language: row.transcript_language,
    transcript_source: row.transcript_source,
    default_playback_rate: Number(row.default_playback_rate ?? 1),
    default_seek_back_ms: Number(row.default_seek_back_ms ?? 5000),
    segment_count: Number(row.segment_count ?? 0),
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function rowToShadowingSegment(row) {
  return {
    id: row.id,
    video_id: row.video_id,
    position: row.position,
    start_ms: row.start_ms,
    end_ms: row.end_ms,
    text: row.text,
    created_at: row.created_at
  };
}

function shadowingEntrySelectSql(whereSql) {
  return `SELECT
    sve.id,
    sve.video_id,
    sve.entry_type,
    sve.visibility,
    sve.owner_user_id,
    sve.owner_device_id,
    sve.created_at,
    sve.updated_at,
    sv.source_type,
    sv.provider_video_id,
    sv.source_url,
    sv.title,
    sv.channel_title,
    sv.thumbnail_url,
    sv.duration_seconds,
    sv.transcript_language,
    sv.transcript_source,
    sv.default_playback_rate,
    sv.default_seek_back_ms,
    COALESCE(segment_counts.segment_count, 0)::int AS segment_count
  FROM shadowing_video_entries sve
  JOIN shadowing_videos sv ON sv.id = sve.video_id
  LEFT JOIN (
    SELECT video_id, COUNT(*)::int AS segment_count
    FROM shadowing_video_segments
    GROUP BY video_id
  ) segment_counts ON segment_counts.video_id = sv.id
  WHERE ${whereSql}`;
}

function shadowingEntryVideoSql(whereSql) {
  return `SELECT
    sv.id,
    sv.source_type,
    sv.provider_video_id,
    sv.source_url,
    sv.title,
    sv.channel_title,
    sv.thumbnail_url,
    sv.duration_seconds,
    sv.transcript_language,
    sv.transcript_source,
    sv.default_playback_rate,
    sv.default_seek_back_ms,
    sv.created_at,
    sv.updated_at,
    COALESCE(segment_counts.segment_count, 0)::int AS segment_count
  FROM shadowing_videos sv
  LEFT JOIN (
    SELECT video_id, COUNT(*)::int AS segment_count
    FROM shadowing_video_segments
    GROUP BY video_id
  ) segment_counts ON segment_counts.video_id = sv.id
  WHERE ${whereSql}`;
}

function buildShadowingEntryOwnerWhere({ entryType, userId }) {
  if (entryType === 'curated') {
    return '1 = 1';
  }
  if (userId) {
    return 'sve.owner_user_id = $3';
  }
  return 'sve.owner_user_id IS NULL AND sve.owner_device_id = $3';
}

function buildShadowingEntryOwnerParams({ videoId, deviceId, userId, entryType }) {
  return [videoId, entryType, userId ?? deviceId];
}
