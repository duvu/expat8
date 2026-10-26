import { extractArticleText, parseFeed } from './feed_parser.js';

const MIN_ARTICLE_CHARS = 400;
const MAX_FEED_BYTES = 2_000_000;
const ACCEPTED_LEVELS = new Set(['A2', 'B1', 'B2', 'C1']);
export const CRAWLER_ADMIN_ID = 'content-crawler';
const USER_AGENT = 'Mozilla/5.0 (compatible; Expat8Bot/1.0; +https://expat8.x51.vn)';

/**
 * Pulls fresh English articles from public RSS feeds, has the LLM grade each one (CEFR level, quality,
 * suitability) and queues the good ones for the normal article pipeline, which extracts vocabulary and
 * sentences into the shared pool. LLM use is bounded: at most `maxArticlesPerRun` assessments per run,
 * one every `intervalMinutes`, and every URL is remembered so nothing is graded twice.
 */
export class ContentCrawler {
  constructor({ store, liteLLMClient, config, logger = console, fetchImpl = fetch, rateLimiter = null, now = () => Date.now() }) {
    this.store = store;
    this.liteLLMClient = liteLLMClient;
    this.config = config;
    this.logger = logger;
    this.fetchImpl = fetchImpl;
    this.rateLimiter = rateLimiter;
    this.now = now;
    this.nextRunAt = 0;
    this.feedCursor = 0;
  }

  /** Runs when due; cheap no-op otherwise, so the worker can call it every tick. */
  async runIfDue() {
    if (!this.config.crawlerEnabled || this.config.crawlerFeeds.length === 0 || this.now() < this.nextRunAt) {
      return null;
    }
    if (this.rateLimiter?.isCircuitOpen?.()) {
      this.nextRunAt = this.now() + 10 * 60_000;
      return null;
    }
    const reserved = this.config.llmReservedRequestsPerHour ?? 0;
    if (this.rateLimiter && this.rateLimiter.remainingHourlyBudget() <= reserved + 15) {
      this.nextRunAt = this.now() + 10 * 60_000;
      this.logger.info?.('crawler_skipped_llm_budget_low');
      return null;
    }
    this.nextRunAt = this.now() + this.config.crawlerIntervalMinutes * 60_000;
    return this.runOnce();
  }

  async runOnce() {
    this.assessedThisRun = 0;
    const summary = { fetched: 0, assessed: 0, queued: 0, rejected: 0, skipped: 0, errors: 0 };
    const feeds = this.config.crawlerFeeds;
    const max = this.config.crawlerMaxArticlesPerRun;
    // Pages rejected before the LLM step are free, but still bound how many pages one run downloads.
    const maxFetched = max * 6;
    const exhausted = () => summary.assessed >= max || summary.fetched >= maxFetched;
    // Rotate the starting feed so one noisy feed cannot monopolise the per-run budget.
    const order = feeds.map((_, index) => feeds[(this.feedCursor + index) % feeds.length]);
    this.feedCursor = (this.feedCursor + 1) % feeds.length;

    for (const feedUrl of order) {
      if (exhausted()) {
        break;
      }
      let items;
      try {
        items = parseFeed(await this.#fetchText(feedUrl));
      } catch (error) {
        summary.errors += 1;
        this.logger.warn?.('crawler_feed_failed', { feed_url: feedUrl, error: error.message });
        continue;
      }
      for (const item of items.slice(0, 15)) {
        if (exhausted()) {
          break;
        }
        if (await this.store.hasCrawledUrl({ url: item.link })) {
          summary.skipped += 1;
          continue;
        }
        summary.fetched += 1;
        try {
          const outcome = await this.#evaluate({ feedUrl, item });
          summary[outcome] += 1;
        } catch (error) {
          // Transient (network/LLM): leave the URL unrecorded so a later run retries it.
          summary.errors += 1;
          this.logger.warn?.('crawler_article_failed', { url: item.link, error: error.message });
          if (/LiteLLM|gateway unavailable/i.test(error.message)) {
            summary.assessed = this.assessedThisRun;
            return this.#finish(summary);
          }
        } finally {
          summary.assessed = this.assessedThisRun;
        }
      }
    }
    return this.#finish(summary);
  }

  #finish(summary) {
    this.logger.info?.('crawler_run_completed', summary);
    return summary;
  }

  async #evaluate({ feedUrl, item }) {
    const record = (status, extra = {}) =>
      this.store.recordCrawledUrl({ url: item.link, feedUrl, status, ...extra });

    let text = '';
    try {
      text = extractArticleText(await this.#fetchText(item.link));
    } catch (error) {
      this.logger.debug?.('crawler_page_unreachable', { url: item.link, error: error.message });
    }
    if (text.length < MIN_ARTICLE_CHARS) {
      await record('rejected', { reason: 'too_short_or_unreadable' });
      return 'rejected';
    }

    this.assessedThisRun += 1;
    const assessment = await this.liteLLMClient.assessArticle({ title: item.title, text });
    const level = assessment.cefr_level;
    const accepted =
      assessment.suitable && assessment.quality >= this.config.crawlerMinArticleQuality && ACCEPTED_LEVELS.has(level);
    if (!accepted) {
      await record('rejected', {
        reason: assessment.reason ?? 'not_suitable',
        level,
        quality: assessment.quality
      });
      return 'rejected';
    }

    // Admin-owned article; the processing worker publishes it automatically once extraction succeeds.
    const article = await this.store.createAdminArticle({
      adminUserId: CRAWLER_ADMIN_ID,
      title: item.title.slice(0, 300),
      sourceUrl: item.link,
      language: 'en',
      rawText: text,
      visibility: 'private'
    });
    await record('queued', { level, quality: assessment.quality, articleId: article.id });
    this.logger.info?.('crawler_article_queued', {
      url: item.link,
      article_id: article.id,
      cefr_level: level,
      quality: assessment.quality
    });
    return 'queued';
  }

  async #fetchText(url) {
    const response = await this.fetchImpl(url, {
      signal: AbortSignal.timeout(15_000),
      redirect: 'follow',
      headers: { 'user-agent': USER_AGENT, accept: 'text/html,application/xhtml+xml,application/xml,text/xml' }
    });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return (await response.text()).slice(0, MAX_FEED_BYTES);
  }
}
