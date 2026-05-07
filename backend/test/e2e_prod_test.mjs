/**
 * E2E test against production backend at https://expat8.x51.vn
 * Run: node backend/test/e2e_prod_test.mjs
 */

import crypto from 'node:crypto';

if (process.env.RUN_PROD_E2E !== '1') {
  console.log('Skipping production E2E test. Set RUN_PROD_E2E=1 to run it explicitly.');
  process.exit(0);
}

const BASE_URL = process.env.BACKEND_URL ?? 'https://expat8.x51.vn';
const APP_ID = process.env.APP_ID ?? 'expat8-mobile-app';
const APP_SECRET = process.env.APP_SECRET ?? 'expat8-mobile-secret';
const DEVICE_ID = `e2e_test_${Date.now()}`;

let passed = 0;
let failed = 0;
const issues = [];

// ── Signing helpers ──────────────────────────────────────────────────────────

let nonceSeq = 0;

function hashBody(rawBody) {
  return crypto.createHash('sha256').update(rawBody ?? '').digest('base64url');
}

function canonicalPathWithSortedQuery(url) {
  const u = new URL(url);
  const sorted = [...u.searchParams.entries()].sort(([a], [b]) => a.localeCompare(b));
  const q = new URLSearchParams(sorted).toString();
  return q ? `${u.pathname}?${q}` : u.pathname;
}

function buildSignedHeaders(method, url, body) {
  const rawBody = body != null ? (typeof body === 'string' ? body : JSON.stringify(body)) : '';
  const timestamp = new Date().toISOString();
  const nonce = `e2e_${Date.now()}_${++nonceSeq}`;
  const contentSha256 = hashBody(rawBody);
  const canonical = ['v1', method.toUpperCase(), canonicalPathWithSortedQuery(url), timestamp, nonce, contentSha256].join('\n');
  const signature = `v1=${crypto.createHmac('sha256', APP_SECRET).update(canonical).digest('base64url')}`;
  return {
    'x-expat8-app-id': APP_ID,
    'x-expat8-timestamp': timestamp,
    'x-expat8-nonce': nonce,
    'x-expat8-content-sha256': contentSha256,
    'x-expat8-signature': signature
  };
}

async function apiRequest(method, path, body) {
  const url = `${BASE_URL}${path}`;
  const rawBody = body != null ? JSON.stringify(body) : undefined;
  const headers = {
    ...(rawBody ? { 'content-type': 'application/json' } : {}),
    ...buildSignedHeaders(method, url, rawBody)
  };
  const res = await fetch(url, { method, headers, body: rawBody });
  let json = null;
  try { json = await res.json(); } catch {}
  return { status: res.status, body: json };
}

// ── Test runner ──────────────────────────────────────────────────────────────

async function test(name, fn) {
  try {
    await fn();
    console.log(`  ✅ ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ❌ ${name}`);
    console.error(`     ${err.message}`);
    failed++;
    issues.push({ test: name, error: err.message });
  }
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg ?? 'Assertion failed');
}

function assertEq(actual, expected, msg) {
  if (actual !== expected) throw new Error(msg ?? `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

function assertHas(obj, key, msg) {
  if (obj == null || !(key in obj)) throw new Error(msg ?? `Missing key "${key}" in ${JSON.stringify(obj)}`);
}

// ── Test suite ───────────────────────────────────────────────────────────────

console.log(`\n🔬 E2E Test: ${BASE_URL}  [device: ${DEVICE_ID}]\n`);

// 1. Health check (no auth required)
console.log('── 1. Health Check ─────────────────────────────────────────────');
await test('GET /health returns 200 with ok:true', async () => {
  const res = await fetch(`${BASE_URL}/health`);
  assertEq(res.status, 200, `Expected 200, got ${res.status}`);
  const body = await res.json();
  assertEq(body.ok, true, `Expected ok:true, got ${JSON.stringify(body)}`);
});

// 2. Auth required
console.log('\n── 2. Authentication ───────────────────────────────────────────');
await test('Unsigned request returns 400 bad_request', async () => {
  const res = await fetch(`${BASE_URL}/v1/learning/cards`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: DEVICE_ID,
      target_language: 'en',
      limit: 10,
      card_mode: 'new'
    })
  });
  assertEq(res.status, 400, `Expected 400, got ${res.status}`);
  const body = await res.json();
  assertEq(body.error, 'bad_request');
});

await test('Wrong secret returns 400 bad_request', async () => {
  const url = `${BASE_URL}/v1/learning/cards`;
  const rawBody = JSON.stringify({
    device_id: DEVICE_ID,
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });
  const headers = {
    'content-type': 'application/json',
    ...buildSignedHeaders('POST', url, rawBody),
    'x-expat8-signature': 'v1=invalidsig'
  };
  const res = await fetch(url, { method: 'POST', headers, body: rawBody });
  assertEq(res.status, 400);
  const body = await res.json();
  assertEq(body.error, 'bad_request');
});

// 3. Learning cards
console.log('\n── 3. Learning Cards ───────────────────────────────────────────');
let firstWord = null;

await test('POST /v1/learning/cards returns items array', async () => {
  const res = await apiRequest('POST', '/v1/learning/cards', {
    device_id: DEVICE_ID,
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });
  assertEq(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
  assert(Array.isArray(res.body.items), 'Expected items array');
  assertEq(res.body.target_mix?.new, 10);
  if (res.body.items.length > 0) {
    firstWord = res.body.items[0];
    assertHas(firstWord, 'server_word_id');
    assertHas(firstWord, 'term');
    assertHas(firstWord, 'meaning_vi');
    assertHas(firstWord, 'difficulty');
    console.log(`     → Got ${res.body.items.length} word(s): ${res.body.items.map(w => w.term).join(', ')}`);
  } else {
    console.log('     → No words returned (empty vocabulary store)');
  }
});

await test('GET /v1/words/recent returns items array', async () => {
  const res = await apiRequest('GET', `/v1/words/recent?limit=5&source_language=vi&target_language=en`);
  assertEq(res.status, 200, `Expected 200, got ${res.status}`);
  assert(Array.isArray(res.body.items), 'Expected items array');
  console.log(`     → Got ${res.body.items.length} recent word(s)`);
});

// 4. Study events
console.log('\n── 4. Study Events ─────────────────────────────────────────────');

const wordId = firstWord?.server_word_id ?? 'test_word_id_does_not_exist';
const clientEventId = `e2e_evt_${Date.now()}`;

await test('POST /v1/study-events accepts a rating event', async () => {
  const res = await apiRequest('POST', '/v1/study-events', {
    device_id: DEVICE_ID,
    client_event_id: clientEventId,
    server_word_id: wordId,
    local_word_id: 'local_1',
    rating: 'easy',
    occurred_at: new Date().toISOString(),
    language: 'en'
  });
  assertEq(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
  assertEq(res.body.success, true);
  assertHas(res.body, 'event_id');
  assertHas(res.body, 'proficiency');
  console.log(`     → event_id=${res.body.event_id}, proficiency level=${res.body.proficiency?.level}`);
});

await test('POST /v1/study-events idempotent on replay', async () => {
  const res = await apiRequest('POST', '/v1/study-events', {
    device_id: DEVICE_ID,
    client_event_id: clientEventId,
    server_word_id: wordId,
    local_word_id: 'local_1',
    rating: 'easy',
    occurred_at: new Date().toISOString(),
    language: 'en'
  });
  assertEq(res.status, 200, `Expected 200, got ${res.status}`);
  assertEq(res.body.idempotent, true, `Expected idempotent:true, got ${JSON.stringify(res.body)}`);
});

await test('POST /v1/study-events/sync accepts batch events', async () => {
  const res = await apiRequest('POST', '/v1/study-events/sync', {
    device_id: DEVICE_ID,
    events: [
      {
        client_event_id: `e2e_sync_${Date.now()}`,
        server_word_id: wordId,
        local_word_id: 'local_2',
        rating: 'hard',
        occurred_at: new Date().toISOString()
      }
    ]
  });
  assertEq(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
  assertHas(res.body, 'accepted_event_ids');
  assertHas(res.body, 'proficiency');
  assertEq(res.body.accepted_event_ids.length, 1, 'Expected 1 accepted event');
  console.log(`     → proficiency level=${res.body.proficiency?.level}, consecutive=${res.body.proficiency?.consecutive_count}`);
});

await test('POST /v1/study-events with invalid rating returns 400', async () => {
  const res = await apiRequest('POST', '/v1/study-events', {
    device_id: DEVICE_ID,
    client_event_id: `e2e_bad_${Date.now()}`,
    server_word_id: wordId,
    local_word_id: 'local_x',
    rating: 'invalid_rating',
    occurred_at: new Date().toISOString(),
    language: 'en'
  });
  assertEq(res.status, 400, `Expected 400, got ${res.status}`);
  assert(res.body.error != null, `Expected an error code, got ${JSON.stringify(res.body)}`);
  console.log(`     → error=${res.body.error}`);
});

// 5. Proficiency
console.log('\n── 5. Proficiency ──────────────────────────────────────────────');
await test('GET /v1/proficiency returns proficiency data for device', async () => {
  const res = await apiRequest('GET', `/v1/proficiency?device_id=${DEVICE_ID}&language=en`);
  assertEq(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
  assertHas(res.body, 'level');
  assertHas(res.body, 'device_id');
  assertEq(res.body.device_id, DEVICE_ID);
  console.log(`     → level=${res.body.level}, consecutive_count=${res.body.consecutive_count}`);
});

// 6. User auth flow
console.log('\n── 6. User Auth Flow ───────────────────────────────────────────');
const testEmail = `e2e.test.${Date.now()}@example.local`;
const testPassword = `TestPass_${Date.now()}!`;
let sessionToken = null;
let userId = null;

await test('POST /v1/users/register creates a new user', async () => {
  const res = await apiRequest('POST', '/v1/users/register', {
    identifier: testEmail,
    password: testPassword,
    display_name: 'E2E Test User',
    device_id: DEVICE_ID
  });
  assertEq(res.status, 201, `Expected 201, got ${res.status}: ${JSON.stringify(res.body)}`);
  assertHas(res.body, 'user_id');
  assertHas(res.body, 'session_token');
  assertEq(res.body.identifier, testEmail);
  sessionToken = res.body.session_token;
  userId = res.body.user_id;
  console.log(`     → user_id=${userId}`);
});

await test('POST /v1/users/register duplicate returns 409', async () => {
  const res = await apiRequest('POST', '/v1/users/register', {
    identifier: testEmail,
    password: testPassword,
    display_name: 'Duplicate',
    device_id: DEVICE_ID
  });
  assertEq(res.status, 409, `Expected 409, got ${res.status}`);
  assertEq(res.body.error, 'user_exists');
});

await test('POST /v1/users/sign-in with valid credentials returns session', async () => {
  const res = await apiRequest('POST', '/v1/users/sign-in', {
    identifier: testEmail,
    password: testPassword,
    device_id: DEVICE_ID
  });
  assertEq(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
  assertHas(res.body, 'session_token');
  assertEq(res.body.user_id, userId);
  sessionToken = res.body.session_token;
});

await test('POST /v1/users/sign-in with wrong password returns 401', async () => {
  const res = await apiRequest('POST', '/v1/users/sign-in', {
    identifier: testEmail,
    password: 'wrong-password',
    device_id: DEVICE_ID
  });
  assertEq(res.status, 401, `Expected 401, got ${res.status}`);
  assertEq(res.body.error, 'invalid_credentials');
});

// 7. Authenticated requests
console.log('\n── 7. Authenticated Requests ───────────────────────────────────');

async function authedRequest(method, path, body) {
  const url = `${BASE_URL}${path}`;
  const rawBody = body != null ? JSON.stringify(body) : undefined;
  const headers = {
    ...(rawBody ? { 'content-type': 'application/json' } : {}),
    ...buildSignedHeaders(method, url, rawBody),
    'authorization': `Bearer ${sessionToken}`
  };
  const res = await fetch(url, { method, headers, body: rawBody });
  let json = null;
  try { json = await res.json(); } catch {}
  return { status: res.status, body: json };
}

await test('POST /v1/learning/cards signed-in returns items', async () => {
  const res = await authedRequest('POST', '/v1/learning/cards', {
    device_id: DEVICE_ID,
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });
  assertEq(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
  assert(Array.isArray(res.body.items), 'Expected items array');
  console.log(`     → ${res.body.items.length} word(s) returned for signed-in user`);
});

await test('POST /v1/study-events signed-in accepted and links to user', async () => {
  const res = await authedRequest('POST', '/v1/study-events', {
    device_id: DEVICE_ID,
    client_event_id: `e2e_auth_evt_${Date.now()}`,
    server_word_id: wordId,
    local_word_id: 'local_3',
    rating: 'too_easy',
    occurred_at: new Date().toISOString(),
    language: 'en'
  });
  assertEq(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
  assertEq(res.body.success, true);
});

await test('GET /v1/proficiency signed-in returns user_id', async () => {
  const res = await authedRequest('GET', `/v1/proficiency?device_id=${DEVICE_ID}&language=en`);
  assertEq(res.status, 200, `Expected 200, got ${res.status}`);
  assertEq(res.body.user_id, userId, `Expected user_id=${userId}`);
  console.log(`     → level=${res.body.level}`);
});

await test('Invalid bearer token returns 4xx with session error', async () => {
  const url = `${BASE_URL}/v1/learning/cards`;
  const rawBody = JSON.stringify({
    device_id: DEVICE_ID,
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });
  const headers = {
    'content-type': 'application/json',
    ...buildSignedHeaders('POST', url, rawBody),
    'authorization': 'Bearer invalid_token_xyz'
  };
  const res = await fetch(url, { method: 'POST', headers, body: rawBody });
  assert(res.status >= 400 && res.status < 500, `Expected 4xx, got ${res.status}`);
  const body = await res.json();
  assert(body.error != null, `Expected an error code, got ${JSON.stringify(body)}`);
  console.log(`     → status=${res.status}, error=${body.error}`);
});

await test('POST /v1/users/sign-out invalidates session', async () => {
  const res = await authedRequest('POST', '/v1/users/sign-out', null);
  assertEq(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
  assertEq(res.body.success, true);
});

await test('Signed-out token no longer valid', async () => {
  const url = `${BASE_URL}/v1/learning/cards`;
  const rawBody = JSON.stringify({
    device_id: DEVICE_ID,
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });
  const headers = {
    'content-type': 'application/json',
    ...buildSignedHeaders('POST', url, rawBody),
    'authorization': `Bearer ${sessionToken}`
  };
  const res = await fetch(url, { method: 'POST', headers, body: rawBody });
  assert(res.status >= 400 && res.status < 500, `Expected 4xx after sign-out, got ${res.status}`);
  const body = await res.json();
  assert(body.error != null, `Expected an error code, got ${JSON.stringify(body)}`);
  console.log(`     → status=${res.status}, error=${body.error}`);
});

// ── Summary ──────────────────────────────────────────────────────────────────

console.log('\n' + '─'.repeat(64));
console.log(`Results: ${passed} passed, ${failed} failed`);

if (issues.length > 0) {
  console.log('\nFailed tests:');
  for (const { test: name, error } of issues) {
    console.log(`  ❌ ${name}: ${error}`);
  }
}

if (failed > 0) process.exit(1);
