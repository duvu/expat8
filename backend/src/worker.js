import { createStore } from './runtime.js';
import { loadConfig } from './config.js';
import { createLogger } from './logger.js';
import { ArticleProcessingWorker } from './article_processing_worker.js';
import { LiteLLMClient } from './litellm_client.js';
import { VocabularyEnrichmentAdapter } from './vocabulary_enrichment_adapter.js';
import { ArticleProcessingPipeline } from './article_processing_pipeline.js';

const config = loadConfig();
const logger = createLogger({
  level: config.logLevel,
  redactionEnabled: config.logRedactionEnabled,
  component: 'article_worker'
});
const store = createStore({ config, logger });
const liteLLMClient = new LiteLLMClient({
  baseUrl: config.liteLLMBaseUrl,
  apiKey: config.liteLLMApiKey,
  model: config.liteLLMModel,
  logger: logger.child({ component: 'litellm_client' })
});
const enrichmentAdapter = new VocabularyEnrichmentAdapter({
  liteLLMClient,
  logger: logger.child({ component: 'vocabulary_enrichment_adapter' })
});
const pipeline = new ArticleProcessingPipeline({
  store,
  suggestionAdapter: enrichmentAdapter,
  logger: logger.child({ component: 'article_processing_pipeline' })
});
const worker = new ArticleProcessingWorker({
  store,
  pipeline,
  logger,
  maxAttempts: Number.parseInt(process.env.ARTICLE_WORKER_MAX_ATTEMPTS ?? '3', 10)
});

const intervalMs = Number.parseInt(process.env.ARTICLE_WORKER_INTERVAL_MS ?? '1000', 10);

async function tick() {
  try {
    await worker.runOnce();
  } catch (error) {
    logger.error?.('article_worker_tick_failed', { error });
  }
}

logger.info?.('article_worker_started', { interval_ms: intervalMs });
setInterval(tick, intervalMs);
void tick();
