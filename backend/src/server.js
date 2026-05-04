import http from 'node:http';

import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { VocabularyGenerationService } from './generation_service.js';
import { LiteLLMClient } from './litellm_client.js';
import { WordStore } from './word_store.js';

const config = loadConfig();
const store = new WordStore();
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

server.listen(config.port, () => {
  console.log(`Expat8 backend listening on http://localhost:${config.port}`);
});
