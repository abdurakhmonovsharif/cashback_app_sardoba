import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/points_history.dart';
import 'auth_storage.dart';

class PointsService {
  PointsService({
    Dio? dio,
    String? baseUrl,
  })  : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl ?? AppConfig.apiBaseUrl)),
        _ownsDio = dio == null;

  static const String _pointsPath = '/api/v1/cashback/user';

  final Dio _dio;
  final bool _ownsDio;

  final _pointsController = StreamController<PointsHistory>.broadcast();
  Stream<PointsHistory> get pointsStream => _pointsController.stream;

  Future<PointsHistory> fetchUserPoints({
    required int userId,
    String? accessToken,
    String? tokenType,
  }) async {
    final storage = AuthStorage.instance;
    final token = accessToken ?? await storage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const PointsServiceException('Not authenticated.');
    }
    String scheme = tokenType ?? await storage.getTokenType() ?? 'Bearer';
    scheme = scheme.trim();
    if (scheme.isEmpty) scheme = 'Bearer';
    final normalizedScheme =
        scheme.toLowerCase() == 'bearer' ? 'Bearer' : scheme;

    try {
      final response = await _dio.get(
        '$_pointsPath/$userId',
        options: Options(
          headers: {
            'Authorization': '$normalizedScheme $token',
          },
        ),
      );
      dynamic payload = response.data;
      if (payload is String && payload.isNotEmpty) {
        payload = jsonDecode(payload);
      }
      if (payload is! Map<String, dynamic>) {
        throw const PointsServiceException('Unexpected points payload.');
      }
      final points = PointsHistory.fromJson(payload);
      _pointsController.add(points);
      return PointsHistory.fromJson(payload);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401) {
        throw const PointsUnauthorizedException('Unauthorized');
      }
      final message = status != null
          ? 'Failed to load points data (status $status).'
          : (error.message ?? 'Failed to load points data.');
      throw PointsServiceException(message);
    } on FormatException catch (error) {
      throw PointsServiceException(
        'Failed to parse points entries. ${error.message}',
      );
    }
  }

  void dispose() {
    if (_ownsDio) {
      _dio.close(force: false);
    }
  }
}

class PointsServiceException implements Exception {
  const PointsServiceException(this.message);

  final String message;

  @override
  String toString() => 'PointsServiceException: $message';
}

class PointsUnauthorizedException extends PointsServiceException {
  const PointsUnauthorizedException(super.message);
}
