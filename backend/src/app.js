import crypto from 'node:crypto';

import express from 'express';

import { InMemoryNonceCache, verifyAppCredentialRequest } from './app_credentials.js';
import { InvalidStudyRatingError } from './proficiency.js';
import {
  DuplicateUserError,
  InvalidCredentialsError,
  InvalidRegistrationInputError
} from './user_identity.js';
import { createLogger } from './logger.js';
import { toApiWord } from './word_store.js';

export function createApp({
  store,
  generationService,
  config,
  logger = createLogger({
    level: config.logLevel,
    redactionEnabled: config.logRedactionEnabled,
    component: 'api'
  }),
  nonceCache = new InMemoryNonceCache()
}) {
  const app = express();

  app.get('/health', (request, response) => {
    response.setHeader('x-request-id', resolveRequestId(request));
    response.json({ ok: true });
  });

  app.get('/health/ready', async (request, response) => {
    response.setHeader('x-request-id', resolveRequestId(request));
    try {
      const healthy = await store.healthCheck();
      if (!healthy) {
        return response.status(503).json({ ok: false, db: 'error' });
      }
      return response.status(200).json({ ok: true, db: 'ok' });
    } catch (error) {
      return response.status(503).json({ ok: false, db: 'error' });
    }
  });

  app.use(
    '/v1',
    corsMiddleware({ config }),
    requestContextMiddleware({ logger }),
    rejectMissingCredentialHeaders,
    captureRawBody({ config }),
    appCredentialGuard({ config, nonceCache }),
    parseJsonFromCapturedBody,
    createV1Router({ store, generationService, config })
  );

  app.use((request, response) => {
    request.log?.warn('route_not_found', {
      method: request.method,
      path: request.originalUrl
    });
    response.status(404).json({ error: 'not_found' });
  });

  app.use((error, request, response, _next) => {
    const statusCode = Number.isInteger(error.statusCode) ? error.statusCode : 500;
    const category = classifyError(error, statusCode);
    request.log?.error('request_failed', {
      category,
      method: request.method,
      path: request.originalUrl,
      status_code: statusCode,
      error
    });

    if (statusCode >= 500) {
      response.status(statusCode).json({ error: 'internal_error', message: error.message });
      return;
    }
    response.status(statusCode).json({ error: error.code ?? 'bad_request', message: error.message });
  });

  return app;
}

function createV1Router({ store, config }) {
  const router = express.Router();

  router.post(
    '/users/register',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      try {
        const result = await store.registerUser({
          identifier: body.identifier,
          password: body.password,
          displayName: body.display_name ?? null,
          deviceId: body.device_id ?? null
        });
        return response.status(201).json(userSessionResponse(result));
      } catch (error) {
        if (error instanceof DuplicateUserError) {
          return response.status(409).json({ error: 'user_exists' });
        }
        if (error instanceof InvalidRegistrationInputError) {
          return response.status(400).json({ error: 'bad_request' });
        }
        throw error;
      }
    })
  );

  router.post(
    '/users/sign-in',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      try {
        const result = await store.createUserSession({
          identifier: body.identifier,
          password: body.password,
          deviceId: body.device_id ?? null
        });
        return response.json(userSessionResponse(result));
      } catch (error) {
        if (error instanceof InvalidCredentialsError) {
          return response.status(401).json({ error: 'invalid_credentials' });
        }
        throw error;
      }
    })
  );

  router.post(
    '/users/sign-out',
    asyncHandler(async (request, response) => {
      const sessionToken = bearerToken(request);
      if (!sessionToken) {
        request.log?.warn('sign_out_failed', { reason: 'missing_session_token' });
        return response.status(401).json({ error: 'invalid_session' });
      }
      const result = await store.revokeUserSession({ sessionToken });
      if (!result.revoked) {
        request.log?.warn('sign_out_failed', { reason: 'invalid_session' });
        return response.status(401).json({ error: 'invalid_session' });
      }
      return response.json({ success: true });
    })
  );

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

  router.post(
    '/learning/cards',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const body = request.body ?? {};
      if (
        !body.device_id ||
        typeof body.device_id !== 'string' ||
        hasClientWordExclusions(body)
      ) {
        return response.status(400).json({ error: 'bad_request' });
      }
      if (normalizeCardMode(body.card_mode) !== 'new') {
        return response.status(400).json({ error: 'bad_request' });
      }
      const limit = clampLimit(body.limit ?? 10, 1, 100);
      const targetLanguage = body.target_language ?? config.defaultTargetLanguage;
      const result = await store.learningCards({
        deviceId: body.device_id,
        userId: userSession?.user.id ?? null,
        targetLanguage,
        limit,
        now: new Date().toISOString()
      });
      return response.json({
        target_mix: result.target_mix,
        actual_mix: result.actual_mix,
        items: result.items.map((card) => ({
          ...toApiWord(card.word),
          card_type: card.cardType,
          selection_reason: card.selectionReason
        }))
      });
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
    '/content-packs',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const language = request.query.language ?? request.query.target_language ?? config.defaultTargetLanguage;
      const afterVersion = request.query.after_version == null
        ? null
        : Number.parseInt(request.query.after_version, 10);
      const limit = clampLimit(request.query.limit, 1, 200);
      const items = await store.listContentPacks({
        language,
        afterVersion: Number.isNaN(afterVersion) ? null : afterVersion,
        limit
      });
      return response.json({ items });
    })
  );

  router.get(
    '/content-packs/:id',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const pack = await store.getContentPackById({ id: request.params.id });
      if (!pack) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(pack);
    })
  );

  router.post(
    '/articles',
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
    '/articles',
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
    '/articles/:id',
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
    '/articles/:id/vocabulary',
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
    '/articles/:id',
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

  router.post(
    '/admin/articles',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
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
    '/admin/articles',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
      const limit = clampLimit(request.query.limit, 1, 100);
      const status = typeof request.query.status === 'string' ? request.query.status : null;
      const items = await store.listAdminArticles({ limit, status });
      return response.json({ items: items.map(toApiArticle) });
    })
  );

  router.post(
    '/admin/articles/:id/reprocess',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
      const article = await store.reprocessArticle({ articleId: request.params.id });
      if (!article) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(toApiArticle(article));
    })
  );

  router.post(
    '/admin/articles/:id/publish',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
      const article = await store.publishArticle({ articleId: request.params.id });
      if (!article) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(toApiArticle(article));
    })
  );

  router.patch(
    '/admin/articles/:id',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
      const body = request.body ?? {};
      const patch = {};
      if (typeof body.title === 'string') patch.title = body.title;
      if (typeof body.language === 'string') patch.language = body.language;
      if (body.visibility !== undefined) {
        const v = String(body.visibility).toLowerCase();
        if (!['private', 'shared', 'published'].includes(v)) {
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
    '/admin/review/vocabulary',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
      const limit = clampLimit(request.query.limit, 1, 200);
      const status = typeof request.query.status === 'string' ? request.query.status : 'pending';
      const items = await store.listVocabularyReviewItems({ status, limit });
      return response.json({ items });
    })
  );

  router.patch(
    '/admin/vocabulary/:id',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
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
    '/admin/speaking-prompts',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
      const limit = clampLimit(request.query.limit, 1, 200);
      const status = typeof request.query.status === 'string' ? request.query.status : null;
      const missingRequired = request.query.missing_required === 'true';
      const items = await store.listSpeakingPrompts({ status, missingRequired, limit });
      return response.json({ items });
    })
  );

  router.post(
    '/admin/speaking-prompts',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
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
    '/admin/speaking-prompts/:id',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }
      const body = request.body ?? {};
      const patch = {};
      const textFields = [
        'target_text', 'vi_hint', 'target_phrase',
        'pronunciation_tip_vi', 'common_mistake_vi', 'difficulty', 'topic'
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

  router.post(
    '/study-events',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const body = request.body ?? {};
      if (!body.device_id || !(body.client_event_id || body.event_id) || !body.rating || !body.occurred_at) {
        return response.status(400).json({ error: 'bad_request' });
      }

      try {
        const result = await store.recordStudyEvent({
          deviceId: body.device_id,
          userId: userSession?.user.id ?? null,
          language: body.language ?? config.defaultTargetLanguage,
          event: {
            event_id: body.event_id ?? null,
            client_event_id: body.client_event_id ?? null,
            server_word_id: body.server_word_id ?? body.word_id ?? null,
            local_word_id: body.local_word_id ?? null,
            rating: body.rating,
            occurred_at: body.occurred_at,
            user_id: body.user_id ?? null
          }
        });
        return response.json({
          success: true,
          event_id: result.eventId,
          idempotent: result.idempotent,
          proficiency: result.proficiency
        });
      } catch (error) {
        if (error instanceof InvalidStudyRatingError) {
          request.log?.warn('study_event_rejected', {
            reason: 'invalid_rating',
            event_id: body.event_id ?? null,
            client_event_id: body.client_event_id ?? null
          });
          return response.status(400).json({ error: 'invalid_rating' });
        }
        throw error;
      }
    })
  );

  router.post(
    '/study-events/sync',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const body = request.body ?? {};
      if (!body.device_id) {
        request.log?.warn('study_events_sync_rejected', { reason: 'missing_device_id' });
        return response.status(400).json({
          accepted_event_ids: [],
          rejected_events: [{ reason: 'missing_device_id' }]
        });
      }
      try {
        const result = await store.syncStudyEvents({
          deviceId: body.device_id,
          userId: userSession?.user.id ?? null,
          language: body.language ?? config.defaultTargetLanguage,
          events: Array.isArray(body.events) ? body.events : []
        });
        return response.json(result);
      } catch (error) {
        if (error instanceof InvalidStudyRatingError) {
          request.log?.warn('study_events_sync_rejected', { reason: 'invalid_rating' });
          return response.status(400).json({ error: 'invalid_rating' });
        }
        throw error;
      }
    })
  );

  router.get(
    '/speaking/summary',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const deviceId = request.query.device_id;
      if (!deviceId || typeof deviceId !== 'string') {
        return response.status(400).json({ error: 'bad_request' });
      }
      const summary = await store.getSpeakingSummary({
        deviceId,
        userId: userSession?.user.id ?? null,
        language: request.query.language ?? config.defaultTargetLanguage,
        weekStart: typeof request.query.week_start === 'string' ? request.query.week_start : null
      });
      return response.json(summary);
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

  router.get(
    '/proficiency',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const deviceId = request.query.device_id;
      if (!deviceId || typeof deviceId !== 'string') {
        return response.status(400).json({ error: 'bad_request' });
      }
      const proficiency = await store.getProficiency({
        deviceId,
        userId: userSession?.user.id ?? null,
        language: request.query.language ?? config.defaultTargetLanguage
      });
      return response.json({ device_id: deviceId, ...proficiency });
    })
  );

  return router;
}

async function resolveOptionalUserSession({ request, response, store }) {
  const token = bearerToken(request);
  if (!token) {
    return null;
  }
  const session = await store.resolveUserSession({ sessionToken: token });
  if (!session) {
    request.log?.warn('session_resolution_failed', { reason: 'invalid_session' });
    response.status(401).json({ error: 'invalid_session' });
    return false;
  }
  return session;
}

function bearerToken(request) {
  const authorization = request.get('authorization') ?? '';
  const [scheme, token] = authorization.split(/\s+/);
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}

function userSessionResponse({ user, sessionToken }) {
  return {
    user_id: user.id,
    identifier: user.identifier,
    display_name: user.display_name,
    session_token: sessionToken
  };
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

async function resolveRequiredUserSession({ request, response, store }) {
  const session = await resolveOptionalUserSession({ request, response, store });
  if (session === false) {
    return null;
  }
  if (!session) {
    response.status(401).json({ error: 'invalid_session' });
    return null;
  }
  return session;
}

function requestContextMiddleware({ logger }) {
  return (request, response, next) => {
    const requestId = resolveRequestId(request);
    const startedAt = process.hrtime.bigint();
    request.requestId = requestId;
    request.log = logger.child({ request_id: requestId });
    response.setHeader('x-request-id', requestId);

    request.log.info('request_started', {
      method: request.method,
      path: request.originalUrl
    });

    response.on('finish', () => {
      const elapsedMs = Number(process.hrtime.bigint() - startedAt) / 1e6;
      request.log.info('request_completed', {
        method: request.method,
        path: request.originalUrl,
        status_code: response.statusCode,
        elapsed_ms: Number(elapsedMs.toFixed(2))
      });
    });

    return next();
  };
}

function resolveRequestId(request) {
  const forwarded = request.get?.('x-request-id') || request.get?.('x-correlation-id');
  return forwarded && forwarded.trim().length > 0 ? forwarded.trim() : crypto.randomUUID();
}

function classifyError(error, statusCode) {
  if (error instanceof InvalidStudyRatingError) {
    return 'validation_error';
  }
  if (statusCode === 401) {
    return 'auth_error';
  }
  if (statusCode >= 500) {
    return 'internal_error';
  }
  return 'bad_request';
}

function rejectMissingCredentialHeaders(request, response, next) {
  const requiredHeaders = [
    'x-expat8-app-id',
    'x-expat8-timestamp',
    'x-expat8-nonce',
    'x-expat8-content-sha256',
    'x-expat8-signature'
  ];

  if (requiredHeaders.some((header) => !request.get(header))) {
    request.log?.warn('request_rejected', { reason: 'missing_credential_headers' });
    return badRequest(response);
  }
  return next();
}

function corsMiddleware({ config }) {
  const allowedOrigin = config.corsAllowedOrigin ?? '*';
  const allowedMethods = 'GET, POST, PUT, PATCH, OPTIONS';
  const allowedHeaders = [
    'content-type',
    'authorization',
    'x-expat8-app-id',
    'x-expat8-timestamp',
    'x-expat8-nonce',
    'x-expat8-content-sha256',
    'x-expat8-signature'
  ].join(', ');

  return (request, response, next) => {
    response.setHeader('Access-Control-Allow-Origin', allowedOrigin);
    response.setHeader('Access-Control-Allow-Methods', allowedMethods);
    response.setHeader('Access-Control-Allow-Headers', allowedHeaders);
    response.setHeader('Access-Control-Max-Age', '86400');
    if (allowedOrigin !== '*') {
      response.vary('Origin');
    }
    if (request.method === 'OPTIONS') {
      return response.status(204).end();
    }
    return next();
  };
}

function captureRawBody({ config }) {
  return (request, response, next) => {
    const limit = request.method === 'GET'
      ? config.appCredentialGetBodyLimitBytes
      : config.appCredentialPostBodyLimitBytes;
    const contentLength = Number.parseInt(request.get('content-length') ?? '0', 10);
    if (contentLength > limit) {
      return badRequest(response);
    }

    const chunks = [];
    let totalBytes = 0;
    let exceeded = false;

    request.on('data', (chunk) => {
      totalBytes += chunk.length;
      if (totalBytes > limit) {
        exceeded = true;
        return;
      }
      chunks.push(chunk);
    });

    request.on('end', () => {
      if (exceeded) {
        return badRequest(response);
      }
      request.rawBody = Buffer.concat(chunks);
      return next();
    });

    request.on('error', () => badRequest(response));
  };
}

function appCredentialGuard({ config, nonceCache }) {
  return (request, response, next) => {
    const url = new URL(request.originalUrl, 'http://localhost');
    const result = verifyAppCredentialRequest({
      method: request.method,
      url,
      headers: request.headers,
      rawBody: request.rawBody ?? Buffer.alloc(0),
      config,
      nonceCache,
      now: new Date()
    });

    if (!result.ok) {
      return badRequest(response);
    }

    request.appCredential = { appId: result.appId };
    return next();
  };
}

function parseJsonFromCapturedBody(request, response, next) {
  if (request.rawBody.length === 0) {
    request.body = {};
    return next();
  }

  try {
    request.body = JSON.parse(request.rawBody.toString('utf8'));
    return next();
  } catch (error) {
    return badRequest(response);
  }
}

function badRequest(response) {
  return response.status(400).json({ error: 'bad_request' });
}

function asyncHandler(handler) {
  return (request, response, next) => {
    Promise.resolve(handler(request, response, next)).catch(next);
  };
}

function hasClientWordExclusions(body) {
  return Object.keys(body).some((key) =>
    [
      'exclude_server_word_id',
      'exclude_server_word_ids',
      'excludeServerWordId',
      'excludeServerWordIds',
      'current_word_id',
      'current_server_word_id'
    ].includes(key)
  );
}

function normalizeCardMode(value) {
  return value === 'new' || value === undefined || value === null || value === ''
    ? 'new'
    : String(value);
}

function clampLimit(raw, min, max) {
  const parsed = Number.parseInt(raw ?? `${min}`, 10);
  if (Number.isNaN(parsed)) {
    return min;
  }
  return Math.max(min, Math.min(max, parsed));
}

function validateArticleBody(body) {
  return (
    typeof body.title === 'string' && body.title.trim().length > 0 &&
    typeof body.language === 'string' && body.language.trim().length > 0 &&
    typeof body.raw_text === 'string' && body.raw_text.trim().length > 0
  );
}

function normalizeVisibility(value) {
  const raw = String(value ?? 'private').toLowerCase();
  return ['private', 'shared', 'published'].includes(raw) ? raw : 'private';
}

function hasAdminAccess({ request, config }) {
  if (config.adminApiTokens.size === 0) {
    return false;
  }
  const token = request.get('x-expat8-admin-token') ?? request.get('x-admin-token');
  return typeof token === 'string' && config.adminApiTokens.has(token);
}
