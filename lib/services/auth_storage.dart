import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import 'account_stream.dart';
import 'auth_service.dart';

class AuthStorage {
  AuthStorage._();

  static final AuthStorage instance = AuthStorage._();

  static const _accountsKey = 'accounts';
  static const _currentUserKey = 'current_user';
  static const _pinKey = 'app_pin';
  static const _authTokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenTypeKey = 'auth_token_type';
  static const _onboardingDoneKey = 'onboarding_done';

  SharedPreferences? _prefs;

  Future<void> ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<List<Account>> _loadAccounts() async {
    await ensureInitialized();
    final raw = _prefs!.getString(_accountsKey);
    return Account.listFromJson(raw);
  }

  Future<void> _saveAccounts(List<Account> accounts) async {
    await ensureInitialized();
    await _prefs!.setString(_accountsKey, Account.listToJson(accounts));
  }

  Future<bool> accountExists(String phone) async {
    final normalized = normalizePhone(phone);
    final accounts = await _loadAccounts();
    return accounts.any((account) => account.phone == normalized);
  }

  Future<Account?> getAccount(String phone) async {
    final normalized = normalizePhone(phone);
    final accounts = await _loadAccounts();
    try {
      return accounts.firstWhere((account) => account.phone == normalized);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertAccount(Account newAccount) async {
    final normalized = normalizePhone(newAccount.phone);
    final accounts = await _loadAccounts();
    final sanitized = newAccount.copyWith(phone: normalized);
    final index = accounts.indexWhere((account) => account.phone == normalized);
    if (index >= 0) {
      accounts[index] = sanitized;
    } else {
      accounts.add(sanitized);
    }
    await _saveAccounts(accounts);
  }

  Future<void> markVerified(String phone, {bool verified = true}) async {
    final normalized = normalizePhone(phone);
    final accounts = await _loadAccounts();
    final index = accounts.indexWhere((account) => account.phone == normalized);
    if (index >= 0) {
      accounts[index] = accounts[index].copyWith(isVerified: verified);
      await _saveAccounts(accounts);
    }
  }

  Future<void> setCurrentUser(String phone) async {
    await ensureInitialized();
    await _prefs!.setString(_currentUserKey, phone);
  }

  Future<void> clearCurrentUser() async {
    await ensureInitialized();
    await _prefs!.remove(_currentUserKey);
    await _prefs!.remove(_authTokenKey);
    await _prefs!.remove(_refreshTokenKey);
    await _prefs!.remove(_tokenTypeKey);
  }

  Future<void> logout() async {
    await clearPin();
    await clearCurrentUser();
  }

  Future<void> setOnboardingCompleted(bool value) async {
    await ensureInitialized();
    await _prefs!.setBool(_onboardingDoneKey, value);
  }

  Future<bool> isOnboardingCompleted() async {
    await ensureInitialized();
    return _prefs!.getBool(_onboardingDoneKey) ?? false;
  }

  Future<bool> refreshTokens({AuthService? authService}) async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    final service = authService ?? AuthService();
    final shouldDispose = authService == null;
    try {
      final tokens = await service.refreshTokens(refreshToken: refreshToken);
      await saveAuthTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        tokenType: tokens.tokenType,
      );
      return true;
    } on AuthUnauthorizedException {
      await logout();
      return false;
    } on AuthServiceException {
      return false;
    } finally {
      if (shouldDispose) {
        service.dispose();
      }
    }
  }

  Future<String?> getCurrentUser() async {
    await ensureInitialized();
    return _prefs!.getString(_currentUserKey);
  }

  Future<Account?> getCurrentAccount() async {
    final currentPhone = await getCurrentUser();
    if (currentPhone == null) return null;
    return getAccount(currentPhone);
  }

  Future<void> updateCurrentAccount(Account account) async {
    final normalizedPhone = normalizePhone(account.phone);
    final normalizedAccount = account.copyWith(phone: normalizedPhone);
    await upsertAccount(normalizedAccount);
    await setCurrentUser(normalizedPhone);
    accountStream.emit(normalizedAccount);
  }

  Future<bool> hasCurrentUser() async {
    return (await getCurrentUser()) != null;
  }

  Future<bool> hasPin() async {
    await ensureInitialized();
    return _prefs!.containsKey(_pinKey);
  }

  Future<void> savePin(String pin) async {
    await ensureInitialized();
    await _prefs!.setString(_pinKey, _hash(pin));
  }

  Future<bool> verifyPin(String pin) async {
    await ensureInitialized();
    final stored = _prefs!.getString(_pinKey);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  Future<void> clearPin() async {
    await ensureInitialized();
    await _prefs!.remove(_pinKey);
  }

  String _hash(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  Future<void> saveAuthTokens({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
  }) async {
    await ensureInitialized();
    if (accessToken == null || accessToken.isEmpty) {
      await _prefs!.remove(_authTokenKey);
    } else {
      await _prefs!.setString(_authTokenKey, accessToken);
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      await _prefs!.remove(_refreshTokenKey);
    } else {
      await _prefs!.setString(_refreshTokenKey, refreshToken);
    }

    if (tokenType == null || tokenType.isEmpty) {
      await _prefs!.remove(_tokenTypeKey);
    } else {
      await _prefs!.setString(_tokenTypeKey, tokenType);
    }
  }

  Future<String?> getAccessToken() async {
    await ensureInitialized();
    return _prefs!.getString(_authTokenKey);
  }

  Future<String?> getRefreshToken() async {
    await ensureInitialized();
    return _prefs!.getString(_refreshTokenKey);
  }

  Future<String?> getTokenType() async {
    await ensureInitialized();
    return _prefs!.getString(_tokenTypeKey);
  }

  @Deprecated('Use saveAuthTokens instead')
  Future<void> saveAuthToken(String? token) async {
    await saveAuthTokens(accessToken: token);
  }

  @Deprecated('Use getAccessToken instead')
  Future<String?> getAuthToken() async {
    await ensureInitialized();
    return _prefs!.getString(_authTokenKey);
  }

  @visibleForTesting
  void resetForTesting() {
    _prefs = null;
  }
}
