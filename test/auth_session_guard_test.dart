import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sardoba_app/services/auth_session_guard.dart';
import 'package:sardoba_app/services/auth_storage.dart';

void main() {
  final storage = AuthStorage.instance;
  final guard = AuthSessionGuard.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage.resetForTesting();
    await storage.ensureInitialized();
    guard.resetForTesting();
  });

  tearDown(() async {
    await storage.logout();
    guard.resetForTesting();
  });

  test('logs out when both tokens are missing', () async {
    var logoutCalls = 0;
    guard.setForceLogoutHandler(() async {
      logoutCalls++;
    });

    final result = await guard.logoutIfTokensMissing();

    expect(result, isTrue);
    expect(logoutCalls, 1);
  });

  test('skips logout when tokens are present', () async {
    await storage.saveAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      tokenType: 'Bearer',
    );

    var logoutCalls = 0;
    guard.setForceLogoutHandler(() async {
      logoutCalls++;
    });

    final result = await guard.logoutIfTokensMissing();

    expect(result, isFalse);
    expect(logoutCalls, 0);
  });
}
