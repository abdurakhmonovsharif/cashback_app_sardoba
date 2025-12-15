import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/branch.dart';

class BranchService {
  BranchService({
    Dio? dio,
    String? baseUrl,
    String? branchesPath,
  })  : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl ?? AppConfig.apiBaseUrl)),
        _ownsDio = dio == null,
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _branchesPath = branchesPath ?? _defaultBranchesPath;

  static const String _defaultBranchesPath = '/branches';

  final Dio _dio;
  final bool _ownsDio;
  String _baseUrl;
  String _branchesPath;

  set baseUrl(String value) {
    _baseUrl = value;
    if (_ownsDio) {
      _dio.options.baseUrl = value;
    }
  }

  set branchesPath(String value) {
    _branchesPath = value;
  }

  Future<List<Branch>> fetchBranches({
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(_branchesPath, queryParameters);

    try {
      final response = await _dio.getUri(
        uri,
        options: Options(headers: headers),
      );

      dynamic payload = response.data;
      if (payload is String && payload.isNotEmpty) {
        payload = jsonDecode(payload);
      }

      if (payload == null) {
        return const [];
      }

      final parsed = _parsePayload(payload);
      return parsed.map(Branch.fromJson).toList();
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final message = statusCode != null
          ? 'Failed to load branches (status: $statusCode).'
          : 'Failed to load branches. ${error.message ?? ''}'.trim();
      throw BranchServiceException(message);
    } on FormatException catch (error) {
      throw BranchServiceException(
        'Invalid branch payload: ${error.message}',
      );
    }
  }

  List<Map<String, dynamic>> _parsePayload(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }

    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
    }

    throw const BranchServiceException(
      'Unexpected branches payload. Provide an array or { "data": [] }.',
    );
  }

  Uri _buildUri(String path, Map<String, String>? queryParameters) {
    final normalizedBase =
        _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParameters,
    });
  }

  void dispose() {
    if (_ownsDio) {
      _dio.close(force: false);
    }
  }
}

class BranchServiceException implements Exception {
  const BranchServiceException(this.message);

  final String message;

  @override
  String toString() => 'BranchServiceException: $message';
}
