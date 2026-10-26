/** @type {import('next').NextConfig} */
const nextConfig = {
  // Self-contained server (.next/standalone/server.js) for the Docker runtime image.
  output: 'standalone',
  // Trace from this app's directory so server.js lands at the standalone root,
  // both locally (inside the monorepo) and in the Docker build context.
  outputFileTracingRoot: import.meta.dirname,
  poweredByHeader: false,
};

export default nextConfig;
