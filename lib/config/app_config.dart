class AppConfig {
  static const String _fallbackBaseUrl = 'http://127.0.0.1:8000';
  // Matches Android strings.xml default; used if no dart-define provided.
  static const String _fallbackYandexApiKey =
      '2e1fd6f5-894a-4ecf-8fd4-70572e2bfb40';

  static String get apiBaseUrl {
    const value = String.fromEnvironment('API_BASE_URL');
    return value.trim().isNotEmpty ? value.trim() : _fallbackBaseUrl;
  }

  static String get yandexMapKitApiKey {
    const value = String.fromEnvironment('YANDEX_MAPKIT_API_KEY');
    return value.trim().isNotEmpty ? value.trim() : _fallbackYandexApiKey;
  }
}
