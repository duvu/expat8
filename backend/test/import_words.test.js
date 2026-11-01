import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import pg from 'pg';

import { importWords, parseArgs, readWordFiles } from '../src/import_words.js';
import { migrateDatabase } from '../src/migrations.js';
import { PostgresWordStore } from '../src/postgres_word_store.js';
import { WordStore } from '../src/word_store.js';

const pgTestOptions = process.env.TEST_DATABASE_URL
  ? {}
  : { skip: 'Set TEST_DATABASE_URL to run PostgreSQL integration tests' };

function hskWord(term, pinyin, difficulty = 'HSK1', overrides = {}) {
  return {
    term,
    language: 'zh',
    meaning_vi: 'nghia thu',
    part_of_speech: 'noun',
    ipa: '',
    vietnamese_pronunciation: pinyin,
    example: `这是${term}。`,
    example_vi: 'Day la tu thu.',
    difficulty,
    topics: ['basic'],
    entry_type: 'word',
    ...overrides
  };
}

function captureLogger() {
  const events = [];
  const record =
    (level) =>
    (event, fields = {}) =>
      events.push({ level, event, ...fields });
  return { events, debug: record('debug'), info: record('info'), warn: record('warn'), error: record('error') };
}

async function withWordDir(files, run) {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'import-words-'));
  try {
    for (const [name, content] of Object.entries(files)) {
      await writeFile(path.join(dir, name), typeof content === 'string' ? content : JSON.stringify(content));
    }
    return await run(dir);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

const sampleFiles = {
  'hsk1.json': [hskWord('猫', 'māo'), hskWord('狗', 'gǒu'), hskWord('猫', 'māo')],
  'hsk2.json': [hskWord('电脑', 'diàn nǎo', 'HSK2')],
  'notes.txt': 'ignored'
};

test('importWords inserts valid words, reports invalid ones, and tallies per level', async () => {
  await withWordDir(
    {
      ...sampleFiles,
      'bad.json': [
        hskWord('鸟', 'niǎo', 'HSK1', { example_vi: '' }),
        hskWord('鱼', '', 'HSK1'),
        hskWord('虎', 'hǔ', 'HSK9'),
        hskWord('马', 'mǎ', 'HSK1', { topics: 'animal' })
      ]
    },
    async (dir) => {
      const logger = captureLogger();
      const store = new WordStore({ seed: false });
      const summary = await importWords({ store, files: await readWordFiles(dir), logger });

      assert.equal(summary.total, 8);
      assert.equal(summary.inserted, 3, '猫, 狗, 电脑');
      assert.equal(summary.existing, 1, 'duplicate 猫 inside the files');
      assert.equal(summary.invalid, 4);
      assert.deepEqual(summary.by_level.HSK2, { inserted: 1, existing: 0, valid: 0, invalid: 0 });

      const reasons = logger.events.filter((e) => e.event === 'words.import.invalid');
      assert.deepEqual(
        reasons.map((e) => [e.file, e.term, e.reason]),
        [
          ['bad.json', '鸟', 'missing_example_vi'],
          ['bad.json', '鱼', 'missing_vietnamese_pronunciation'],
          ['bad.json', '虎', 'invalid_difficulty'],
          ['bad.json', '马', 'topics_must_be_array']
        ]
      );
      const stored = store.recentWords({ targetLanguage: 'zh' });
      assert.equal(stored.length, 3);
      assert.ok(stored.every((word) => word.generation_source === 'import'));
    }
  );
});

test('importWords is idempotent and leaves existing words untouched', async () => {
  await withWordDir(sampleFiles, async (dir) => {
    const store = new WordStore({ seed: false });
    const logger = captureLogger();
    const existing = store.insertWord(hskWord('猫', 'māo', 'HSK1', { meaning_vi: 'meo (da co)' })).word;

    const first = await importWords({ store, files: await readWordFiles(dir), logger });
    assert.equal(first.inserted, 2);
    assert.equal(first.existing, 2);

    const second = await importWords({ store, files: await readWordFiles(dir), logger });
    assert.equal(second.inserted, 0);
    assert.equal(second.existing, 4);
    assert.equal(store.recentWords({ targetLanguage: 'zh' }).length, 3);
    assert.equal(store.insertWord(hskWord('猫', 'māo')).word.meaning_vi, existing.meaning_vi);
  });
});

test('importWords --dry-run validates but never touches the store', async () => {
  await withWordDir({ ...sampleFiles, 'bad.json': [hskWord('鸟', 'niǎo', 'HSK1', { example: '' })] }, async (dir) => {
    const store = {
      insertWord() {
        assert.fail('dry run must not write');
      }
    };
    const summary = await importWords({
      store,
      files: await readWordFiles(dir),
      dryRun: true,
      logger: captureLogger()
    });
    assert.equal(summary.dry_run, true);
    assert.equal(summary.valid, 4);
    assert.equal(summary.invalid, 1);
    assert.equal(summary.inserted, 0);
    assert.equal(summary.existing, 0);
  });
});

test('readWordFiles rejects empty directories and non-array files', async () => {
  await withWordDir({ 'readme.txt': 'x' }, async (dir) => {
    await assert.rejects(readWordFiles(dir), /no \.json files/);
  });
  await withWordDir({ 'one.json': { term: 'x' } }, async (dir) => {
    await assert.rejects(readWordFiles(dir), /must contain a JSON array/);
  });
});

test('parseArgs requires --dir and understands --dry-run', () => {
  assert.deepEqual(parseArgs(['--dir', 'data/zh_hsk']), { dir: 'data/zh_hsk', dryRun: false });
  assert.deepEqual(parseArgs(['--dry-run', '--dir', 'x']), { dir: 'x', dryRun: true });
  assert.throws(() => parseArgs([]), /usage/);
  assert.throws(() => parseArgs(['--dir', 'x', '--nope']), /unknown argument/);
});

test('importWords works through PostgresWordStore and is idempotent', pgTestOptions, async (t) => {
  // A dedicated database keeps this file independent of the other PostgreSQL tests, which reset `public`.
  const dbName = 'import_words_test';
  const admin = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL, max: 1 });
  await admin.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
  await admin.query(`CREATE DATABASE ${dbName}`);
  const url = new URL(process.env.TEST_DATABASE_URL);
  url.pathname = `/${dbName}`;
  const pool = new pg.Pool({ connectionString: url.toString(), max: 2 });
  t.after(async () => {
    await pool.end();
    await admin.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
    await admin.end();
  });
  await migrateDatabase({ pool });

  await withWordDir(sampleFiles, async (dir) => {
    const store = new PostgresWordStore({ pool });
    const logger = captureLogger();
    const files = await readWordFiles(dir);

    const dry = await importWords({ store, files, dryRun: true, logger });
    assert.equal(dry.valid, 4);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM words')).rows[0].n, 0, 'dry run wrote nothing');

    const first = await importWords({ store, files, logger });
    assert.equal(first.inserted, 3);
    assert.equal(first.existing, 1);
    const second = await importWords({ store, files, logger });
    assert.equal(second.inserted, 0);
    assert.equal(second.existing, 4);

    const rows = (await pool.query('SELECT term, difficulty, generation_source FROM words ORDER BY term')).rows;
    assert.equal(rows.length, 3);
    assert.ok(rows.every((row) => row.generation_source === 'import'));
  });
});
