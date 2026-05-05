import http from 'node:http';

import pg from 'pg';

import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { VocabularyGenerationService } from './generation_service.js';
import { LiteLLMClient } from './litellm_client.js';
import { createLogger } from './logger.js';
import { PostgresWordStore } from './postgres_word_store.js';
import { VocabularyPoolScheduler } from './vocabulary_pool_scheduler.js';
import { WordStore } from './word_store.js';

export function createStore({ config, logger, poolFactory = (options) => new pg.Pool(options) }) {
  const storeLogger = logger ?? createLogger({
    level: config.logLevel,
    redactionEnabled: config.logRedactionEnabled,
    component: 'backend'
  });

  if (config.databaseUrl) {
    return new PostgresWordStore({
      pool: poolFactory({ connectionString: config.databaseUrl }),
      logger: storeLogger.child({ component: 'postgres_word_store' })
    });
  }
  return new WordStore();
}

export function createBackendRuntime({ config = loadConfig(), poolFactory, logger } = {}) {
  const runtimeLogger = logger ?? createLogger({
    level: config.logLevel,
    redactionEnabled: config.logRedactionEnabled,
    component: 'backend'
  });
  const store = createStore({ config, logger: runtimeLogger, poolFactory });
  const liteLLMClient = new LiteLLMClient({
    baseUrl: config.liteLLMBaseUrl,
    apiKey: config.liteLLMApiKey,
    model: config.liteLLMModel,
    logger: runtimeLogger.child({ component: 'litellm_client' })
  });
  const generationService = new VocabularyGenerationService({
    liteLLMClient,
    store,
    logger: runtimeLogger.child({ component: 'generation_service' })
  });
  const vocabularyPoolScheduler = new VocabularyPoolScheduler({
    store,
    generationService,
    config,
    logger: runtimeLogger.child({ component: 'vocabulary_scheduler' })
  });
  const server = http.createServer(createApp({
    store,
    generationService,
    config,
    logger: runtimeLogger.child({ component: 'api' })
  }));

  return {
    config,
    store,
    generationService,
    vocabularyPoolScheduler,
    server,
    logger: runtimeLogger
  };
}
