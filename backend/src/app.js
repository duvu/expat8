import crypto from 'node:crypto';

import express from 'express';

import { InMemoryNonceCache, verifyAppCredentialRequest } from './app_credentials.js';
import { InvalidStudyRatingError } from './proficiency.js';
import { FileLogArchiveStore } from './log_archive_store.js';
import { createLogger } from './logger.js';
import { InMemoryRateLimiter } from './rate_limit.js';
import { createExamRouter } from './routes/exam.js';
import { createAuthRouter } from './routes/auth.js';
import { createAdminRouter } from './routes/admin.js';
import { createLearningRouter } from './routes/learning.js';
import { createArticlesRouter } from './routes/articles.js';
import { createSpeakingRouter } from './routes/speaking.js';
import { createProficiencyRouter } from './routes/proficiency.js';
import { createStudyEventsRouter } from './routes/study_events.js';
import { createContentPacksRouter } from './routes/content_packs.js';
import { createUserRouter } from './routes/user.js';

export function createApp({
  store,
  generationService: _generationService,
  config,
  logger = createLogger({
    level: config.logLevel,
    redactionEnabled: config.logRedactionEnabled,
    component: 'api'
  }),
  nonceCache = new InMemoryNonceCache(),
  logArchiveStore = null
}) {
  const app = express();
  const resolvedLogArchiveStore =
    logArchiveStore ??
    new FileLogArchiveStore({
      rootDir: config.logArchiveDir,
      retentionDays: config.logArchiveRetentionDays,
      maxTotalBytes: config.logArchiveMaxTotalBytes,
      logger: logger.child({ component: 'log_archive_store' })
    });

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
    } catch (_error) {
      return response.status(503).json({ ok: false, db: 'error' });
    }
  });

  // Public exam certificate endpoint — no app-credential auth required.
  app.get('/v1/exam/certificate/:id', async (request, response) => {
    try {
      const cert = await store.getExamCertificate({ id: request.params.id });
      if (!cert) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(cert);
    } catch (_err) {
      return response.status(500).json({ error: 'internal_error' });
    }
  });

  const rateLimiters = createRateLimiters({
    registerMax: config.authRateLimitRegister,
    signInMax: config.authRateLimitSignIn
  });

  app.use(
    '/v1',
    corsMiddleware({ config }),
    requestContextMiddleware({ logger }),
    rejectMissingCredentialHeaders,
    captureRawBody({ config }),
    appCredentialGuard({ config, nonceCache }),
    parseJsonFromCapturedBody,
    createV1Router({ store, config, logArchiveStore: resolvedLogArchiveStore, rateLimiters })
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

// ─── Rate Limiters ──────────────────────────────────────────────────────────

function createRateLimiters({
  registerMax = 10,
  registerWindowMs = 60_000,
  signInMax = 20,
  signInWindowMs = 60_000
} = {}) {
  return {
    registerLimiter: new InMemoryRateLimiter({ windowMs: registerWindowMs, maxRequests: registerMax }),
    signInLimiter: new InMemoryRateLimiter({ windowMs: signInWindowMs, maxRequests: signInMax }),
    articleUploadLimiter: new InMemoryRateLimiter({ windowMs: 60_000, maxRequests: 20 }),
    learningCardsLimiter: new InMemoryRateLimiter({ windowMs: 60_000, maxRequests: 60 }),
    studyEventSyncLimiter: new InMemoryRateLimiter({ windowMs: 60_000, maxRequests: 30 })
  };
}

// ─── V1 Router (mounts all domain routers) ──────────────────────────────────

function createV1Router({ store, config, logArchiveStore, rateLimiters = {} }) {
  const router = express.Router();

  router.use('/exam', createExamRouter({ store }));
  router.use('/', createAuthRouter({ store, config, rateLimiters }));
  router.use('/admin', createAdminRouter({ store, config, logArchiveStore }));
  router.use('/learning', createLearningRouter({ store, config, rateLimiters }));
  router.use('/articles', createArticlesRouter({ store, config, rateLimiters }));
  router.use('/speaking', createSpeakingRouter({ store, config }));
  router.use('/proficiency', createProficiencyRouter({ store, config }));
  router.use('/study-events', createStudyEventsRouter({ store, config, rateLimiters }));
  router.use('/content-packs', createContentPacksRouter({ store, config }));
  router.use('/', createUserRouter({ store, config, logArchiveStore }));

  return router;
}

// ─── Middleware ──────────────────────────────────────────────────────────────

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
    'x-expat8-signature',
    'x-expat8-device-id',
    'x-expat8-log-source',
    'x-expat8-log-filename'
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
    const limit = resolveBodyLimit({ request, config });
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
  return async (request, response, next) => {
    const url = new URL(request.originalUrl, 'http://localhost');
    const result = await verifyAppCredentialRequest({
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

  const contentType = String(request.get('content-type') ?? '').toLowerCase();
  const isJsonContentType = contentType.includes('application/json') || contentType.endsWith('+json');
  if (!isJsonContentType) {
    const pathName = new URL(request.originalUrl, 'http://localhost').pathname;
    if (pathName === '/v1/mobile/log-archives') {
      request.body = {};
      return next();
    }
    return badRequest(response);
  }

  try {
    request.body = JSON.parse(request.rawBody.toString('utf8'));
    return next();
  } catch (_error) {
    return badRequest(response);
  }
}

// ─── Utilities ──────────────────────────────────────────────────────────────

function badRequest(response) {
  return response.status(400).json({ error: 'bad_request' });
}

function resolveBodyLimit({ request, config }) {
  const pathName = new URL(request.originalUrl, 'http://localhost').pathname;
  if (request.method === 'POST' && pathName === '/v1/mobile/log-archives') {
    return config.logArchiveUploadBodyLimitBytes;
  }
  return request.method === 'GET' ? config.appCredentialGetBodyLimitBytes : config.appCredentialPostBodyLimitBytes;
}
