export function loadConfig(env = process.env) {
  const logArchiveMaxTotalBytes = Number.parseInt(env.LOG_ARCHIVE_MAX_TOTAL_BYTES ?? String(100 * 1024 * 1024), 10);
  return {
    port: Number.parseInt(env.PORT ?? '8787', 10),
    databaseUrl: env.DATABASE_URL,
    liteLLMBaseUrl: env.LITELLM_BASE_URL,
    liteLLMApiKey: env.LITELLM_API_KEY ?? '',
    liteLLMModel: env.LITELLM_MODEL ?? 'gpt-4o-mini',
    defaultSourceLanguage: env.DEFAULT_SOURCE_LANGUAGE ?? 'vi',
    defaultTargetLanguage: env.DEFAULT_TARGET_LANGUAGE ?? 'en',
    newWordTimeoutSeconds: Number.parseInt(env.NEW_WORD_TIMEOUT_SECONDS ?? '5', 10),
    corsAllowedOrigin: env.CORS_ALLOWED_ORIGIN ?? '*',
    appCredentials: parseAppCredentials(env.APP_CREDENTIALS_JSON),
    appCredentialTimestampSkewSeconds: Number.parseInt(env.APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS ?? '300', 10),
    appCredentialNonceTtlSeconds: Number.parseInt(env.APP_CREDENTIAL_NONCE_TTL_SECONDS ?? '300', 10),
    appCredentialGetBodyLimitBytes: Number.parseInt(env.APP_CREDENTIAL_GET_BODY_LIMIT_BYTES ?? '0', 10),
    appCredentialPostBodyLimitBytes: Number.parseInt(env.APP_CREDENTIAL_POST_BODY_LIMIT_BYTES ?? '262144', 10),
    logArchiveDir: env.LOG_ARCHIVE_DIR ?? './data/log-archives',
    logArchiveRetentionDays: Number.parseInt(env.LOG_ARCHIVE_RETENTION_DAYS ?? '3', 10),
    logArchiveMaxTotalBytes,
    logArchiveUploadBodyLimitBytes: Number.parseInt(
      env.LOG_ARCHIVE_UPLOAD_BODY_LIMIT_BYTES ?? String(logArchiveMaxTotalBytes),
      10
    ),
    logLevel: String(env.LOG_LEVEL ?? 'info').toLowerCase(),
    logRedactionEnabled: parseBoolean(env.LOG_REDACTION_ENABLED ?? 'true'),
    proficiencyCompatibilityMode: String(env.PROFICIENCY_COMPATIBILITY_MODE ?? 'additive').toLowerCase(),
    vocabSchedulerEnabled: parseBoolean(env.VOCAB_SCHEDULER_ENABLED ?? 'true'),
    vocabPoolMinSize: Number.parseInt(env.VOCAB_POOL_MIN_SIZE ?? '1000', 10),
    vocabFillIntervalSeconds: Number.parseInt(env.VOCAB_FILL_INTERVAL_SECONDS ?? '60', 10),
    vocabDailyGenerationCount: Number.parseInt(env.VOCAB_DAILY_GENERATION_COUNT ?? '10', 10),
    vocabDailyGenerationHourUtc: Number.parseInt(env.VOCAB_DAILY_GENERATION_HOUR_UTC ?? '0', 10),
    vocabGenerationBatchSize: Number.parseInt(env.VOCAB_GENERATION_BATCH_SIZE ?? '100', 10),
    vocabSchedulerLockTtlSeconds: Number.parseInt(env.VOCAB_SCHEDULER_LOCK_TTL_SECONDS ?? '120', 10),
    authRateLimitRegister: Number.parseInt(env.AUTH_RATE_LIMIT_REGISTER ?? '10', 10),
    authRateLimitSignIn: Number.parseInt(env.AUTH_RATE_LIMIT_SIGN_IN ?? '20', 10),
    dbPoolMax: Number.parseInt(env.DB_POOL_MAX ?? '10', 10),
    dbIdleTimeoutMs: Number.parseInt(env.DB_IDLE_TIMEOUT_MS ?? '10000', 10),
    dbConnectionTimeoutMs: Number.parseInt(env.DB_CONNECTION_TIMEOUT_MS ?? '5000', 10),
    validLanguages: new Set(
      String(env.VALID_LANGUAGES ?? 'en,vi,fr,de,es,ja,ko,zh,pt,it,ru,ar')
        .split(',')
        .map((l) => l.trim())
        .filter(Boolean)
    ),
    adminApiTokens: new Set(
      String(env.ADMIN_API_TOKENS ?? '')
        .split(',')
        .map((token) => token.trim())
        .filter(Boolean)
    ),
    speakingEventsStrictAttemptId: parseBoolean(env.SPEAKING_EVENTS_STRICT_ATTEMPT_ID ?? 'false')
  };
}

function parseBoolean(raw) {
  return ['1', 'true', 'yes', 'on'].includes(String(raw).toLowerCase());
}

function parseAppCredentials(raw) {
  if (!raw) {
    return [];
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (_error) {
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
