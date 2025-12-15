import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String _fallbackBaseUrl = 'http://127.0.0.1:8000';

  static String get apiBaseUrl {
    final value = _read('API_BASE_URL');
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return _fallbackBaseUrl;
  }

  static String get yandexMapKitApiKey {
    return _read('YANDEX_MAPKIT_API_KEY') ?? '';
  }

  static String? _read(String key) {
    try {
      if (!dotenv.isInitialized) return null;
      final value = dotenv.maybeGet(key, fallback: null);
      return value?.trim();
    } catch (error) {
      debugPrint('AppConfig: failed to read $key from .env ($error)');
      return null;
    }
  }
}
