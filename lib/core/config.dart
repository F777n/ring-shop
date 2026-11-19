const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

class ApiProbe {
  static int? failOnce;
  static int? delayMs;

  static void readLaunchUri() {
    final params = Uri.base.queryParameters;
    failOnce = int.tryParse(params['__fail'] ?? '');
    delayMs = int.tryParse(params['__delay'] ?? '');
  }
}
