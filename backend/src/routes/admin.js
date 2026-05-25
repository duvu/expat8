import express from 'express';
import { openArchiveReadStream } from '../log_archive_store.js';
import { asyncHandler, clampLimit, hasAdminAccess } from './helpers.js';

export function createAdminRouter({ store, config, logArchiveStore }) {
  const router = express.Router();

  router.use((request, response, next) => {
    if (!hasAdminAccess({ request, config })) {
      return response.status(403).json({ error: 'forbidden' });
    }
    return next();
  });

  router.post(
    '/articles',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      if (!validateArticleBody(body)) {
        return response.status(400).json({ error: 'bad_request' });
      }
      const article = await store.createAdminArticle({
        title: body.title.trim(),
        sourceUrl: typeof body.source_url === 'string' ? body.source_url : null,
        language: body.language.trim(),
        rawText: body.raw_text,
        visibility: normalizeVisibility(body.visibility ?? 'published')
      });
      return response.status(201).json(toApiArticle(article));
    })
  );

  router.get(
    '/articles',
    asyncHandler(async (request, response) => {
      const limit = clampLimit(request.query.limit, 1, 100);
      const status = typeof request.query.status === 'string' ? request.query.status : null;
      const items = await store.listAdminArticles({ limit, status });
      return response.json({ items: items.map(toApiArticle) });
    })
  );

  router.post(
    '/articles/:id/reprocess',
    asyncHandler(async (request, response) => {
      const article = await store.reprocessArticle({ articleId: request.params.id });
      if (!article) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(toApiArticle(article));
    })
  );

  router.post(
    '/articles/:id/publish',
    asyncHandler(async (request, response) => {
      const article = await store.publishArticle({ articleId: request.params.id });
      if (!article) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(toApiArticle(article));
    })
  );

  router.patch(
    '/articles/:id',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      const patch = {};
      if (typeof body.title === 'string') patch.title = body.title;
      if (typeof body.language === 'string') patch.language = body.language;
      if (body.visibility !== undefined) {
        const v = String(body.visibility).toLowerCase();
        if (!['private', 'published'].includes(v)) {
          return response.status(400).json({ error: 'bad_request' });
        }
        patch.visibility = v;
      }
      if (typeof body.status === 'string') patch.status = body.status;
      const article = await store.patchAdminArticle({
        articleId: request.params.id,
        patch
      });
      if (!article) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(toApiArticle(article));
    })
  );

  router.get(
    '/review/vocabulary',
    asyncHandler(async (request, response) => {
      const limit = clampLimit(request.query.limit, 1, 200);
      const status = typeof request.query.status === 'string' ? request.query.status : 'pending';
      const items = await store.listVocabularyReviewItems({ status, limit });
      return response.json({ items });
    })
  );

  router.patch(
    '/vocabulary/:id',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      const nextStatus = String(body.status ?? '').trim();
      if (!['approved', 'rejected', 'pending'].includes(nextStatus)) {
        return response.status(400).json({ error: 'bad_request' });
      }
      const item = await store.reviewVocabularyItem({
        itemId: request.params.id,
        status: nextStatus,
        reviewNote: typeof body.review_note === 'string' ? body.review_note : null
      });
      if (!item) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(item);
    })
  );

  router.get(
    '/speaking-prompts',
    asyncHandler(async (request, response) => {
      const limit = clampLimit(request.query.limit ?? 100, 1, 200);
      const status = typeof request.query.status === 'string' ? request.query.status : null;
      const missingRequired = request.query.missing_required === 'true';
      const items = await store.listSpeakingPrompts({ status, missingRequired, limit });
      return response.json({ items });
    })
  );

  router.post(
    '/speaking-prompts',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      if (!body.word_sense_id || typeof body.word_sense_id !== 'string') {
        return response.status(400).json({ error: 'bad_request', message: 'word_sense_id required' });
      }
      const prompt = await store.createSpeakingPrompt({
        word_sense_id: body.word_sense_id,
        article_term_id: typeof body.article_term_id === 'string' ? body.article_term_id : null,
        target_text: typeof body.target_text === 'string' ? body.target_text : null,
        vi_hint: typeof body.vi_hint === 'string' ? body.vi_hint : null,
        target_phrase: typeof body.target_phrase === 'string' ? body.target_phrase : null,
        pronunciation_tip_vi: typeof body.pronunciation_tip_vi === 'string' ? body.pronunciation_tip_vi : null,
        common_mistake_vi: typeof body.common_mistake_vi === 'string' ? body.common_mistake_vi : null,
        difficulty: typeof body.difficulty === 'string' ? body.difficulty : null,
        topic: typeof body.topic === 'string' ? body.topic : null,
        status: typeof body.status === 'string' ? body.status : 'pending_review'
      });
      return response.status(201).json(prompt);
    })
  );

  router.patch(
    '/speaking-prompts/:id',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      const patch = {};
      const textFields = [
        'target_text',
        'vi_hint',
        'target_phrase',
        'pronunciation_tip_vi',
        'common_mistake_vi',
        'difficulty',
        'topic'
      ];
      for (const field of textFields) {
        if (body[field] !== undefined) {
          patch[field] = typeof body[field] === 'string' ? body[field].trim() || null : null;
        }
      }
      if (body.status !== undefined) {
        const validStatuses = ['pending_review', 'approved', 'rejected'];
        if (!validStatuses.includes(body.status)) {
          return response.status(400).json({ error: 'bad_request', message: 'invalid_status' });
        }
        patch.status = body.status;
      }
      const prompt = await store.updateSpeakingPrompt({
        promptId: request.params.id,
        patch,
        reviewerUserId: null
      });
      if (!prompt) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(prompt);
    })
  );

  router.get(
    '/log-archives',
    asyncHandler(async (request, response) => {
      const limit = clampLimit(request.query.limit ?? 100, 1, 200);
      const archives = await logArchiveStore.listArchives({ limit });
      return response.json({ items: archives.map(toApiLogArchive) });
    })
  );

  router.get(
    '/log-archives/:id',
    asyncHandler(async (request, response) => {
      const archive = await logArchiveStore.getArchiveById({ id: request.params.id });
      if (!archive) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(toApiLogArchive(archive));
    })
  );

  router.get(
    '/log-archives/:id/content',
    asyncHandler(async (request, response) => {
      const archive = await logArchiveStore.getArchiveById({ id: request.params.id });
      if (!archive) {
        return response.status(404).json({ error: 'not_found' });
      }
      response.type(archive.contentType ?? 'text/plain; charset=utf-8');
      return openArchiveReadStream(archive)
        .on('error', (error) => {
          request.log?.error('log_archive_stream_failed', { error, log_archive_id: archive.id });
          if (!response.headersSent) {
            response.status(500).json({ error: 'internal_error' });
          }
        })
        .pipe(response);
    })
  );

  router.get(
    '/log-archives/:id/download',
    asyncHandler(async (request, response) => {
      const archive = await logArchiveStore.getArchiveById({ id: request.params.id });
      if (!archive) {
        return response.status(404).json({ error: 'not_found' });
      }
      response.setHeader('content-disposition', `attachment; filename="${sanitizeDownloadFileName(archive)}"`);
      response.type(archive.contentType ?? 'text/plain; charset=utf-8');
      return openArchiveReadStream(archive)
        .on('error', (error) => {
          request.log?.error('log_archive_download_failed', { error, log_archive_id: archive.id });
          if (!response.headersSent) {
            response.status(500).json({ error: 'internal_error' });
          }
        })
        .pipe(response);
    })
  );

  router.delete(
    '/log-archives/:id',
    asyncHandler(async (request, response) => {
      const deleted = await logArchiveStore.deleteArchiveById({ id: request.params.id });
      if (!deleted) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.status(204).end();
    })
  );

  return router;
}

function toApiArticle(article) {
  return {
    id: article.id,
    title: article.title,
    source_url: article.source_url,
    language: article.language,
    visibility: article.visibility,
    status: article.status,
    processing_error: article.processing_error,
    created_at: article.created_at,
    updated_at: article.updated_at
  };
}

function validateArticleBody(body) {
  return (
    typeof body.title === 'string' &&
    body.title.trim().length > 0 &&
    typeof body.language === 'string' &&
    body.language.trim().length > 0 &&
    typeof body.raw_text === 'string' &&
    body.raw_text.trim().length > 0
  );
}

function normalizeVisibility(value) {
  const raw = String(value ?? 'private').toLowerCase();
  return ['private', 'published'].includes(raw) ? raw : 'private';
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

function sanitizeDownloadFileName(archive) {
  return sanitizeLogFileName(archive.originalFileName) ?? `log-archive-${archive.id}.txt`;
}
