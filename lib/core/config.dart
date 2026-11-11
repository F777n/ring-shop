/// Адрес API задаётся при запуске, а не зашит в код:
/// flutter run -d chrome --web-port=5555 --dart-define=API_BASE_URL=http://localhost:8080/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

/// Параметры учебной диагностики из адреса страницы: ?__fail=500 и ?__delay=1500.
class ApiProbe {
  static int? failOnce;
  static int? delayMs;

  static void readLaunchUri() {
    final params = Uri.base.queryParameters;
    failOnce = int.tryParse(params['__fail'] ?? '');
    delayMs = int.tryParse(params['__delay'] ?? '');
  }
}
