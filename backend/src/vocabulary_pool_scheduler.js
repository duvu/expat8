import { createId } from './ids.js';
import { getProficiencyProfile } from './proficiency.js';

export class VocabularyPoolScheduler {
  constructor({ store, generationService, config, logger = console, now = () => new Date(), rateLimiter = null }) {
    this.store = store;
    this.generationService = generationService;
    this.config = config;
    this.logger = logger;
    this.now = now;
    this.rateLimiter = rateLimiter;
    this.timer = null;
    this.ownerId = createId('scheduler');
    // Consecutive runs that added nothing (or failed); drives exponential backoff so a stuck level
    // or a throttled gateway is not retried every minute.
    this.emptyRuns = 0;
    this.notBefore = 0;
  }

  async runOnce({ targetLanguage = this.config.defaultTargetLanguage } = {}) {
    const now = this.now();
    const runDate = now.toISOString().slice(0, 10);
    if (now.getTime() < this.notBefore) {
      return { mode: 'idle', reason: 'backing_off' };
    }
    if (this.rateLimiter?.isCircuitOpen?.()) {
      return { mode: 'idle', reason: 'llm_unavailable' };
    }
    if (this.#budgetLow()) {
      return { mode: 'idle', reason: 'llm_budget_low' };
    }

    const profile = getProficiencyProfile({ language: targetLanguage });
    const counts = await this.store.countWordsByLevel({ targetLanguage });
    const count = Object.values(counts).reduce((sum, value) => sum + value, 0);
    const plan = planLevelFill({ profile, counts, config: this.config });
    const mode = plan.deficit > 0 ? 'fill' : 'daily_top_up';

    this.logger.debug?.('scheduler_run_evaluated', {
      target_language: targetLanguage,
      mode,
      cefr_level: plan.level,
      pool_count: count,
      level_counts: counts,
      level_deficit: plan.deficit
    });

    if (mode === 'daily_top_up') {
      if (now.getUTCHours() < this.config.vocabDailyGenerationHourUtc) {
        return { mode: 'idle', reason: 'before_daily_hour', count };
      }
      const alreadyRan = await this.store.hasGenerationRun({ targetLanguage, mode, runDate });
      if (alreadyRan) {
        return { mode: 'idle', reason: 'daily_top_up_already_done', count };
      }
    }

    const requestedCount =
      mode === 'fill'
        ? Math.min(this.config.vocabGenerationBatchSize, plan.deficit)
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
      this.logger.debug?.('scheduler_run_skipped', { target_language: targetLanguage, reason: 'locked' });
      return { mode: 'idle', reason: 'locked', count };
    }

    const startedAt = now.toISOString();
    try {
      this.logger.info?.('scheduler_generation_started', {
        target_language: targetLanguage,
        mode,
        cefr_level: plan.level,
        requested_count: requestedCount
      });
      const avoidTerms = await this.store.sampleWordTerms({ targetLanguage, level: plan.level, limit: 150 });
      const generated = await this.generationService.generateAndStore({
        sourceLanguage: this.config.defaultSourceLanguage,
        targetLanguage,
        limit: requestedCount,
        difficultyLevel: plan.level,
        avoidTerms
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
      this.#recordOutcome({ productive: generated.length > 0 });
      this.logger.info?.('scheduler_generation_completed', {
        target_language: targetLanguage,
        mode,
        cefr_level: plan.level,
        requested_count: requestedCount,
        inserted_count: generated.length,
        next_run_delay_seconds: this.#delaySeconds()
      });
      return { mode, level: plan.level, requestedCount, insertedCount: generated.length, count };
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
      this.#recordOutcome({ productive: false });
      this.logger.error?.('scheduler_generation_failed', {
        target_language: targetLanguage,
        mode,
        cefr_level: plan.level,
        error,
        next_run_delay_seconds: this.#delaySeconds()
      });
      return { mode, level: plan.level, requestedCount, insertedCount: 0, failed: true, count };
    } finally {
      await this.store.releaseGenerationLock({ targetLanguage, ownerId: this.ownerId });
    }
  }

  #budgetLow() {
    if (!this.rateLimiter) {
      return false;
    }
    return this.rateLimiter.remainingHourlyBudget() <= (this.config.llmReservedRequestsPerHour ?? 0);
  }

  #recordOutcome({ productive }) {
    this.emptyRuns = productive ? 0 : this.emptyRuns + 1;
    this.notBefore = this.emptyRuns === 0 ? 0 : this.now().getTime() + this.#delaySeconds() * 1000;
  }

  #delaySeconds() {
    if (this.emptyRuns === 0) {
      return 0;
    }
    const base = Math.max(1, this.config.vocabFillIntervalSeconds ?? 60);
    return Math.min(this.config.vocabMaxBackoffSeconds ?? 1800, base * 2 ** this.emptyRuns);
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

/**
 * Chooses which level to generate next. Each level has a target size (config.vocabLevelTargets, or an
 * even split of vocabPoolMinSize for scales without explicit targets); the level furthest below its
 * target wins, higher levels first on ties. With every target met, the level with the lowest
 * fill ratio gets the daily top-up.
 */
export function planLevelFill({ profile, counts, config }) {
  const explicit = config.vocabLevelTargets ?? {};
  const hasExplicit = profile.levels.some((level) => explicit[level] !== undefined);
  const even = Math.ceil((config.vocabPoolMinSize ?? 0) / profile.levels.length);
  const targets = profile.levels
    .map((level) => ({ level, target: hasExplicit ? (explicit[level] ?? 0) : even, count: counts[level] ?? 0 }))
    .filter((entry) => entry.target > 0);
  if (targets.length === 0) {
    return { level: profile.defaultLevel, deficit: 0 };
  }
  const deficient = targets
    .map((entry) => ({ ...entry, deficit: entry.target - entry.count }))
    .filter((entry) => entry.deficit > 0)
    .sort((a, b) => b.deficit - a.deficit || profile.levels.indexOf(b.level) - profile.levels.indexOf(a.level));
  if (deficient.length > 0) {
    return { level: deficient[0].level, deficit: deficient[0].deficit };
  }
  const lowest = [...targets].sort((a, b) => a.count / a.target - b.count / b.target)[0];
  return { level: lowest.level, deficit: 0 };
}
