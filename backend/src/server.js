import { migrateDatabase } from './migrations.js';
import { createBackendRuntime } from './runtime.js';
import { createWorkerRunner } from './worker_runner.js';

const { config, server, store, vocabularyPoolScheduler, logger } = createBackendRuntime();
const workerRunner = config.embeddedWorker ? createWorkerRunner({ config, store, logger }) : null;

if (config.migrateOnStart && store.pool) {
  try {
    const { applied } = await migrateDatabase({ pool: store.pool, logger });
    logger.info('db.migration.complete', { applied_count: applied.length });
  } catch (error) {
    logger.error('db.migration.failed', { error: error.message });
    process.exit(1);
  }
}
server.listen(config.port, () => {
  logger.info('server_started', { port: config.port, url: `http://localhost:${config.port}` });
  if (config.vocabSchedulerEnabled) {
    vocabularyPoolScheduler.start();
  }
  workerRunner?.start();
});

process.on('SIGTERM', async () => {
  logger.info('server_stopping', { signal: 'SIGTERM' });
  vocabularyPoolScheduler.stop();
  await workerRunner?.stop();
  server.close(() => process.exit(0));
});
