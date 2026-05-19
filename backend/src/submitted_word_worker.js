export class SubmittedWordWorker {
  constructor({
    store,
    generationService,
    logger = console,
    maxAttempts = 3,
    sourceLanguage = 'vi'
  }) {
    this.store = store;
    this.generationService = generationService;
    this.logger = logger;
    this.maxAttempts = Math.max(1, maxAttempts);
    this.sourceLanguage = sourceLanguage;
  }

  async runOnce() {
    if (
      typeof this.store.claimNextSubmittedWordJob !== 'function' ||
      typeof this.store.getUserSubmittedWordById !== 'function'
    ) {
      return { processed: 0 };
    }

    const job = await this.store.claimNextSubmittedWordJob();
    if (!job) {
      return { processed: 0 };
    }

    const submission = await this.store.getUserSubmittedWordById({ submissionId: job.submission_id });
    if (!submission) {
      await this.store.failSubmittedWordJob?.({ jobId: job.id, errorMessage: 'submission_not_found' });
      return { processed: 0, failed: 1 };
    }

    try {
      const result = await this.generationService.generateSubmittedWord({
        sourceLanguage: this.sourceLanguage,
        targetLanguage: submission.language,
        term: submission.submitted_term
      });
      await this.store.completeSubmittedWordJob({
        jobId: job.id,
        resolvedWordId: result.word.id,
        resolutionType: result.resolutionType
      });
      this.logger.info?.('submitted_word_job_completed', {
        job_id: job.id,
        submission_id: submission.id,
        resolution_type: result.resolutionType,
        resolved_word_id: result.word.id
      });
      return { processed: 1 };
    } catch (error) {
      const shouldRetry = Number(job.attempt_count ?? 0) < this.maxAttempts;
      const errorMessage = `${error?.message ?? error}`;
      if (shouldRetry) {
        await this.store.retrySubmittedWordJob?.({ jobId: job.id, errorMessage });
      } else {
        await this.store.failSubmittedWordJob?.({ jobId: job.id, errorMessage });
      }
      this.logger.error?.('submitted_word_job_failed', {
        job_id: job.id,
        submission_id: submission.id,
        attempt_count: job.attempt_count,
        max_attempts: this.maxAttempts,
        retry_scheduled: shouldRetry,
        error
      });
      return {
        processed: 0,
        failed: 1,
        retry_scheduled: shouldRetry,
        dead_lettered: shouldRetry ? 0 : 1
      };
    }
  }
}
