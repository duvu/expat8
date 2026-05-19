import express from 'express';
import { toApiWord, toApiWorkplaceSentence } from '../word_store.js';
import { asyncHandler, clampLimit, resolveOptionalUserSession, resolveRequiredUserSession } from './helpers.js';

export function createUserRouter({ store, config, logArchiveStore }) {
  const router = express.Router();

  router.get(
    '/me',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      return response.json({
        user_id: userSession.user.id,
        identifier: userSession.user.identifier,
        display_name: userSession.user.display_name
      });
    })
  );

  router.put(
    '/user-word-cache',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const body = request.body ?? {};
      if (
        !body.device_id ||
        typeof body.device_id !== 'string' ||
        !Array.isArray(body.server_word_ids) ||
        body.server_word_ids.length > 1000 ||
        (body.observed_at !== undefined && Number.isNaN(Date.parse(body.observed_at)))
      ) {
        return response.status(400).json({ error: 'bad_request' });
      }
      const result = await store.replaceCachedWordIds({
        deviceId: body.device_id,
        userId: userSession?.user.id ?? null,
        wordIds: body.server_word_ids,
        observedAt: body.observed_at ?? new Date().toISOString()
      });
      return response.json(result);
    })
  );

  router.post(
    '/user-submitted-words',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }

      const body = request.body ?? {};
      const deviceId = typeof body.device_id === 'string' ? body.device_id.trim() : '';
      const term = typeof body.term === 'string' ? body.term.trim() : '';
      const targetLanguage = typeof body.target_language === 'string' ? body.target_language.trim() : '';
      if (!deviceId || !term || !targetLanguage || !config.validLanguages.has(targetLanguage)) {
        return response.status(400).json({ error: 'bad_request' });
      }

      const result = await store.createUserSubmittedWord({
        deviceId,
        userId: userSession?.user.id ?? null,
        term,
        language: targetLanguage
      });
      return response.status(result.created ? 201 : 200).json(toApiSubmittedWord(result.submission));
    })
  );

  router.get(
    '/user-submitted-words',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }

      const deviceId = typeof request.query.device_id === 'string' ? request.query.device_id.trim() : '';
      if (!deviceId) {
        return response.status(400).json({ error: 'bad_request' });
      }

      const items = await store.listUserSubmittedWords({
        deviceId,
        userId: userSession?.user.id ?? null,
        limit: clampLimit(request.query.limit, 1, 100)
      });
      return response.json({ items: items.map(toApiSubmittedWord) });
    })
  );

  router.get(
    '/words/recent',
    asyncHandler(async (request, response) => {
      const limit = clampLimit(request.query.limit, 1, 1000);
      const targetLanguage = request.query.target_language ?? config.defaultTargetLanguage;
      const words = await store.recentWords({ targetLanguage, limit });
      response.json({ items: words.map(toApiWord) });
    })
  );

  router.get(
    '/workplace-sentences/recent',
    asyncHandler(async (request, response) => {
      const limit = clampLimit(request.query.limit, 1, 1000);
      const targetLanguage = request.query.target_language ?? config.defaultTargetLanguage;
      const sentences = await store.recentWorkplaceSentences({ targetLanguage, limit });
      response.json({ items: sentences.map(toApiWorkplaceSentence) });
    })
  );

  router.post(
    '/mobile/log-archives',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      if (!request.rawBody || request.rawBody.length === 0) {
        return response.status(400).json({ error: 'bad_request' });
      }

      const archive = await logArchiveStore.saveArchive({
        appId: request.appCredential?.appId,
        userId: userSession?.user.id ?? null,
        deviceId: optionalHeaderValue(request, 'x-expat8-device-id'),
        sourceLabel: optionalHeaderValue(request, 'x-expat8-log-source') ?? 'mobile',
        originalFileName: sanitizeLogFileName(optionalHeaderValue(request, 'x-expat8-log-filename')),
        contentType: request.get('content-type') ?? 'text/plain; charset=utf-8',
        body: request.rawBody,
        uploadedAt: new Date()
      });

      request.log?.info('log_archive_uploaded', {
        log_archive_id: archive.id,
        size_bytes: archive.sizeBytes,
        source_app_id: archive.appId
      });

      return response.status(201).json(toApiLogArchive(archive));
    })
  );

  return router;
}

function optionalHeaderValue(request, headerName) {
  const value = request.get(headerName);
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function sanitizeLogFileName(value) {
  if (!value) {
    return null;
  }
  const sanitized = value
    .replace(/[^A-Za-z0-9._-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '');
  return sanitized || null;
}

function toApiLogArchive(archive) {
  return {
    id: archive.id,
    file_name: archive.originalFileName ?? `log-archive-${archive.id}.txt`,
    content_type: archive.contentType,
    size_bytes: archive.sizeBytes,
    uploaded_at: archive.uploadedAt,
    source_app_id: archive.appId,
    source_device_id: archive.deviceId,
    source_user_id: archive.userId,
    source_label: archive.sourceLabel,
    retention_expires_at: archive.retentionExpiresAt,
    retention_state: archive.retentionState,
    content_url: archive.contentUrl,
    download_url: archive.downloadUrl
  };
}

function toApiSubmittedWord(submission) {
  return {
    id: submission.id,
    submitted_term: submission.submitted_term,
    target_language: submission.language,
    status: submission.status,
    resolution_type: submission.resolution_type ?? null,
    failure_reason: submission.failure_reason ?? null,
    resolved_word: submission.resolved_word ? toApiWord(submission.resolved_word) : null,
    created_at: submission.created_at,
    updated_at: submission.updated_at,
    resolved_at: submission.resolved_at ?? null
  };
}
