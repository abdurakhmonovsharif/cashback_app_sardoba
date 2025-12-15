class CatalogCategory {
  CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.items,
    this.thumbnail,
  });

  final String id;
  final String name;
  final String slug;
  final List<CatalogItem> items;
  final String? thumbnail;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogItem.fromJson)
        .toList();

    String? extractThumbnail() {
      const keys = ['thumbnail', 'image', 'icon', 'cover'];
      for (final key in keys) {
        final value = json[key];
        if (value is String) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        }
      }
      return null;
    }

    return CatalogCategory(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      items: items,
      thumbnail: extractThumbnail(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'items': items.map((item) => item.toJson()).toList(),
        if (thumbnail != null) 'thumbnail': thumbnail,
      };
}

class CatalogItem {
  CatalogItem({
    required this.id,
    required this.name,
    required this.prices,
    required this.images,
  });

  final String id;
  final String name;
  final List<CatalogPrice> prices;
  final List<String> images;

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    final prices = (json['prices'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogPrice.fromJson)
        .toList();

    final images = (json['images'] as List<dynamic>? ?? [])
        .map((image) => image?.toString() ?? '')
        .where((image) => image.isNotEmpty)
        .toList();

    return CatalogItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      prices: prices,
      images: images,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'prices': prices.map((price) => price.toJson()).toList(),
        'images': images,
      };
}

class CatalogPrice {
  CatalogPrice({
    required this.storeId,
    required this.storeName,
    required this.price,
    required this.disabled,
  });

  final int storeId;
  final String storeName;
  final double price;
  final bool disabled;

  factory CatalogPrice.fromJson(Map<String, dynamic> json) {
    return CatalogPrice(
      storeId: _parseStoreId(json['storeId']),
      storeName: (json['storeName'] ?? '').toString(),
      price: _parsePrice(json['price']),
      disabled: json['disabled'] == true,
    );
  }

  static int _parseStoreId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    return 0;
  }

  static double _parsePrice(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'storeId': storeId,
        'storeName': storeName,
        'price': price,
        'disabled': disabled,
      };
}

class CatalogPayload {
  const CatalogPayload({
    required this.success,
    required this.categories,
  });

  final bool success;
  final List<CatalogCategory> categories;

  factory CatalogPayload.fromJson(Map<String, dynamic> json) {
    final categories = (json['categories'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogCategory.fromJson)
        .toList();

    return CatalogPayload(
      success: json['success'] != false,
      categories: categories,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'categories': categories.map((category) => category.toJson()).toList(),
      };
}
