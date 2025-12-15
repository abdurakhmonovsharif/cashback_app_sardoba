import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteProducts extends ChangeNotifier {
  FavoriteProducts._();

  static final FavoriteProducts instance = FavoriteProducts._();
  static const _storageKey = 'favorite_products';

  final Set<String> _favorites = <String>{};
  SharedPreferences? _prefs;
  bool _initialized = false;

  UnmodifiableSetView<String> get favorites =>
      UnmodifiableSetView<String>(_favorites);

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final storedIds = _prefs!.getStringList(_storageKey);
    if (storedIds != null) {
      _favorites
        ..clear()
        ..addAll(storedIds);
    }
    _initialized = true;
    notifyListeners();
  }

  bool isFavorite(String productId) {
    return _favorites.contains(productId);
  }

  Future<void> toggle(String productId) async {
    final markFavorite = !isFavorite(productId);
    await setFavorite(productId, markFavorite);
  }

  Future<void> setFavorite(String productId, bool markFavorite) async {
    await ensureInitialized();
    final changed = markFavorite
        ? _favorites.add(productId)
        : _favorites.remove(productId);
    if (!changed) return;
    await _prefs!.setStringList(
      _storageKey,
      _sortedFavorites(),
    );
    notifyListeners();
  }

  List<String> _sortedFavorites() {
    final ids = _favorites.toList();
    ids.sort();
    return ids;
  }
}
