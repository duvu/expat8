class AppConfig {
  const AppConfig({
    required this.backendBaseUrl,
    required this.newWordTimeout,
    required this.appCredentialAppId,
    required this.appCredentialSecret,
    required this.logLevel,
    required this.logMaxEntries,
    required this.logRetentionDays,
    required this.vocabPrefetchLimit,
    required this.vocabDailyRefreshCount,
    required this.vocabProactiveThreshold,
    required this.vocabProactiveMinNew,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      backendBaseUrl: String.fromEnvironment(
        'BACKEND_BASE_URL',
        defaultValue: 'https://expat8.x51.vn',
      ),
      newWordTimeout: Duration(
        seconds: int.fromEnvironment('NEW_WORD_TIMEOUT_SECONDS', defaultValue: 5),
      ),
      appCredentialAppId: String.fromEnvironment(
        'APP_CREDENTIAL_APP_ID',
        defaultValue: 'expat8-mobile-app',
      ),
      appCredentialSecret: String.fromEnvironment(
        'APP_CREDENTIAL_SECRET',
        defaultValue: 'expat8-mobile-secret',
      ),
      logLevel: String.fromEnvironment(
        'APP_LOG_LEVEL',
        defaultValue: 'info',
      ),
      logMaxEntries: int.fromEnvironment(
        'APP_LOG_MAX_ENTRIES',
        defaultValue: 5000,
      ),
      logRetentionDays: int.fromEnvironment(
        'APP_LOG_RETENTION_DAYS',
        defaultValue: 7,
      ),
      vocabPrefetchLimit: int.fromEnvironment(
        'VOCAB_PREFETCH_LIMIT',
        defaultValue: 10,
      ),
      vocabDailyRefreshCount: int.fromEnvironment(
        'VOCAB_DAILY_REFRESH_COUNT',
        defaultValue: 10,
      ),
      vocabProactiveThreshold: int.fromEnvironment(
        'VOCAB_PROACTIVE_THRESHOLD',
        defaultValue: 100,
      ),
      vocabProactiveMinNew: int.fromEnvironment(
        'VOCAB_PROACTIVE_MIN_NEW',
        defaultValue: 10,
      ),
    );
  }

  final String backendBaseUrl;
  final Duration newWordTimeout;
  final String appCredentialAppId;
  final String appCredentialSecret;
  final String logLevel;
  final int logMaxEntries;
  final int logRetentionDays;
  final int vocabPrefetchLimit;
  final int vocabDailyRefreshCount;
  final int vocabProactiveThreshold;
  final int vocabProactiveMinNew;
}
