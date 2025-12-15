import '../models/account.dart';
import '../navigation/app_navigator.dart';
import 'auth_service.dart';
import 'auth_session_guard.dart';
import 'auth_storage.dart';

/// Helper that keeps the current profile synced with authenticated sessions.
class SessionSyncService {
  SessionSyncService._();

  static final SessionSyncService instance = SessionSyncService._();

  final AuthStorage _storage = AuthStorage.instance;
  final AuthSessionGuard _guard = AuthSessionGuard.instance;

  /// Ensure the stored account is refreshed using the latest tokens.
  Future<Account?> sync({
    AuthService? authService,
    String? fallbackName,
  }) async {
    final service = authService ?? AuthService();
    final shouldDispose = authService == null;
    try {
      return await _syncWithService(
        service,
        fallbackName: fallbackName,
      );
    } finally {
      if (shouldDispose) {
        service.dispose();
      }
    }
  }

  Future<Account?> _syncWithService(
    AuthService service, {
    String? fallbackName,
  }) async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return null;
    final tokenType = await _storage.getTokenType();
    final currentPhone = await _storage.getCurrentUser();
    try {
      return await _fetchAndStoreProfile(
        service,
        accessToken: accessToken,
        tokenType: tokenType,
        fallbackPhone: currentPhone,
        fallbackName: fallbackName,
      );
    } on AuthUnauthorizedException {
      if (await _guard.logoutIfTokensMissing()) {
        return null;
      }
      final refreshed = await _storage.refreshTokens();
      if (!refreshed) {
        await AppNavigator.forceLogout();
        return null;
      }
      final newToken = await _storage.getAccessToken();
      final newType = await _storage.getTokenType();
      if (newToken == null || newToken.isEmpty) {
        await AppNavigator.forceLogout();
        return null;
      }
      try {
        return await _fetchAndStoreProfile(
          service,
          accessToken: newToken,
          tokenType: newType,
          fallbackPhone: currentPhone,
          fallbackName: fallbackName,
        );
      } on AuthUnauthorizedException {
        await AppNavigator.forceLogout();
      }
    } catch (_) {
      // Ignore other profile sync failures.
    }
    return null;
  }

  Future<Account?> _fetchAndStoreProfile(
    AuthService service, {
    required String accessToken,
    String? tokenType,
    String? fallbackPhone,
    String? fallbackName,
  }) async {
    final profile = await service.fetchProfileWithToken(
      accessToken: accessToken,
      tokenType: tokenType,
      fallbackPhone: fallbackPhone,
      fallbackName: fallbackName,
    );
    if (profile == null) return null;
    final cached = profile.copyWith(isVerified: true);
    await _storage.upsertAccount(cached);
    if (fallbackPhone == null || fallbackPhone.isEmpty) {
      await _storage.setCurrentUser(profile.phone);
    }
    return cached;
  }
}
