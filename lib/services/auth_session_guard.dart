import 'package:flutter/foundation.dart';

import '../navigation/app_navigator.dart';
import 'auth_storage.dart';

class AuthSessionGuard {
  AuthSessionGuard._();

  static final AuthSessionGuard instance = AuthSessionGuard._();

  final AuthStorage _storage = AuthStorage.instance;
  Future<void> Function() _forceLogoutHandler = AppNavigator.forceLogout;
  bool _isLoggingOut = false;

  Future<bool> logoutIfTokensMissing() async {
    final accessToken = await _storage.getAccessToken();
    final refreshToken = await _storage.getRefreshToken();
    if ((accessToken?.isNotEmpty ?? false) || (refreshToken?.isNotEmpty ?? false)) {
      return false;
    }
    if (_isLoggingOut) return true;
    _isLoggingOut = true;
    try {
      // Guard logs indicate 401 may result from empty storage; ensure we exit to login.
      await _forceLogoutHandler();
    } finally {
      _isLoggingOut = false;
    }
    return true;
  }

  @visibleForTesting
  void setForceLogoutHandler(Future<void> Function() handler) {
    _forceLogoutHandler = handler;
  }

  @visibleForTesting
  void resetForTesting() {
    _forceLogoutHandler = AppNavigator.forceLogout;
    _isLoggingOut = false;
  }
}
