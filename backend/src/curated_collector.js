import { CURATED_TOPICS } from './curated_topics.js';

const MIN_TEXT_CHARS = 1200;
const MAX_TEXT_CHARS = 6000;
const MAX_CANDIDATES_PER_RUN = 6;
const ACCEPTED_LEVELS = new Set(['A2', 'B1', 'B2', 'C1', 'C2']);
const USER_AGENT = 'Expat8Bot/1.0 (https://expat8.x51.vn)';
const TAIL_SECTIONS = /^(see also|references|notes|footnotes|sources|bibliography|further reading|external links|citations)$/i;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Builds a reading collection of speeches, biographies and history stories from Wikipedia: a backfill
 * of `curatedInitialCount` articles first (one every `curatedBackfillIntervalMinutes`, so LLM load stays
 * spread out), then one new article every `curatedIntervalDays`. Each candidate is graded by the LLM
 * (level and quality) and queued into the normal article pipeline. Progress is derived from the
 * `crawled_urls` table, so it survives restarts and never repeats a topic.
 */
export class CuratedCollector {
  constructor({
    store,
    liteLLMClient,
    config,
    logger = console,
    fetchImpl = fetch,
    rateLimiter = null,
    now = () => Date.now(),
    topics = CURATED_TOPICS
  }) {
    this.store = store;
    this.liteLLMClient = liteLLMClient;
    this.config = config;
    this.logger = logger;
    this.fetchImpl = fetchImpl;
    this.rateLimiter = rateLimiter;
    this.now = now;
    this.topics = topics;
    this.nextCheckAt = 0;
  }

  /** Cheap no-op unless a collection run is due; safe to call every worker tick. */
  async runIfDue() {
    if (!this.config.curatedEnabled || this.now() < this.nextCheckAt) {
      return null;
    }
    const stats = await this.store.curatedStats();
    const backfilling = stats.queued < this.config.curatedInitialCount;
    const intervalMs = backfilling
      ? this.config.curatedBackfillIntervalMinutes * 60_000
      : this.config.curatedIntervalDays * DAY_MS;
    const lastAt = stats.lastQueuedAt ? Date.parse(stats.lastQueuedAt) : 0;
    const dueAt = Math.max(lastAt + intervalMs, this.nextCheckAt);
    if (this.now() < dueAt) {
      this.nextCheckAt = Math.min(dueAt, this.now() + 10 * 60_000);
      return null;
    }
    if (this.rateLimiter?.isCircuitOpen?.()) {
      this.nextCheckAt = this.now() + 10 * 60_000;
      return null;
    }
    const reserved = this.config.llmReservedRequestsPerHour ?? 0;
    if (this.rateLimiter && this.rateLimiter.remainingHourlyBudget() <= reserved + 15) {
      this.nextCheckAt = this.now() + 10 * 60_000;
      this.logger.info?.('curated_collector_skipped_llm_budget_low');
      return null;
    }
    const result = await this.collectOne();
    // A failed/empty run backs off instead of hammering Wikipedia and the LLM every tick.
    this.nextCheckAt = this.now() + (result.queued ? 60_000 : 30 * 60_000);
    return { ...result, backfilling, collected: stats.queued + result.queued };
  }

  /** Tries candidates in order until one passes grading; returns what happened. */
  async collectOne() {
    const summary = { queued: 0, rejected: 0, errors: 0, skipped: 0 };
    let tried = 0;
    await this.#extendTopicsIfExhausted();
    for (const topic of this.topics) {
      if (summary.queued > 0 || tried >= MAX_CANDIDATES_PER_RUN) {
        break;
      }
      if (await this.#usedOnAnyHost(topic)) {
        summary.skipped += 1;
        continue;
      }
      const page = await this.#fetchTopic(topic).catch((error) => {
        summary.errors += 1;
        this.logger.warn?.('curated_fetch_failed', { title: topic.title, error: error.message });
        return null;
      });
      if (!page) {
        continue;
      }
      if (await this.store.hasCrawledUrl({ url: page.url })) {
        summary.skipped += 1; // topic redirected to a page we already evaluated
        continue;
      }
      tried += 1;
      const feedUrl = `curated:${topic.category}`;
      if (page.text.length < MIN_TEXT_CHARS) {
        await this.store.recordCrawledUrl({ url: page.url, feedUrl, status: 'rejected', reason: 'too_short' });
        summary.rejected += 1;
        continue;
      }
      let assessment;
      try {
        assessment = await this.liteLLMClient.assessArticle({ title: page.title, text: page.text });
      } catch (error) {
        // LLM unavailable/throttled: leave unrecorded so the same topic is retried next run.
        summary.errors += 1;
        this.logger.warn?.('curated_assess_failed', { title: page.title, error: error.message });
        break;
      }
      // Curated topics are pre-vetted, so `suitable` is not enforced; level and quality still are.
      if (!ACCEPTED_LEVELS.has(assessment.level) || assessment.quality < this.config.crawlerMinArticleQuality) {
        await this.store.recordCrawledUrl({
          url: page.url,
          feedUrl,
          status: 'rejected',
          reason: assessment.reason ?? 'level_or_quality',
          level: assessment.level,
          quality: assessment.quality
        });
        summary.rejected += 1;
        continue;
      }
      const article = await this.store.createArticle({
        userId: null,
        title: page.title.slice(0, 300),
        sourceUrl: page.url,
        language: 'en',
        rawText: page.text,
        visibility: 'private'
      });
      await this.store.recordCrawledUrl({
        url: page.url,
        feedUrl,
        status: 'queued',
        level: assessment.level,
        quality: assessment.quality,
        articleId: article.id
      });
      summary.queued += 1;
      this.logger.info?.('curated_article_queued', {
        category: topic.category,
        title: page.title,
        url: page.url,
        cefr_level: assessment.level,
        quality: assessment.quality
      });
    }
    this.logger.info?.('curated_collect_completed', summary);
    return summary;
  }

  /** When every built-in topic has been used, ask the LLM for fresh Wikipedia titles per category. */
  async #extendTopicsIfExhausted() {
    if (typeof this.liteLLMClient.suggestWikipediaTitles !== 'function') {
      return;
    }
    const known = new Set(this.topics.map((topic) => topic.title.toLowerCase()));
    for (const topic of this.topics) {
      const url = `https://${topic.hosts[0]}/wiki/${encodeURIComponent(topic.title.replace(/ /g, '_'))}`;
      if (!(await this.store.hasCrawledUrl({ url })) && !(await this.#usedOnAnyHost(topic))) {
        return;
      }
    }
    for (const category of ['speech', 'biography', 'history']) {
      try {
        const titles = await this.liteLLMClient.suggestWikipediaTitles({ category, count: 8, avoid: [...known] });
        for (const title of titles) {
          if (!known.has(title.toLowerCase())) {
            known.add(title.toLowerCase());
            this.topics.push({
              category,
              title,
              hosts: category === 'speech' ? ['en.wikipedia.org'] : ['simple.wikipedia.org', 'en.wikipedia.org']
            });
          }
        }
      } catch (error) {
        this.logger.warn?.('curated_topic_suggestion_failed', { category, error: error.message });
      }
    }
  }

  async #usedOnAnyHost(topic) {
    for (const host of topic.hosts) {
      const url = `https://${host}/wiki/${encodeURIComponent(topic.title.replace(/ /g, '_'))}`;
      if (await this.store.hasCrawledUrl({ url })) {
        return true;
      }
    }
    return false;
  }

  async #fetchTopic(topic) {
    for (const host of topic.hosts) {
      const page = await this.#fetchExtract(host, topic.title);
      if (page && page.text.length >= MIN_TEXT_CHARS) {
        return page;
      }
      // Simple English articles are often stubs; fall through to the next host.
      if (page && host === topic.hosts.at(-1)) {
        return page;
      }
    }
    return null;
  }

  async #fetchExtract(host, title) {
    const url =
      `https://${host}/w/api.php?action=query&prop=extracts&explaintext=1&exsectionformat=plain` +
      `&redirects=1&format=json&titles=${encodeURIComponent(title)}`;
    const response = await this.fetchImpl(url, {
      signal: AbortSignal.timeout(15_000),
      headers: { 'user-agent': USER_AGENT }
    });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const page = Object.values((await response.json())?.query?.pages ?? {})[0];
    if (!page || 'missing' in page || !page.extract) {
      return null;
    }
    return {
      title: page.title,
      text: cleanExtract(page.extract),
      url: `https://${host}/wiki/${encodeURIComponent(String(page.title).replace(/ /g, '_'))}`
    };
  }
}

/** Drops headings and trailing reference sections, keeps prose paragraphs up to MAX_TEXT_CHARS. */
export function cleanExtract(extract) {
  const paragraphs = [];
  let length = 0;
  for (const raw of String(extract).split('\n')) {
    const line = raw.trim();
    if (!line) {
      continue;
    }
    if (TAIL_SECTIONS.test(line)) {
      break;
    }
    const looksLikeProse = line.length >= 80 || /[.!?”"]$/.test(line);
    if (!looksLikeProse || /^==/.test(line)) {
      continue;
    }
    if (length + line.length > MAX_TEXT_CHARS) {
      break;
    }
    paragraphs.push(line);
    length += line.length + 2;
  }
  return paragraphs.join('\n\n');
}
