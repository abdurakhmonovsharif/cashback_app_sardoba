import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../app_language.dart';

class Branch {
  Branch({
    required this.id,
    required this.name,
    required String address,
    Map<AppLocale, String>? localizedAddresses,
    required this.point,
    this.storeId,
    this.phone,
  })  : _fallbackAddress = address.trim(),
        addresses = _normalizeAddresses(localizedAddresses);

  final String id;
  final int? storeId;
  final String name;
  final String? phone;
  final Map<AppLocale, String> addresses;
  final Point point;
  final String _fallbackAddress;

  static Map<AppLocale, String> _normalizeAddresses(
    Map<AppLocale, String>? source,
  ) {
    if (source == null || source.isEmpty) {
      return const <AppLocale, String>{};
    }
    final filtered = <AppLocale, String>{};
    for (final entry in source.entries) {
      final text = entry.value.trim();
      if (text.isEmpty) continue;
      filtered.putIfAbsent(entry.key, () => text);
    }
    if (filtered.isEmpty) {
      return const <AppLocale, String>{};
    }
    return Map<AppLocale, String>.unmodifiable(filtered);
  }

  String addressForLocale(AppLocale locale) {
    final localized = addresses[locale]?.trim();
    if (localized != null && localized.isNotEmpty) {
      return localized;
    }

    final fallbackLocale =
        locale == AppLocale.ru ? AppLocale.uz : AppLocale.ru;
    final fallback = addresses[fallbackLocale]?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    if (_fallbackAddress.isNotEmpty) {
      return _fallbackAddress;
    }

    for (final value in addresses.values) {
      final candidate = value.trim();
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }

    return '';
  }

  String get address => addressForLocale(AppLanguage.instance.locale);

  String get addressRu =>
      addresses[AppLocale.ru] ?? _fallbackAddress;

  String get addressUz =>
      addresses[AppLocale.uz] ?? _fallbackAddress;

  factory Branch.fromJson(Map<String, dynamic> json) {
    final latitude = _readCoordinate(json, 'latitude', fallbackKeys: const [
      'lat',
      'Latitude',
      'Lat',
      'y',
    ]);
    final longitude = _readCoordinate(json, 'longitude', fallbackKeys: const [
      'lon',
      'lng',
      'Longitude',
      'Lng',
      'x',
    ]);

    if (latitude == null || longitude == null) {
      throw const FormatException(
        'Branch JSON is missing latitude/longitude coordinates.',
      );
    }

    final addresses = <AppLocale, String>{};

    AppLocale? parseLocaleKey(String key) {
      final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      switch (normalized) {
        case 'ru':
        case 'rus':
        case 'russian':
          return AppLocale.ru;
        case 'uz':
        case 'uzb':
        case 'uzbek':
          return AppLocale.uz;
      }
      return null;
    }

    void addAddress(AppLocale locale, dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return;
      addresses.putIfAbsent(locale, () => text);
    }

    final addressMap = json['addresses'];
    if (addressMap is Map) {
      addressMap.forEach((key, value) {
        if (key is! String) return;
        final locale = parseLocaleKey(key);
        if (locale != null) {
          addAddress(locale, value);
        }
      });
    }

    final baseAddress = (json['address'] ?? json['location'] ?? '').toString();
    addAddress(AppLocale.ru, json['address_ru'] ?? json['addressRu']);
    addAddress(AppLocale.uz, json['address_uz'] ?? json['addressUz']);

    return Branch(
      id: (json['id'] ?? json['branch_id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      address: baseAddress,
      storeId: _parseStoreId(json['storeId'] ?? json['store_id']),
      phone: json['phone']?.toString(),
      localizedAddresses: addresses.isEmpty ? null : addresses,
      point: Point(latitude: latitude, longitude: longitude),
    );
  }

  Map<String, dynamic> toJson() {
    final ruAddress = addressRu;
    final uzAddress = addressUz;

    return {
      'id': id,
      'name': name,
      'address': _fallbackAddress,
      'address_ru': ruAddress,
      'address_uz': uzAddress,
      'addresses': addresses.isEmpty
          ? null
          : {
              for (final entry in addresses.entries) entry.key.name: entry.value,
            },
      'latitude': point.latitude,
      'longitude': point.longitude,
      'storeId': storeId,
      'phone': phone,
    };
  }

  static int? _parseStoreId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _readCoordinate(
    Map<String, dynamic> json,
    String primaryKey, {
    required List<String> fallbackKeys,
  }) {
    double? parseValue(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    var value = parseValue(json[primaryKey]);
    if (value != null) return value;

    if (json['coordinates'] is Map) {
      final coords = json['coordinates'] as Map;
      value = parseValue(coords[primaryKey]);
      if (value != null) return value;
      for (final key in fallbackKeys) {
        value = parseValue(coords[key]);
        if (value != null) return value;
      }
    }

    for (final key in fallbackKeys) {
      value = parseValue(json[key]);
      if (value != null) return value;
    }

    return null;
  }
}
