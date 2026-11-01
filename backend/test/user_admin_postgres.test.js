import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import pg from 'pg';

import { createApp } from '../src/app.js';
import { USER_REFERENCES } from '../src/domain/user_admin.js';
import { migrateDatabase } from '../src/migrations.js';
import { PostgresWordStore } from '../src/postgres_word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

const pgTestOptions = process.env.TEST_DATABASE_URL
  ? {}
  : { skip: 'Set TEST_DATABASE_URL to run PostgreSQL integration tests' };

const T = '2026-01-01T00:00:00.000Z';
const ADMIN = { 'content-type': 'application/json', 'x-expat8-admin-token': 'admin-token' };

// A dedicated database keeps this file independent of the tests that reset `public`.
async function createTestDatabase(t, dbName) {
  const admin = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL, max: 1 });
  await admin.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
  await admin.query(`CREATE DATABASE ${dbName}`);
  const url = new URL(process.env.TEST_DATABASE_URL);
  url.pathname = `/${dbName}`;
  const pool = new pg.Pool({ connectionString: url.toString(), max: 4 });
  t.after(async () => {
    await pool.end();
    await admin.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
    await admin.end();
  });
  await migrateDatabase({ pool });
  return pool;
}

async function insert(pool, table, row) {
  const columns = Object.keys(row);
  await pool.query(
    `INSERT INTO ${table} (${columns.join(', ')}) VALUES (${columns.map((_, i) => `$${i + 1}`).join(', ')})`,
    Object.values(row)
  );
}

const count = async (pool, sql, params = []) => Number((await pool.query(sql, params)).rows[0].count);

/**
 * Seeds `userId` (signed in on `device`) with a row in every table that
 * references a user, plus anonymous rows recorded on the same device.
 */
async function seedAccount(pool, { userId, device, tag }) {
  const id = (name) => `${tag}_${name}`;
  await insert(pool, 'users', { id: userId, identifier: `${tag}@example.com`, password_hash: 'x', created_at: T, updated_at: T });
  await insert(pool, 'user_sessions', { id: id('sess'), user_id: userId, token_hash: id('hash'), device_id: device, created_at: T });
  for (const n of [1, 2]) {
    await insert(pool, 'words', {
      id: id(`w${n}`), term: `${tag}${n}`, normalized_term: `${tag}${n}`, language: 'en', meaning_vi: 'm', ipa: 'i',
      vietnamese_pronunciation: 'p', example: 'e', example_vi: 'v', difficulty: 'A1', topics_json: '[]',
      generation_source: 'seed', created_at: T, updated_at: T
    });
  }
  await insert(pool, 'user_proficiency', { id: id('prof'), user_id: userId, device_id: device, language: 'en', level: 'A1', created_at: T, updated_at: T });
  await insert(pool, 'user_proficiency', { id: id('prof_anon'), user_id: null, device_id: device, language: 'zh', level: 'A1', created_at: T, updated_at: T });
  await insert(pool, 'user_word_states', { id: id('state'), user_id: userId, device_id: device, word_id: id('w1'), status: 'new', updated_at: T });
  await insert(pool, 'user_word_states', { id: id('state_anon'), user_id: null, device_id: device, word_id: id('w2'), status: 'new', updated_at: T });
  await insert(pool, 'user_cached_words', { user_id: userId, device_id: device, word_id: id('w1'), observed_at: T, updated_at: T });
  await insert(pool, 'user_cached_words', { user_id: null, device_id: device, word_id: id('w2'), observed_at: T, updated_at: T });
  for (const [suffix, owner] of [['', userId], ['_anon', null]]) {
    await insert(pool, 'study_events', { id: id(`study${suffix}`), client_event_id: id(`study${suffix}`), device_id: device, user_id: owner, word_id: id('w1'), rating: 'easy', occurred_at: T, received_at: T });
    await insert(pool, 'speaking_events', { id: id(`speak${suffix}`), event_id: id(`speak${suffix}`), device_id: device, user_id: owner, event_type: 'speaking_recorded', occurred_at: T, received_at: T });
    await insert(pool, 'game_rounds', {
      id: id(`game${suffix}`), client_round_id: id(`game${suffix}`), device_id: device, user_id: owner, game: 'g', mode: 'm', language: 'en',
      score: 1, correct_count: 1, answered_count: 1, best_combo: 1, wave: 1, duration_ms: 1, completed_at: T, received_at: T
    });
    await insert(pool, 'user_submitted_words', { id: id(`sub${suffix}`), device_id: device, user_id: owner, submitted_term: 's', normalized_term: `s${suffix}`, language: 'en', created_at: T, updated_at: T });
    await insert(pool, 'user_submitted_word_jobs', { id: id(`subjob${suffix}`), submission_id: id(`sub${suffix}`), status: 'queued', queued_at: T, created_at: T, updated_at: T });
  }
  // exam
  await insert(pool, 'exam_sessions', { id: id('exam'), user_id: userId, topic: 't', language: 'en', created_at: T, expires_at: T });
  await insert(pool, 'exam_questions', { id: id('examq'), session_id: id('exam'), word_id: id('w1'), prompt_word: 'p', choices_json: '[]', correct_index: 0, ordinal: 0, created_at: T });
  await insert(pool, 'exam_attempts', { id: id('attempt'), session_id: id('exam'), user_id: userId, topic: 't', language: 'en', total_questions: 1, correct_count: 1, score_pct: 100, created_at: T });
  await insert(pool, 'exam_certificates', { id: id('cert'), attempt_id: id('attempt'), user_id: userId, topic: 't', language: 'en', score_pct: 100, issued_at: T });
  // owned article with terms, review item, processing job and workplace sentence
  await insert(pool, 'articles', { id: id('article'), owner_user_id: userId, title: 'a', language: 'en', raw_text: 'r', created_at: T, updated_at: T });
  await insert(pool, 'article_processing_jobs', { id: id('job'), article_id: id('article'), status: 'queued', queued_at: T, created_at: T, updated_at: T });
  await insert(pool, 'terms', { id: id('term1'), language: 'en', display_term: 'x', normalized_term: id('term1'), created_at: T });
  await insert(pool, 'word_senses', { id: id('sense1'), term_id: id('term1'), meaning_vi: 'm', created_at: T, updated_at: T });
  await insert(pool, 'article_terms', { id: id('aterm'), article_id: id('article'), term_id: id('term1'), word_sense_id: id('sense1'), surface_text: 'x', created_at: T });
  await insert(pool, 'vocabulary_review_items', { id: id('review_own'), word_sense_id: id('sense1'), article_id: id('article'), created_at: T, updated_at: T });
  await insert(pool, 'workplace_sentences', { id: id('sentence'), text: 't', normalized_text: id('sentence'), language: 'en', meaning_vi: 'm', generation_source: 's', created_at: T, updated_at: T });
  await insert(pool, 'article_workplace_sentences', { id: id('asl'), article_id: id('article'), workplace_sentence_id: id('sentence'), created_at: T });
  // owned memorization passage; own progress plus another learner's progress on it
  await insert(pool, 'memorization_passages', { id: id('passage'), owner_user_id: userId, title: 'p', language: 'en', raw_text: 'r', created_at: T, updated_at: T });
  await insert(pool, 'memorization_segments', { id: id('segment'), passage_id: id('passage'), position: 0, text: 't', created_at: T });
  await insert(pool, 'terms', { id: id('term2'), language: 'en', display_term: 'y', normalized_term: id('term2'), created_at: T });
  await insert(pool, 'word_senses', { id: id('sense2'), term_id: id('term2'), meaning_vi: 'm', created_at: T, updated_at: T });
  await insert(pool, 'memorization_segment_terms', { id: id('mterm'), passage_id: id('passage'), segment_id: id('segment'), term_id: id('term2'), word_sense_id: id('sense2'), surface_text: 'y', created_at: T });
  await insert(pool, 'memorization_segment_progress', { id: id('mprog'), user_id: userId, segment_id: id('segment'), created_at: T, updated_at: T });
  // shadowing entries: account-owned and anonymous on the device
  await insert(pool, 'shadowing_videos', { id: id('video'), source_type: 'youtube', provider_video_id: id('video'), source_url: 'u', title: 't', transcript_source: 's', created_at: T, updated_at: T });
  await insert(pool, 'shadowing_video_entries', { id: id('shadow'), video_id: id('video'), owner_user_id: userId, created_at: T, updated_at: T });
  await insert(pool, 'shadowing_video_entries', { id: id('shadow_anon'), video_id: id('video'), owner_device_id: device, created_at: T, updated_at: T });
  // admin content this user reviewed: kept, reference cleared
  await insert(pool, 'terms', { id: id('term3'), language: 'en', display_term: 'z', normalized_term: id('term3'), created_at: T });
  await insert(pool, 'word_senses', { id: id('sense3'), term_id: id('term3'), meaning_vi: 'm', created_at: T, updated_at: T });
  await insert(pool, 'vocabulary_review_items', { id: id('review_admin'), word_sense_id: id('sense3'), reviewer_user_id: userId, created_at: T, updated_at: T });
  await insert(pool, 'speaking_prompts', { id: id('prompt'), target_text: 't', vi_hint: 'h', reviewer_user_id: userId, article_term_id: id('aterm'), created_at: T, updated_at: T });
}

async function textColumnsMatching(pool, value) {
  const columns = await pool.query(
    `SELECT table_name, column_name FROM information_schema.columns
     WHERE table_schema = 'public' AND data_type = 'text' AND table_name <> 'schema_migrations'`
  );
  const found = [];
  for (const { table_name: table, column_name: column } of columns.rows) {
    const rows = await count(pool, `SELECT count(*) FROM ${table} WHERE ${column} = $1`, [value]);
    if (rows > 0) found.push(`${table}.${column}`);
  }
  return found;
}

test('deleteUser removes everything tied to the account and nothing of other learners', pgTestOptions, async (t) => {
  const pool = await createTestDatabase(t, 'user_admin_delete_test');
  const store = new PostgresWordStore({ pool, logger: { error() {}, info() {} } });
  await seedAccount(pool, { userId: 'user_target', device: 'dev_target', tag: 'tg' });
  await seedAccount(pool, { userId: 'user_other', device: 'dev_other', tag: 'ot' });
  // Another learner using the target's device keeps their own rows.
  await insert(pool, 'study_events', { id: 'shared_evt', client_event_id: 'shared_evt', device_id: 'dev_target', user_id: 'user_other', word_id: 'ot_w1', rating: 'easy', occurred_at: T, received_at: T });
  // Another learner's progress on the target's passage goes with the passage.
  await insert(pool, 'memorization_segment_progress', { id: 'other_prog', user_id: 'user_other', segment_id: 'tg_segment', created_at: T, updated_at: T });

  assert.equal(await store.deleteUser({ userId: 'user_missing' }), null);
  const summary = await store.deleteUser({ userId: 'user_target' });

  assert.deepEqual(summary, {
    user: 1,
    sessions: 1,
    proficiency: 2,
    study_events: 2,
    speaking_events: 2,
    game_rounds: 2,
    exam_rows: 4,
    word_states: 2,
    cached_words: 2,
    submitted_words: 2,
    articles: 1,
    memorization_content: 1,
    memorization_progress: 1,
    shadowing_entries: 2,
    cleared_reviewer_refs: 2
  });

  for (const { table, column, action } of USER_REFERENCES) {
    const remaining = await count(pool, `SELECT count(*) FROM ${table} WHERE ${column} = $1`, ['user_target']);
    assert.equal(remaining, 0, `${table}.${column} still references the deleted user`);
    if (action === 'clear') {
      assert.equal(await count(pool, `SELECT count(*) FROM ${table} WHERE id LIKE 'tg_%'`), 1, `${table} row must be kept`);
    }
  }
  assert.deepEqual(await textColumnsMatching(pool, 'user_target'), []);
  assert.deepEqual(await textColumnsMatching(pool, 'dev_target'), ['study_events.device_id'], 'only the other learner\'s row may mention the shared device');

  // Content created only for the deleted account is gone, shared content stays.
  assert.equal(await count(pool, "SELECT count(*) FROM word_senses WHERE id IN ('tg_sense1', 'tg_sense2')"), 0);
  assert.equal(await count(pool, "SELECT count(*) FROM word_senses WHERE id = 'tg_sense3'"), 1);
  assert.equal(await count(pool, "SELECT count(*) FROM workplace_sentences WHERE id = 'tg_sentence'"), 0);
  assert.equal(await count(pool, "SELECT count(*) FROM words WHERE id LIKE 'tg_%'"), 2);
  assert.equal(await count(pool, "SELECT count(*) FROM speaking_prompts WHERE id = 'tg_prompt' AND article_term_id IS NULL"), 1);
  assert.equal(await count(pool, "SELECT count(*) FROM memorization_segment_progress WHERE id = 'other_prog'"), 0);

  // The other learner is untouched, including anonymous data on their own device.
  for (const { table, column, action } of USER_REFERENCES) {
    const expected = action === 'clear' ? 1 : table === 'user_cached_words' ? 1 : null;
    const actual = await count(pool, `SELECT count(*) FROM ${table} WHERE ${column} = $1`, ['user_other']);
    assert.ok(actual >= 1, `${table}.${column} rows of the other learner must survive`);
    if (expected !== null) assert.equal(actual, expected);
  }
  assert.equal(await count(pool, "SELECT count(*) FROM study_events WHERE user_id IS NULL AND device_id = 'dev_other'"), 1);
  assert.equal(await count(pool, "SELECT count(*) FROM shadowing_video_entries WHERE owner_device_id = 'dev_other'"), 1);
  assert.equal(await count(pool, "SELECT count(*) FROM study_events WHERE id = 'shared_evt'"), 1);
});

test('every foreign key to users is covered by the account deletion', pgTestOptions, async (t) => {
  const pool = await createTestDatabase(t, 'user_admin_fk_test');
  const covered = new Set(USER_REFERENCES.map(({ table, column }) => `${table}.${column}`));

  const foreignKeys = await pool.query(
    `SELECT kcu.table_name, kcu.column_name
     FROM information_schema.table_constraints tc
     JOIN information_schema.key_column_usage kcu
       ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
     JOIN information_schema.constraint_column_usage ccu
       ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
     WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public' AND ccu.table_name = 'users'`
  );
  const uncovered = foreignKeys.rows
    .map(({ table_name: table, column_name: column }) => `${table}.${column}`)
    .filter((reference) => !covered.has(reference));
  assert.deepEqual(
    uncovered,
    [],
    'New foreign key to users(id): add it to USER_REFERENCES, to deleteUser (stores/postgres/user_admin.js and the memory store) and to this test\'s seed'
  );

  // Tables that hold a user id without a foreign key (events, word states...) must be covered too.
  const userColumns = await pool.query(
    `SELECT table_name, column_name FROM information_schema.columns
     WHERE table_schema = 'public' AND column_name ~ '(^|_)user_id$'`
  );
  const unlisted = userColumns.rows
    .map(({ table_name: table, column_name: column }) => `${table}.${column}`)
    .filter((reference) => !covered.has(reference));
  assert.deepEqual(unlisted, [], 'user id column missing from USER_REFERENCES');

  const schemaColumns = new Set(userColumns.rows.map(({ table_name: t, column_name: c }) => `${t}.${c}`));
  assert.deepEqual([...covered].filter((reference) => !schemaColumns.has(reference)), [], 'stale USER_REFERENCES entry');
});

test('admin endpoints reset passwords and delete accounts against PostgreSQL', pgTestOptions, async (t) => {
  const pool = await createTestDatabase(t, 'user_admin_api_test');
  const store = new PostgresWordStore({ pool, logger: { error() {}, info() {} } });
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig({ ADMIN_API_TOKENS: 'admin-token' }) })
  );
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = (path, method, body) =>
    fetch(`${base}${path}`, signedFetchOptions(`${base}${path}`, { method, headers: ADMIN, ...(body ? { body: JSON.stringify(body) } : {}) }));

  const { user, sessionToken } = await store.registerUser({ identifier: 'Pg.Learner@Example.com', password: 'old password 1', deviceId: 'dev_api' });
  const reset = await call(`/v1/admin/users/${user.id}/reset-password`, 'POST', {});
  assert.equal(reset.status, 200);
  const resetBody = await reset.json();
  assert.equal(resetBody.identifier, 'pg.learner@example.com');
  assert.ok(resetBody.temporary_password.length >= 12);
  assert.equal(await store.resolveUserSession({ sessionToken }), null);
  await assert.rejects(store.createUserSession({ identifier: 'pg.learner@example.com', password: 'old password 1' }));
  assert.equal((await store.createUserSession({ identifier: 'pg.learner@example.com', password: resetBody.temporary_password })).user.id, user.id);

  const refused = await call(`/v1/admin/users/${user.id}`, 'DELETE', { confirm: 'someone@else.com' });
  assert.equal(refused.status, 400);
  assert.deepEqual(await refused.json(), { error: 'confirmation_required' });
  const deleted = await call(`/v1/admin/users/${user.id}`, 'DELETE', { confirm: 'PG.learner@example.com ' });
  assert.equal(deleted.status, 200);
  const deletedBody = await deleted.json();
  assert.equal(deletedBody.deleted.user, 1);
  assert.equal(deletedBody.deleted.sessions, 2);
  assert.equal((await call(`/v1/admin/users/${user.id}`, 'DELETE', { confirm: 'pg.learner@example.com' })).status, 404);
  assert.equal((await call(`/v1/admin/users/${user.id}/reset-password`, 'POST', {})).status, 404);
});
