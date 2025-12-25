import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/app_notification.dart';
import '../navigation/app_navigator.dart';
import 'auth_session_guard.dart';
import 'auth_storage.dart';

class NotificationService {
  NotificationService({
    Dio? dio,
    String? baseUrl,
  })  : _dio =
            dio ?? Dio(BaseOptions(baseUrl: baseUrl ?? AppConfig.apiBaseUrl)),
        _ownsDio = dio == null;

  static const String _notificationsPath = '/api/v1/notifications/clients';

  final Dio _dio;
  final bool _ownsDio;

  Future<ClientNotificationsResponse> fetchNotifications({
    int limit = 50,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 200).toInt();
      final response = await _performAuthenticatedRequest(
        limit: safeLimit,
      );
      dynamic payload = response.data;
      if (payload is String && payload.isNotEmpty) {
        payload = jsonDecode(payload);
      }
      if (payload is! Map<String, dynamic>) {
        throw const NotificationServiceException(
          'Unexpected notifications payload.',
        );
      }

      final items = (payload['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(AppNotification.fromJson)
              .toList() ??
          <AppNotification>[];
      final unreadCount = (payload['unread_count'] as num?)?.toInt() ?? 0;

      return ClientNotificationsResponse(
        items: items,
        unreadCount: unreadCount,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final message = status != null
          ? 'Failed to load notifications (status $status).'
          : (error.message ?? 'Failed to load notifications.');
      throw NotificationServiceException(message);
    } on FormatException catch (error) {
      throw NotificationServiceException(
        'Failed to parse notifications. ${error.message}',
      );
    }
  }

  Future<Response> _performAuthenticatedRequest({
    required int limit,
  }) async {
    final storage = AuthStorage.instance;
    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw NotificationServiceException('Missing access token.');
    }
    final scheme = _normalizeScheme(await storage.getTokenType());
    try {
      return await _dio.get(
        _notificationsPath,
        queryParameters: {
          'limit': limit,
        },
        options: Options(
          headers: {'Authorization': '$scheme $token'},
        ),
      );
    } on DioException catch (error) {
      if (_isAuthError(error)) {
        if (await AuthSessionGuard.instance.logoutIfTokensMissing()) {
          throw NotificationServiceException('Session expired.');
        }
        final refreshed = await storage.refreshTokens();
        if (!refreshed) {
          await AppNavigator.forceLogout();
          throw NotificationServiceException('Session expired.');
        }
        final newToken = await storage.getAccessToken();
        final newScheme = _normalizeScheme(await storage.getTokenType());
        if (newToken == null || newToken.isEmpty) {
          await AppNavigator.forceLogout();
          throw NotificationServiceException('Session expired.');
        }
        return await _dio.get(
          _notificationsPath,
          queryParameters: {
            'limit': limit,
          },
          options: Options(
            headers: {'Authorization': '$newScheme $newToken'},
          ),
        );
      }
      rethrow;
    }
  }

  bool _isAuthError(DioException error) {
    final status = error.response?.statusCode;
    return status == 401 || status == 403;
  }

  String _normalizeScheme(String? tokenType) {
    var scheme = tokenType?.trim();
    if (scheme == null || scheme.isEmpty) {
      scheme = 'Bearer';
    }
    if (scheme.toLowerCase() == 'bearer') {
      scheme = 'Bearer';
    }
    return scheme;
  }

  void dispose() {
    if (_ownsDio) {
      _dio.close(force: false);
    }
  }

  Future<void> markAsRead({required int notificationId}) async {
    final storage = AuthStorage.instance;
    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw NotificationServiceException('Missing access token.');
    }
    final scheme = _normalizeScheme(await storage.getTokenType());
    final path = '$_notificationsPath/$notificationId/read';
    try {
      await _dio.post(
        path,
        options: Options(headers: {'Authorization': '$scheme $token'}),
      );
    } on DioException catch (error) {
      if (_isAuthError(error)) {
        if (await AuthSessionGuard.instance.logoutIfTokensMissing()) {
          throw NotificationServiceException('Session expired.');
        }
        final refreshed = await storage.refreshTokens();
        if (!refreshed) {
          await AppNavigator.forceLogout();
          throw NotificationServiceException('Session expired.');
        }
        final newToken = await storage.getAccessToken();
        final newScheme = _normalizeScheme(await storage.getTokenType());
        await _dio.post(
          path,
          options: Options(headers: {'Authorization': '$newScheme $newToken'}),
        );
        return;
      }
      rethrow;
    }
  }
}

class NotificationServiceException implements Exception {
  const NotificationServiceException(this.message);

  final String message;

  @override
  String toString() => 'NotificationServiceException: $message';
}

class ClientNotificationsResponse {
  const ClientNotificationsResponse({
    required this.items,
    required this.unreadCount,
  });

  final List<AppNotification> items;
  final int unreadCount;
}
