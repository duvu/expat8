import pg from 'pg';

import { loadConfig } from './config.js';
import { createLogger } from './logger.js';
import { migrateDatabase } from './migrations.js';

const config = loadConfig();
const logger = createLogger({
  level: config.logLevel,
  redactionEnabled: config.logRedactionEnabled,
  component: 'migrate'
});

if (!config.databaseUrl) {
  logger.error('db.migration.no_database_url', {});
  process.exit(1);
}

const pool = new pg.Pool({ connectionString: config.databaseUrl, max: 1 });
try {
  const { applied } = await migrateDatabase({ pool, logger });
  logger.info('db.migration.complete', { applied_count: applied.length });
} catch (error) {
  logger.error('db.migration.failed', { error: error.message });
  process.exitCode = 1;
} finally {
  await pool.end();
}
