export function loadConfig(env = process.env) {
  const logArchiveMaxTotalBytes = Number.parseInt(env.LOG_ARCHIVE_MAX_TOTAL_BYTES ?? String(100 * 1024 * 1024), 10);
  return {
    port: Number.parseInt(env.PORT ?? '8787', 10),
    databaseUrl: env.DATABASE_URL,
    liteLLMBaseUrl: env.LITELLM_BASE_URL,
    liteLLMApiKey: env.LITELLM_API_KEY ?? '',
    liteLLMModel: env.LITELLM_MODEL ?? 'gpt-4o-mini',
    liteLLMTimeoutMs: Number.parseInt(env.LITELLM_TIMEOUT_MS ?? '120000', 10),
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
    releaseStorageDir: env.RELEASE_STORAGE_DIR ?? './data/releases',
    releaseUploadBodyLimitBytes: Number.parseInt(
      env.RELEASE_UPLOAD_BODY_LIMIT_BYTES ?? String(50 * 1024 * 1024),
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
    vocabLevelTargets: parseLevelTargets(env.VOCAB_LEVEL_TARGETS ?? 'A1:200,A2:250,B1:300,B2:300,C1:200'),
    vocabMaxBackoffSeconds: Number.parseInt(env.VOCAB_MAX_BACKOFF_SECONDS ?? '1800', 10),
    // OmniRoute throttling shared by every LLM caller in the process.
    llmMinIntervalMs: Number.parseInt(env.LLM_MIN_INTERVAL_MS ?? '3000', 10),
    llmMaxConcurrent: Number.parseInt(env.LLM_MAX_CONCURRENT ?? '1', 10),
    llmMaxRetries: Number.parseInt(env.LLM_MAX_RETRIES ?? '4', 10),
    llmBackoffBaseMs: Number.parseInt(env.LLM_BACKOFF_BASE_MS ?? '15000', 10),
    llmMaxRequestsPerHour: Number.parseInt(env.LLM_MAX_REQUESTS_PER_HOUR ?? '120', 10),
    // Requests per hour kept free for user-facing work (submitted words) before background jobs pause.
    llmReservedRequestsPerHour: Number.parseInt(env.LLM_RESERVED_REQUESTS_PER_HOUR ?? '30', 10),
    crawlerEnabled: parseBoolean(env.CRAWLER_ENABLED ?? 'true'),
    crawlerIntervalMinutes: Number.parseInt(env.CRAWLER_INTERVAL_MINUTES ?? '180', 10),
    crawlerMaxArticlesPerRun: Number.parseInt(env.CRAWLER_MAX_ARTICLES_PER_RUN ?? '3', 10),
    crawlerMinArticleQuality: Number.parseInt(env.CRAWLER_MIN_ARTICLE_QUALITY ?? '3', 10),
    crawlerFeeds: parseCrawlerFeeds(env.CRAWLER_FEEDS),
    // Curated collection (speeches, biographies, history): backfill first, then one article per interval.
    curatedEnabled: parseBoolean(env.CURATED_ENABLED ?? 'true'),
    curatedInitialCount: Number.parseInt(env.CURATED_INITIAL_COUNT ?? '20', 10),
    curatedBackfillIntervalMinutes: Number.parseInt(env.CURATED_BACKFILL_INTERVAL_MINUTES ?? '15', 10),
    curatedIntervalDays: Number.parseInt(env.CURATED_INTERVAL_DAYS ?? '7', 10),
    authRateLimitRegister: Number.parseInt(env.AUTH_RATE_LIMIT_REGISTER ?? '10', 10),
    authRateLimitSignIn: Number.parseInt(env.AUTH_RATE_LIMIT_SIGN_IN ?? '20', 10),
    authRateLimitIp: Number.parseInt(env.AUTH_RATE_LIMIT_IP ?? '60', 10),
    trustProxy: parseTrustProxy(env.TRUST_PROXY),
    embeddedWorker: parseBoolean(env.EMBEDDED_WORKER ?? 'false'),
    migrateOnStart: parseBoolean(env.MIGRATE_ON_START ?? 'false'),
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

// Express `trust proxy` setting. Only enable behind a reverse proxy that
// overwrites X-Forwarded-For, otherwise clients can spoof their IP and bypass
// IP-based rate limits. Accepts false/true, a hop count, or a comma-separated
// list of trusted addresses/subnets.
function parseTrustProxy(value) {
  if (value === undefined || value === null) {
    return false;
  }
  const trimmed = String(value).trim();
  if (trimmed === '' || trimmed.toLowerCase() === 'false') {
    return false;
  }
  if (trimmed.toLowerCase() === 'true') {
    return true;
  }
  if (/^\d+$/.test(trimmed)) {
    return Number.parseInt(trimmed, 10);
  }
  return trimmed;
}

/** "A1:200,B1:300" -> { A1: 200, B1: 300 }; malformed entries are ignored. */
function parseLevelTargets(raw) {
  const targets = {};
  for (const entry of String(raw).split(',')) {
    const [level, count] = entry.split(':').map((part) => part.trim());
    const parsed = Number.parseInt(count, 10);
    if (level && Number.isFinite(parsed) && parsed >= 0) {
      targets[level.toUpperCase()] = parsed;
    }
  }
  return targets;
}

const DEFAULT_CRAWLER_FEEDS = [
  'https://www.newsinlevels.com/feed/',
  'https://feeds.bbci.co.uk/news/technology/rss.xml',
  'https://feeds.npr.org/1001/rss.xml',
  'https://www.sciencedaily.com/rss/top/science.xml',
  'https://www.theguardian.com/world/rss'
];

/** Comma-separated feed URLs (English). Set CRAWLER_FEEDS= (empty) to disable all feeds. */
function parseCrawlerFeeds(raw) {
  if (raw === undefined) {
    return DEFAULT_CRAWLER_FEEDS;
  }
  return String(raw)
    .split(',')
    .map((url) => url.trim())
    .filter(Boolean);
}
