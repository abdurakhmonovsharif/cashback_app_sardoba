import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalog.dart';

class CatalogCacheEntry {
  const CatalogCacheEntry({
    required this.payload,
    required this.updatedAt,
  });

  final CatalogPayload payload;
  final DateTime updatedAt;
}

class CatalogStorage {
  CatalogStorage._();

  static final CatalogStorage instance = CatalogStorage._();

  static const String _catalogKey = 'catalog_cache_payload';
  static const String _timestampKey = 'catalog_cache_timestamp';

  SharedPreferences? _prefs;

  Future<void> ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> save(CatalogPayload payload) async {
    await ensureInitialized();
    final jsonString = jsonEncode(payload.toJson());
    await _prefs!.setString(_catalogKey, jsonString);
    await _prefs!
        .setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<CatalogCacheEntry?> read() async {
    await ensureInitialized();
    final data = _prefs!.getString(_catalogKey);
    final timestamp = _prefs!.getInt(_timestampKey);
    if (data == null || timestamp == null) return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return null;
      final payload = CatalogPayload.fromJson(decoded);
      final updatedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return CatalogCacheEntry(payload: payload, updatedAt: updatedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await ensureInitialized();
    await _prefs!.remove(_catalogKey);
    await _prefs!.remove(_timestampKey);
  }
}
