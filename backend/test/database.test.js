import assert from 'node:assert/strict';
import test from 'node:test';

import { initializeDatabaseSchema, readSchemaSql } from '../src/database.js';

test('reads schema SQL and applies it through the pool', async () => {
  const schemaSql = readSchemaSql();
  const pool = new SchemaPool();

  await initializeDatabaseSchema({ pool, schemaSql });

  assert.match(schemaSql, /CREATE TABLE words/);
  assert.match(schemaSql, /CREATE TABLE user_proficiency/);
  assert.match(schemaSql, /scale TEXT NOT NULL DEFAULT 'cefr'/);
  assert.match(schemaSql, /level_index INTEGER NOT NULL DEFAULT 0/);
  assert.equal(pool.queries.length, 1);
  assert.equal(pool.queries[0], schemaSql);
});

class SchemaPool {
  constructor() {
    this.queries = [];
  }

  async query(sql) {
    this.queries.push(sql);
    return { rows: [] };
  }
}
