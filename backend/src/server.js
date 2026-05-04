import { createBackendRuntime } from './runtime.js';

const { config, server } = createBackendRuntime();
server.listen(config.port, () => {
  console.log(`Expat8 backend listening on http://localhost:${config.port}`);
});
