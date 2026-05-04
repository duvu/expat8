import express from 'express';

import { InMemoryNonceCache, verifyAppCredentialRequest } from './app_credentials.js';
import { toApiWord } from './word_store.js';

export function createApp({ store, generationService, config, nonceCache = new InMemoryNonceCache() }) {
  const app = express();

  app.get('/health', (_request, response) => {
    response.json({ ok: true });
  });

  app.use(
    '/v1',
    rejectMissingCredentialHeaders,
    captureRawBody({ config }),
    appCredentialGuard({ config, nonceCache }),
    parseJsonFromCapturedBody,
    createV1Router({ store, generationService, config })
  );

  app.use((_request, response) => {
    response.status(404).json({ error: 'not_found' });
  });

  app.use((error, _request, response, _next) => {
    response.status(500).json({ error: 'internal_error', message: error.message });
  });

  return app;
}

function createV1Router({ store, generationService, config }) {
  const router = express.Router();

  router.get(
    '/words/next',
    asyncHandler(async (request, response) => {
      const limit = clampLimit(request.query.limit, 1, 20);
      const targetLanguage = request.query.target_language ?? config.defaultTargetLanguage;
      const excludeServerWordIds = normalizeExcludedWordIds(request.query.exclude_server_word_id);
      const recentWords = await store.recentWords({ targetLanguage, limit: 1000 });
      let words = await store.findNewWords({
        targetLanguage,
        limit,
        excludeWordIds: excludeServerWordIds
      });
      if (words.length < limit && generationService) {
        const generated = await generationService.generateAndStore({
          sourceLanguage: request.query.source_language ?? config.defaultSourceLanguage,
          targetLanguage,
          limit: limit - words.length,
          avoidTerms: recentWords.map((word) => word.term)
        });
        words = [...words, ...generated].slice(0, limit);
      }
      response.json({ items: words.map(toApiWord) });
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

  router.post(
    '/study-events/sync',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      if (!body.device_id) {
        return response.status(400).json({
          accepted_event_ids: [],
          rejected_events: [{ reason: 'missing_device_id' }]
        });
      }
      const result = await store.syncStudyEvents({
        deviceId: body.device_id,
        events: Array.isArray(body.events) ? body.events : []
      });
      return response.json(result);
    })
  );

  return router;
}

function normalizeExcludedWordIds(value) {
  if (Array.isArray(value)) {
    return value.filter((item) => typeof item === 'string' && item.length > 0);
  }
  return typeof value === 'string' && value.length > 0 ? [value] : [];
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
    return badRequest(response);
  }
  return next();
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

function clampLimit(raw, min, max) {
  const parsed = Number.parseInt(raw ?? `${min}`, 10);
  if (Number.isNaN(parsed)) {
    return min;
  }
  return Math.max(min, Math.min(max, parsed));
}
