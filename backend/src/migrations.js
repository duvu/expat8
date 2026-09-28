import { readdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { readSchemaSql } from './database.js';

const currentDir = dirname(fileURLToPath(import.meta.url));
const defaultMigrationsDir = resolve(currentDir, '../db/migrations');

export const BASELINE_VERSION = '00000000_baseline_schema';

// Arbitrary constant shared by every backend process so only one of them
// migrates at a time.
const MIGRATION_LOCK_KEY = 80_870_928;

export function listMigrations({ migrationsDir = defaultMigrationsDir } = {}) {
  return readdirSync(migrationsDir)
    .filter((name) => name.endsWith('.sql'))
    .sort()
    .map((name) => ({
      version: name.replace(/\.sql$/, ''),
      sql: readFileSync(resolve(migrationsDir, name), 'utf8')
    }));
}

/**
 * Brings the database up to date and records what was applied in
 * `schema_migrations`.
 *
 * - Empty database: applies `db/schema.sql` as the baseline.
 * - Existing database without history (Compose init or a hand-migrated
 *   production DB): records the baseline without re-running it.
 * - Then applies every migration not yet recorded, each in its own
 *   transaction (except single-statement `CONCURRENTLY` migrations). Migrations must stay idempotent because databases created
 *   before this runner existed replay all of them once.
 */
export async function migrateDatabase({
  pool,
  logger,
  schemaSql = readSchemaSql(),
  migrations = listMigrations()
}) {
  const client = await pool.connect();
  try {
    await client.query('SELECT pg_advisory_lock($1)', [MIGRATION_LOCK_KEY]);
    try {
      await client.query(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
          version TEXT PRIMARY KEY,
          applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      `);
      const applied = new Set(
        (await client.query('SELECT version FROM schema_migrations')).rows.map((row) => row.version)
      );

      const appliedNow = [];
      if (!applied.has(BASELINE_VERSION)) {
        const hasBaseline = (await client.query("SELECT to_regclass('public.words') IS NOT NULL AS present")).rows[0]
          .present;
        await applyInTransaction(client, BASELINE_VERSION, hasBaseline ? null : schemaSql);
        appliedNow.push(BASELINE_VERSION);
        logger?.info('db.migration.baseline', { applied_schema: !hasBaseline });
      }

      for (const migration of migrations) {
        if (applied.has(migration.version)) {
          continue;
        }
        await applyInTransaction(client, migration.version, migration.sql);
        appliedNow.push(migration.version);
        logger?.info('db.migration.applied', { version: migration.version });
      }

      return { applied: appliedNow };
    } finally {
      await client.query('SELECT pg_advisory_unlock($1)', [MIGRATION_LOCK_KEY]);
    }
  } finally {
    client.release();
  }
}

async function applyInTransaction(client, version, sql) {
  if (sql && /\bCONCURRENTLY\b/i.test(sql)) {
    // CREATE INDEX CONCURRENTLY cannot run inside a transaction block, so such
    // migrations must hold exactly one idempotent statement.
    try {
      await client.query(sql);
    } catch (error) {
      error.message = `migration ${version} failed: ${error.message}`;
      throw error;
    }
    await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [version]);
    return;
  }

  await client.query('BEGIN');
  try {
    if (sql) {
      await client.query(sql);
    }
    await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [version]);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    error.message = `migration ${version} failed: ${error.message}`;
    throw error;
  }
}
