import assert from 'node:assert/strict';
import test from 'node:test';

import { loadConfig } from '../src/config.js';
import { PostgresWordStore } from '../src/postgres_word_store.js';
import { createStore } from '../src/runtime.js';
import { WordStore } from '../src/word_store.js';

test('creates postgres store when database URL is configured', () => {
  const store = createStore({
    config: loadConfig({ DATABASE_URL: 'postgres://expat8:secret@db:5432/expat8' }),
    poolFactory: (options) => ({ options })
  });

  assert.ok(store instanceof PostgresWordStore);
  assert.equal(store.pool.options.connectionString, 'postgres://expat8:secret@db:5432/expat8');
});

test('creates in-memory store when database URL is omitted', () => {
  const store = createStore({
    config: loadConfig({}),
    poolFactory: () => assert.fail('poolFactory should not be called')
  });

  assert.ok(store instanceof WordStore);
});
