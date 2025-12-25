import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sardoba_app/services/cashback_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../app_language.dart';
import '../config/app_config.dart';
import '../navigation/app_navigator.dart';
import '../models/app_notification.dart';
import 'auth_storage.dart';
import 'push_notification_service.dart';
import 'session_sync_service.dart';

class NotificationSocketManager {
  NotificationSocketManager._();

  static final NotificationSocketManager instance =
      NotificationSocketManager._();
  final CashbackService cashbackService = CashbackService();
  final AuthStorage _storage = AuthStorage.instance;
  final PushNotificationManager _pushManager = PushNotificationManager.instance;
  final StreamController<AppNotification> _controller =
      StreamController<AppNotification>.broadcast();
  final ValueNotifier<SocketConnectionState> connectionState =
      ValueNotifier<SocketConnectionState>(SocketConnectionState.disconnected);

  final Dio _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  bool _isStarting = false;
  bool _isRefreshingTokens = false;
  bool _isHandlingMissingTokens = false;

  Stream<AppNotification> get notificationStream => _controller.stream;

  Future<void> start() async {
    if (_isStarting || _shouldReconnect) return;
    _isStarting = true;
    debugPrint('🔌 Notification WS starting…');
    try {
      _shouldReconnect = true;
      connectionState.value = SocketConnectionState.connecting;
      await _syncProfileOnConnect();
      await _registerDevice();
      await _connectInternal();
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stop() async {
    debugPrint('🛑 Notification WS stopping…');
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channelSubscription?.cancel();
    await _channel?.sink.close(WebSocketStatus.normalClosure, 'Client stop');
    _channel = null;
    _channelSubscription = null;
    connectionState.value = SocketConnectionState.disconnected;
  }

  Future<void> _registerDevice() async {
    if (!await _ensureAccessTokenAvailable()) return;
    final success = await _performTokenRequest((token, scheme) async {
      await _dio.post(
        '/api/v1/notifications/register-token',
        data: {
          'deviceType': _deviceType,
          'deviceToken': null,
          'language': AppLanguage.instance.locale.apiCode,
          'usesWebSocket': true,
        },
        options: Options(
          headers: {
            'Authorization': '$scheme $token',
          },
        ),
      );
    });
    if (success) {
      debugPrint('✅ Notification device registered for WebSocket.');
    }
  }

  Future<void> _connectInternal() async {
    if (!_shouldReconnect) return;
    if (!await _ensureAccessTokenAvailable()) return;
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      connectionState.value = SocketConnectionState.disconnected;
      return;
    }
    final tokenType = await _storage.getTokenType();
    final scheme = _normalizeScheme(tokenType);
    final uri = _buildWebSocketUri();
    try {
      await _disposeChannel();
      debugPrint('🌐 Connecting to notification WS at $uri');
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'Authorization': '$scheme $token',
          'Sec-WebSocket-Protocol': '$scheme $token',
        },
      );
      _channel?.sink.add(
        jsonEncode({
          'type': 'auth',
          'token': '$scheme $token',
          'language': AppLanguage.instance.locale.apiCode,
        }),
      );
      debugPrint('🔑 Notification WS auth payload sent.');
      _channelSubscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDone,
        onError: _handleError,
        cancelOnError: true,
      );
      _resetReconnect();
      connectionState.value = SocketConnectionState.connected;
      debugPrint('✅ Connected to notification WS at $uri');
    } catch (error) {
      debugPrint('⚠️ Notification WS connect failed: $error');
      connectionState.value = SocketConnectionState.disconnected;
      _scheduleReconnect();
    }
  }

  Future<void> _disposeChannel() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    await _channel?.sink.close(WebSocketStatus.normalClosure, 'Reconnect');
    _channel = null;
  }

  void _handleDone() {
    debugPrint('⚠️ Notification WS connection closed.');
    connectionState.value = SocketConnectionState.disconnected;
    _scheduleReconnect();
  }

  void _handleError(Object error, StackTrace stack) {
    debugPrint('⚠️ Notification WS error: $error');
    connectionState.value = SocketConnectionState.disconnected;
    if (_isAuthFailure(error)) {
      _refreshTokensAndReconnect();
      return;
    }
    _scheduleReconnect();
  }

  bool _isAuthFailure(Object error) {
    if (error is WebSocketChannelException) {
      final message = error.message ?? '';
      if (message.contains('HTTP status code: 403') ||
          message.contains('HTTP status code: 401') ||
          message.contains('403 Unauthorized')) {
        return true;
      }
    }
    return false;
  }

  void _refreshTokensAndReconnect() {
    if (_isRefreshingTokens) return;
    _isRefreshingTokens = true;
    unawaited(_disposeChannel());
    unawaited(_doRefresh());
  }

  Future<void> _doRefresh() async {
    final refreshed = await _storage.refreshTokens();
    _isRefreshingTokens = false;
    if (refreshed) {
      if (!_shouldReconnect) {
        _shouldReconnect = true;
      }
      await _registerDevice();
      _scheduleReconnect();
      return;
    }
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    await AppNavigator.forceLogout();
  }

  void _handleMessage(dynamic message) {
    debugPrint('🔔 Notification WS message received: $message');
    try {
      final payload = _normalizePayload(message);
      if (payload == null) return;
      final notification = _toAppNotification(payload);
      _controller.add(notification);
      _pushManager.showNotification(
        id: notification.id,
        title: notification.title,
        body: notification.description,
        payload: notification.id.toString(),
      );
      unawaited(
        _refreshCashbackForCurrentUser().catchError((error) {
          debugPrint(
              '⚠️ Failed to refresh cashback after notification: $error');
        }),
      );
    } catch (error) {
      debugPrint('⚠️ Notification WS message parse failed: $error');
    }
  }

  Future<void> _refreshCashbackForCurrentUser() async {
    final account = await _storage.getCurrentAccount();
    final userId = account?.id;
    if (account == null || userId == null) return;
    final history = await cashbackService.fetchUserCashback(userId: userId);
    double? updatedBalance = history.loyalty.cashbackBalance;
    if (updatedBalance == null && history.transactions.isNotEmpty) {
      updatedBalance = history.transactions.first.balanceAfter;
    }
    final updatedAccount = account.copyWith(
      cashbackHistory: history.transactions,
      loyalty: history.loyalty,
      cashbackBalance: updatedBalance ?? account.cashbackBalance,
    );
    await _storage.updateCurrentAccount(updatedAccount);
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    final delaySeconds = min(60, 2 << min(_reconnectAttempts, 5));
    final delay = Duration(seconds: delaySeconds);
    _reconnectAttempts++;
    debugPrint(
        '🔄 Scheduling notification WS reconnect in ${delay.inSeconds}s');
    connectionState.value = SocketConnectionState.connecting;
    _reconnectTimer = Timer(delay, () => _connectInternal());
  }

  void _resetReconnect() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Map<String, dynamic>? _normalizePayload(dynamic message) {
    if (message is String) {
      final data = jsonDecode(message);
      if (data is Map<String, dynamic>) return data;
      return null;
    }
    if (message is Map<String, dynamic>) return message;
    return null;
  }

  AppNotification _toAppNotification(Map<String, dynamic> payload) {
    Map<String, dynamic>? parsePayload(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is String && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    final idValue = payload['notification_id'] ??
        payload['id'] ??
        payload['notificationId'];
    final id = (idValue is num)
        ? idValue.toInt()
        : int.tryParse(idValue?.toString() ?? '') ??
            DateTime.now().millisecondsSinceEpoch;
    final createdRaw =
        payload['created_at'] ?? payload['createdAt'] ?? payload['timestamp'];
    final createdAt = _parseDate(createdRaw);
    final title =
        (payload['title'] ?? payload['notification_title'] ?? '').toString();
    final description = (payload['description'] ??
            payload['body'] ??
            payload['notification_description'] ??
            payload['message'])
        .toString();
    final type = (payload['type'] ?? '').toString();
    final language = (payload['language'] ?? '').toString();
    return AppNotification(
      id: id,
      title: title,
      description: description,
      createdAt: createdAt,
      type: type.isEmpty ? null : type,
      language: language.isEmpty ? null : language,
      payload: parsePayload(payload['payload']),
      isSent: true,
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final text = (value ?? '').toString();
    if (text.isEmpty) return DateTime.now();
    return DateTime.tryParse(text) ?? DateTime.now();
  }

  Uri _buildWebSocketUri() {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final baseSegments =
        base.pathSegments.where((segment) => segment.isNotEmpty);
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      pathSegments: [
        ...baseSegments,
        'api',
        'v1',
        'notifications',
        'ws',
      ],
    );
  }

  String get _deviceType {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'android';
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

  Future<bool> _performTokenRequest(
    Future<void> Function(String token, String scheme) action, {
    bool retry = true,
  }) async {
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) return false;
    final scheme = _normalizeScheme(await _storage.getTokenType());
    try {
      await action(token, scheme);
      return true;
    } on DioException catch (error) {
      if (retry && _isDioAuthFailure(error)) {
        final refreshed = await _storage.refreshTokens();
        if (!refreshed) {
          await AppNavigator.forceLogout();
          return false;
        }
        return _performTokenRequest(action, retry: false);
      }
      debugPrint(
        '⚠️ Notification registration failed: ${error.response?.statusCode ?? ''} ${error.message}',
      );
      return false;
    } catch (error) {
      debugPrint('⚠️ Notification registration failed: $error');
      return false;
    }
  }

  bool _isDioAuthFailure(DioException error) {
    final status = error.response?.statusCode;
    return status == 401 || status == 403;
  }

  Future<bool> _ensureAccessTokenAvailable() async {
    if (_isRefreshingTokens) {
      debugPrint(
          '🔄 Token refresh already in progress, skipping socket setup.');
      return false;
    }
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      return true;
    }
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint(
        '⚠️ Missing both access and refresh tokens, logging the user out.',
      );
      await _handleMissingTokens();
      return false;
    }
    debugPrint(
      '🔄 Access token missing, attempting refresh using stored refresh token.',
    );
    _refreshTokensAndReconnect();
    return false;
  }

  Future<void> _handleMissingTokens() async {
    if (_isHandlingMissingTokens) return;
    _isHandlingMissingTokens = true;
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    connectionState.value = SocketConnectionState.disconnected;
    await _disposeChannel();
    try {
      await AppNavigator.forceLogout();
    } finally {
      _isHandlingMissingTokens = false;
    }
  }

  Future<void> _syncProfileOnConnect() async {
    await SessionSyncService.instance.sync();
  }
}

enum SocketConnectionState { disconnected, connecting, connected }
