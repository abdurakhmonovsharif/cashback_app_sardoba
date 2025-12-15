import '../models/catalog.dart';

import 'catalog_service.dart';
import 'catalog_storage.dart';

class CatalogRepository {
  CatalogRepository._({
    CatalogService? service,
    CatalogStorage? storage,
    Duration? cacheDuration,
  })  : _service = service ?? CatalogService(),
        _storage = storage ?? CatalogStorage.instance,
        _cacheDuration = cacheDuration ?? const Duration(minutes: 30);

  static final CatalogRepository instance = CatalogRepository._();

  final CatalogService _service;
  final CatalogStorage _storage;
  final Duration _cacheDuration;

  Future<CatalogPayload> loadCatalog({bool forceRefresh = false}) async {
    final cacheEntry = await _storage.read();
    final now = DateTime.now();
    final isCacheFresh = cacheEntry != null &&
        now.difference(cacheEntry.updatedAt) < _cacheDuration;

    if (!forceRefresh && isCacheFresh) {
      return cacheEntry.payload;
    }

    try {
      final payload = await _service.fetchCatalog();
      await _storage.save(payload);
      return payload;
    } on CatalogServiceException {
      if (cacheEntry != null) {
        return cacheEntry.payload;
      }
      rethrow;
    } catch (_) {
      if (cacheEntry != null) {
        return cacheEntry.payload;
      }
      rethrow;
    }
  }

  Future<CatalogPayload?> getCachedCatalog() async {
    final entry = await _storage.read();
    return entry?.payload;
  }

  Future<DateTime?> getLastUpdated() async {
    final entry = await _storage.read();
    return entry?.updatedAt;
  }

  Future<void> clearCache() => _storage.clear();

  void dispose() {
    _service.dispose();
  }
}
