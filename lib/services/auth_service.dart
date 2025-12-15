import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/account.dart';
import '../models/cashback_entry.dart';
import '../models/loyalty_summary.dart';
import '../models/login_response.dart';

class AuthService {
  AuthService({
    Dio? dio,
    String? baseUrl,
  })  : _dio =
            dio ?? Dio(BaseOptions(baseUrl: baseUrl ?? AppConfig.apiBaseUrl)),
        _ownsDio = dio == null;

  static const String _requestOtpPath = '/api/v1/auth/client/request-otp';
  static const String _verifyOtpPath = '/api/v1/auth/client/verify-otp';
  static const String _profilePath = '/api/v1/auth/me';
  static const String _refreshPath = '/api/v1/auth/refresh';
  static const String _userPath = '/api/v1/users/me';
  static const String _profilePhotoPath = '/api/v1/files/profile-photo';

  final Dio _dio;
  final bool _ownsDio;

  Future<void> requestOtp({
    required String phone,
    String purpose = 'login',
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    try {
      await _dio.post(
        _requestOtpPath,
        data: {
          'phone': normalizedPhone,
          'purpose': purpose,
        },
      );
    } on DioException catch (error) {
      final localized = _localizedMessagesFromResponse(error.response?.data);
      final message = localized?.values.first ??
          _errorMessageFromResponse(error) ??
          'Failed to request code.';
      throw AuthServiceException(
        message,
        localizedMessages: localized,
      );
    }
  }

  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
    String? name,
    required String purpose,
    String? waiterReferralCode,
    DateTime? dateOfBirth,
  }) async {
    final normalizedPhone = _normalizePhone(phone);

    final payload = <String, dynamic>{
      'phone': normalizedPhone,
      'code': code,
      'purpose': purpose,
    };

    if (name != null && name.trim().isNotEmpty) {
      payload['name'] = name.trim();
    }

    if (waiterReferralCode != null && waiterReferralCode.trim().isNotEmpty) {
      payload['waiter_referral_code'] = waiterReferralCode.trim();
    }
    if (dateOfBirth != null) {
      payload['date_of_birth'] = _formatDate(dateOfBirth);
    }

    try {
      final response = await _dio.post(
        _verifyOtpPath,
        data: payload,
      );

      dynamic body = response.data;
      if (body is String && body.isNotEmpty) {
        body = jsonDecode(body);
      }

      final map = _asMap(body) ?? <String, dynamic>{};
      final data = _asMap(map['data']) ?? map;
      final tokens = _tokenResponseFromMap(map);
      final accessToken = tokens.accessToken;
      final refreshToken = tokens.refreshToken;
      final tokenType = tokens.tokenType;

      Map<String, dynamic>? profile;
      if (accessToken != null && accessToken.isNotEmpty) {
        profile = await _fetchProfile(
          accessToken: accessToken,
          tokenType: tokenType,
        );
      }

      final accountSource = profile ??
          _asMap(data['profile']) ??
          _asMap(data['client']) ??
          _asMap(data['user']) ??
          _asMap(data['account']) ??
          data;

      final account = _accountFromPayload(
        accountSource,
        normalizedPhone: normalizedPhone,
        fallbackName: name,
      );

      return AuthSession(
        account: account,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenType: tokenType,
      );
    } on DioException catch (error) {
      final localized = _localizedMessagesFromResponse(error.response?.data);
      final message = localized?.values.first ??
          _errorMessageFromResponse(error) ??
          (error.message?.isNotEmpty == true
              ? error.message!
              : 'Failed to verify code.');
      throw AuthServiceException(
        message,
        localizedMessages: localized,
      );
    } catch (error) {
      throw AuthServiceException('Failed to verify code. $error');
    }
  }

  Future<Account?> fetchProfileWithToken({
    required String accessToken,
    String? tokenType,
    String? fallbackPhone,
    String? fallbackName,
  }) async {
    final payload = await _fetchProfile(
      accessToken: accessToken,
      tokenType: tokenType,
    );
    if (payload == null) return null;
    final normalizedPhone = fallbackPhone != null && fallbackPhone.isNotEmpty
        ? _normalizePhone(fallbackPhone)
        : '';
    return _accountFromPayload(
      payload,
      normalizedPhone: normalizedPhone,
      fallbackName: fallbackName,
    );
  }

  Future<Map<String, dynamic>?> _fetchProfile({
    required String accessToken,
    String? tokenType,
  }) async {
    final scheme =
        (tokenType?.trim().isNotEmpty ?? false) ? tokenType!.trim() : 'Bearer';
    final normalizedScheme =
        scheme.toLowerCase() == 'bearer' ? 'Bearer' : scheme;
    try {
      final response = await _dio.get(
        _profilePath,
        options: Options(
          headers: {
            'Authorization': '$normalizedScheme $accessToken',
          },
        ),
      );

      dynamic payload = response.data;
      if (payload is String && payload.isNotEmpty) {
        payload = jsonDecode(payload);
      }

      final map = _asMap(payload) ?? const <String, dynamic>{};
      final root = _asMap(map['data']) ?? map;
      final profileMap = _asMap(root['profile']) ??
          _asMap(root['user']) ??
          _asMap(root['client']) ??
          root;
      final profile = Map<String, dynamic>.from(profileMap);
      final cashback = _asMap(root['cashback']);
      if (cashback != null) {
        final cashbackCopy = Map<String, dynamic>.from(cashback);
        final transactions = _asList(cashback['transactions']);
        if (transactions != null) {
          cashbackCopy['transactions'] = transactions
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        profile['_cashback'] = cashbackCopy;
        if (!profile.containsKey('cashback_balance')) {
          profile['cashback_balance'] = _double(cashbackCopy['balance']) ??
              _double(cashbackCopy['current_points']) ??
              cashbackCopy['balance'];
        }
        final loyalty = _asMap(cashbackCopy['loyalty']);
        if (loyalty != null) {
          profile['_loyalty'] = loyalty;
        }
      }
      return profile;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw AuthUnauthorizedException(
          'Session expired. Please sign in again.',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Account> updateUserProfile({
    required String accessToken,
    String? tokenType,
    String? name,
    String? surname,
    String? middleName,
    DateTime? dateOfBirth,
    String? profilePhotoUrl,
    String? fallbackPhone,
    String? fallbackName,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      payload['name'] = name.trim();
    }
    if (surname != null && surname.trim().isNotEmpty) {
      payload['surname'] = surname.trim();
    }
    if (middleName != null && middleName.trim().isNotEmpty) {
      payload['middleName'] = middleName.trim();
    }
    if (dateOfBirth != null) {
      payload['date_of_birth'] = _formatDate(dateOfBirth);
    }
    if (profilePhotoUrl != null && profilePhotoUrl.trim().isNotEmpty) {
      payload['profile_photo_url'] = profilePhotoUrl.trim();
    }
    try {
      final response = await _dio.put(
        _userPath,
        data: payload,
        options: _optionsWithAuth(
          accessToken: accessToken,
          tokenType: tokenType,
        ),
      );
      dynamic body = response.data;
      if (body is String && body.isNotEmpty) {
        body = jsonDecode(body);
      }
      final map = _asMap(body) ?? const <String, dynamic>{};
      return _accountFromPayload(
        map,
        normalizedPhone: fallbackPhone ?? '',
        fallbackName: fallbackName,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw AuthUnauthorizedException(
          'Session expired. Please sign in again.',
        );
      }
      final localized = _localizedMessagesFromResponse(error.response?.data);
      final message = localized?.values.first ??
          _errorMessageFromResponse(error) ??
          'Failed to update profile.';
      throw AuthServiceException(
        message,
        localizedMessages: localized,
      );
    }
  }

  Future<Account> uploadProfilePhoto({
    required String accessToken,
    String? tokenType,
    required File file,
    String? fallbackPhone,
    String? fallbackName,
  }) async {
    final filename = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'avatar.jpg';
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
    });
    try {
      final response = await _dio.post(
        _profilePhotoPath,
        data: formData,
        options: _optionsWithAuth(
          accessToken: accessToken,
          tokenType: tokenType,
          isMultipart: true,
        ),
      );
      dynamic body = response.data;
      if (body is String && body.isNotEmpty) {
        body = jsonDecode(body);
      }
      final map = _asMap(body) ?? const <String, dynamic>{};
      return _accountFromPayload(
        map,
        normalizedPhone: fallbackPhone ?? '',
        fallbackName: fallbackName,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw AuthUnauthorizedException(
          'Session expired. Please sign in again.',
        );
      }
      final localized = _localizedMessagesFromResponse(error.response?.data);
      final message = localized?.values.first ??
          _errorMessageFromResponse(error) ??
          'Failed to upload photo.';
      throw AuthServiceException(
        message,
        localizedMessages: localized,
      );
    }
  }

  Future<void> deleteAccount({
    required String accessToken,
    String? tokenType,
  }) async {
    try {
      await _dio.delete(
        _userPath,
        options: _optionsWithAuth(
          accessToken: accessToken,
          tokenType: tokenType,
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw AuthUnauthorizedException(
          'Session expired. Please sign in again.',
        );
      }
      final localized = _localizedMessagesFromResponse(error.response?.data);
      final message = localized?.values.first ??
          _errorMessageFromResponse(error) ??
          'Failed to delete account.';
      throw AuthServiceException(
        message,
        localizedMessages: localized,
      );
    }
  }

  Future<LoginResponse> refreshTokens({required String refreshToken}) async {
    try {
      final response = await _dio.post(
        _refreshPath,
        data: {'refresh_token': refreshToken},
      );

      dynamic body = response.data;
      if (body is String && body.isNotEmpty) {
        body = jsonDecode(body);
      }

      final map = _asMap(body) ?? <String, dynamic>{};
      return _tokenResponseFromMap(map);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        throw AuthUnauthorizedException(
          'Session expired. Please sign in again.',
        );
      }
      final localized = _localizedMessagesFromResponse(error.response?.data);
      final message = localized?.values.first ??
          _errorMessageFromResponse(error) ??
          'Failed to refresh tokens.';
      throw AuthServiceException(
        message,
        localizedMessages: localized,
      );
    }
  }

  Account _accountFromPayload(
    Map<String, dynamic>? payload, {
    required String normalizedPhone,
    String? fallbackName,
  }) {
    final source = payload ?? const <String, dynamic>{};
    final resolvedName = _string(source['name']) ??
        _string(source['full_name']) ??
        (() {
          final trimmed = fallbackName?.trim() ?? '';
          return trimmed.isNotEmpty ? trimmed : null;
        })() ??
        '';
    final resolvedSurname = _string(source['surname']) ??
        _string(source['last_name']) ??
        _string(source['family_name']);
    final resolvedMiddleName = _string(source['middleName']) ??
        _string(source['middle_name']) ??
        _string(source['patronymic']);
    final resolvedPhone =
        _digitsOnly(_string(source['phone']) ?? normalizedPhone);
    final fallbackPhone = _digitsOnly(normalizedPhone);
    final referral = _string(source['waiter_referral_code']) ??
        _string(source['referral_code']);
    final isVerified = (source['is_verified'] as bool?) ?? true;
    final id = _int(source['id']);
    final cashbackMap = _asMap(source['_cashback']);
    double? cashbackBalance = _double(source['cashback_balance']) ??
        _double(cashbackMap?['balance']) ??
        _double(cashbackMap?['current_points']);
    final dateOfBirth =
        _date(source['date_of_birth']) ?? _date(source['dateOfBirth']);
    final profilePhotoUrl = _resolveProfilePhotoUrl(
      _string(source['profile_photo_url']) ??
          _string(source['profilePhotoUrl']),
    );
    final waiterId = _int(source['waiter_id']) ?? _int(source['waiterId']);
    final loyaltySummaryMap =
        _asMap(source['_loyalty']) ?? _asMap(source['loyalty']);
    final loyalty = loyaltySummaryMap != null
        ? LoyaltySummary.fromJson(loyaltySummaryMap)
        : null;
    final transactions = _asList(cashbackMap?['transactions']) ??
        _asList(source['cashback_transactions']);
    final cashbackHistory = transactions
        ?.whereType<Map>()
        .map((e) => CashbackEntry.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
    final cards = _asList(cashbackMap?['cards']);
    final cardTracks = cards
        ?.expand((e) {
          if (e is String) return [e];
          if (e is Map) {
            return [
              _string(e['card_track']),
              _string(e['card_number']),
            ];
          }
          return const <String?>[];
        })
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return Account(
      name: resolvedName,
      surname: resolvedSurname,
      middleName: resolvedMiddleName,
      phone: resolvedPhone.isNotEmpty ? resolvedPhone : fallbackPhone,
      referralCode: referral,
      isVerified: isVerified,
      id: id,
      cashbackBalance: cashbackBalance,
      dateOfBirth: dateOfBirth,
      profilePhotoUrl: profilePhotoUrl,
      waiterId: waiterId,
      loyalty: loyalty,
      level: _string(source['level']) ?? loyalty?.level,
      cashbackHistory: cashbackHistory,
      cardTracks: cardTracks,
    );
  }

  LoginResponse _tokenResponseFromMap(Map<String, dynamic> map) {
    final data = _asMap(map['data']) ?? map;
    final tokensMap = _asMap(data['tokens']) ?? _asMap(map['tokens']);
    final accessToken = _string(tokensMap?['access_token']) ??
        _string(data['access_token']) ??
        _string(data['token']) ??
        _string(map['token']);
    final refreshToken = _string(tokensMap?['refresh_token']) ??
        _string(data['refresh_token']) ??
        _string(map['refresh_token']);
    var tokenType = _string(tokensMap?['token_type']) ??
        _string(data['token_type']) ??
        _string(map['token_type']);
    final trimmedTokenType = tokenType?.trim();
    tokenType = (trimmedTokenType != null && trimmedTokenType.isNotEmpty)
        ? trimmedTokenType
        : 'bearer';

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw AuthServiceException('Invalid token response.');
    }

    return LoginResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
    );
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  String _normalizePhone(String value) {
    final digitsOnly = _digitsOnly(value);
    if (digitsOnly.isEmpty) return value;
    return '+$digitsOnly';
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String? _string(dynamic value) {
    if (value is String) return value;
    return null;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _double(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[\s\u00A0]'), '');
      final sanitized =
          cleaned.replaceAll(RegExp(r'[^0-9,.\-]'), '').replaceAll(',', '.');
      return double.tryParse(sanitized);
    }
    return double.tryParse(value.toString());
  }

  DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }
    return null;
  }

  List<dynamic>? _asList(dynamic value) {
    if (value is List) return value;
    return null;
  }

  String? _resolveProfilePhotoUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null &&
        parsed.hasScheme &&
        (parsed.host.isNotEmpty || parsed.scheme == 'data')) {
      return parsed.toString();
    }

    final base = Uri.tryParse(_dio.options.baseUrl);
    if (base == null || !base.hasScheme || base.host.isEmpty) {
      return trimmed;
    }

    try {
      if (parsed != null) {
        return base.resolveUri(parsed).toString();
      }
      return base.resolve(trimmed).toString();
    } catch (_) {
      return trimmed;
    }
  }

  Options _optionsWithAuth({
    required String accessToken,
    String? tokenType,
    bool isMultipart = false,
    Map<String, dynamic>? extraHeaders,
  }) {
    String scheme =
        (tokenType?.trim().isNotEmpty ?? false) ? tokenType!.trim() : 'Bearer';
    if (scheme.toLowerCase() == 'bearer') {
      scheme = 'Bearer';
    }
    final headers = <String, dynamic>{
      'Authorization': '$scheme $accessToken',
      if (extraHeaders != null) ...extraHeaders,
    };
    return Options(
      headers: headers,
      contentType: isMultipart ? 'multipart/form-data' : null,
    );
  }

  String? _errorMessageFromResponse(DioException exception) {
    final data = exception.response?.data;
    final localized = _localizedMessagesFromResponse(data);
    if (localized != null && localized.isNotEmpty) {
      return localized.values.first;
    }
    final message = _extractMessage(data);
    if (message != null && message.isNotEmpty) {
      return message;
    }
    final status = exception.response?.statusMessage;
    if (status != null && status.isNotEmpty) {
      return status;
    }
    if (exception.response?.statusCode != null) {
      return 'Request failed with status ${exception.response!.statusCode}.';
    }
    return null;
  }

  String? _extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      final text = data.trim();
      return text.isNotEmpty ? text : null;
    }
    if (data is List) {
      for (final item in data) {
        final message = _extractMessage(item);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      return null;
    }
    if (data is Map<String, dynamic>) {
      final candidates = [
        data['message'],
        data['error'],
        data['detail'],
        data['msg'],
      ];
      for (final candidate in candidates) {
        final message = _extractMessage(candidate);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      return null;
    }
    return data.toString();
  }

  Map<String, String>? _localizedMessagesFromResponse(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final map = Map<dynamic, dynamic>.from(data);
      final localized = _extractLocalizedMap(map);
      if (localized != null && localized.isNotEmpty) return localized;
      final priorityKeys = ['detail', 'error', 'message', 'data'];
      for (final key in priorityKeys) {
        final nested = _localizedMessagesFromResponse(map[key]);
        if (nested != null) return nested;
      }
      for (final value in map.values) {
        final nested = _localizedMessagesFromResponse(value);
        if (nested != null) return nested;
      }
      return null;
    }
    if (data is List) {
      for (final item in data) {
        final nested = _localizedMessagesFromResponse(item);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  Map<String, String>? _extractLocalizedMap(Map<dynamic, dynamic> data) {
    const localeKeys = {'uz', 'ru', 'en', 'default'};
    final result = <String, String>{};
    data.forEach((key, value) {
      final normalizedKey = key.toString().toLowerCase();
      if (localeKeys.contains(normalizedKey) && value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          result[normalizedKey] = trimmed;
        }
      }
    });
    return result.isNotEmpty ? result : null;
  }

  void dispose() {
    if (_ownsDio) {
      _dio.close(force: false);
    }
  }
}

class AuthSession {
  const AuthSession({
    required this.account,
    this.accessToken,
    this.refreshToken,
    this.tokenType,
  });

  final Account account;
  final String? accessToken;
  final String? refreshToken;
  final String? tokenType;

  String? get token => accessToken;
}

class AuthServiceException implements Exception {
  AuthServiceException(this.message, {this.localizedMessages});
  final String message;
  final Map<String, String>? localizedMessages;

  @override
  String toString() => 'AuthServiceException: $message';
}

class AuthUnauthorizedException extends AuthServiceException {
  AuthUnauthorizedException(super.message);
}
