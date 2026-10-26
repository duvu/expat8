import { createStore } from './runtime.js';
import { loadConfig } from './config.js';
import { createLogger } from './logger.js';
import { createWorkerRunner } from './worker_runner.js';

const config = loadConfig();
const logger = createLogger({
  level: config.logLevel,
  redactionEnabled: config.logRedactionEnabled,
  component: 'article_worker'
});
const store = createStore({ config, logger });
const runner = createWorkerRunner({ config, store, logger });

let isShuttingDown = false;

async function handleShutdown(signal) {
  if (isShuttingDown) return;
  isShuttingDown = true;
  logger.info?.('article_worker_shutdown_requested', { signal });
  const drainTimeout = setTimeout(() => {
    logger.warn?.('article_worker_drain_timeout', { signal });
    process.exit(1);
  }, 10_000);
  drainTimeout.unref();
  await runner.stop();
  logger.info?.('article_worker_shutdown_clean');
  process.exit(0);
}

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));

runner.start();
