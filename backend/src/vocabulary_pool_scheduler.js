import { createId } from './ids.js';

export class VocabularyPoolScheduler {
  constructor({
    store,
    generationService,
    config,
    logger = console,
    now = () => new Date()
  }) {
    this.store = store;
    this.generationService = generationService;
    this.config = config;
    this.logger = logger;
    this.now = now;
    this.timer = null;
    this.ownerId = createId('scheduler');
  }

  async runOnce({ targetLanguage = this.config.defaultTargetLanguage } = {}) {
    const now = this.now();
    const runDate = now.toISOString().slice(0, 10);
    const count = await this.store.countUsableWords({ targetLanguage });
    const poolMin = this.config.vocabPoolMinSize;
    const mode = count < poolMin ? 'fill' : 'daily_top_up';

    this.logger.debug?.('scheduler_run_evaluated', {
      target_language: targetLanguage,
      mode,
      pool_count: count,
      pool_min: poolMin
    });

    if (mode === 'daily_top_up') {
      if (now.getUTCHours() < this.config.vocabDailyGenerationHourUtc) {
        return { mode: 'idle', reason: 'before_daily_hour', count };
      }
      const alreadyRan = await this.store.hasGenerationRun({
        targetLanguage,
        mode,
        runDate
      });
      if (alreadyRan) {
        return { mode: 'idle', reason: 'daily_top_up_already_done', count };
      }
    }

    const requestedCount = mode === 'fill'
      ? Math.min(this.config.vocabGenerationBatchSize, poolMin - count)
      : this.config.vocabDailyGenerationCount;
    if (requestedCount <= 0) {
      return { mode: 'idle', reason: 'nothing_to_generate', count };
    }

    const locked = await this.store.acquireGenerationLock({
      targetLanguage,
      ownerId: this.ownerId,
      now,
      ttlSeconds: this.config.vocabSchedulerLockTtlSeconds
    });
    if (!locked) {
      this.logger.debug?.('scheduler_run_skipped', {
        target_language: targetLanguage,
        reason: 'locked'
      });
      return { mode: 'idle', reason: 'locked', count };
    }

    const startedAt = now.toISOString();
    try {
      this.logger.info?.('scheduler_generation_started', {
        target_language: targetLanguage,
        mode,
        requested_count: requestedCount
      });
      const generated = await this.generationService.generateAndStore({
        sourceLanguage: this.config.defaultSourceLanguage,
        targetLanguage,
        limit: requestedCount
      });
      await this.store.recordGenerationRun({
        targetLanguage,
        mode,
        status: 'success',
        requestedCount,
        insertedCount: generated.length,
        runDate,
        startedAt,
        finishedAt: this.now().toISOString()
      });
      this.logger.info?.('scheduler_generation_completed', {
        target_language: targetLanguage,
        mode,
        requested_count: requestedCount,
        inserted_count: generated.length
      });
      return { mode, requestedCount, insertedCount: generated.length, count };
    } catch (error) {
      await this.store.recordGenerationRun({
        targetLanguage,
        mode,
        status: 'failed',
        requestedCount,
        insertedCount: 0,
        errorMessage: error.message,
        runDate,
        startedAt,
        finishedAt: this.now().toISOString()
      });
      this.logger.error?.('scheduler_generation_failed', {
        target_language: targetLanguage,
        mode,
        error
      });
      return { mode, requestedCount, insertedCount: 0, failed: true, count };
    } finally {
      await this.store.releaseGenerationLock({
        targetLanguage,
        ownerId: this.ownerId
      });
    }
  }

  start() {
    if (this.timer) {
      return;
    }
    const intervalMs = this.config.vocabFillIntervalSeconds * 1000;
    this.logger.info?.('scheduler_started', { interval_seconds: this.config.vocabFillIntervalSeconds });
    this.timer = setInterval(() => {
      this.runOnce().catch((error) => {
        this.logger.error?.('scheduler_run_failed', { error });
      });
    }, intervalMs);
    this.timer.unref?.();
  }

  stop() {
    if (!this.timer) {
      return;
    }
    clearInterval(this.timer);
    this.timer = null;
    this.logger.info?.('scheduler_stopped');
  }
}
