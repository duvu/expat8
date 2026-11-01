import http from 'node:http';

import pg from 'pg';

import { createApp } from './app.js';
import { attachPartyRelay } from './party_relay.js';
import { InMemoryNonceCache, PostgresNonceCache } from './app_credentials.js';
import { loadConfig } from './config.js';
import { VocabularyGenerationService } from './generation_service.js';
import { LiteLLMClient } from './litellm_client.js';
import { getSharedLlmRateLimiter } from './llm_rate_limiter.js';
import { createLogger } from './logger.js';
import { PostgresWordStore } from './postgres_word_store.js';
import { FileLogArchiveStore } from './log_archive_store.js';
import { ReleaseStore } from './release_store.js';
import { PostgresReleaseStore } from './postgres_release_store.js';
import { YouTubeShadowingVideoResolver } from './shadowing_video_resolver.js';
import { VocabularyPoolScheduler } from './vocabulary_pool_scheduler.js';
import { WordStore } from './word_store.js';

export function createStore({ config, logger, poolFactory = (options) => new pg.Pool(options) }) {
  const storeLogger =
    logger ??
    createLogger({
      level: config.logLevel,
      redactionEnabled: config.logRedactionEnabled,
      component: 'backend'
    });

  if (config.databaseUrl) {
    const pool = poolFactory({
      connectionString: config.databaseUrl,
      max: config.dbPoolMax,
      idleTimeoutMillis: config.dbIdleTimeoutMs,
      connectionTimeoutMillis: config.dbConnectionTimeoutMs
    });
    return new PostgresWordStore({
      pool,
      logger: storeLogger.child({ component: 'postgres_word_store' }),
      strictAttemptId: config.speakingEventsStrictAttemptId
    });
  }
  return new WordStore({ strictAttemptId: config.speakingEventsStrictAttemptId });
}

export function createBackendRuntime({ config = loadConfig(), poolFactory, logger } = {}) {
  const runtimeLogger =
    logger ??
    createLogger({
      level: config.logLevel,
      redactionEnabled: config.logRedactionEnabled,
      component: 'backend'
    });
  const store = createStore({ config, logger: runtimeLogger, poolFactory });
  const llmRateLimiter = getSharedLlmRateLimiter(config, runtimeLogger.child({ component: 'llm_rate_limiter' }));
  const liteLLMClient = new LiteLLMClient({
    baseUrl: config.liteLLMBaseUrl,
    apiKey: config.liteLLMApiKey,
    model: config.liteLLMModel,
    timeoutMs: config.liteLLMTimeoutMs,
    logger: runtimeLogger.child({ component: 'litellm_client' }),
    rateLimiter: llmRateLimiter
  });
  const generationService = new VocabularyGenerationService({
    liteLLMClient,
    store,
    logger: runtimeLogger.child({ component: 'generation_service' })
  });
  const logArchiveStore = new FileLogArchiveStore({
    rootDir: config.logArchiveDir,
    retentionDays: config.logArchiveRetentionDays,
    maxTotalBytes: config.logArchiveMaxTotalBytes,
    logger: runtimeLogger.child({ component: 'log_archive_store' })
  });
  const releaseStore = store.pool
    ? new PostgresReleaseStore({
        pool: store.pool,
        storageDir: config.releaseStorageDir,
        logger: runtimeLogger.child({ component: 'release_store' })
      })
    : new ReleaseStore({
        storageDir: config.releaseStorageDir,
        logger: runtimeLogger.child({ component: 'release_store' })
      });
  const vocabularyPoolScheduler = new VocabularyPoolScheduler({
    store,
    generationService,
    config,
    rateLimiter: llmRateLimiter,
    logger: runtimeLogger.child({ component: 'vocabulary_scheduler' })
  });
  const shadowingVideoResolver = new YouTubeShadowingVideoResolver({
    logger: runtimeLogger.child({ component: 'shadowing_video_resolver' })
  });

  // Use Postgres-backed nonce cache when a database is configured so replay
  // protection survives process restarts and works across multiple instances.
  // Falls back to the in-memory implementation for local/test environments.
  const nonceCache = store.pool ? new PostgresNonceCache(store.pool) : new InMemoryNonceCache();

  const server = http.createServer(
    createApp({
      store,
      generationService,
      config,
      logger: runtimeLogger.child({ component: 'api' }),
      logArchiveStore,
      releaseStore,
      shadowingVideoResolver,
      nonceCache
    })
  );
  // Internet party games: WebSocket relay on the same port (see party_relay.js).
  const partyRelay = attachPartyRelay(server, {
    config,
    nonceCache,
    logger: runtimeLogger.child({ component: 'party_relay' })
  });

  return {
    config,
    store,
    generationService,
    logArchiveStore,
    releaseStore,
    shadowingVideoResolver,
    vocabularyPoolScheduler,
    server,
    partyRelay,
    logger: runtimeLogger
  };
}
