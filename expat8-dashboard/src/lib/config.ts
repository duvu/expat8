/**
 * Server-only runtime configuration. Every value is read from the process
 * environment at request time, never at build time, so `next build` needs no
 * secrets. Do not import this module from a 'use client' file.
 */

/** First non-empty value among the given env vars (empty strings count as unset). */
function readEnv(...names: string[]): string {
  for (const name of names) {
    const value = process.env[name]?.trim();
    if (value) return value;
  }
  return '';
}

export function getAdminConfig() {
  return {
    backendBaseUrl: readEnv('BACKEND_BASE_URL') || 'http://localhost:8787',
    databaseUrl: readEnv('EXPAT8_DASHBOARD_DATABASE_URL', 'WEB_ADMIN_DATABASE_URL', 'DATABASE_URL'),
    adminToken: readEnv('ADMIN_TOKEN'),
    appId: readEnv('APP_CREDENTIAL_APP_ID'),
    appSecret: readEnv('APP_CREDENTIAL_SECRET'),
  };
}
