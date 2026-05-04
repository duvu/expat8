import http from 'node:http';

import pg from 'pg';

import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { VocabularyGenerationService } from './generation_service.js';
import { LiteLLMClient } from './litellm_client.js';
import { PostgresWordStore } from './postgres_word_store.js';
import { WordStore } from './word_store.js';

export function createStore({ config, poolFactory = (options) => new pg.Pool(options) }) {
  if (config.databaseUrl) {
    return new PostgresWordStore({
      pool: poolFactory({ connectionString: config.databaseUrl })
    });
  }
  return new WordStore();
}

export function createBackendRuntime({ config = loadConfig(), poolFactory } = {}) {
  const store = createStore({ config, poolFactory });
  const liteLLMClient = new LiteLLMClient({
    baseUrl: config.liteLLMBaseUrl,
    apiKey: config.liteLLMApiKey,
    model: config.liteLLMModel
  });
  const generationService = new VocabularyGenerationService({
    liteLLMClient,
    store
  });
  const server = http.createServer(createApp({ store, generationService, config }));

  return { config, store, generationService, server };
}
