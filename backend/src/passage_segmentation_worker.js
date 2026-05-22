export class PassageSegmentationWorker {
  constructor({ store, pipeline, logger = console, maxAttempts = 3 }) {
    this.store = store;
    this.pipeline = pipeline;
    this.logger = logger;
    this.maxAttempts = Math.max(1, maxAttempts);
  }

  async runOnce() {
    if (typeof this.store.claimNextPendingPassage !== 'function') {
      return { processed: 0 };
    }

    const passage = await this.store.claimNextPendingPassage();
    if (!passage) {
      return { processed: 0 };
    }

    try {
      const result = await this.pipeline.processPassage({ passageId: passage.id });

      if (!result.success) {
        const currentAttempts = (passage.attempt_count ?? 0) + 1;
        const shouldRetry = currentAttempts < this.maxAttempts;

        await this.store.updatePassage({
          passageId: passage.id,
          status: shouldRetry ? 'pending_segmentation' : 'failed',
          processing_error: result.error,
          attempt_count: currentAttempts
        });

        this.logger.error?.('passage_segmentation_worker_failed', {
          passage_id: passage.id,
          error: result.error,
          attempt: currentAttempts,
          retry_scheduled: shouldRetry
        });

        return { processed: 0, failed: 1, retry_scheduled: shouldRetry };
      }

      this.logger.info?.('passage_segmentation_worker_completed', {
        passage_id: passage.id,
        segment_count: result.segment_count
      });

      // Auto-queue enrichment after successful segmentation
      if (typeof this.store.updatePassageEnrichmentStatus === 'function') {
        await this.store.updatePassageEnrichmentStatus({ passageId: passage.id, enrichmentStatus: 'pending' });
      }

      return { processed: 1 };
    } catch (error) {
      await this.store.updatePassage({
        passageId: passage.id,
        status: 'failed',
        processing_error: `${error}`
      });

      this.logger.error?.('passage_segmentation_worker_error', {
        passage_id: passage.id,
        error
      });

      return { processed: 0, failed: 1 };
    }
  }
}
