import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/branch.dart';
import '../../models/catalog.dart';
import '../../services/branch_state.dart';
import '../../services/favorite_products.dart';

class CatalogProductDetailsScreen extends StatefulWidget {
  const CatalogProductDetailsScreen({
    required this.category,
    required this.initialItem,
    super.key,
  });

  final CatalogCategory category;
  final CatalogItem initialItem;

  @override
  State<CatalogProductDetailsScreen> createState() =>
      _CatalogProductDetailsScreenState();
}

class _CatalogProductDetailsScreenState
    extends State<CatalogProductDetailsScreen> {
  final BranchState _branchState = BranchState.instance;
  final FavoriteProducts _favorites = FavoriteProducts.instance;

  late CatalogItem _activeItem;
  late Branch _activeBranch;
  bool _favoritesInitialized = false;

  @override
  void initState() {
    super.initState();
    _activeItem = widget.initialItem;
    _activeBranch = _branchState.activeBranch;
    _branchState.addListener(_handleBranchChanged);
    _favorites.addListener(_handleFavoritesChanged);
    _initializeFavorites();
  }

  @override
  void dispose() {
    _branchState.removeListener(_handleBranchChanged);
    _favorites.removeListener(_handleFavoritesChanged);
    super.dispose();
  }

  Future<void> _initializeFavorites() async {
    await _favorites.ensureInitialized();
    if (!mounted) return;
    setState(() => _favoritesInitialized = true);
  }

  void _handleBranchChanged() {
    final branch = _branchState.activeBranch;
    if (!mounted || branch.id == _activeBranch.id) return;
    setState(() => _activeBranch = branch);
  }

  void _handleFavoritesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _selectItem(CatalogItem item) {
    if (_activeItem.id == item.id) return;
    setState(() {
      _activeItem = item;
    });
  }

  CatalogPrice? _priceForActiveBranch(CatalogItem item) {
    final storeId = _activeBranch.storeId;
    if (storeId == null) return null;
    for (final price in item.prices) {
      if (price.storeId == storeId) return price;
    }
    return null;
  }

  _PriceInfo _resolvePriceInfo(
    CatalogItem item,
    AppStrings l10n,
  ) {
    final price = _priceForActiveBranch(item);
    final isRu = l10n.locale == AppLocale.ru;
    final unavailableLabel = l10n.catalogUnavailableInBranch;

    if (price == null) {
      return _PriceInfo(
        unavailableLabel,
        bodyTextColor,
        hasPrice: false,
      );
    }
    if (price.disabled) {
      final label = l10n.catalogTemporarilyDisabled;
      return _PriceInfo(
        label,
        accentColor,
        hasPrice: false,
      );
    }

    final formatted = _formatPrice(price.price, isRu);
    return _PriceInfo(
      formatted,
      titleColor,
      hasPrice: true,
    );
  }

  String _formatPrice(double value, bool isRu) {
    final intValue = value.round();
    final reversedDigits = intValue.toString().split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < reversedDigits.length; i++) {
      if (i != 0 && i % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(reversedDigits[i]);
    }
    final formatted = buffer.toString().split('').reversed.join();
    final suffix = isRu ? 'сум' : 'soʻm';
    return '$formatted $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final priceInfo = _resolvePriceInfo(_activeItem, l10n);
    final images = _activeItem.images;
    final relatedItems = widget.category.items
        .where((item) => item.id != _activeItem.id)
        .where((item) => _priceForActiveBranch(item) != null)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5F9),
        elevation: 0,
        iconTheme: const IconThemeData(color: titleColor),
        title: Text(
          widget.category.name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            defaultPadding,
            12,
            defaultPadding,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductHeroImage(image: images.isNotEmpty ? images.first : null),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _activeItem.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _favoritesInitialized
                              ? () => _favorites.toggle(_activeItem.id)
                              : null,
                          icon: Icon(
                            _favorites.isFavorite(_activeItem.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                          color: _favorites.isFavorite(_activeItem.id)
                              ? primaryColor
                              : bodyTextColor,
                          splashRadius: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      priceInfo.label,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: priceInfo.color,
                        fontWeight: priceInfo.hasPrice
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    if (priceInfo.hasPrice) ...[
                      const SizedBox(height: 8),
                      Text(
                        _activeBranch.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: bodyTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (relatedItems.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  l10n.catalogRelatedProducts(widget.category.name),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: relatedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = relatedItems[index];
                      final info = _resolvePriceInfo(item, l10n);
                      return _RelatedProductCard(
                        item: item,
                        priceInfo: info,
                        isFavorite: _favorites.isFavorite(item.id),
                        onFavorite: () => _favorites.toggle(item.id),
                        onTap: () => _selectItem(item),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductHeroImage extends StatelessWidget {
  const _ProductHeroImage({this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: image != null
              ? Image.network(
                  image!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFFF6F8FC),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const _ImageFallback(),
                )
              : const _ImageFallback(),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FC),
      alignment: Alignment.center,
      child: const Icon(
        Icons.fastfood_outlined,
        size: 72,
        color: bodyTextColor,
      ),
    );
  }
}

class _RelatedProductCard extends StatelessWidget {
  const _RelatedProductCard({
    required this.item,
    required this.priceInfo,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });

  final CatalogItem item;
  final _PriceInfo priceInfo;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = item.images.isNotEmpty ? item.images.first : null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: image != null
                    ? CachedNetworkImage(
                        imageUrl: image,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const _RelatedImagePlaceholder(),
                        errorWidget: (context, url, error) =>
                            const _RelatedImagePlaceholder(),

                        // optional optimizations
                        memCacheHeight: 300,
                        memCacheWidth: 300,
                      )
                    : const _RelatedImagePlaceholder(),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              priceInfo.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: priceInfo.color,
                                fontWeight: priceInfo.hasPrice
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: onFavorite,
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                            ),
                            color: isFavorite ? primaryColor : bodyTextColor,
                            iconSize: 22,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelatedImagePlaceholder extends StatelessWidget {
  const _RelatedImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      color: const Color(0xFFF3F5F9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.fastfood_outlined,
        color: bodyTextColor,
      ),
    );
  }
}

class _PriceInfo {
  const _PriceInfo(
    this.label,
    this.color, {
    required this.hasPrice,
  });

  final String label;
  final Color color;
  final bool hasPrice;
}
