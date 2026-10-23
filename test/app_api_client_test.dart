import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sardoba_app/services/app_api_client.dart';
import 'package:sardoba_app/services/app_update_service.dart';
import 'package:sardoba_app/services/auth_service.dart';
import 'package:sardoba_app/services/auth_storage.dart';

const _updateChannel = MethodChannel('com.sardoba/app_update');
const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = AuthStorage.instance;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    storage.resetForTesting();
    await storage.ensureInitialized();
    AppUpdateService.resetForTesting();
    AppApiClient.requiredUpdate.value = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_updateChannel, (call) async {
      if (call.method == 'getAppInfo') {
        return {'version': '2.0.0', 'platform': 'android'};
      }
      if (call.method == 'checkForUpdate') {
        return {'updateAvailable': false};
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, (_) async => true);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_updateChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, null);
    debugDefaultTargetPlatformOverride = null;
    AppApiClient.requiredUpdate.value = null;
    await storage.logout();
  });

  test('adds installed version and platform to guest OTP requests', () async {
    RequestOptions? captured;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final service = AuthService(dio: dio);
    _stubResponse(dio, onRequest: (options) => captured = options);

    await service.requestOtp(phone: '+998901234567');

    expect(captured?.path, '/api/v1/auth/client/request-otp');
    expect(captured?.headers['X-App-Version'], '2.0.0');
    expect(captured?.headers['X-App-Platform'], 'android');
    service.dispose();
  });

  test('native metadata failure blocks the request and is retried', () async {
    var metadataCalls = 0;
    var adapterCalls = 0;
    RequestOptions? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_updateChannel, (call) async {
      if (call.method == 'getAppInfo') {
        metadataCalls++;
        if (metadataCalls == 1) {
          throw PlatformException(code: 'APP_VERSION_UNAVAILABLE');
        }
        return {'version': '2.3.1+8', 'platform': 'android'};
      }
      return {'updateAvailable': false};
    });

    final dio = AppApiClient.configure(
      Dio(BaseOptions(baseUrl: 'https://example.test')),
    );
    _stubResponse(dio, onRequest: (options) {
      adapterCalls++;
      captured = options;
    });

    await expectLater(
      dio.get('/api/v1/auth/me'),
      throwsA(
        isA<DioException>().having(
          (error) => error.error,
          'local version resolution error',
          isA<AppVersionResolutionException>(),
        ),
      ),
    );
    expect(adapterCalls, 0);

    await dio.get('/api/v1/auth/me');
    expect(metadataCalls, 2);
    expect(adapterCalls, 1);
    expect(captured?.headers['X-App-Version'], '2.3.1+8');
    expect(captured?.headers['X-App-Platform'], 'android');
    dio.close();
  });

  test('empty, malformed, or mismatched native metadata never sends request',
      () async {
    for (final metadata in [
      {'version': '', 'platform': 'android'},
      {'version': '2.0.0-rc.1', 'platform': 'android'},
      {'version': '2.0.0', 'platform': 'ios'},
    ]) {
      AppUpdateService.resetForTesting();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        _updateChannel,
        (call) async => metadata,
      );
      var adapterCalls = 0;
      final dio = AppApiClient.configure(
        Dio(BaseOptions(baseUrl: 'https://example.test')),
      );
      _stubResponse(dio, onRequest: (_) => adapterCalls++);

      await expectLater(
        dio.get('/api/v1/cashback/me/transactions'),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'local version resolution error',
            isA<AppVersionResolutionException>(),
          ),
        ),
      );
      expect(adapterCalls, 0);
      dio.close();
    }
  });

  test('invalid native metadata is not cached', () async {
    var metadataCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_updateChannel, (call) async {
      metadataCalls++;
      return metadataCalls == 1
          ? {'version': '', 'platform': 'android'}
          : {'version': '2.0.1', 'platform': 'android'};
    });

    await expectLater(
      AppUpdateService.installedAppInfo(),
      throwsA(isA<AppVersionResolutionException>()),
    );
    final info = await AppUpdateService.installedAppInfo();

    expect(metadataCalls, 2);
    expect(info.version, '2.0.1');
  });

  test('legacy versions omit headers and invalid versions fail closed',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _updateChannel,
      (call) async => {'version': '1.9.9', 'platform': 'android'},
    );
    RequestOptions? captured;
    final legacyDio = AppApiClient.configure(
      Dio(BaseOptions(baseUrl: 'https://example.test')),
    );
    _stubResponse(legacyDio, onRequest: (options) => captured = options);
    await legacyDio.get('/api/v1/catalog/live');
    expect(captured?.headers.containsKey('X-App-Version'), isFalse);
    expect(captured?.headers.containsKey('X-App-Platform'), isFalse);
    legacyDio.close();

    AppUpdateService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _updateChannel,
      (call) async => {
        'version': 'not-a-version',
        'platform': 'android',
      },
    );
    var invalidRequestReachedAdapter = false;
    final invalidDio = AppApiClient.configure(
      Dio(BaseOptions(baseUrl: 'https://example.test')),
    );
    _stubResponse(invalidDio, onRequest: (_) {
      invalidRequestReachedAdapter = true;
    });
    await expectLater(
      invalidDio.get('/api/v1/catalog/live'),
      throwsA(isA<DioException>()),
    );
    expect(invalidRequestReachedAdapter, isFalse);
    invalidDio.close();
  });

  test('503 APP_UPDATE_REQUIRED notifies UI and preserves session data',
      () async {
    await storage.saveAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      tokenType: 'Bearer',
    );
    await storage.setCurrentUser('+998901234567');
    await storage.savePin('1234');
    final dio = AppApiClient.configure(
      Dio(BaseOptions(baseUrl: 'https://example.test')),
    );
    _stubResponse(
      dio,
      statusCode: 503,
      body: {
        'code': 'APP_UPDATE_REQUIRED',
        'min_version': '2.0.0',
        'ios_store_url': 'https://apps.apple.com/uz/app/sardoba/id6757268380',
        'android_store_url':
            'https://play.google.com/store/apps/details?id=com.sardobabukhara.app',
      },
    );

    await expectLater(dio.get('/api/v1/cashback/me/transactions'),
        throwsA(isA<DioException>()));

    expect(AppApiClient.requiredUpdate.value?.minimumVersion, '2.0.0');
    expect(await storage.getAccessToken(), 'access');
    expect(await storage.getRefreshToken(), 'refresh');
    expect(await storage.getCurrentUser(), '+998901234567');
    expect(await storage.hasPin(), isTrue);
    dio.close();
  });

  test('503 MAINTENANCE remains separate from required update', () async {
    final dio = AppApiClient.configure(
      Dio(BaseOptions(baseUrl: 'https://example.test')),
    );
    _stubResponse(
      dio,
      statusCode: 503,
      body: {'code': 'MAINTENANCE', 'detail': 'Maintenance'},
    );

    await expectLater(
        dio.get('/api/v1/catalog/live'), throwsA(isA<DioException>()));
    expect(AppApiClient.requiredUpdate.value, isNull);
    dio.close();
  });

  test('refresh endpoint still accepts the normal token rotation response',
      () async {
    await storage.saveAuthTokens(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );
    RequestOptions? captured;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final service = AuthService(dio: dio);
    _stubResponse(
      dio,
      onRequest: (options) => captured = options,
      body: {
        'access_token': 'new-access',
        'refresh_token': 'new-refresh',
        'token_type': 'Bearer',
      },
    );

    expect(await storage.refreshTokens(authService: service), isTrue);
    expect(captured?.path, '/api/v1/auth/refresh');
    expect(captured?.headers['X-App-Version'], '2.0.0');
    expect(await storage.getAccessToken(), 'new-access');
    expect(await storage.getRefreshToken(), 'new-refresh');
    service.dispose();
  });

  test('expired access token is classified as auth failure before refresh',
      () async {
    await storage.saveAuthTokens(
      accessToken: 'expired-access',
      refreshToken: 'old-refresh',
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final service = AuthService(dio: dio);
    _stubResponse(
      dio,
      statusCode: 401,
      body: {'detail': 'Token expired'},
    );

    await expectLater(
      service.fetchProfileWithToken(accessToken: 'expired-access'),
      throwsA(isA<AuthUnauthorizedException>()),
    );

    _stubResponse(
      dio,
      body: {
        'access_token': 'new-access',
        'refresh_token': 'new-refresh',
        'token_type': 'Bearer',
      },
    );
    expect(await storage.refreshTokens(authService: service), isTrue);
    expect(await storage.getAccessToken(), 'new-access');
    expect(await storage.getRefreshToken(), 'new-refresh');
    service.dispose();
  });

  test('update-required refresh preserves existing account and credentials',
      () async {
    await storage.saveAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      tokenType: 'Bearer',
    );
    await storage.setCurrentUser('+998901234567');
    await storage.savePin('1234');
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final service = AuthService(dio: dio);
    _stubResponse(
      dio,
      statusCode: 503,
      body: {'code': 'APP_UPDATE_REQUIRED', 'min_version': '2.0.0'},
    );

    await expectLater(
      storage.refreshTokens(authService: service),
      throwsA(isA<AuthUpdateRequiredException>()),
    );

    expect(await storage.getAccessToken(), 'access');
    expect(await storage.getRefreshToken(), 'refresh');
    expect(await storage.getCurrentUser(), '+998901234567');
    expect(await storage.hasPin(), isTrue);
    service.dispose();
  });

  test('native version failure during refresh preserves session and PIN',
      () async {
    await storage.saveAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      tokenType: 'Bearer',
    );
    await storage.setCurrentUser('+998901234567');
    await storage.savePin('1234');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _updateChannel,
      (_) async => throw PlatformException(code: 'APP_VERSION_UNAVAILABLE'),
    );
    var adapterCalls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final service = AuthService(dio: dio);
    _stubResponse(dio, onRequest: (_) => adapterCalls++);

    await expectLater(
      storage.refreshTokens(authService: service),
      throwsA(isA<AuthVersionResolutionException>()),
    );

    expect(adapterCalls, 0);
    expect(await storage.getAccessToken(), 'access');
    expect(await storage.getRefreshToken(), 'refresh');
    expect(await storage.getCurrentUser(), '+998901234567');
    expect(await storage.hasPin(), isTrue);
    service.dispose();
  });

  test('Android ordinary Store update remains optional', () async {
    final methods = <String>[];
    String? openedUrl;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_updateChannel, (call) async {
      methods.add(call.method);
      if (call.method == 'checkForUpdate') {
        return {'updateAvailable': true};
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, (call) async {
      if (call.method == 'launch') {
        openedUrl = (call.arguments as Map)['url'] as String;
      }
      return true;
    });

    expect(await AppUpdateService.checkForAvailableUpdate(), isTrue);
    expect(methods, ['checkForUpdate']);
    await AppUpdateService.openOptionalUpdate();

    expect(methods, isNot(contains('startImmediateUpdate')));
    expect(openedUrl, startsWith('https://play.google.com/store/apps/details'));
  });

  test('Android mandatory update starts Immediate Update flow', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_updateChannel, (call) async {
      methods.add(call.method);
      return true;
    });

    await AppUpdateService.openMandatoryUpdate(
      androidStoreUrl:
          'https://play.google.com/store/apps/details?id=com.sardobabukhara.app',
    );

    expect(methods, ['startImmediateUpdate']);
  });

  test('iOS mandatory update opens the App Store destination', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    String? openedUrl;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, (call) async {
      if (call.method == 'launch') {
        openedUrl = (call.arguments as Map)['url'] as String;
      }
      return true;
    });

    await AppUpdateService.openMandatoryUpdate(
      iosStoreUrl: 'https://apps.apple.com/uz/app/sardoba/id6757268380',
    );

    expect(openedUrl, 'https://apps.apple.com/uz/app/sardoba/id6757268380');
  });

  test('version comparison is numeric and observes semantic prereleases', () {
    expect(AppApiClient.compareVersions('2.0.0', '2.0.0'), 0);
    expect(AppApiClient.compareVersions('2.0.10', '2.0.2'), greaterThan(0));
    expect(AppApiClient.compareVersions('2.0.0-rc.1', '2.0.0'), lessThan(0));
    expect(AppApiClient.compareVersions('invalid', '2.0.0'), lessThan(0));
  });
}

void _stubResponse(
  Dio dio, {
  int statusCode = 200,
  Object? body = const {'ok': true},
  void Function(RequestOptions)? onRequest,
}) {
  dio.httpClientAdapter = _ResponseAdapter(
    statusCode: statusCode,
    body: body,
    onRequest: onRequest,
  );
}

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter({
    required this.statusCode,
    required this.body,
    this.onRequest,
  });

  final int statusCode;
  final Object? body;
  final void Function(RequestOptions)? onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest?.call(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
