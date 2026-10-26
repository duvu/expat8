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
    crawlerFeeds: ['https://feed.example/rss'],
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
    { cefr_level: 'B1', quality: 4, suitable: true },
    { cefr_level: 'A1', quality: 5, suitable: true }
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
    liteLLMClient: { assessArticle: async () => ({ cefr_level: 'B2', quality: 4, suitable: true }) },
    logger: {}
  });

  const summary = await crawler.runOnce();

  assert.equal(summary.queued, 1);
  assert.equal(summary.assessed, 1);
  assert.equal(summary.rejected, 4);
});
