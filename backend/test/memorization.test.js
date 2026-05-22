import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { PassageEnrichmentPipeline } from '../src/passage_enrichment_pipeline.js';
import { PassageEnrichmentWorker } from '../src/passage_enrichment_worker.js';
import { PassageSegmentationPipeline } from '../src/passage_segmentation_pipeline.js';
import { PassageSegmentationWorker } from '../src/passage_segmentation_worker.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

// ─── Helpers ────────────────────────────────────────────────────────────────

const ADMIN_TOKEN = 'test-admin-token';
const SAMPLE_TEXT = 'A'.repeat(60); // minimal valid raw_text (>= 50 chars)
const LONG_TEXT =
  'The quick brown fox jumps over the lazy dog. ' +
  'She sells seashells by the seashore. ' +
  'How much wood would a woodchuck chuck if a woodchuck could chuck wood. ' +
  'Peter Piper picked a peck of pickled peppers.';

function makeStore() {
  return new WordStore({ seed: false });
}

function makeConfig(env = {}) {
  return loadTestConfig({ ADMIN_API_TOKENS: ADMIN_TOKEN, ...env });
}

function listen(server) {
  return new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
}

async function fetchJson(url, options) {
  const response = await fetch(url, signedFetchOptions(url, options));
  if (!response.ok) {
    assert.fail(`${response.status} ${await response.text()}`);
  }
  return response.json();
}

async function fetchStatus(url, options) {
  const response = await fetch(url, signedFetchOptions(url, options));
  return { status: response.status, body: await response.json() };
}

async function registerUser(baseUrl, overrides = {}) {
  const body = {
    identifier: overrides.identifier ?? `user_${Date.now()}@test.com`,
    password: overrides.password ?? 'test-password-123',
    display_name: overrides.display_name ?? 'Test User',
    device_id: overrides.device_id ?? `device_${Date.now()}`
  };
  const result = await fetchJson(`${baseUrl}/v1/users/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body)
  });
  return result;
}

function silentLogger() {
  return { info() {}, warn() {}, error() {} };
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. Store-level tests
// ═══════════════════════════════════════════════════════════════════════════════

test('store: createPassage creates passage with correct fields and auto-generated ID', async () => {
  const store = makeStore();
  const passage = store.createPassage({
    title: 'My Passage',
    language: 'en',
    rawText: SAMPLE_TEXT,
    ownerType: 'user',
    ownerUserId: 'user_1',
    visibility: 'private'
  });

  assert.ok(passage.id.startsWith('passage_'));
  assert.equal(passage.title, 'My Passage');
  assert.equal(passage.language, 'en');
  assert.equal(passage.raw_text, SAMPLE_TEXT);
  assert.equal(passage.owner_type, 'user');
  assert.equal(passage.owner_user_id, 'user_1');
  assert.equal(passage.visibility, 'private');
  assert.equal(passage.status, 'pending_segmentation');
  assert.equal(passage.processing_error, null);
  assert.equal(passage.segment_count, 0);
  assert.ok(passage.created_at);
  assert.ok(passage.updated_at);
});

test('store: getPassage returns passage by ID', async () => {
  const store = makeStore();
  const created = store.createPassage({ title: 'Test', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  const retrieved = store.getPassage({ passageId: created.id });
  assert.deepEqual(retrieved, created);
});

test('store: getPassage returns null for non-existent ID', async () => {
  const store = makeStore();
  const result = store.getPassage({ passageId: 'passage_nonexistent' });
  assert.equal(result, null);
});

test('store: listPassages lists user own passages + published ones', async () => {
  const store = makeStore();
  store.createPassage({ title: 'Own', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'user_a', visibility: 'private' });
  store.createPassage({ title: 'Other', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'user_b', visibility: 'private' });
  store.createPassage({ title: 'Published', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'user_b', visibility: 'published' });

  const passages = store.listPassages({ userId: 'user_a' });
  assert.equal(passages.length, 2); // own + published
  const titles = passages.map((p) => p.title);
  assert.ok(titles.includes('Own'));
  assert.ok(titles.includes('Published'));
  assert.ok(!titles.includes('Other'));
});

test('store: listPublishedPassages only returns published + published-status passages', async () => {
  const store = makeStore();
  store.createPassage({ title: 'Pub', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: null, visibility: 'published' });
  // Not yet "published" status — still "pending_segmentation"
  const publishedPassages = store.listPublishedPassages();
  assert.equal(publishedPassages.length, 0); // status is pending_segmentation, not published

  // Update status to 'published'
  const p = store.createPassage({ title: 'Ready', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: null, visibility: 'published' });
  store.updatePassage({ passageId: p.id, status: 'published' });
  const result = store.listPublishedPassages();
  assert.equal(result.length, 1);
  assert.equal(result[0].title, 'Ready');
});

test('store: listAdminPassages lists all passages, with optional status filter', async () => {
  const store = makeStore();
  const p1 = store.createPassage({ title: 'A', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  const p2 = store.createPassage({ title: 'B', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u2' });
  store.updatePassage({ passageId: p2.id, status: 'segmented' });

  const all = store.listAdminPassages();
  assert.equal(all.length, 2);

  const pending = store.listAdminPassages({ status: 'pending_segmentation' });
  assert.equal(pending.length, 1);
  assert.equal(pending[0].id, p1.id);

  const segmented = store.listAdminPassages({ status: 'segmented' });
  assert.equal(segmented.length, 1);
  assert.equal(segmented[0].id, p2.id);
});

test('store: updatePassage updates title, visibility, status fields', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'Old', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });

  const updated = store.updatePassage({ passageId: p.id, title: 'New', visibility: 'published', status: 'segmented' });
  assert.equal(updated.title, 'New');
  assert.equal(updated.visibility, 'published');
  assert.equal(updated.status, 'segmented');
});

test('store: updatePassage returns null for non-existent passage', async () => {
  const store = makeStore();
  const result = store.updatePassage({ passageId: 'nope', title: 'X' });
  assert.equal(result, null);
});

test('store: deletePassage removes passage and its segments', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'Del', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  store.createSegments({ passageId: p.id, segments: [{ position: 0, text: 'chunk one' }] });

  const deleted = store.deletePassage({ passageId: p.id });
  assert.equal(deleted, true);
  assert.equal(store.getPassage({ passageId: p.id }), null);
  assert.deepEqual(store.getSegmentsByPassage({ passageId: p.id }), []);
});

test('store: deletePassage returns false for non-existent', async () => {
  const store = makeStore();
  assert.equal(store.deletePassage({ passageId: 'nope' }), false);
});

test('store: createSegments creates segment records with positions', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'Seg', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  const segments = store.createSegments({
    passageId: p.id,
    segments: [
      { position: 0, text: 'First segment text here.' },
      { position: 1, text: 'Second segment text here.' }
    ]
  });

  assert.equal(segments.length, 2);
  assert.ok(segments[0].id.startsWith('segment_'));
  assert.equal(segments[0].passage_id, p.id);
  assert.equal(segments[0].position, 0);
  assert.equal(segments[0].text, 'First segment text here.');
  assert.equal(segments[0].word_count, 4);
  assert.equal(segments[1].position, 1);

  // Passage segment_count updated
  const updated = store.getPassage({ passageId: p.id });
  assert.equal(updated.segment_count, 2);
});

test('store: getSegmentsByPassage returns segments ordered by position', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'Order', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  store.createSegments({
    passageId: p.id,
    segments: [
      { position: 2, text: 'Third' },
      { position: 0, text: 'First' },
      { position: 1, text: 'Second' }
    ]
  });

  const segments = store.getSegmentsByPassage({ passageId: p.id });
  assert.equal(segments.length, 3);
  assert.equal(segments[0].position, 0);
  assert.equal(segments[1].position, 1);
  assert.equal(segments[2].position, 2);
});

test('store: deleteSegmentsByPassage removes all segments for a passage', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'Del', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  store.createSegments({ passageId: p.id, segments: [{ position: 0, text: 'chunk' }, { position: 1, text: 'chunk2' }] });

  store.deleteSegmentsByPassage({ passageId: p.id });
  assert.deepEqual(store.getSegmentsByPassage({ passageId: p.id }), []);
  // segment_count reset
  const updated = store.getPassage({ passageId: p.id });
  assert.equal(updated.segment_count, 0);
});

test('store: upsertSegmentProgress creates progress for a segment', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'Prog', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  const segs = store.createSegments({ passageId: p.id, segments: [{ position: 0, text: 'text' }] });

  const progress = store.upsertSegmentProgress({
    userId: 'u1',
    segmentId: segs[0].id,
    status: 'learning',
    reviewCount: 1
  });

  assert.ok(progress.id.startsWith('segprog_'));
  assert.equal(progress.user_id, 'u1');
  assert.equal(progress.segment_id, segs[0].id);
  assert.equal(progress.status, 'learning');
  assert.equal(progress.review_count, 1);
  assert.equal(progress.ease_factor, 2.5);
});

test('store: upsertSegmentProgress updates existing progress', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'Up', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  const segs = store.createSegments({ passageId: p.id, segments: [{ position: 0, text: 'text' }] });

  store.upsertSegmentProgress({ userId: 'u1', segmentId: segs[0].id, status: 'learning', reviewCount: 1 });
  const updated = store.upsertSegmentProgress({ userId: 'u1', segmentId: segs[0].id, status: 'review', reviewCount: 3 });

  assert.equal(updated.status, 'review');
  assert.equal(updated.review_count, 3);
});

test('store: getSegmentProgress returns progress for user on a passage', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'GP', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  const segs = store.createSegments({
    passageId: p.id,
    segments: [{ position: 0, text: 'a' }, { position: 1, text: 'b' }]
  });
  store.upsertSegmentProgress({ userId: 'u1', segmentId: segs[0].id, status: 'mastered' });
  store.upsertSegmentProgress({ userId: 'u1', segmentId: segs[1].id, status: 'learning' });
  store.upsertSegmentProgress({ userId: 'other', segmentId: segs[0].id, status: 'new' });

  const progress = store.getSegmentProgress({ userId: 'u1', passageId: p.id });
  assert.equal(progress.length, 2);
  assert.ok(progress.every((pr) => pr.user_id === 'u1'));
});

test('store: getPassageProgress returns summary for user on a passage', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'PP', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });
  const segs = store.createSegments({
    passageId: p.id,
    segments: [{ position: 0, text: 'a' }, { position: 1, text: 'b' }, { position: 2, text: 'c' }]
  });
  store.upsertSegmentProgress({ userId: 'u1', segmentId: segs[0].id, status: 'mastered' });
  store.upsertSegmentProgress({ userId: 'u1', segmentId: segs[1].id, status: 'review' });
  // segs[2] has no progress → counts as 'new'

  const summary = store.getPassageProgress({ userId: 'u1', passageId: p.id });
  assert.equal(summary.total, 3);
  assert.equal(summary.mastered, 1);
  assert.equal(summary.reviewing, 1);
  assert.equal(summary.newCount, 1);
  assert.equal(summary.percentage, 67); // (1+1)/3 = 67%
});

test('store: claimNextPendingPassage claims a pending passage, returns null when none', async () => {
  const store = makeStore();
  const p = store.createPassage({ title: 'Claim', language: 'en', rawText: SAMPLE_TEXT, ownerUserId: 'u1' });

  const claimed = store.claimNextPendingPassage();
  assert.equal(claimed.id, p.id);
  assert.equal(claimed.status, 'segmenting');

  // No more pending
  const none = store.claimNextPendingPassage();
  assert.equal(none, null);
});

// ═══════════════════════════════════════════════════════════════════════════════
// 2. HTTP-level API tests
// ═══════════════════════════════════════════════════════════════════════════════

test('POST /v1/memorization/passages — creates passage (requires auth)', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  const result = await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'My Passage', language: 'en', raw_text: LONG_TEXT })
  });

  assert.ok(result.id);
  assert.equal(result.title, 'My Passage');
  assert.equal(result.language, 'en');
  assert.equal(result.status, 'pending_segmentation');
  assert.equal(result.owner_user_id, user.user_id);
});

test('POST /v1/memorization/passages — 400 for missing fields', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);

  // Missing title
  const r1 = await fetchStatus(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ language: 'en', raw_text: LONG_TEXT })
  });
  assert.equal(r1.status, 400);
  assert.equal(r1.body.error, 'title is required');

  // Missing raw_text
  const r2 = await fetchStatus(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'Test', language: 'en' })
  });
  assert.equal(r2.status, 400);
  assert.equal(r2.body.error, 'raw_text is required');

  // raw_text too short
  const r3 = await fetchStatus(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'Test', language: 'en', raw_text: 'short' })
  });
  assert.equal(r3.status, 400);
  assert.equal(r3.body.error, 'raw_text must be at least 50 characters');

  // Unsupported language
  const r4 = await fetchStatus(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'Test', language: 'ja', raw_text: LONG_TEXT })
  });
  assert.equal(r4.status, 400);
  assert.equal(r4.body.error, 'unsupported language');
});

test('POST /v1/memorization/passages — 401 without auth', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const r = await fetchStatus(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ title: 'Test', language: 'en', raw_text: LONG_TEXT })
  });
  assert.equal(r.status, 401);
});

test('GET /v1/memorization/passages — lists user passages', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'P1', language: 'en', raw_text: LONG_TEXT })
  });
  await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'P2', language: 'vi', raw_text: LONG_TEXT })
  });

  const list = await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'GET',
    headers: { authorization: `Bearer ${user.session_token}` }
  });
  assert.equal(list.items.length, 2);
});

test('GET /v1/memorization/passages/:id — returns passage with segments', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  const created = await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'Detail', language: 'en', raw_text: LONG_TEXT })
  });

  // Manually add segments to test inclusion in response
  store.createSegments({ passageId: created.id, segments: [{ position: 0, text: 'chunk one' }] });

  const detail = await fetchJson(`${baseUrl}/v1/memorization/passages/${created.id}`, {
    method: 'GET',
    headers: { authorization: `Bearer ${user.session_token}` }
  });
  assert.equal(detail.id, created.id);
  assert.ok(Array.isArray(detail.segments));
  assert.equal(detail.segments.length, 1);
  assert.equal(detail.segments[0].text, 'chunk one');
});

test('GET /v1/memorization/passages/:id — 404 for non-existent', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  const r = await fetchStatus(`${baseUrl}/v1/memorization/passages/passage_fake`, {
    method: 'GET',
    headers: { authorization: `Bearer ${user.session_token}` }
  });
  assert.equal(r.status, 404);
});

test('DELETE /v1/memorization/passages/:id — deletes own passage', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  const created = await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'ToDel', language: 'en', raw_text: LONG_TEXT })
  });

  const result = await fetchJson(`${baseUrl}/v1/memorization/passages/${created.id}`, {
    method: 'DELETE',
    headers: { authorization: `Bearer ${user.session_token}` }
  });
  assert.equal(result.success, true);

  // Verify gone
  const r = await fetchStatus(`${baseUrl}/v1/memorization/passages/${created.id}`, {
    method: 'GET',
    headers: { authorization: `Bearer ${user.session_token}` }
  });
  assert.equal(r.status, 404);
});

test('DELETE /v1/memorization/passages/:id — 403 for other user passage', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user1 = await registerUser(baseUrl, { identifier: 'owner@test.com' });
  const user2 = await registerUser(baseUrl, { identifier: 'other@test.com' });

  const created = await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user1.session_token}` },
    body: JSON.stringify({ title: 'Owned', language: 'en', raw_text: LONG_TEXT })
  });

  const r = await fetchStatus(`${baseUrl}/v1/memorization/passages/${created.id}`, {
    method: 'DELETE',
    headers: { authorization: `Bearer ${user2.session_token}` }
  });
  assert.equal(r.status, 403);
  assert.equal(r.body.error, 'forbidden');
});

test('POST /v1/memorization/progress — upserts progress records', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  const created = await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'Progress', language: 'en', raw_text: LONG_TEXT })
  });

  const segs = store.createSegments({ passageId: created.id, segments: [{ position: 0, text: 'text' }] });

  const result = await fetchJson(`${baseUrl}/v1/memorization/progress`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({
      entries: [{ segment_id: segs[0].id, status: 'learning', review_count: 2 }]
    })
  });

  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].status, 'learning');
  assert.equal(result.items[0].review_count, 2);
});

test('POST /v1/memorization/progress — 400 for invalid entries', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  const r = await fetchStatus(`${baseUrl}/v1/memorization/progress`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({})
  });
  assert.equal(r.status, 400);
  assert.equal(r.body.error, 'entries array is required');
});

test('GET /v1/memorization/progress?passage_id=X — returns progress', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  const created = await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'GetProg', language: 'en', raw_text: LONG_TEXT })
  });
  const segs = store.createSegments({ passageId: created.id, segments: [{ position: 0, text: 'seg' }] });
  store.upsertSegmentProgress({ userId: user.user_id, segmentId: segs[0].id, status: 'mastered' });

  const result = await fetchJson(`${baseUrl}/v1/memorization/progress?passage_id=${created.id}`, {
    method: 'GET',
    headers: { authorization: `Bearer ${user.session_token}` }
  });
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].status, 'mastered');
});

test('GET /v1/memorization/progress — 400 without passage_id', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  const r = await fetchStatus(`${baseUrl}/v1/memorization/progress`, {
    method: 'GET',
    headers: { authorization: `Bearer ${user.session_token}` }
  });
  assert.equal(r.status, 400);
  assert.equal(r.body.error, 'passage_id query parameter is required');
});

// ─── Admin endpoints ────────────────────────────────────────────────────────

test('POST /v1/admin/memorization/passages — creates admin passage', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const result = await fetchJson(`${baseUrl}/v1/admin/memorization/passages`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-expat8-admin-token': ADMIN_TOKEN
    },
    body: JSON.stringify({ title: 'Admin Passage', language: 'en', raw_text: LONG_TEXT, visibility: 'published' })
  });

  assert.ok(result.id);
  assert.equal(result.title, 'Admin Passage');
  assert.equal(result.owner_type, 'admin');
  assert.equal(result.visibility, 'published');
});

test('POST /v1/admin/memorization/passages — 403 without admin token', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const r = await fetchStatus(`${baseUrl}/v1/admin/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ title: 'Admin', language: 'en', raw_text: LONG_TEXT })
  });
  assert.equal(r.status, 403);
});

test('GET /v1/admin/memorization/passages — lists all passages with status filter', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  await fetchJson(`${baseUrl}/v1/admin/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ title: 'A1', language: 'en', raw_text: LONG_TEXT })
  });

  const list = await fetchJson(`${baseUrl}/v1/admin/memorization/passages`, {
    method: 'GET',
    headers: { 'x-expat8-admin-token': ADMIN_TOKEN }
  });
  assert.equal(list.items.length, 1);

  // Filter by status
  const filtered = await fetchJson(`${baseUrl}/v1/admin/memorization/passages?status=segmented`, {
    method: 'GET',
    headers: { 'x-expat8-admin-token': ADMIN_TOKEN }
  });
  assert.equal(filtered.items.length, 0);
});

test('GET /v1/admin/memorization/passages/:id — returns passage with segments', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const created = await fetchJson(`${baseUrl}/v1/admin/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ title: 'Detail', language: 'en', raw_text: LONG_TEXT })
  });
  store.createSegments({ passageId: created.id, segments: [{ position: 0, text: 'seg1' }] });

  const detail = await fetchJson(`${baseUrl}/v1/admin/memorization/passages/${created.id}`, {
    method: 'GET',
    headers: { 'x-expat8-admin-token': ADMIN_TOKEN }
  });
  assert.equal(detail.id, created.id);
  assert.equal(detail.segments.length, 1);
});

test('PATCH /v1/admin/memorization/passages/:id — updates passage fields', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const created = await fetchJson(`${baseUrl}/v1/admin/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ title: 'Original', language: 'en', raw_text: LONG_TEXT })
  });

  const patched = await fetchJson(`${baseUrl}/v1/admin/memorization/passages/${created.id}`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ title: 'Updated Title' })
  });
  assert.equal(patched.title, 'Updated Title');
});

test('PATCH /v1/admin/memorization/passages/:id — publish sets status when segmented', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const created = await fetchJson(`${baseUrl}/v1/admin/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ title: 'Pub', language: 'en', raw_text: LONG_TEXT })
  });

  // First set status to segmented manually
  store.updatePassage({ passageId: created.id, status: 'segmented' });

  const patched = await fetchJson(`${baseUrl}/v1/admin/memorization/passages/${created.id}`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ visibility: 'published' })
  });
  assert.equal(patched.visibility, 'published');
  assert.equal(patched.status, 'published');
});

test('POST /v1/admin/memorization/passages/:id/resegment — resets passage for re-segmentation', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const created = await fetchJson(`${baseUrl}/v1/admin/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ title: 'Reseg', language: 'en', raw_text: LONG_TEXT })
  });
  store.createSegments({ passageId: created.id, segments: [{ position: 0, text: 'old' }] });
  store.updatePassage({ passageId: created.id, status: 'segmented' });

  const result = await fetchJson(`${baseUrl}/v1/admin/memorization/passages/${created.id}/resegment`, {
    method: 'POST',
    headers: { 'x-expat8-admin-token': ADMIN_TOKEN }
  });
  assert.equal(result.status, 'pending_segmentation');

  // Segments should be deleted
  const segs = store.getSegmentsByPassage({ passageId: created.id });
  assert.equal(segs.length, 0);
});

test('PATCH /v1/admin/memorization/segments/:id — updates a segment', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const p = store.createPassage({ title: 'S', language: 'en', rawText: LONG_TEXT, ownerType: 'admin' });
  const segs = store.createSegments({ passageId: p.id, segments: [{ position: 0, text: 'original text' }] });

  const result = await fetchJson(`${baseUrl}/v1/admin/memorization/segments/${segs[0].id}`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ text: 'updated text', position: 5 })
  });
  assert.equal(result.text, 'updated text');
  assert.equal(result.position, 5);
});

test('POST /v1/admin/memorization/segments/:id/split — splits a segment and reorders positions', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'Split', language: 'en', rawText: LONG_TEXT, ownerType: 'admin' });
  const [segment] = store.createSegments({
    passageId: passage.id,
    segments: [{ position: 0, text: 'First sentence. Second sentence.' }]
  });

  const result = await fetchJson(`${baseUrl}/v1/admin/memorization/segments/${segment.id}/split`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ split_at: 'First sentence.'.length })
  });

  assert.equal(result.items.length, 2);
  assert.equal(result.items[0].text, 'First sentence.');
  assert.equal(result.items[1].text, 'Second sentence.');
  assert.equal(store.getPassage({ passageId: passage.id }).segment_count, 2);
});

test('POST /v1/admin/memorization/segments/:id/merge — merges adjacent segments and reorders positions', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'Merge', language: 'en', rawText: LONG_TEXT, ownerType: 'admin' });
  const segments = store.createSegments({
    passageId: passage.id,
    segments: [
      { position: 0, text: 'First.' },
      { position: 1, text: 'Second.' },
      { position: 2, text: 'Third.' }
    ]
  });

  const result = await fetchJson(`${baseUrl}/v1/admin/memorization/segments/${segments[0].id}/merge`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ next_segment_id: segments[1].id })
  });

  assert.equal(result.items.length, 2);
  assert.equal(result.items[0].text, 'First. Second.');
  assert.equal(result.items[0].position, 0);
  assert.equal(result.items[1].text, 'Third.');
  assert.equal(result.items[1].position, 1);
  assert.equal(store.getPassage({ passageId: passage.id }).segment_count, 2);
});

test('PATCH /v1/admin/memorization/segments/:id — 404 for non-existent segment', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const r = await fetchStatus(`${baseUrl}/v1/admin/memorization/segments/segment_nope`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': ADMIN_TOKEN },
    body: JSON.stringify({ text: 'x' })
  });
  assert.equal(r.status, 404);
});

// ═══════════════════════════════════════════════════════════════════════════════
// 3. Pipeline tests
// ═══════════════════════════════════════════════════════════════════════════════

test('pipeline: successful segmentation with mock LLM client', async () => {
  const store = makeStore();
  const passage = store.createPassage({ title: 'Pipe', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });

  const mockLLMClient = {
    async chatCompletion() {
      return {
        choices: [{
          message: {
            content: JSON.stringify({
              segments: [
                { text: 'First segment.' },
                { text: 'Second segment.' }
              ]
            })
          }
        }]
      };
    }
  };

  const pipeline = new PassageSegmentationPipeline({ store, liteLLMClient: mockLLMClient, logger: silentLogger() });
  const result = await pipeline.processPassage({ passageId: passage.id });

  assert.equal(result.success, true);
  assert.equal(result.segment_count, 2);

  const segments = store.getSegmentsByPassage({ passageId: passage.id });
  assert.equal(segments.length, 2);
  assert.equal(segments[0].text, 'First segment.');
  assert.equal(segments[1].text, 'Second segment.');

  const updated = store.getPassage({ passageId: passage.id });
  assert.equal(updated.status, 'segmented');
  assert.equal(updated.segment_count, 2);
});

test('pipeline: extracts vocabulary per segment and links it to segments', async () => {
  const store = makeStore();
  const passage = store.createPassage({ title: 'Vocab', language: 'en', rawText: LONG_TEXT, ownerType: 'user', ownerUserId: 'u1' });
  const mockLLMClient = {
    async chatCompletion() {
      return {
        choices: [{ message: { content: JSON.stringify({ segments: [{ text: 'A bold word appears.' }] }) } }]
      };
    }
  };
  const suggestionAdapter = {
    async suggestVocabulary({ chunk }) {
      return [
        {
          term: 'bold',
          language: 'en',
          meaning_vi: 'dam',
          part_of_speech: 'adjective',
          ipa: '/boʊld/',
          vietnamese_pronunciation: 'bâu-đ',
          example: chunk,
          example_vi: 'Mot tu dam xuat hien.',
          difficulty: 'A1',
          level: 'A1',
          topics: ['memorization'],
          classification: 'memorization_segment_vocabulary',
          suggestion_type: 'word',
          frequency: 1,
          confidence: 0.9
        }
      ];
    }
  };

  const pipeline = new PassageSegmentationPipeline({
    store,
    liteLLMClient: mockLLMClient,
    suggestionAdapter,
    logger: silentLogger()
  });
  const result = await pipeline.processPassage({ passageId: passage.id });

  assert.equal(result.success, true);
  assert.equal(result.vocabulary_count, 1);
  assert.equal(store.memorizationSegmentTermsById.size, 1);
  const [link] = store.memorizationSegmentTermsById.values();
  const [segment] = store.getSegmentsByPassage({ passageId: passage.id });
  assert.equal(link.passage_id, passage.id);
  assert.equal(link.segment_id, segment.id);
  assert.equal(link.surface_text, 'bold');
  assert.equal([...store.vocabularyReviewItemsById.values()][0].status, 'approved');
  assert.ok([...store.words.values()].some((word) => word.term === 'bold'));
});

test('pipeline: handles LLM errors gracefully', async () => {
  const store = makeStore();
  const passage = store.createPassage({ title: 'Err', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });

  const mockLLMClient = {
    async chatCompletion() {
      throw new Error('LLM service unavailable');
    }
  };

  const pipeline = new PassageSegmentationPipeline({ store, liteLLMClient: mockLLMClient, logger: silentLogger() });
  const result = await pipeline.processPassage({ passageId: passage.id });

  assert.equal(result.success, false);
  assert.ok(result.error.includes('LLM service unavailable'));
});

test('pipeline: caps segments at 50', async () => {
  const store = makeStore();
  const passage = store.createPassage({ title: 'Cap', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });

  const manySegments = Array.from({ length: 60 }, (_, i) => ({ text: `Segment ${i}` }));
  const mockLLMClient = {
    async chatCompletion() {
      return {
        choices: [{
          message: {
            content: JSON.stringify({ segments: manySegments })
          }
        }]
      };
    }
  };

  const pipeline = new PassageSegmentationPipeline({ store, liteLLMClient: mockLLMClient, logger: silentLogger() });
  const result = await pipeline.processPassage({ passageId: passage.id });

  assert.equal(result.success, true);
  assert.equal(result.segment_count, 50);

  const segments = store.getSegmentsByPassage({ passageId: passage.id });
  assert.equal(segments.length, 50);
});

test('pipeline: returns error for non-existent passage', async () => {
  const store = makeStore();
  const mockLLMClient = { async chatCompletion() { return { choices: [{ message: { content: '[]' } }] }; } };
  const pipeline = new PassageSegmentationPipeline({ store, liteLLMClient: mockLLMClient, logger: silentLogger() });

  const result = await pipeline.processPassage({ passageId: 'passage_nonexistent' });
  assert.equal(result.success, false);
  assert.equal(result.error, 'passage_not_found');
});

test('pipeline: returns error when no segments produced', async () => {
  const store = makeStore();
  const passage = store.createPassage({ title: 'Empty', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });

  const mockLLMClient = {
    async chatCompletion() {
      return { choices: [{ message: { content: JSON.stringify({ segments: [] }) } }] };
    }
  };

  const pipeline = new PassageSegmentationPipeline({ store, liteLLMClient: mockLLMClient, logger: silentLogger() });
  const result = await pipeline.processPassage({ passageId: passage.id });

  assert.equal(result.success, false);
  assert.equal(result.error, 'no_segments_produced');
});

// ═══════════════════════════════════════════════════════════════════════════════
// 4. Worker tests
// ═══════════════════════════════════════════════════════════════════════════════

test('worker: processes next pending passage', async () => {
  const store = makeStore();
  store.createPassage({ title: 'W1', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });

  const mockPipeline = {
    async processPassage() {
      return { success: true, segment_count: 3 };
    }
  };

  const worker = new PassageSegmentationWorker({ store, pipeline: mockPipeline, logger: silentLogger() });
  const result = await worker.runOnce();

  assert.equal(result.processed, 1);
});

test('worker: no-ops when no pending passages', async () => {
  const store = makeStore();
  const mockPipeline = { async processPassage() { return { success: true, segment_count: 0 }; } };
  const worker = new PassageSegmentationWorker({ store, pipeline: mockPipeline, logger: silentLogger() });

  const result = await worker.runOnce();
  assert.equal(result.processed, 0);
});

test('worker: handles pipeline failure with retry logic', async () => {
  const store = makeStore();
  store.createPassage({ title: 'Retry', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });

  const mockPipeline = {
    async processPassage() {
      return { success: false, error: 'llm_timeout' };
    }
  };

  const worker = new PassageSegmentationWorker({ store, pipeline: mockPipeline, logger: silentLogger(), maxAttempts: 3 });

  // First attempt — should schedule retry (attempt_count becomes 1, < 3)
  const r1 = await worker.runOnce();
  assert.equal(r1.processed, 0);
  assert.equal(r1.failed, 1);
  assert.equal(r1.retry_scheduled, true);

  // The passage should be back to pending_segmentation for retry
  const passages = store.listAdminPassages({ status: 'pending_segmentation' });
  assert.equal(passages.length, 1);
});

test('worker: handles unexpected pipeline exceptions', async () => {
  const store = makeStore();
  store.createPassage({ title: 'Exc', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });

  const mockPipeline = {
    async processPassage() {
      throw new Error('unexpected crash');
    }
  };

  const worker = new PassageSegmentationWorker({ store, pipeline: mockPipeline, logger: silentLogger() });
  const result = await worker.runOnce();

  assert.equal(result.processed, 0);
  assert.equal(result.failed, 1);

  // Passage should be marked as failed
  const passages = store.listAdminPassages({ status: 'failed' });
  assert.equal(passages.length, 1);
  assert.ok(passages[0].processing_error.includes('unexpected crash'));
});

// ─── 5. Enrichment Pipeline tests ──────────────────────────────────────────

test('enrichment pipeline: successful enrichment with mock LLM', async () => {
  const store = makeStore();
  const passage = store.createPassage({ title: 'Enrich Test', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });
  const [segment] = store.createSegments({ passageId: passage.id, segments: [{ position: 0, text: 'Four score and seven years ago.' }] });
  store.updatePassage({ passageId: passage.id, status: 'segmented' });

  const mockLLM = {
    async chatCompletion() {
      return {
        choices: [{
          message: {
            content: JSON.stringify([{ ipa: '/fɔːr skɔːr ænd ˈsɛvən jɪrz əˈɡoʊ/', translation: 'Bốn mươi bảy năm trước.', viet_reading: 'fo sco ren xê-vần di-ơz ơ-gâu' }])
          }
        }]
      };
    }
  };

  const pipeline = new PassageEnrichmentPipeline({ store, liteLLMClient: mockLLM, logger: silentLogger() });
  const result = await pipeline.processPassage({ passageId: passage.id });

  assert.equal(result.success, true);
  assert.equal(result.segment_count, 1);

  const enriched = store.getSegmentsByPassage({ passageId: passage.id });
  assert.equal(enriched[0].ipa_text, '/fɔːr skɔːr ænd ˈsɛvən jɪrz əˈɡoʊ/');
  assert.equal(enriched[0].translation_text, 'Bốn mươi bảy năm trước.');
  assert.equal(enriched[0].translation_language, 'vi');
  assert.equal(enriched[0].viet_reading_text, 'fo sco ren xê-vần di-ơz ơ-gâu');

  const updated = store.getPassage({ passageId: passage.id });
  assert.equal(updated.enrichment_status, 'enriched');
});

test('enrichment pipeline: handles missing ipa/translation fields gracefully (null fallback)', async () => {
  const store = makeStore();
  const passage = store.createPassage({ title: 'Null Fields', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });
  store.createSegments({ passageId: passage.id, segments: [{ position: 0, text: 'Hello world.' }] });
  store.updatePassage({ passageId: passage.id, status: 'segmented' });

  const mockLLM = {
    async chatCompletion() {
      // LLM omits ipa and translation fields
      return { choices: [{ message: { content: JSON.stringify([{}]) } }] };
    }
  };

  const pipeline = new PassageEnrichmentPipeline({ store, liteLLMClient: mockLLM, logger: silentLogger() });
  const result = await pipeline.processPassage({ passageId: passage.id });

  assert.equal(result.success, true);

  const [seg] = store.getSegmentsByPassage({ passageId: passage.id });
  assert.equal(seg.ipa_text, null);
  assert.equal(seg.translation_text, null);
  assert.equal(seg.translation_language, 'vi'); // language is always set
  assert.equal(seg.viet_reading_text, null);
});

test('enrichment pipeline: handles length mismatch gracefully', async () => {
  const store = makeStore();
  const passage = store.createPassage({ title: 'Mismatch', language: 'en', rawText: LONG_TEXT, ownerUserId: 'u1' });
  store.createSegments({ passageId: passage.id, segments: [
    { position: 0, text: 'First sentence.' },
    { position: 1, text: 'Second sentence.' }
  ] });
  store.updatePassage({ passageId: passage.id, status: 'segmented' });

  // LLM returns only 1 item for 2 segments
  const mockLLM = {
    async chatCompletion() {
      return { choices: [{ message: { content: JSON.stringify([{ ipa: '/fɜːst/', translation: 'Câu đầu tiên.' }]) } }] };
    }
  };

  const pipeline = new PassageEnrichmentPipeline({ store, liteLLMClient: mockLLM, logger: silentLogger() });
  const result = await pipeline.processPassage({ passageId: passage.id });

  assert.equal(result.success, true);
  const segs = store.getSegmentsByPassage({ passageId: passage.id });
  // First segment gets data, second gets null (no matching enrichment item)
  assert.equal(segs[0].ipa_text, '/fɜːst/');
  assert.equal(segs[1].ipa_text, null);
});

// ─── 6. Admin enrich endpoint tests ────────────────────────────────────────

test('PATCH /v1/admin/memorization/passages/:id/enrich — queues enrichment for segmented passage', async (t) => {
  const store = makeStore();
  const config = makeConfig({ ADMIN_API_TOKENS: ADMIN_TOKEN });
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'To Enrich', language: 'en', rawText: LONG_TEXT, ownerUserId: null, ownerType: 'admin' });
  store.updatePassage({ passageId: passage.id, status: 'segmented' });

  const res = await fetchJson(`${baseUrl}/v1/admin/memorization/passages/${passage.id}/enrich`, {
    method: 'PATCH',
    headers: { 'x-admin-token': ADMIN_TOKEN }
  });

  assert.equal(res.success, true);
  assert.equal(res.message, 'enrichment_queued');

  const updated = store.getPassage({ passageId: passage.id });
  assert.equal(updated.enrichment_status, 'pending');
});

test('PATCH /v1/admin/memorization/passages/:id/enrich — 400 for non-segmented passage', async (t) => {
  const store = makeStore();
  const config = makeConfig({ ADMIN_API_TOKENS: ADMIN_TOKEN });
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'Pending', language: 'en', rawText: LONG_TEXT, ownerUserId: null, ownerType: 'admin' });
  // Status is still pending_segmentation

  const res = await fetchStatus(`${baseUrl}/v1/admin/memorization/passages/${passage.id}/enrich`, {
    method: 'PATCH',
    headers: { 'x-admin-token': ADMIN_TOKEN }
  });

  assert.equal(res.status, 400);
  assert.equal(res.body.error, 'passage_not_segmented');
});

test('GET /v1/memorization/passages/:id — includes enrichment fields in segment response', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const user = await registerUser(baseUrl);
  const created = await fetchJson(`${baseUrl}/v1/memorization/passages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.session_token}` },
    body: JSON.stringify({ title: 'Enrichment Fields Test', language: 'en', raw_text: LONG_TEXT })
  });

  // Manually add enriched segments
  const [seg] = store.createSegments({ passageId: created.id, segments: [{ position: 0, text: 'Four score and seven years ago.' }] });
  store.updateSegmentEnrichment({
    segmentId: seg.id,
    ipa_text: '/fɔːr skɔːr/',
    translation_text: 'Bốn mươi bảy năm trước.',
    translation_language: 'vi',
    viet_reading_text: 'fo sco'
  });
  store.updatePassageEnrichmentStatus({ passageId: created.id, enrichmentStatus: 'enriched' });

  const detail = await fetchJson(`${baseUrl}/v1/memorization/passages/${created.id}`, {
    method: 'GET',
    headers: { authorization: `Bearer ${user.session_token}` }
  });

  assert.equal(detail.enrichment_status, 'enriched');
  assert.equal(detail.segments[0].ipa_text, '/fɔːr skɔːr/');
  assert.equal(detail.segments[0].translation_text, 'Bốn mươi bảy năm trước.');
  assert.equal(detail.segments[0].translation_language, 'vi');
  assert.equal(detail.segments[0].viet_reading_text, 'fo sco');
});

// ─── 7. Retry endpoint tests ─────────────────────────────────────────────────

test('POST /v1/admin/memorization/passages/:id/retry — resets failed passage for re-segmentation', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'Retry Test', language: 'en', rawText: SAMPLE_TEXT, ownerType: 'admin' });
  store.updatePassage({ passageId: passage.id, status: 'failed', processing_error: 'llm timeout', attempt_count: 3 });

  const res = await fetchJson(`${baseUrl}/v1/admin/memorization/passages/${passage.id}/retry`, {
    method: 'POST',
    headers: { 'x-admin-token': ADMIN_TOKEN }
  });
  assert.equal(res.success, true);
  assert.equal(res.message, 'retry_queued');

  const updated = store.getPassage({ passageId: passage.id });
  assert.equal(updated.status, 'pending_segmentation');
  assert.equal(updated.processing_error, null);
  assert.equal(updated.attempt_count, 0);
});

test('POST /v1/admin/memorization/passages/:id/retry — 400 for non-failed passage', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'Non-Failed', language: 'en', rawText: SAMPLE_TEXT, ownerType: 'admin' });
  // Status is 'pending_segmentation' by default — not failed

  const { status, body } = await fetchStatus(`${baseUrl}/v1/admin/memorization/passages/${passage.id}/retry`, {
    method: 'POST',
    headers: { 'x-admin-token': ADMIN_TOKEN }
  });
  assert.equal(status, 400);
  assert.equal(body.error, 'passage_not_failed');
});

test('POST /v1/admin/memorization/passages/:id/retry — 404 for unknown passage', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const { status, body } = await fetchStatus(`${baseUrl}/v1/admin/memorization/passages/nonexistent/retry`, {
    method: 'POST',
    headers: { 'x-admin-token': ADMIN_TOKEN }
  });
  assert.equal(status, 404);
  assert.equal(body.error, 'not_found');
});

test('POST /v1/admin/memorization/passages/:id/retry — 403 without admin token', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'Auth Test', language: 'en', rawText: SAMPLE_TEXT, ownerType: 'admin' });
  store.updatePassage({ passageId: passage.id, status: 'failed' });

  const { status, body } = await fetchStatus(`${baseUrl}/v1/admin/memorization/passages/${passage.id}/retry`, {
    method: 'POST'
    // No admin token
  });
  assert.equal(status, 403);
  assert.equal(body.error, 'forbidden');
});

test('PATCH /v1/admin/memorization/passages/:id/retry-enrichment — resets failed enrichment', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'Enrich Retry', language: 'en', rawText: SAMPLE_TEXT, ownerType: 'admin' });
  store.updatePassage({ passageId: passage.id, status: 'segmented' });
  store.createSegments({ passageId: passage.id, segments: [{ position: 0, text: 'Hello world.' }] });
  store.updatePassageEnrichmentStatus({ passageId: passage.id, enrichmentStatus: 'failed', enrichment_attempt_count: 3 });

  const res = await fetchJson(`${baseUrl}/v1/admin/memorization/passages/${passage.id}/retry-enrichment`, {
    method: 'PATCH',
    headers: { 'x-admin-token': ADMIN_TOKEN }
  });
  assert.equal(res.success, true);
  assert.equal(res.message, 'enrichment_retry_queued');

  const updated = store.getPassage({ passageId: passage.id });
  assert.equal(updated.enrichment_status, 'pending');
  assert.equal(updated.enrichment_attempt_count, 0);
  // Segment should be untouched
  const segments = store.getSegmentsByPassage({ passageId: passage.id });
  assert.equal(segments.length, 1);
});

test('PATCH /v1/admin/memorization/passages/:id/retry-enrichment — 400 when enrichment not failed', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'Not Failed', language: 'en', rawText: SAMPLE_TEXT, ownerType: 'admin' });
  store.createSegments({ passageId: passage.id, segments: [{ position: 0, text: 'Hello.' }] });
  // enrichment_status is 'none' by default

  const { status, body } = await fetchStatus(`${baseUrl}/v1/admin/memorization/passages/${passage.id}/retry-enrichment`, {
    method: 'PATCH',
    headers: { 'x-admin-token': ADMIN_TOKEN }
  });
  assert.equal(status, 400);
  assert.equal(body.error, 'enrichment_not_failed');
});

test('PATCH /v1/admin/memorization/passages/:id/retry-enrichment — 400 when no segments', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'No Segments', language: 'en', rawText: SAMPLE_TEXT, ownerType: 'admin' });
  store.updatePassageEnrichmentStatus({ passageId: passage.id, enrichmentStatus: 'failed' });

  const { status, body } = await fetchStatus(`${baseUrl}/v1/admin/memorization/passages/${passage.id}/retry-enrichment`, {
    method: 'PATCH',
    headers: { 'x-admin-token': ADMIN_TOKEN }
  });
  assert.equal(status, 400);
  assert.equal(body.error, 'passage_has_no_segments');
});

test('PATCH /v1/admin/memorization/passages/:id/retry-enrichment — 404 for unknown passage', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const { status, body } = await fetchStatus(`${baseUrl}/v1/admin/memorization/passages/nonexistent/retry-enrichment`, {
    method: 'PATCH',
    headers: { 'x-admin-token': ADMIN_TOKEN }
  });
  assert.equal(status, 404);
  assert.equal(body.error, 'not_found');
});

test('PATCH /v1/admin/memorization/passages/:id/retry-enrichment — 403 without admin token', async (t) => {
  const store = makeStore();
  const config = makeConfig();
  const server = http.createServer(createApp({ store, generationService: null, config }));
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const passage = store.createPassage({ title: 'Auth Test', language: 'en', rawText: SAMPLE_TEXT, ownerType: 'admin' });
  store.createSegments({ passageId: passage.id, segments: [{ position: 0, text: 'Hello.' }] });
  store.updatePassageEnrichmentStatus({ passageId: passage.id, enrichmentStatus: 'failed' });

  const { status, body } = await fetchStatus(`${baseUrl}/v1/admin/memorization/passages/${passage.id}/retry-enrichment`, {
    method: 'PATCH'
    // No admin token
  });
  assert.equal(status, 403);
  assert.equal(body.error, 'forbidden');
});
