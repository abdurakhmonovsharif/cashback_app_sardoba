import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_location.dart';

class SavedLocationsService extends ChangeNotifier {
  SavedLocationsService._();

  static final SavedLocationsService instance = SavedLocationsService._();

  static const _storageKey = 'saved_locations';

  final List<SavedLocation> _locations = [];
  SharedPreferences? _prefs;
  bool _initialized = false;

  UnmodifiableListView<SavedLocation> get locations =>
      UnmodifiableListView(_locations);

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(raw) as List<dynamic>;
        _locations
          ..clear()
          ..addAll(decoded
              .whereType<Map<String, dynamic>>()
              .map(SavedLocation.fromJson));
      } catch (_) {
        _locations.clear();
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> addLocation(SavedLocation location) async {
    await ensureInitialized();
    _locations.add(location);
    await _persist();
    notifyListeners();
  }

  Future<void> updateLocation(SavedLocation location) async {
    await ensureInitialized();
    final index = _locations.indexWhere((item) => item.id == location.id);
    if (index == -1) return;
    _locations[index] = location;
    await _persist();
    notifyListeners();
  }

  Future<void> removeLocation(String id) async {
    await ensureInitialized();
    _locations.removeWhere((item) => item.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_prefs == null) return;
    final encoded = json.encode(_locations.map((e) => e.toJson()).toList());
    await _prefs!.setString(_storageKey, encoded);
  }
}
