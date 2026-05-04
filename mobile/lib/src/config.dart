class AppConfig {
  const AppConfig({
    required this.backendBaseUrl,
    required this.newWordTimeout,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      backendBaseUrl: String.fromEnvironment(
        'BACKEND_BASE_URL',
        defaultValue: 'http://localhost:8787',
      ),
      newWordTimeout: Duration(
        seconds: int.fromEnvironment('NEW_WORD_TIMEOUT_SECONDS', defaultValue: 5),
      ),
    );
  }

  final String backendBaseUrl;
  final Duration newWordTimeout;
}
