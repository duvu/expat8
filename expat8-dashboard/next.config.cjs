// Ensure Next.js produces a standalone server build so the Dockerfile
// can copy the generated server.js into the runtime image.
module.exports = {
  output: 'standalone',
}
