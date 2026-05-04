import express from 'express';

import { InMemoryNonceCache, verifyAppCredentialRequest } from './app_credentials.js';
import { normalizeDifficultyLevel, InvalidStudyRatingError } from './proficiency.js';
import { DuplicateUserError, InvalidCredentialsError } from './user_identity.js';
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
        if (error instanceof InvalidCredentialsError) {
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
        return response.status(401).json({ error: 'invalid_session' });
      }
      const result = await store.revokeUserSession({ sessionToken });
      if (!result.revoked) {
        return response.status(401).json({ error: 'invalid_session' });
      }
      return response.json({ success: true });
    })
  );

  router.get(
    '/words/next',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const limit = clampLimit(request.query.limit, 1, 20);
      const targetLanguage = request.query.target_language ?? config.defaultTargetLanguage;
      const proficiencyLevel = normalizeOptionalProficiencyLevel(request.query.proficiency_level);
      const deviceId = request.query.device_id ?? null;
      const excludeServerWordIds = normalizeExcludedWordIds(request.query.exclude_server_word_id);
      const recentWords = await store.recentWords({ targetLanguage, limit: 1000 });
      let words = await store.findNewWords({
        targetLanguage,
        limit,
        excludeWordIds: excludeServerWordIds,
        proficiencyLevel,
        deviceId,
        userId: userSession?.user.id ?? null
      });
      if (words.length < limit && generationService) {
        const generated = await generationService.generateAndStore({
          sourceLanguage: request.query.source_language ?? config.defaultSourceLanguage,
          targetLanguage,
          limit: limit - words.length,
          avoidTerms: recentWords.map((word) => word.term),
          difficultyLevel: proficiencyLevel ?? undefined
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
    '/study-events',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const body = request.body ?? {};
      if (!body.device_id || !body.client_event_id || !body.rating || !body.occurred_at) {
        return response.status(400).json({ error: 'bad_request' });
      }

      try {
        const result = await store.recordStudyEvent({
          deviceId: body.device_id,
          userId: userSession?.user.id ?? null,
          language: body.language ?? config.defaultTargetLanguage,
          event: {
            client_event_id: body.client_event_id,
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
          return response.status(400).json({ error: 'invalid_rating' });
        }
        throw error;
      }
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

function normalizeOptionalProficiencyLevel(value) {
  if (value === undefined || value === null || value === '') {
    return null;
  }
  return normalizeDifficultyLevel(value);
}

async function resolveOptionalUserSession({ request, response, store }) {
  const token = bearerToken(request);
  if (!token) {
    return null;
  }
  const session = await store.resolveUserSession({ sessionToken: token });
  if (!session) {
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
