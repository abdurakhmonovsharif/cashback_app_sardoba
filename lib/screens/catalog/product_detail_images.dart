/// Selects the API's image renditions without depending on array ordering.
abstract final class ProductDetailImages {
  static final _variant = RegExp(
    r'-(44x44|88x88|254x196|376x276|508x392|752x552|500x250)x100\.webp$',
    caseSensitive: false,
  );
  static final _card = RegExp(r'-508x392x100\.webp$', caseSensitive: false);
  static final _image = RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false);

  static Uri? _valid(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty &&
            _image.hasMatch(uri.path)
        ? uri
        : null;
  }

  static String? original(List<String> images) {
    for (final image in images) {
      final uri = _valid(image);
      if (uri != null && !_variant.hasMatch(uri.path)) return image;
    }
    return null;
  }

  static String? recommendation(List<String> images) {
    for (final image in images) {
      final uri = _valid(image);
      if (uri != null && _card.hasMatch(uri.path)) return image;
    }
    return original(images);
  }
}
