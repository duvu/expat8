import express from 'express';

import { UnavailableShadowingVideoResolver } from '../shadowing_video_resolver.js';
import {
  InvalidShadowingVideoSourceError,
  ShadowingImportFailedError,
  ShadowingTranscriptUnavailableError,
  canAccessShadowingEntry,
  toApiShadowingEntry
} from '../shadowing_videos.js';
import { asyncHandler, clampLimit, resolveOptionalUserSession } from './helpers.js';

const unavailableShadowingVideoResolver = new UnavailableShadowingVideoResolver();

export function createShadowingRouter({ store, shadowingVideoResolver = unavailableShadowingVideoResolver }) {
  const router = express.Router();

  router.get(
    '/videos',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }

      const deviceId = normalizeDeviceId(request.query.device_id);
      if (!deviceId) {
        return response.status(400).json({ error: 'bad_request' });
      }

      const items = await store.listShadowingVideoEntries({
        deviceId,
        userId: userSession?.user.id ?? null,
        limit: clampLimit(request.query.limit, 1, 100)
      });
      return response.json({ items: items.map((entry) => toApiShadowingEntry(entry)) });
    })
  );

  router.post(
    '/videos',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }

      const body = request.body ?? {};
      const deviceId = normalizeDeviceId(body.device_id);
      const sourceUrl = typeof body.source_url === 'string' ? body.source_url.trim() : '';
      if (!deviceId || !sourceUrl) {
        return response.status(400).json({ error: 'bad_request' });
      }

      try {
        const resolvedVideo = await shadowingVideoResolver.resolve({ sourceUrl });
        const result = await store.createShadowingVideoEntry({
          deviceId,
          userId: userSession?.user.id ?? null,
          resolvedVideo,
          entryType: 'saved',
          visibility: 'private'
        });
        request.log?.info('shadowing_video_saved', {
          entry_id: result.entry.id,
          user_id: userSession?.user.id ?? null,
          device_id: deviceId,
          created: result.created,
          youtube_video_id: result.entry.provider_video_id
        });
        return response.status(result.created ? 201 : 200).json(toApiShadowingEntry(result.entry));
      } catch (error) {
        return mapImportError(error, response);
      }
    })
  );

  router.get(
    '/videos/:entryId',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }

      const deviceId = normalizeDeviceId(request.query.device_id);
      if (!deviceId) {
        return response.status(400).json({ error: 'bad_request' });
      }

      const entry = await store.getShadowingVideoEntryDetail({ entryId: request.params.entryId });
      if (!entry || !canAccessShadowingEntry(entry, { deviceId, userId: userSession?.user.id ?? null })) {
        return response.status(404).json({ error: 'not_found' });
      }

      return response.json(toApiShadowingEntry(entry, { includeSegments: true }));
    })
  );

  return router;
}

function normalizeDeviceId(value) {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : '';
}

function mapImportError(error, response) {
  if (error instanceof InvalidShadowingVideoSourceError) {
    return response.status(400).json({ error: error.code });
  }
  if (error instanceof ShadowingTranscriptUnavailableError) {
    return response.status(422).json({ error: error.code });
  }
  if (error instanceof ShadowingImportFailedError) {
    const statusCode = error.message === 'shadowing_import_unavailable' ? 503 : 502;
    const errorCode = error.message === 'shadowing_import_unavailable' ? 'shadowing_import_unavailable' : error.code;
    return response.status(statusCode).json({ error: errorCode });
  }
  throw error;
}
