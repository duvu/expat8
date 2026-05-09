export function getAdminConfig() {
  return {
    backendBaseUrl: process.env.BACKEND_BASE_URL ?? 'http://localhost:8787',
    databaseUrl: process.env.EXPAT8_DASHBOARD_DATABASE_URL ?? process.env.WEB_ADMIN_DATABASE_URL ?? process.env.DATABASE_URL ?? '',
    adminToken: process.env.ADMIN_TOKEN ?? '',
    appId: process.env.APP_CREDENTIAL_APP_ID ?? '',
    appSecret: process.env.APP_CREDENTIAL_SECRET ?? ''
  };
}
