import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/news.dart';

class NewsService {
  NewsService({
    Dio? dio,
    String? baseUrl,
  })  : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl ?? AppConfig.apiBaseUrl)),
        _ownsDio = dio == null;

  static const String _newsPath = '/api/v1/news';

  final Dio _dio;
  final bool _ownsDio;

  Future<List<NewsItem>> fetchNews() async {
    try {
      final response = await _dio.get(_newsPath);
      dynamic payload = response.data;
      if (payload is String && payload.isNotEmpty) {
        payload = jsonDecode(payload);
      }
      if (payload is! List) {
        throw const NewsServiceException('Unexpected news payload.');
      }
      return payload
          .whereType<Map<String, dynamic>>()
          .map(NewsItem.fromJson)
          .toList();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final message = status != null
          ? 'Failed to load news (status $status).'
          : (error.message ?? 'Failed to load news.');
      throw NewsServiceException(message);
    } on FormatException catch (error) {
      throw NewsServiceException('Failed to parse news. ${error.message}');
    }
  }

  Future<NewsItem?> fetchFeaturedNews() async {
    final items = await fetchNews();
    return pickFeaturedNews(items);
  }

  NewsItem? pickFeaturedNews(List<NewsItem> items) {
    if (items.isEmpty) return null;
    final active = items.where((item) => item.isActive).toList();
    final pool = active.isNotEmpty ? active : items;
    pool.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return pool.first;
  }

  void dispose() {
    if (_ownsDio) {
      _dio.close(force: false);
    }
  }
}

class NewsServiceException implements Exception {
  const NewsServiceException(this.message);

  final String message;

  @override
  String toString() => 'NewsServiceException: $message';
}
