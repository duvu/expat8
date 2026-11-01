import { extractArticleText, parseFeed } from './feed_parser.js';

const MAX_FEED_BYTES = 2_000_000;
// Per language: which levels make good study material, and how long a page must be to be an article
// (Chinese packs more meaning into fewer characters).
const LANGUAGES = {
  en: { acceptedLevels: new Set(['A2', 'B1', 'B2', 'C1']), minChars: 400 },
  // Mainland news is mostly above HSK6 ("BEYOND"); it is still good reading for advanced learners, and
  // vocabulary extraction picks HSK-level words from it.
  zh: { acceptedLevels: new Set(['HSK3', 'HSK4', 'HSK5', 'HSK6', 'BEYOND']), minChars: 250 }
};
// A run queues up to `crawlerMaxArticlesPerRun` articles per language; these bound the work (and the LLM
// calls) spent finding them when many candidates are unsuitable.
const ASSESSMENTS_PER_ARTICLE = 4;
const PAGES_PER_ARTICLE = 12;
export const CRAWLER_ADMIN_ID = 'content-crawler';
const USER_AGENT = 'Mozilla/5.0 (compatible; Expat8Bot/1.0; +https://expat8.x51.vn)';

/**
 * Pulls fresh articles (English and Chinese) from public RSS feeds, has the LLM grade each one (CEFR/HSK
 * level, quality, suitability) and queues the good ones for the normal article pipeline, which extracts
 * vocabulary and sentences into the shared pool. LLM use is bounded: per language, at most
 * `maxArticlesPerRun` articles are queued (and a few times as many assessed) per run, one run every
 * `intervalMinutes`, and every URL is remembered so nothing is graded twice.
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
    this.feedCursors = {};
  }

  /** Runs when due; cheap no-op otherwise, so the worker can call it every tick. */
  async runIfDue() {
    if (!this.config.crawlerEnabled || !this.#hasFeeds() || this.now() < this.nextRunAt) {
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

  #hasFeeds() {
    return Object.values(this.config.crawlerFeeds).some((urls) => urls.length > 0);
  }

  async runOnce() {
    const summary = { fetched: 0, assessed: 0, queued: 0, rejected: 0, skipped: 0, errors: 0 };
    for (const [language, feeds] of Object.entries(this.config.crawlerFeeds)) {
      if (feeds.length === 0 || !LANGUAGES[language]) {
        continue;
      }
      // false = the LLM gateway is down: no point trying the next language.
      if (!(await this.#crawlLanguage(language, feeds, summary))) {
        break;
      }
    }
    return this.#finish(summary);
  }

  async #crawlLanguage(language, feeds, summary) {
    const run = { assessed: 0, queued: 0, fetched: 0 };
    const max = this.config.crawlerMaxArticlesPerRun;
    const exhausted = () =>
      run.queued >= max || run.assessed >= max * ASSESSMENTS_PER_ARTICLE || run.fetched >= max * PAGES_PER_ARTICLE;
    const total = (outcome) => {
      summary[outcome] += 1;
    };
    // Rotate the starting feed so one noisy feed cannot monopolise the per-run budget.
    const cursor = this.feedCursors[language] ?? 0;
    const order = feeds.map((_, index) => feeds[(cursor + index) % feeds.length]);
    this.feedCursors[language] = (cursor + 1) % feeds.length;

    try {
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
          run.fetched += 1;
          summary.fetched += 1;
          try {
            const outcome = await this.#evaluate({ feedUrl, item, language, run });
            total(outcome);
            if (outcome === 'queued') {
              run.queued += 1;
            }
          } catch (error) {
            // Transient (network/LLM): leave the URL unrecorded so a later run retries it.
            summary.errors += 1;
            this.logger.warn?.('crawler_article_failed', { url: item.link, error: error.message });
            if (/LiteLLM|gateway unavailable/i.test(error.message)) {
              return false;
            }
          }
        }
      }
      return true;
    } finally {
      summary.assessed += run.assessed;
    }
  }

  #finish(summary) {
    this.logger.info?.('crawler_run_completed', summary);
    return summary;
  }

  async #evaluate({ feedUrl, item, language, run }) {
    const { acceptedLevels, minChars } = LANGUAGES[language];
    const record = (status, extra = {}) =>
      this.store.recordCrawledUrl({ url: item.link, feedUrl, status, ...extra });

    let text = '';
    try {
      text = extractArticleText(await this.#fetchText(item.link));
    } catch (error) {
      this.logger.debug?.('crawler_page_unreachable', { url: item.link, error: error.message });
    }
    if (text.length < minChars) {
      await record('rejected', { reason: 'too_short_or_unreadable' });
      return 'rejected';
    }

    run.assessed += 1;
    const assessment = await this.liteLLMClient.assessArticle({ title: item.title, text, language });
    const level = assessment.level;
    const accepted =
      assessment.suitable && assessment.quality >= this.config.crawlerMinArticleQuality && acceptedLevels.has(level);
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
      language,
      rawText: text,
      visibility: 'private'
    });
    await record('queued', { level, quality: assessment.quality, articleId: article.id });
    this.logger.info?.('crawler_article_queued', {
      url: item.link,
      article_id: article.id,
      language,
      // Not `level`: that key is the logger's own severity field.
      article_level: level,
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
