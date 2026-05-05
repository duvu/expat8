export function loadConfig(env = process.env) {
  return {
    port: Number.parseInt(env.PORT ?? '8787', 10),
    databaseUrl: env.DATABASE_URL,
    liteLLMBaseUrl: env.LITELLM_BASE_URL ?? 'https://lite.x51.vn',
    liteLLMApiKey: env.LITELLM_API_KEY ?? '',
    liteLLMModel: env.LITELLM_MODEL ?? 'gpt-4o-mini',
    defaultSourceLanguage: env.DEFAULT_SOURCE_LANGUAGE ?? 'vi',
    defaultTargetLanguage: env.DEFAULT_TARGET_LANGUAGE ?? 'en',
    newWordTimeoutSeconds: Number.parseInt(env.NEW_WORD_TIMEOUT_SECONDS ?? '5', 10),
    corsAllowedOrigin: env.CORS_ALLOWED_ORIGIN ?? '*',
    appCredentials: parseAppCredentials(env.APP_CREDENTIALS_JSON),
    appCredentialTimestampSkewSeconds: Number.parseInt(
      env.APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS ?? '300',
      10
    ),
    appCredentialNonceTtlSeconds: Number.parseInt(
      env.APP_CREDENTIAL_NONCE_TTL_SECONDS ?? '300',
      10
    ),
    appCredentialGetBodyLimitBytes: Number.parseInt(
      env.APP_CREDENTIAL_GET_BODY_LIMIT_BYTES ?? '0',
      10
    ),
    appCredentialPostBodyLimitBytes: Number.parseInt(
      env.APP_CREDENTIAL_POST_BODY_LIMIT_BYTES ?? '262144',
      10
    )
  };
}

function parseAppCredentials(raw) {
  if (!raw) {
    return [];
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    throw new Error('APP_CREDENTIALS_JSON must be valid JSON');
  }

  if (!Array.isArray(parsed)) {
    throw new Error('APP_CREDENTIALS_JSON must be an array');
  }

  return parsed.map((credential) => {
    if (
      !credential ||
      typeof credential.appId !== 'string' ||
      credential.appId.length === 0 ||
      typeof credential.secret !== 'string' ||
      credential.secret.length === 0 ||
      typeof credential.status !== 'string' ||
      credential.status.length === 0
    ) {
      throw new Error('APP_CREDENTIALS_JSON entries require appId, secret, and status');
    }

    return {
      appId: credential.appId,
      secret: credential.secret,
      status: credential.status
    };
  });
}
