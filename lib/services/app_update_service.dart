import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  AppUpdateService._();

  static const _channel = MethodChannel('com.sardoba/app_update');
  static const _appStoreUrl =
      'https://apps.apple.com/uz/app/sardoba/id6757268380';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.sardobabukhara.app&hl=uz';
  static const _numericVersionPattern =
      r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
      r'(?:\+[0-9A-Za-z.-]+)?$';
  static Future<InstalledAppInfo>? _installedAppInfo;

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get supportsVersionedApi => _isAndroid || _isIOS;

  static Future<InstalledAppInfo> installedAppInfo() {
    final cached = _installedAppInfo;
    if (cached != null) return cached;

    final lookup = _readInstalledAppInfo();
    _installedAppInfo = lookup;
    return lookup.catchError((Object error, StackTrace stackTrace) {
      if (identical(_installedAppInfo, lookup)) _installedAppInfo = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  @visibleForTesting
  static void resetForTesting() {
    _installedAppInfo = null;
  }

  static Future<InstalledAppInfo> _readInstalledAppInfo() async {
    if (!supportsVersionedApi) {
      throw const AppVersionResolutionException();
    }

    try {
      final response = await _channel
          .invokeMapMethod<String, dynamic>('getAppInfo')
          .timeout(const Duration(seconds: 2));
      final version = response?['version']?.toString().trim();
      final platform = response?['platform']?.toString();
      final expectedPlatform = _isAndroid ? 'android' : 'ios';
      if (version == null ||
          !_isBackendVersion(version) ||
          platform != expectedPlatform) {
        throw const AppVersionResolutionException();
      }
      return InstalledAppInfo(version: version, platform: platform!);
    } on AppVersionResolutionException {
      rethrow;
    } on PlatformException {
      throw const AppVersionResolutionException();
    } on MissingPluginException {
      throw const AppVersionResolutionException();
    } on TimeoutException {
      throw const AppVersionResolutionException();
    } catch (_) {
      throw const AppVersionResolutionException();
    }
  }

  static bool _isBackendVersion(String version) =>
      RegExp(_numericVersionPattern).hasMatch(version);

  /// Store availability is advisory only and never gates startup.
  static Future<bool> checkForAvailableUpdate() async {
    if (!_isAndroid && !_isIOS) return false;

    try {
      final response =
          await _channel.invokeMapMethod<String, dynamic>('checkForUpdate');
      return response?['updateAvailable'] == true;
    } on PlatformException {
      // Store checks can fail during network outages or when Play is unavailable.
      return false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openMandatoryUpdate({
    String? iosStoreUrl,
    String? androidStoreUrl,
  }) async {
    if (_isAndroid) {
      try {
        await _channel.invokeMethod<void>('startImmediateUpdate');
        return;
      } on PlatformException {
        // If Play's in-app flow is unavailable, open the Play listing directly.
      } on MissingPluginException {
        // Fall through to the official store listing.
      }
    }

    final uri = _storeUri(
      _isIOS ? iosStoreUrl : androidStoreUrl,
      ios: _isIOS,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Optional updates only open the Store listing after an explicit tap.
  static Future<void> openOptionalUpdate() async {
    final uri = Uri.parse(_isIOS ? _appStoreUrl : _playStoreUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Uri _storeUri(String? requested, {required bool ios}) {
    final fallback = Uri.parse(ios ? _appStoreUrl : _playStoreUrl);
    final candidate = Uri.tryParse(requested ?? '');
    if (candidate == null || candidate.scheme != 'https') return fallback;
    final validHost = ios
        ? candidate.host == 'apps.apple.com'
        : candidate.host == 'play.google.com';
    return validHost ? candidate : fallback;
  }
}

class InstalledAppInfo {
  const InstalledAppInfo({required this.version, required this.platform});

  final String version;
  final String platform;
}

class AppVersionResolutionException implements Exception {
  const AppVersionResolutionException();

  String get message =>
      'Unable to verify the installed app version. Please restart and try again.';

  @override
  String toString() => message;
}
