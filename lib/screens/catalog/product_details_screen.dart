import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../components/inline_price_text.dart';
import '../../constants.dart';
import '../../models/branch.dart';
import '../../models/catalog.dart';
import '../../services/branch_state.dart';
import '../../services/favorite_products.dart';
import 'product_detail_images.dart';
import 'product_detail_pressable.dart';

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
        compactLabel: l10n.catalogUnavailableInBranchCompact,
      );
    }
    if (price.disabled) {
      final label = l10n.catalogTemporarilyDisabled;
      return _PriceInfo(
        label,
        accentColor,
        hasPrice: false,
        compactLabel: l10n.catalogTemporarilyDisabledCompact,
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
    final suffix = isRu ? 'сум' : "so'm";
    return '$formatted $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final priceInfo = _resolvePriceInfo(_activeItem, l10n);
    final relatedItems = widget.category.items
        .where((item) => item.id != _activeItem.id)
        .where((item) => _priceForActiveBranch(item) != null)
        .toList();
    final favorite = _favorites.isFavorite(_activeItem.id);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontSize: ProductDetailTokens.titleSize,
      height: 1.3,
      color: titleColor,
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      appBar: AppBar(
        backgroundColor: screenBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: ProductDetailPressable(
          key: const ValueKey('product-back'),
          label: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: titleColor, size: 22),
        ),
        title: Text(widget.category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w600,
            )),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('product-detail-scroll'),
          padding: const EdgeInsets.fromLTRB(defaultPadding, AppSpacing.related,
              defaultPadding, defaultPadding + AppSpacing.related),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductHeroImage(images: _activeItem.images),
              const SizedBox(height: AppSpacing.section),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(_activeItem.name,
                          key: const ValueKey('product-title'),
                          style: titleStyle),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.related),
                  _FavoriteButton(
                    key: const ValueKey('product-favorite'),
                    isFavorite: favorite,
                    label: favorite
                        ? l10n.catalogFavoriteRemove(_activeItem.name)
                        : l10n.catalogFavoriteAdd(_activeItem.name),
                    onPressed: _favoritesInitialized
                        ? () => _favorites.toggle(_activeItem.id)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.related),
              if (priceInfo.hasPrice)
                InlinePriceText(
                  key: const ValueKey('product-price'),
                  label: priceInfo.label,
                  hasPrice: true,
                  currencyFontSize: ProductDetailTokens.currencySize,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: ProductDetailTokens.priceSize,
                    height: 1.25,
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                _UnavailableProductStatus(
                  label: priceInfo.label,
                  semanticLabel: priceInfo.label,
                ),
              const SizedBox(height: AppSpacing.related),
              Text(_activeBranch.name,
                  key: const ValueKey('product-branch'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                    height: 1.4,
                  )),
              if (relatedItems.isNotEmpty) ...[
                const SizedBox(height: ProductDetailTokens.sectionGap),
                const Divider(height: 1, color: appBorderColor),
                const SizedBox(height: ProductDetailTokens.sectionGap),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.catalogRelatedProducts(widget.category.name),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                SizedBox(
                  height: _RelatedProductCard.heightFor(context),
                  child: ListView.separated(
                    key: const ValueKey('product-recommendations'),
                    scrollDirection: Axis.horizontal,
                    itemCount: relatedItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.section),
                    itemBuilder: (context, index) {
                      final item = relatedItems[index];
                      final isFavorite = _favorites.isFavorite(item.id);
                      return _RelatedProductCard(
                        item: item,
                        priceInfo: _resolvePriceInfo(item, l10n),
                        isFavorite: isFavorite,
                        favoriteTooltip: isFavorite
                            ? l10n.catalogFavoriteRemove(item.name)
                            : l10n.catalogFavoriteAdd(item.name),
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
  const _ProductHeroImage({required this.images});
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AspectRatio(
        key: const ValueKey('product-hero'),
        aspectRatio: 1,
        child: _ProductImage(
          image: ProductDetailImages.original(images),
          hero: true,
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.image, this.fallback, this.hero = false});
  final String? image;
  final String? fallback;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    if (image == null) return const _ImageFallback();
    return CachedNetworkImage(
      imageUrl: image!,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      // Preserve the original's detail in the hero; bound small-card decoding.
      memCacheWidth: hero ? null : ProductDetailTokens.cardDecodeWidth,
      placeholder: (context, url) => hero
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : const _ImageFallback(),
      errorWidget: (context, url, error) =>
          fallback != null && fallback != image
              ? _ProductImage(image: fallback)
              : const _ImageFallback(),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: screenBackgroundColor,
        child:
            Center(child: Icon(Icons.fastfood_outlined, color: bodyTextColor)),
      );
}

class _RelatedProductCard extends StatelessWidget {
  const _RelatedProductCard({
    required this.item,
    required this.priceInfo,
    required this.isFavorite,
    required this.favoriteTooltip,
    required this.onFavorite,
    required this.onTap,
  });

  final CatalogItem item;
  final _PriceInfo priceInfo;
  final bool isFavorite;
  final String favoriteTooltip;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  static double widthFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final scaledWidth = ProductDetailTokens.cardWidth *
        scaler.scale(ProductDetailTokens.cardTitleSize) /
        ProductDetailTokens.cardTitleSize;
    final available = MediaQuery.sizeOf(context).width - defaultPadding * 2;
    if (available <= ProductDetailTokens.cardWidth) return available;
    return scaledWidth.clamp(ProductDetailTokens.cardWidth, available);
  }

  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleHeight =
        scaler.scale(ProductDetailTokens.cardTitleSize) * 1.3 * 2;
    final priceHeight =
        scaler.scale(ProductDetailTokens.cardPriceSize) * 1.3 * 2;
    return widthFor(context) / ProductDetailTokens.cardAspectRatio +
        AppSpacing.section * 2 +
        titleHeight +
        AppSpacing.related +
        (priceHeight > ProductDetailTokens.touchTarget
            ? priceHeight
            : ProductDetailTokens.touchTarget);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleHeight = MediaQuery.textScalerOf(context)
            .scale(ProductDetailTokens.cardTitleSize) *
        1.3 *
        2;
    final original = ProductDetailImages.original(item.images);
    return ProductDetailPressable(
      key: ValueKey('related-open-${item.id}'),
      label: '${item.name}, ${priceInfo.label}',
      preserveChildSemantics: true,
      onPressed: onTap,
      child: SizedBox(
        width: widthFor(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ProductDetailTokens.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.card)),
                      child: AspectRatio(
                        aspectRatio: ProductDetailTokens.cardAspectRatio,
                        child: _ProductImage(
                          image:
                              ProductDetailImages.recommendation(item.images),
                          fallback: original,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.section,
                          AppSpacing.section, AppSpacing.section, 0),
                      child: SizedBox(
                        height: titleHeight,
                        child: Text(item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: ProductDetailTokens.cardTitleSize,
                              height: 1.3,
                              color: titleColor,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.related),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.section, 0, 0, AppSpacing.section),
                  child: Row(
                    children: [
                      Expanded(
                        child: ExcludeSemantics(
                          child: priceInfo.hasPrice
                              ? InlinePriceText(
                                  label: priceInfo.label,
                                  hasPrice: true,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: ProductDetailTokens.cardPriceSize,
                                    height: 1.3,
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : _UnavailableProductStatus(
                                  label:
                                      priceInfo.compactLabel ?? priceInfo.label,
                                  semanticLabel: priceInfo.label,
                                  compact: true,
                                ),
                        ),
                      ),
                      _FavoriteButton(
                        key: ValueKey('related-favorite-${item.id}'),
                        isFavorite: isFavorite,
                        label: favoriteTooltip,
                        onPressed: onFavorite,
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

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton(
      {super.key,
      required this.isFavorite,
      required this.label,
      required this.onPressed});
  final bool isFavorite;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: ProductDetailPressable(
          label: label,
          selected: isFavorite,
          onPressed: onPressed,
          child: SizedBox.square(
            dimension: ProductDetailTokens.touchTarget,
            child: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? primaryColor : bodyTextColor),
          ),
        ),
      );
}

class _UnavailableProductStatus extends StatelessWidget {
  const _UnavailableProductStatus(
      {required this.label, required this.semanticLabel, this.compact = false});
  final String label;
  final String semanticLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: Text(
          label,
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: (compact
                  ? Theme.of(context).textTheme.bodySmall
                  : Theme.of(context).textTheme.bodyMedium)
              ?.copyWith(
                  color: bodyTextColor,
                  fontWeight: FontWeight.w500,
                  height: 1.3),
        ),
      );
}

class _PriceInfo {
  const _PriceInfo(this.label, this.color,
      {required this.hasPrice, this.compactLabel});
  final String label;
  final Color color;
  final bool hasPrice;
  final String? compactLabel;
}
