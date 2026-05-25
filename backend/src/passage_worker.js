/**
 * Generic passage worker that drives a claim → process → update loop.
 *
 * Subclasses supply configuration via super() to avoid duplicating the shared
 * loop in PassageSegmentationWorker and PassageEnrichmentWorker.
 */
export class PassageWorker {
  /**
   * @param {object} opts
   * @param {object} opts.store
   * @param {object} opts.pipeline - must have processPassage({ passageId })
   * @param {object} opts.logger
   * @param {number} opts.maxAttempts
   * @param {string} opts.claimMethod - store method name to claim next item
   * @param {string} opts.attemptField - field on the claimed passage for attempt count
   * @param {string} opts.logPrefix - e.g. 'passage_segmentation_worker'
   * @param {Function} opts.updateFailure - async (store, { passageId, retry, attemptCount, error }) => void
   * @param {Function} opts.updateError  - async (store, { passageId, error }) => void
   * @param {Function} [opts.onSuccess]  - optional async (store, passage, result) => void
   */
  constructor({
    store,
    pipeline,
    logger = console,
    maxAttempts = 3,
    claimMethod,
    attemptField,
    logPrefix,
    updateFailure,
    updateError,
    onSuccess
  }) {
    this.store = store;
    this.pipeline = pipeline;
    this.logger = logger;
    this.maxAttempts = Math.max(1, maxAttempts);
    this.claimMethod = claimMethod;
    this.attemptField = attemptField;
    this.logPrefix = logPrefix;
    this.updateFailure = updateFailure;
    this.updateError = updateError;
    this.onSuccess = onSuccess ?? null;
  }

  async runOnce() {
    if (typeof this.store[this.claimMethod] !== 'function') {
      return { processed: 0 };
    }

    const passage = await this.store[this.claimMethod]();
    if (!passage) {
      return { processed: 0 };
    }

    try {
      const result = await this.pipeline.processPassage({ passageId: passage.id });

      if (!result.success) {
        const currentAttempts = (passage[this.attemptField] ?? 0) + 1;
        const shouldRetry = currentAttempts < this.maxAttempts;

        await this.updateFailure(this.store, {
          passageId: passage.id,
          retry: shouldRetry,
          attemptCount: currentAttempts,
          error: result.error
        });

        this.logger.error?.(`${this.logPrefix}_failed`, {
          passage_id: passage.id,
          error: result.error,
          attempt: currentAttempts,
          retry_scheduled: shouldRetry
        });

        return { processed: 0, failed: 1, retry_scheduled: shouldRetry };
      }

      this.logger.info?.(`${this.logPrefix}_completed`, {
        passage_id: passage.id,
        segment_count: result.segment_count
      });

      if (this.onSuccess) {
        await this.onSuccess(this.store, passage, result);
      }

      return { processed: 1 };
    } catch (error) {
      await this.updateError(this.store, { passageId: passage.id, error });

      this.logger.error?.(`${this.logPrefix}_error`, {
        passage_id: passage.id,
        error
      });

      return { processed: 0, failed: 1 };
    }
  }
}
