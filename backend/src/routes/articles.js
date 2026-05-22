import express from 'express';
import { rateLimitMiddleware } from '../rate_limit.js';
import { asyncHandler, clampLimit, resolveRequiredUserSession } from './helpers.js';

export function createArticlesRouter({ store, _config, rateLimiters = {} }) {
  const { articleUploadLimiter } = rateLimiters;
  const router = express.Router();

  router.post(
    '/',
    ...(articleUploadLimiter ? [rateLimitMiddleware(articleUploadLimiter, { keyPrefix: 'articles' })] : []),
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const body = request.body ?? {};
      if (!validateArticleBody(body)) {
        return response.status(400).json({ error: 'bad_request' });
      }

      const article = await store.createArticle({
        userId: userSession.user.id,
        title: body.title.trim(),
        sourceUrl: typeof body.source_url === 'string' ? body.source_url : null,
        language: body.language.trim(),
        rawText: body.raw_text,
        visibility: normalizeVisibility(body.visibility)
      });

      return response.status(201).json(toApiArticle(article));
    })
  );

  router.get(
    '/',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const limit = clampLimit(request.query.limit, 1, 100);
      const items = await store.listArticles({ userId: userSession.user.id, limit });
      return response.json({ items: items.map(toApiArticle) });
    })
  );

  router.get(
    '/:id',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const article = await store.getArticleByIdForUser({
        articleId: request.params.id,
        userId: userSession.user.id
      });
      if (!article) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(toApiArticle(article));
    })
  );

  router.get(
    '/:id/vocabulary',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const vocabulary = await store.getArticleVocabulary({
        articleId: request.params.id,
        userId: userSession.user.id
      });
      if (!vocabulary) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(vocabulary);
    })
  );

  router.delete(
    '/:id',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const article = await store.softDeleteArticle({
        articleId: request.params.id,
        userId: userSession.user.id
      });
      if (!article) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json({ success: true });
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
