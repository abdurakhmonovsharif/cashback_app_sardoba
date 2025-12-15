import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/catalog.dart';

class CatalogService {
  CatalogService({
    Dio? dio,
    String? baseUrl,
    String? catalogPath,
  })  : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl ?? AppConfig.apiBaseUrl)),
        _ownsDio = dio == null,
        _catalogPath = catalogPath ?? _defaultCatalogPath;

  static const String _defaultCatalogPath = '/api/v1/catalog/live';

  final Dio _dio;
  final bool _ownsDio;
  String _catalogPath;

  set catalogPath(String value) {
    _catalogPath = value;
  }

  Future<CatalogPayload> fetchCatalog() async {
    try {
      final response = await _dio.get(_catalogPath);
      dynamic payload = response.data;

      if (payload is String && payload.isNotEmpty) {
        payload = jsonDecode(payload);
      }

      if (payload is! Map<String, dynamic>) {
        throw const CatalogServiceException(
          'Unexpected catalog payload. Expected a JSON object.',
        );
      }

      final catalog = CatalogPayload.fromJson(payload);
      if (!catalog.success) {
        throw const CatalogServiceException(
          'Catalog response indicated failure.',
        );
      }

      return catalog;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final details = status != null
          ? 'Request failed with status $status.'
          : (error.message ?? 'Request failed.');
      throw CatalogServiceException('Failed to load catalog. $details');
    } on FormatException catch (error) {
      throw CatalogServiceException('Failed to parse catalog. ${error.message}');
    }
  }

  void dispose() {
    if (_ownsDio) {
      _dio.close(force: false);
    }
  }
}

class CatalogServiceException implements Exception {
  const CatalogServiceException(this.message);

  final String message;

  @override
  String toString() => 'CatalogServiceException: $message';
}
