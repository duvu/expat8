export class ArticleProcessingWorker {
  constructor({ store, pipeline, logger = console, maxAttempts = 3 }) {
    this.store = store;
    this.pipeline = pipeline;
    this.logger = logger;
    this.maxAttempts = Math.max(1, maxAttempts);
  }

  async runOnce() {
    if (typeof this.store.claimNextArticleProcessingJob !== 'function') {
      return { processed: 0 };
    }

    if (typeof this.store.countPendingArticleJobs === 'function') {
      const pendingCount = await this.store.countPendingArticleJobs();
      this.logger.info?.('article_processing_backlog', { pending_count: pendingCount });
    }

    const job = await this.store.claimNextArticleProcessingJob();
    if (!job) {
      return { processed: 0 };
    }

    try {
      const result = await this.pipeline.processArticle({ articleId: job.article_id });
      const terminalStatus = result.success
        ? resolveSuccessStatus({ article: await this.store.getArticleById({ articleId: job.article_id }) })
        : 'processing_failed';

      await this.store.completeArticleProcessingJob({
        jobId: job.id,
        status: terminalStatus,
        errorMessage: result.success ? null : result.classification
      });
      this.logger.info?.('article_processing_job_completed', {
        job_id: job.id,
        article_id: job.article_id,
        extracted_count: result.extracted_count,
        accepted_count: result.accepted_count,
        rejected_count: result.rejected_count,
        status: terminalStatus
      });
      return { processed: 1 };
    } catch (error) {
      const shouldRetry = Number(job.attempt_count ?? 0) < this.maxAttempts;
      await this.store.completeArticleProcessingJob({
        jobId: job.id,
        status: shouldRetry ? 'pending_processing' : 'dead_lettered',
        errorMessage: `${error}`
      });
      this.logger.error?.('article_processing_job_failed', {
        job_id: job.id,
        article_id: job.article_id,
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

function resolveSuccessStatus({ article }) {
  if (!article) {
    return 'processed';
  }
  return article.created_by_admin_id ? 'pending_review' : 'processed';
}
