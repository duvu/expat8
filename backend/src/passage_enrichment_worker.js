export class PassageEnrichmentWorker {
  constructor({ store, pipeline, logger = console, maxAttempts = 3 }) {
    this.store = store;
    this.pipeline = pipeline;
    this.logger = logger;
    this.maxAttempts = Math.max(1, maxAttempts);
  }

  async runOnce() {
    if (typeof this.store.claimNextPendingEnrichment !== 'function') {
      return { processed: 0 };
    }

    const passage = await this.store.claimNextPendingEnrichment();
    if (!passage) {
      return { processed: 0 };
    }

    try {
      const result = await this.pipeline.processPassage({ passageId: passage.id });

      if (!result.success) {
        const currentAttempts = (passage.enrichment_attempt_count ?? 0) + 1;
        const shouldRetry = currentAttempts < this.maxAttempts;

        await this.store.updatePassageEnrichmentStatus({
          passageId: passage.id,
          enrichmentStatus: shouldRetry ? 'pending' : 'failed',
          enrichment_attempt_count: currentAttempts
        });

        this.logger.error?.('passage_enrichment_worker_failed', {
          passage_id: passage.id,
          error: result.error,
          attempt: currentAttempts,
          retry_scheduled: shouldRetry
        });

        return { processed: 0, failed: 1, retry_scheduled: shouldRetry };
      }

      this.logger.info?.('passage_enrichment_worker_completed', {
        passage_id: passage.id,
        segment_count: result.segment_count
      });

      return { processed: 1 };
    } catch (error) {
      await this.store.updatePassageEnrichmentStatus({
        passageId: passage.id,
        enrichmentStatus: 'failed'
      });

      this.logger.error?.('passage_enrichment_worker_error', {
        passage_id: passage.id,
        error
      });

      return { processed: 0, failed: 1 };
    }
  }
}
