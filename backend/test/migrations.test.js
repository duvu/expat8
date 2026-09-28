import assert from 'node:assert/strict';
import test from 'node:test';
import pg from 'pg';

import { readSchemaSql } from '../src/database.js';
import { BASELINE_VERSION, listMigrations, migrateDatabase } from '../src/migrations.js';
import { PostgresWordStore } from '../src/postgres_word_store.js';

const testDatabaseUrl = process.env.TEST_DATABASE_URL;
const pgTestOptions = testDatabaseUrl ? {} : { skip: 'Set TEST_DATABASE_URL to run PostgreSQL migration tests' };

test('migration files are uniquely versioned and sorted', () => {
  const versions = listMigrations().map((migration) => migration.version);
  assert.ok(versions.length > 0);
  assert.deepEqual(versions, [...versions].sort());
  assert.equal(new Set(versions).size, versions.length);
});

test('migrates an empty database and is a no-op on the second run', pgTestOptions, async (t) => {
  const pool = new pg.Pool({ connectionString: testDatabaseUrl });
  t.after(async () => pool.end());
  await dropAllTables(pool);

  const first = await migrateDatabase({ pool });
  assert.equal(first.applied[0], BASELINE_VERSION);
  assert.equal(first.applied.length, listMigrations().length + 1);

  const second = await migrateDatabase({ pool });
  assert.deepEqual(second.applied, []);

  for (const table of ['speaking_events', 'speaking_prompts', 'content_packs', 'exam_sessions', 'nonces']) {
    const { rows } = await pool.query('SELECT to_regclass($1) IS NOT NULL AS present', [`public.${table}`]);
    assert.equal(rows[0].present, true, `${table} should exist after migrating`);
  }
});

test('adopts a database initialized from schema.sql without migration history', pgTestOptions, async (t) => {
  const pool = new pg.Pool({ connectionString: testDatabaseUrl });
  t.after(async () => pool.end());
  await dropAllTables(pool);
  await pool.query(readSchemaSql());

  const result = await migrateDatabase({ pool });
  assert.equal(result.applied[0], BASELINE_VERSION);
  assert.equal(result.applied.length, listMigrations().length + 1);
});

test('replays every migration on a fully migrated database without history', pgTestOptions, async (t) => {
  const pool = new pg.Pool({ connectionString: testDatabaseUrl });
  t.after(async () => pool.end());
  await dropAllTables(pool);
  await migrateDatabase({ pool });
  await pool.query('DROP TABLE schema_migrations');

  const result = await migrateDatabase({ pool });
  assert.equal(result.applied.length, listMigrations().length + 1);
});

test('migrated schema accepts loop_completed speaking events', pgTestOptions, async (t) => {
  const pool = new pg.Pool({ connectionString: testDatabaseUrl });
  t.after(async () => pool.end());
  await dropAllTables(pool);
  await migrateDatabase({ pool });

  const store = new PostgresWordStore({ pool });
  await store.recordSpeakingEvent({
    deviceId: 'device_loop_pg',
    event: {
      client_event_id: 'loop_done_pg',
      event_type: 'loop_completed',
      occurred_at: '2026-05-10T09:05:00.000Z',
      speaking: { duration_ms: 60000, prompts_count: 5 }
    }
  });

  const summary = await store.getSpeakingSummary({ deviceId: 'device_loop_pg', weekStart: '2026-05-10' });
  assert.equal(summary.loop_completion_count, 1);
});

export async function dropAllTables(pool) {
  await pool.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
}

test('postgres sign-in claims anonymous study, speaking and proficiency history', pgTestOptions, async (t) => {
  const pool = new pg.Pool({ connectionString: testDatabaseUrl });
  t.after(async () => pool.end());
  await dropAllTables(pool);
  await migrateDatabase({ pool });
  const store = new PostgresWordStore({ pool });

  const { word } = await store.insertWord({
    term: 'reliable',
    language: 'en',
    meaning_vi: 'đáng tin cậy',
    part_of_speech: 'adjective',
    ipa: '/rɪˈlaɪəbl/',
    vietnamese_pronunciation: 'ri-lai-ơ-bồ',
    example: 'She is reliable.',
    example_vi: 'Cô ấy đáng tin cậy.',
    difficulty: 'A1',
    topics: ['work']
  });
  const events = Array.from({ length: 5 }, (_, i) => ({
    client_event_id: `evt_pg_claim_${i}`,
    server_word_id: word.id,
    rating: 'too_easy',
    occurred_at: `2026-09-28T08:0${i}:00.000Z`
  }));
  events.push({
    client_event_id: 'loop_pg_claim',
    event_type: 'loop_completed',
    occurred_at: '2026-09-28T09:00:00.000Z',
    speaking: { duration_ms: 60000, prompts_count: 3 }
  });
  await store.syncStudyEvents({ deviceId: 'device_pg_claim', events, language: 'en' });
  const deviceLevel = (await store.getProficiency({ deviceId: 'device_pg_claim', language: 'en' })).level;
  assert.notEqual(deviceLevel, 'A1');

  const { user } = await store.registerUser({
    identifier: 'pg-claim@example.com',
    password: 'correct horse battery',
    deviceId: 'device_pg_claim'
  });

  const userLevel = (await store.getProficiency({ deviceId: 'other', userId: user.id, language: 'en' })).level;
  assert.equal(userLevel, deviceLevel);
  const summary = await store.getSpeakingSummary({
    deviceId: 'other',
    userId: user.id,
    weekStart: '2026-09-28T00:00:00.000Z'
  });
  assert.equal(summary.loop_completion_count, 1);
  const { rows } = await pool.query('SELECT count(*)::int AS n FROM study_events WHERE user_id = $1', [user.id]);
  assert.equal(rows[0].n, 5);
});
