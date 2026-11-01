import assert from 'node:assert/strict';
import test from 'node:test';

import { CuratedCollector, cleanExtract } from '../src/curated_collector.js';
import { WordStore } from '../src/word_store.js';

const PROSE = 'Marie Curie was a physicist and chemist who conducted pioneering research on radioactivity. ';
const LONG = Array.from({ length: 20 }, () => PROSE).join('');

function wikiFetch(pages) {
  const calls = [];
  const impl = async (url) => {
    calls.push(url);
    const parsed = new URL(url);
    const title = parsed.searchParams.get('titles');
    const key = `${parsed.host}|${title}`;
    const extract = pages[key];
    const page = extract === undefined ? { title, missing: '' } : { title, extract };
    return { ok: true, status: 200, json: async () => ({ query: { pages: { 1: page } } }) };
  };
  impl.calls = calls;
  return impl;
}

function config(overrides = {}) {
  return {
    curatedEnabled: true,
    curatedInitialCount: 2,
    curatedBackfillIntervalMinutes: 15,
    curatedIntervalDays: 7,
    crawlerMinArticleQuality: 3,
    llmReservedRequestsPerHour: 30,
    ...overrides
  };
}

const topics = [
  { category: 'biography', title: 'Alpha', hosts: ['simple.wikipedia.org', 'en.wikipedia.org'] },
  { category: 'speech', title: 'Beta', hosts: ['en.wikipedia.org'] },
  { category: 'history', title: 'Gamma', hosts: ['simple.wikipedia.org'] }
];

test('cleanExtract keeps prose, drops headings and stops at reference sections', () => {
  const text = cleanExtract(`Intro paragraph that is long enough to be treated as prose by the cleaner here.\nEarly life\n${PROSE}\nReferences\nSmith, J. (2001) Something`);
  assert.match(text, /Intro paragraph/);
  assert.match(text, /pioneering research/);
  assert.doesNotMatch(text, /Early life|Smith/);
});

test('falls back to English Wikipedia when the Simple English page is a stub', async () => {
  const store = new WordStore({ seed: false });
  const fetchImpl = wikiFetch({ 'simple.wikipedia.org|Alpha': 'Too short.', 'en.wikipedia.org|Alpha': LONG });
  const collector = new CuratedCollector({
    store,
    config: config(),
    fetchImpl,
    topics: [topics[0]],
    liteLLMClient: { assessArticle: async () => ({ level: 'B2', quality: 4, suitable: false }) },
    logger: {}
  });

  const result = await collector.collectOne();

  assert.equal(result.queued, 1);
  const [article] = [...store.articlesById.values()];
  assert.equal(article.source_url, 'https://en.wikipedia.org/wiki/Alpha');
  assert.equal(article.owner_user_id, null);
});

test('rejections are remembered and the next candidate is tried', async () => {
  const store = new WordStore({ seed: false });
  const levels = ['A1', 'B1'];
  const collector = new CuratedCollector({
    store,
    config: config(),
    fetchImpl: wikiFetch({ 'simple.wikipedia.org|Alpha': LONG, 'en.wikipedia.org|Beta': LONG }),
    topics: topics.slice(0, 2),
    liteLLMClient: { assessArticle: async () => ({ level: levels.shift(), quality: 4, suitable: true }) },
    logger: {}
  });

  const result = await collector.collectOne();
  assert.deepEqual({ queued: result.queued, rejected: result.rejected }, { queued: 1, rejected: 1 });
  assert.equal(store.curatedStats().queued, 1);

  // A second run never re-evaluates either topic.
  const again = await collector.collectOne();
  assert.equal(again.queued, 0);
  assert.equal(again.rejected, 0);
});

test('backfills quickly, then switches to one article per week', async () => {
  const store = new WordStore({ seed: false });
  let clock = Date.now(); // the store stamps rows with the real clock
  const collector = new CuratedCollector({
    store,
    config: config({ curatedInitialCount: 2 }),
    fetchImpl: wikiFetch({
      'simple.wikipedia.org|Alpha': LONG,
      'en.wikipedia.org|Beta': LONG,
      'simple.wikipedia.org|Gamma': LONG
    }),
    topics,
    now: () => clock,
    liteLLMClient: { assessArticle: async () => ({ level: 'B1', quality: 4, suitable: true }) },
    logger: {}
  });

  assert.equal((await collector.runIfDue()).backfilling, true);
  assert.equal(await collector.runIfDue(), null, 'next backfill waits for its interval');
  clock += 16 * 60_000;
  assert.equal((await collector.runIfDue()).backfilling, true);
  assert.equal(store.curatedStats().queued, 2);

  clock += 3 * 24 * 3_600_000;
  assert.equal(await collector.runIfDue(), null, 'weekly cadence not reached');
  clock += 5 * 24 * 3_600_000;
  const weekly = await collector.runIfDue();
  assert.equal(weekly.backfilling, false);
  assert.equal(weekly.queued, 1);
  assert.equal(store.curatedStats().queued, 3);
});

test('does not record a topic when the LLM is unavailable so it is retried', async () => {
  const store = new WordStore({ seed: false });
  const collector = new CuratedCollector({
    store,
    config: config(),
    fetchImpl: wikiFetch({ 'simple.wikipedia.org|Alpha': LONG }),
    topics: [topics[0]],
    liteLLMClient: {
      assessArticle: async () => {
        throw new Error('LiteLLM HTTP 429');
      }
    },
    logger: {}
  });

  const result = await collector.collectOne();
  assert.equal(result.errors, 1);
  assert.equal(store.curatedStats().queued, 0);
  assert.equal(store.crawledUrls.size, 0);
});

test('asks the LLM for new titles once every built-in topic has been used', async () => {
  const store = new WordStore({ seed: false });
  store.recordCrawledUrl({ url: 'https://simple.wikipedia.org/wiki/Alpha', status: 'queued', feedUrl: 'curated:biography' });
  let asked = 0;
  const collector = new CuratedCollector({
    store,
    config: config(),
    fetchImpl: wikiFetch({ 'simple.wikipedia.org|Delta': LONG }),
    topics: [topics[0]],
    liteLLMClient: {
      suggestWikipediaTitles: async ({ category }) => {
        asked += 1;
        return category === 'biography' ? ['Delta'] : [];
      },
      assessArticle: async () => ({ level: 'B1', quality: 4 })
    },
    logger: {}
  });

  const result = await collector.collectOne();

  assert.equal(asked, 3);
  assert.equal(result.queued, 1);
});
