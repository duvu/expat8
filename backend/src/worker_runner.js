import { ArticleProcessingWorker } from './article_processing_worker.js';
import { SubmittedWordWorker } from './submitted_word_worker.js';
import { PassageSegmentationWorker } from './passage_segmentation_worker.js';
import { PassageEnrichmentWorker } from './passage_enrichment_worker.js';
import { LiteLLMClient } from './litellm_client.js';
import { getSharedLlmRateLimiter } from './llm_rate_limiter.js';
import { VocabularyEnrichmentAdapter } from './vocabulary_enrichment_adapter.js';
import { ArticleProcessingPipeline } from './article_processing_pipeline.js';
import { PassageSegmentationPipeline } from './passage_segmentation_pipeline.js';
import { PassageEnrichmentPipeline } from './passage_enrichment_pipeline.js';
import { VocabularyGenerationService } from './generation_service.js';
import { ContentCrawler } from './content_crawler.js';
import { CuratedCollector } from './curated_collector.js';

/**
 * Background queue processing (articles, passages, submitted words). Shared by the standalone
 * `worker.js` entry point and the API server when EMBEDDED_WORKER=true.
 */
export function createWorkerRunner({ config, store, logger, env = process.env }) {
  const maxAttempts = Number.parseInt(env.ARTICLE_WORKER_MAX_ATTEMPTS ?? '3', 10);
  const intervalMs = Number.parseInt(env.ARTICLE_WORKER_INTERVAL_MS ?? '1000', 10);

  const llmRateLimiter = getSharedLlmRateLimiter(config, logger.child({ component: 'llm_rate_limiter' }));
  const liteLLMClient = new LiteLLMClient({
    baseUrl: config.liteLLMBaseUrl,
    apiKey: config.liteLLMApiKey,
    model: config.liteLLMModel,
    timeoutMs: config.liteLLMTimeoutMs,
    logger: logger.child({ component: 'litellm_client' }),
    rateLimiter: llmRateLimiter
  });
  const enrichmentAdapter = new VocabularyEnrichmentAdapter({
    liteLLMClient,
    logger: logger.child({ component: 'vocabulary_enrichment_adapter' })
  });
  const generationService = new VocabularyGenerationService({
    liteLLMClient,
    store,
    logger: logger.child({ component: 'generation_service' })
  });
  const worker = new ArticleProcessingWorker({
    store,
    pipeline: new ArticleProcessingPipeline({
      store,
      suggestionAdapter: enrichmentAdapter,
      logger: logger.child({ component: 'article_processing_pipeline' })
    }),
    logger,
    maxAttempts
  });
  const submittedWordWorker = new SubmittedWordWorker({
    store,
    generationService,
    logger: logger.child({ component: 'submitted_word_worker' }),
    maxAttempts,
    sourceLanguage: config.defaultSourceLanguage
  });
  const passageSegmentationWorker = new PassageSegmentationWorker({
    store,
    pipeline: new PassageSegmentationPipeline({
      store,
      liteLLMClient,
      suggestionAdapter: enrichmentAdapter,
      logger: logger.child({ component: 'passage_segmentation_pipeline' })
    }),
    logger: logger.child({ component: 'passage_segmentation_worker' }),
    maxAttempts
  });
  const passageEnrichmentWorker = new PassageEnrichmentWorker({
    store,
    pipeline: new PassageEnrichmentPipeline({
      store,
      liteLLMClient,
      logger: logger.child({ component: 'passage_enrichment_pipeline' })
    }),
    logger: logger.child({ component: 'passage_enrichment_worker' }),
    maxAttempts
  });

  const crawler = new ContentCrawler({
    store,
    liteLLMClient,
    config,
    rateLimiter: llmRateLimiter,
    logger: logger.child({ component: 'content_crawler' })
  });

  const curatedCollector = new CuratedCollector({
    store,
    liteLLMClient,
    config,
    rateLimiter: llmRateLimiter,
    logger: logger.child({ component: 'curated_collector' })
  });

  const steps = [
    ['article_worker_tick_failed', () => worker.runOnce()],
    ['passage_segmentation_worker_tick_failed', () => passageSegmentationWorker.runOnce()],
    ['passage_enrichment_worker_tick_failed', () => passageEnrichmentWorker.runOnce()],
    ['submitted_word_worker_tick_failed', () => submittedWordWorker.runOnce()],
    ['content_crawler_tick_failed', () => crawler.runIfDue()],
    ['curated_collector_tick_failed', () => curatedCollector.runIfDue()]
  ];

  let timer = null;
  let stopping = false;
  let currentTick = null;

  async function runTick() {
    for (const [failureEvent, step] of steps) {
      // Every step needs the LLM; while the gateway is down, leave queued jobs untouched so their
      // retry attempts are not burned (they resume when the circuit closes).
      if (llmRateLimiter.isCircuitOpen()) {
        return;
      }
      try {
        await step();
      } catch (error) {
        logger.error?.(failureEvent, { error });
      }
    }
  }

  function tick() {
    // A tick can outlast the interval (LLM calls), so never run two at once.
    if (stopping || currentTick) return;
    currentTick = runTick().finally(() => {
      currentTick = null;
    });
  }

  return {
    start() {
      logger.info?.('article_worker_started', { interval_ms: intervalMs });
      timer = setInterval(tick, intervalMs);
      tick();
    },
    /** Stops scheduling and resolves once the in-flight tick (if any) has finished. */
    async stop() {
      stopping = true;
      clearInterval(timer);
      await currentTick;
    }
  };
}
