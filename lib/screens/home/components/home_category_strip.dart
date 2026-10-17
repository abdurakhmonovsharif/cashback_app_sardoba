import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/catalog.dart';

/// A scrollable category selector that keeps names readable at larger text sizes.
class HomeCategoryStrip extends StatelessWidget {
  const HomeCategoryStrip({
    super.key,
    required this.categories,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<CatalogCategory> categories;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  static double heightFor(BuildContext context) =>
      8 +
      64 +
      8 +
      (MediaQuery.textScalerOf(context).scale(14) * 1.3).ceilToDouble() * 2 +
      8;

  @override
  Widget build(BuildContext context) {
    final labelSize = MediaQuery.textScalerOf(context).scale(14);
    final itemWidth = (labelSize * 8).clamp(112.0, 224.0);

    return SizedBox(
      height: heightFor(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.section),
        itemBuilder: (context, index) {
          final category = categories[index];
          final label = category.name;
          final selected = index == activeIndex;
          final imageUrl = _categoryImageUrl(category);
          final color = selected ? primaryColor : titleColor;

          return Semantics(
            button: true,
            selected: selected,
            label: label,
            onTap: () => onChanged(index),
            excludeSemantics: true,
            child: Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: SizedBox(
                key: ValueKey('home-category-${category.id}'),
                width: itemWidth,
                child: Material(
                  color: selected ? const Color(0xFFEAF4ED) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    side: BorderSide(
                      color: selected ? primaryColor : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(index),
                    excludeFromSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox.square(
                            key: ValueKey('home-category-image-${category.id}'),
                            dimension: 64,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.control,
                                    ),
                                    child: imageUrl == null || imageUrl.isEmpty
                                        ? _CategoryImagePlaceholder(
                                            icon: _categoryIcon(category.slug),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            fit: BoxFit.contain,
                                            memCacheWidth: (64 *
                                                    MediaQuery
                                                        .devicePixelRatioOf(
                                                            context))
                                                .ceil(),
                                            placeholder: (_, __) =>
                                                _CategoryImagePlaceholder(
                                              icon:
                                                  _categoryIcon(category.slug),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                _CategoryImagePlaceholder(
                                              icon:
                                                  _categoryIcon(category.slug),
                                            ),
                                          ),
                                  ),
                                ),
                                if (selected)
                                  const Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(3),
                                        child: Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: (labelSize * 1.3).ceilToDouble() * 2,
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: color,
                                    fontSize: ProductDetailTokens.cardTitleSize,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                    height: 1.3,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String? _categoryImageUrl(CatalogCategory category) {
    if (category.items.length < 3) return null;
    final images = category.items[2].images;
    if (images.length < 3) return null;
    final thirdImage = images[2].trim();
    return thirdImage.isEmpty ? null : thirdImage;
  }

  static IconData _categoryIcon(String slug) {
    if (slug.startsWith('salat')) return Icons.eco_outlined;
    if (slug.startsWith('zakusk')) return Icons.tapas_outlined;
    if (slug.startsWith('pervye')) return Icons.soup_kitchen_outlined;
    if (slug.startsWith('vtorye')) return Icons.lunch_dining_outlined;
    return Icons.restaurant_outlined;
  }
}

class _CategoryImagePlaceholder extends StatelessWidget {
  const _CategoryImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEAF4ED),
      child: Center(
        child: Icon(
          icon,
          size: 30,
          color: primaryColor,
        ),
      ),
    );
  }
}
