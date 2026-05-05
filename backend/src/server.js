import { createBackendRuntime } from './runtime.js';

const { config, server, vocabularyPoolScheduler, logger } = createBackendRuntime();
server.listen(config.port, () => {
  logger.info('server_started', { port: config.port, url: `http://localhost:${config.port}` });
  if (config.vocabSchedulerEnabled) {
    vocabularyPoolScheduler.start();
  }
});

process.on('SIGTERM', () => {
  logger.info('server_stopping', { signal: 'SIGTERM' });
  vocabularyPoolScheduler.stop();
  server.close(() => process.exit(0));
});
