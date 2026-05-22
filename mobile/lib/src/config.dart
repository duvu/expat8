class AppConfig {
  const AppConfig({
    required this.backendBaseUrl,
    required this.newWordTimeout,
    required this.appCredentialAppId,
    required this.appCredentialSecret,
    required this.defaultLearningLanguage,
    required this.supportedLearningLanguages,
    required this.speakingFoundationEnabled,
    required this.logLevel,
    required this.logMaxEntries,
    this.logRetention = defaultLogRetention,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      backendBaseUrl: String.fromEnvironment(
        'BACKEND_BASE_URL',
        defaultValue: '',
      ),
      newWordTimeout: Duration(
        seconds:
        int.fromEnvironment('NEW_WORD_TIMEOUT_SECONDS', defaultValue: 60),
      ),
      appCredentialAppId: String.fromEnvironment(
        'APP_CREDENTIAL_APP_ID',
        defaultValue: '',
      ),
      appCredentialSecret: String.fromEnvironment(
        'APP_CREDENTIAL_SECRET',
        defaultValue: '',
      ),
      defaultLearningLanguage: 'en',
      supportedLearningLanguages: ['en', 'zh', 'vi'],
      speakingFoundationEnabled: bool.fromEnvironment(
        'SPEAKING_FOUNDATION_ENABLED',
        defaultValue: true,
      ),
      logLevel: String.fromEnvironment(
        'APP_LOG_LEVEL',
        defaultValue: 'info',
      ),
      logMaxEntries: int.fromEnvironment(
        'APP_LOG_MAX_ENTRIES',
        defaultValue: 5000,
      ),
    );
  }

  final String backendBaseUrl;
  final Duration newWordTimeout;
  final String appCredentialAppId;
  final String appCredentialSecret;
  final String defaultLearningLanguage;
  final List<String> supportedLearningLanguages;
  final bool speakingFoundationEnabled;
  final String logLevel;
  final int logMaxEntries;
  final Duration logRetention;

  static const Duration defaultLogRetention = Duration(minutes: 60);
}
