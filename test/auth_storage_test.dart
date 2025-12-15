import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sardoba_app/models/login_response.dart';
import 'package:sardoba_app/services/auth_service.dart';
import 'package:sardoba_app/services/auth_storage.dart';

class _StubAuthService extends AuthService {
  _StubAuthService(this.tokens)
      : super(dio: Dio(BaseOptions(baseUrl: 'https://example.test')));

  final LoginResponse tokens;

  @override
  Future<LoginResponse> refreshTokens({required String refreshToken}) async {
    return tokens;
  }

  @override
  void dispose() {}
}

class _UnauthorizedAuthService extends AuthService {
  _UnauthorizedAuthService()
      : super(dio: Dio(BaseOptions(baseUrl: 'https://example.test')));

  @override
  Future<LoginResponse> refreshTokens({required String refreshToken}) async {
    throw AuthUnauthorizedException('Expired');
  }

  @override
  void dispose() {}
}

void main() {
  final storage = AuthStorage.instance;

  Future<void> resetPrefs() async {
    SharedPreferences.setMockInitialValues({});
    storage.resetForTesting();
    await storage.ensureInitialized();
  }

  setUp(() async {
    await resetPrefs();
  });

  tearDown(() async {
    await storage.logout();
  });

  test('refreshTokens saves new tokens returned by AuthService', () async {
    await storage.saveAuthTokens(
      accessToken: 'oldAccess',
      refreshToken: 'oldRefresh',
      tokenType: 'Bearer',
    );

    const newTokens = LoginResponse(
      accessToken: 'newAccess',
      refreshToken: 'newRefresh',
      tokenType: 'Bearer',
    );
    final result = await storage.refreshTokens(
      authService: _StubAuthService(newTokens),
    );

    expect(result, isTrue);
    expect(await storage.getAccessToken(), 'newAccess');
    expect(await storage.getRefreshToken(), 'newRefresh');
    expect(await storage.getTokenType(), 'Bearer');
  });

  test('refreshTokens logs out when service throws AuthUnauthorizedException',
      () async {
    await storage.saveAuthTokens(
      accessToken: 'oldAccess',
      refreshToken: 'oldRefresh',
      tokenType: 'Bearer',
    );
    await storage.setCurrentUser('+998901234567');

    final result = await storage.refreshTokens(
      authService: _UnauthorizedAuthService(),
    );

    expect(result, isFalse);
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
    expect(await storage.getCurrentUser(), isNull);
  });
}
