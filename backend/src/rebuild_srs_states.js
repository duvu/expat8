// One-off: recompute every user_word_states row from study_events with the SRS scheduler
// (run after the 20261027_srs_memory migration, or whenever the scheduler changes).
import pg from 'pg';

import { loadConfig } from './config.js';
import { createLogger } from './logger.js';
import { PostgresWordStore } from './postgres_word_store.js';

const config = loadConfig();
const logger = createLogger({
  level: config.logLevel,
  redactionEnabled: config.logRedactionEnabled,
  component: 'rebuild_srs_states'
});

if (!config.databaseUrl) {
  logger.error('srs.rebuild.no_database_url', {});
  process.exit(1);
}

const pool = new pg.Pool({ connectionString: config.databaseUrl, max: 2 });
try {
  const rebuilt = await new PostgresWordStore({ pool, logger }).rebuildWordStates();
  logger.info('srs.rebuild.complete', { rebuilt_count: rebuilt });
} catch (error) {
  logger.error('srs.rebuild.failed', { error: error.message });
  process.exitCode = 1;
} finally {
  await pool.end();
}
