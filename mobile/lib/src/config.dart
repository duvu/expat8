class AppConfig {
  const AppConfig({
    required this.backendBaseUrl,
    required this.newWordTimeout,
    required this.appCredentialAppId,
    required this.appCredentialSecret,
    required this.defaultLearningLanguage,
    required this.supportedLearningLanguages,
    required this.logLevel,
    required this.logMaxEntries,
    required this.logRetentionDays,
    required this.vocabFirstInstallSize,
    required this.vocabPoolFullSize,
    required this.vocabHourlyTopUpSize,
    required this.vocabRotationSize,
    required this.vocabRotationUnstudiedThreshold,
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
      defaultLearningLanguage: 'en',
      supportedLearningLanguages: ['en', 'zh', 'vi'],
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
      vocabFirstInstallSize: int.fromEnvironment(
        'VOCAB_FIRST_INSTALL_SIZE',
        defaultValue: 200,
      ),
      vocabPoolFullSize: int.fromEnvironment(
        'VOCAB_POOL_FULL_SIZE',
        defaultValue: 1000,
      ),
      vocabHourlyTopUpSize: int.fromEnvironment(
        'VOCAB_HOURLY_TOP_UP_SIZE',
        defaultValue: 10,
      ),
      vocabRotationSize: int.fromEnvironment(
        'VOCAB_ROTATION_SIZE',
        defaultValue: 100,
      ),
      vocabRotationUnstudiedThreshold: int.fromEnvironment(
        'VOCAB_ROTATION_UNSTUDIED_THRESHOLD',
        defaultValue: 100,
      ),
    );
  }

  final String backendBaseUrl;
  final Duration newWordTimeout;
  final String appCredentialAppId;
  final String appCredentialSecret;
  final String defaultLearningLanguage;
  final List<String> supportedLearningLanguages;
  final String logLevel;
  final int logMaxEntries;
  final int logRetentionDays;
  final int vocabFirstInstallSize;
  final int vocabPoolFullSize;
  final int vocabHourlyTopUpSize;
  final int vocabRotationSize;
  final int vocabRotationUnstudiedThreshold;
}
