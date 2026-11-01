import assert from 'node:assert/strict';
import test from 'node:test';

import { ContentCrawler } from '../src/content_crawler.js';
import { extractArticleText, parseFeed } from '../src/feed_parser.js';
import { WordStore } from '../src/word_store.js';

const RSS = `<?xml version="1.0"?><rss><channel>
<item><title><![CDATA[Cities plan &amp; build greener streets]]></title><link>https://example.com/a</link><description>Short.</description><pubDate>Mon, 01 Jan 2026 00:00:00 GMT</pubDate></item>
<item><title>Second story</title><link>https://example.com/b</link></item>
<item><title>No link</title></item>
</channel></rss>`;

const PROSE =
  'Local councils across the country are planning to build greener streets so that residents can walk and cycle more safely. ';
const ARTICLE_HTML = `<html><body><nav><p>Menu menu menu menu menu menu menu menu menu menu menu menu.</p></nav>
<article>${Array.from({ length: 6 }, () => `<p>${PROSE}</p>`).join('')}<p>Subscribe to our newsletter for more stories every day of the week.</p></article>
<script>var x = "<p>ignored paragraph that should never appear in the extracted text at all.</p>";</script></body></html>`;

function crawlerConfig(overrides = {}) {
  return {
    crawlerEnabled: true,
    crawlerFeeds: { en: ['https://feed.example/rss'], zh: [] },
    crawlerIntervalMinutes: 60,
    crawlerMaxArticlesPerRun: 3,
    crawlerMinArticleQuality: 3,
    ...overrides
  };
}

function fakeFetch(pages) {
  const calls = [];
  const impl = async (url) => {
    calls.push(url);
    const body = pages[url];
    return body === undefined
      ? { ok: false, status: 404, text: async () => '' }
      : { ok: true, status: 200, text: async () => body };
  };
  impl.calls = calls;
  return impl;
}

test('parseFeed reads RSS items, decodes entities and drops entries without links', () => {
  const items = parseFeed(RSS);
  assert.equal(items.length, 2);
  assert.equal(items[0].title, 'Cities plan & build greener streets');
  assert.equal(items[0].link, 'https://example.com/a');
});

test('extractArticleText keeps prose paragraphs and drops navigation, scripts and boilerplate', () => {
  const text = extractArticleText(ARTICLE_HTML);
  assert.match(text, /greener streets/);
  assert.doesNotMatch(text, /Menu menu|ignored paragraph|newsletter/);
});

test('queues an article the LLM rates suitable and remembers rejected ones', async () => {
  const store = new WordStore({ seed: false });
  const fetchImpl = fakeFetch({
    'https://feed.example/rss': RSS,
    'https://example.com/a': ARTICLE_HTML,
    'https://example.com/b': ARTICLE_HTML
  });
  const assessments = [
    { level: 'B1', quality: 4, suitable: true },
    { level: 'A1', quality: 5, suitable: true }
  ];
  const crawler = new ContentCrawler({
    store,
    config: crawlerConfig(),
    fetchImpl,
    liteLLMClient: { assessArticle: async () => assessments.shift() },
    logger: {}
  });

  const summary = await crawler.runOnce();

  assert.deepEqual({ queued: summary.queued, rejected: summary.rejected }, { queued: 1, rejected: 1 });
  const queued = [...store.articlesById.values()];
  assert.equal(queued.length, 1);
  assert.equal(queued[0].source_url, 'https://example.com/a');
  assert.equal(queued[0].owner_user_id, null);
  assert.equal(queued[0].created_by_admin_id, 'content-crawler');
  assert.equal(queued[0].visibility, 'private');

  const second = await crawler.runOnce();
  assert.equal(second.skipped, 2);
  assert.equal(second.queued, 0);
});

test('does not record a URL when the LLM is unavailable so it is retried later', async () => {
  const store = new WordStore({ seed: false });
  const crawler = new ContentCrawler({
    store,
    config: crawlerConfig(),
    fetchImpl: fakeFetch({ 'https://feed.example/rss': RSS, 'https://example.com/a': ARTICLE_HTML }),
    liteLLMClient: {
      assessArticle: async () => {
        throw new Error('LiteLLM HTTP 429: slow down');
      }
    },
    logger: {}
  });

  const summary = await crawler.runOnce();

  assert.equal(summary.errors, 1);
  assert.equal(store.hasCrawledUrl({ url: 'https://example.com/a' }), false);
});

test('runIfDue honours the interval and the LLM budget', async () => {
  const store = new WordStore({ seed: false });
  let clock = 1_000;
  const fetchImpl = fakeFetch({ 'https://feed.example/rss': '<rss></rss>' });
  const crawler = new ContentCrawler({
    store,
    config: crawlerConfig({ llmReservedRequestsPerHour: 30 }),
    fetchImpl,
    liteLLMClient: {},
    rateLimiter: { remainingHourlyBudget: () => 100 },
    now: () => clock,
    logger: {}
  });

  assert.ok(await crawler.runIfDue());
  assert.equal(await crawler.runIfDue(), null);
  clock += 61 * 60_000;
  assert.ok(await crawler.runIfDue());

  const starved = new ContentCrawler({
    store,
    config: crawlerConfig({ llmReservedRequestsPerHour: 30 }),
    fetchImpl,
    liteLLMClient: {},
    rateLimiter: { remainingHourlyBudget: () => 40 },
    now: () => clock,
    logger: {}
  });
  assert.equal(await starved.runIfDue(), null);
});

test('pages rejected before the LLM step do not use up the per-run assessment budget', async () => {
  const store = new WordStore({ seed: false });
  const junk = Array.from({ length: 4 }, (_, index) => `<item><title>Junk ${index}</title><link>https://example.com/junk${index}</link></item>`);
  const rss = `<rss><channel>${junk.join('')}<item><title>Good</title><link>https://example.com/good</link></item></channel></rss>`;
  const crawler = new ContentCrawler({
    store,
    config: crawlerConfig({ crawlerMaxArticlesPerRun: 1 }),
    fetchImpl: fakeFetch({ 'https://feed.example/rss': rss, 'https://example.com/good': ARTICLE_HTML }),
    liteLLMClient: { assessArticle: async () => ({ level: 'B2', quality: 4, suitable: true }) },
    logger: {}
  });

  const summary = await crawler.runOnce();

  assert.equal(summary.queued, 1);
  assert.equal(summary.assessed, 1);
  assert.equal(summary.rejected, 4);
});

const ZH_PROSE = '各地正在建设更多绿色步道，方便居民步行和骑自行车出行，也让城市空气变得更加清新。';
const ZH_ARTICLE_HTML = `<html><body><article>${Array.from({ length: 6 }, () => `<p>${ZH_PROSE}</p>`).join('')}<p>责任编辑：某某</p><p>来源：中国新闻网。</p></article></body></html>`;

test('extractArticleText reads Chinese prose: short CJK paragraphs, 。！？ endings, no editor credits', () => {
  const text = extractArticleText(ZH_ARTICLE_HTML);
  assert.match(text, /绿色步道/);
  assert.doesNotMatch(text, /责任编辑|来源/);
  assert.ok(text.length >= 250);
});

test('crawls Chinese feeds with an HSK grade and queues Chinese articles', async () => {
  const store = new WordStore({ seed: false });
  const zhRss = `<rss><channel>
<item><title>太浅的文章</title><link>https://zh.example/easy</link></item>
<item><title>绿色步道</title><link>https://zh.example/good</link></item>
<item><title>太难的文章</title><link>https://zh.example/hard</link></item>
</channel></rss>`;
  const graded = [];
  const assessments = { 太浅的文章: 'HSK1', 绿色步道: 'BEYOND', 太难的文章: 'HSK6' };
  const crawler = new ContentCrawler({
    store,
    config: crawlerConfig({ crawlerFeeds: { en: [], zh: ['https://zh.example/rss'] }, crawlerMaxArticlesPerRun: 1 }),
    fetchImpl: fakeFetch({
      'https://zh.example/rss': zhRss,
      'https://zh.example/easy': ZH_ARTICLE_HTML,
      'https://zh.example/good': ZH_ARTICLE_HTML,
      'https://zh.example/hard': ZH_ARTICLE_HTML
    }),
    liteLLMClient: {
      assessArticle: async ({ title, language }) => {
        graded.push([title, language]);
        return { level: assessments[title], quality: 4, suitable: true };
      }
    },
    logger: {}
  });

  const summary = await crawler.runOnce();

  // HSK1 is too easy to be reading material; "BEYOND" (above HSK6, typical for news) is accepted and ends the run.
  assert.deepEqual({ queued: summary.queued, rejected: summary.rejected, assessed: summary.assessed }, { queued: 1, rejected: 1, assessed: 2 });
  assert.deepEqual(graded, [['太浅的文章', 'zh'], ['绿色步道', 'zh']]);
  const [article] = [...store.articlesById.values()];
  assert.equal(article.language, 'zh');
  assert.equal(article.source_url, 'https://zh.example/good');
});

test('each language gets its own per-run article budget and assessment cap', async () => {
  const store = new WordStore({ seed: false });
  const many = (host, count) =>
    `<rss><channel>${Array.from({ length: count }, (_, i) => `<item><title>T${i}</title><link>https://${host}/${i}</link></item>`).join('')}</channel></rss>`;
  const pages = { 'https://en.example/rss': many('en.example', 10), 'https://zh.example/rss': many('zh.example', 10) };
  for (let i = 0; i < 10; i += 1) {
    pages[`https://en.example/${i}`] = ARTICLE_HTML;
    pages[`https://zh.example/${i}`] = ZH_ARTICLE_HTML;
  }
  const seen = { en: 0, zh: 0 };
  const crawler = new ContentCrawler({
    store,
    config: crawlerConfig({
      crawlerFeeds: { en: ['https://en.example/rss'], zh: ['https://zh.example/rss'] },
      crawlerMaxArticlesPerRun: 1
    }),
    fetchImpl: fakeFetch(pages),
    // Nothing is ever suitable: the assessment cap (4 per article) must stop each language.
    liteLLMClient: {
      assessArticle: async ({ language }) => {
        seen[language] += 1;
        return { level: null, quality: 1, suitable: false };
      }
    },
    logger: {}
  });

  const summary = await crawler.runOnce();

  assert.deepEqual(seen, { en: 4, zh: 4 });
  assert.equal(summary.queued, 0);
  assert.equal(summary.assessed, 8);
});
