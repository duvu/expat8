class AppConfig {
  const AppConfig({
    required this.backendBaseUrl,
    required this.newWordTimeout,
    required this.appCredentialAppId,
    required this.appCredentialSecret,
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
    );
  }

  final String backendBaseUrl;
  final Duration newWordTimeout;
  final String appCredentialAppId;
  final String appCredentialSecret;
}
