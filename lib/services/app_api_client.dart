import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'app_update_service.dart';

/// Adds app identity to Sardoba REST requests and surfaces mandatory updates.
/// WebSocket handshakes use a separate transport and are intentionally untouched.
class AppApiClient {
  AppApiClient._();

  static const _configuredKey = 'sardobaAppApiClientConfigured';
  static final ValueNotifier<RequiredAppUpdate?> requiredUpdate =
      ValueNotifier(null);

  static Dio configure(Dio dio) {
    if (dio.options.extra[_configuredKey] == true) return dio;
    dio.options.extra[_configuredKey] = true;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!AppUpdateService.supportsVersionedApi) {
            handler.next(options);
            return;
          }

          options.headers.removeWhere((key, _) {
            final normalized = key.toLowerCase();
            return normalized == 'x-app-version' ||
                normalized == 'x-app-platform';
          });
          try {
            final appInfo = await AppUpdateService.installedAppInfo();
            final version = appInfo.version;
            if (compareVersions(version, '2.0.0') >= 0) {
              options.headers['X-App-Version'] = version;
              options.headers['X-App-Platform'] = appInfo.platform;
            }
          } catch (error) {
            final failure = error is AppVersionResolutionException
                ? error
                : const AppVersionResolutionException();
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                error: failure,
                message: failure.message,
              ),
            );
            return;
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final body = _responseMap(error.response?.data);
          if (error.response?.statusCode == 503 &&
              body?['code'] == 'APP_UPDATE_REQUIRED') {
            requiredUpdate.value ??= RequiredAppUpdate(
              minimumVersion: body?['min_version']?.toString(),
              iosStoreUrl: body?['ios_store_url']?.toString(),
              androidStoreUrl: body?['android_store_url']?.toString(),
            );
          }
          handler.next(error);
        },
      ),
    );
    return dio;
  }

  static int compareVersions(String left, String right) {
    final leftVersion = _parseVersion(left);
    final rightVersion = _parseVersion(right);
    if (leftVersion == null) return -1;
    if (rightVersion == null) return 1;
    for (var i = 0; i < 3; i++) {
      final result = leftVersion.parts[i].compareTo(rightVersion.parts[i]);
      if (result != 0) return result;
    }
    final leftPre = leftVersion.prerelease;
    final rightPre = rightVersion.prerelease;
    if (leftPre == null) return rightPre == null ? 0 : 1;
    if (rightPre == null) return -1;
    final length =
        leftPre.length > rightPre.length ? leftPre.length : rightPre.length;
    for (var i = 0; i < length; i++) {
      if (i >= leftPre.length) return -1;
      if (i >= rightPre.length) return 1;
      final a = leftPre[i];
      final b = rightPre[i];
      if (a == b) continue;
      final aNumber = int.tryParse(a);
      final bNumber = int.tryParse(b);
      if (aNumber != null && bNumber != null) return aNumber.compareTo(bNumber);
      if (aNumber != null) return -1;
      if (bNumber != null) return 1;
      return a.compareTo(b);
    }
    return 0;
  }

  static _ParsedVersion? _parseVersion(String value) {
    final match = RegExp(
      r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
      r'(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    final parts = [
      int.tryParse(match.group(1)!),
      int.tryParse(match.group(2)!),
      int.tryParse(match.group(3)!),
    ];
    if (parts.any((part) => part == null)) return null;
    final prerelease = match.group(4)?.split('.');
    if (prerelease?.any((part) => part.isEmpty) == true) return null;
    return _ParsedVersion(parts.cast<int>(), prerelease);
  }

  static Map<String, dynamic>? _responseMap(dynamic body) {
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        return null;
      }
    }
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }
}

class RequiredAppUpdate {
  const RequiredAppUpdate({
    this.minimumVersion,
    this.iosStoreUrl,
    this.androidStoreUrl,
  });

  final String? minimumVersion;
  final String? iosStoreUrl;
  final String? androidStoreUrl;
}

class _ParsedVersion {
  const _ParsedVersion(this.parts, this.prerelease);

  final List<int> parts;
  final List<String>? prerelease;
}
