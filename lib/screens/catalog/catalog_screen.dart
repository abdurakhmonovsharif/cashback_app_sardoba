import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../constants.dart';
import '../../utils/responsive_layout.dart';
import '../../components/branch_picker_sheet.dart';
import '../../components/inline_price_text.dart';
import '../../models/branch.dart';
import '../../models/catalog.dart';
import '../../services/branch_state.dart';
import '../../services/catalog_repository.dart';
import '../../services/favorite_products.dart';
import 'product_details_screen.dart';
import '../search/search_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, this.initialCategoryId});

  /// Null opens the first available category; IDs remain stable across catalog order.
  final String? initialCategoryId;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final CatalogRepository _catalogRepository = CatalogRepository.instance;
  final BranchState _branchState = BranchState.instance;
  final FavoriteProducts _favorites = FavoriteProducts.instance;

  bool _isLoading = true;
  String? _errorMessage;
  List<CatalogCategory> _categories = const [];
  String? _activeCategoryId;
  final ScrollController _productsScrollController = ScrollController();
  late Branch _activeBranch;

  @override
  void initState() {
    super.initState();
    _activeCategoryId = widget.initialCategoryId;
    _activeBranch = _branchState.activeBranch;
    _branchState.addListener(_handleBranchChange);
    _favorites.addListener(_handleFavoritesChanged);
    _initializeFavorites();
    _loadCachedCatalog();
    _loadCatalog();
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategoryId != widget.initialCategoryId) {
      _activeCategoryId = widget.initialCategoryId;
      if (_productsScrollController.hasClients) {
        _productsScrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _productsScrollController.dispose();
    _branchState.removeListener(_handleBranchChange);
    _favorites.removeListener(_handleFavoritesChanged);
    super.dispose();
  }

  Future<void> _initializeFavorites() async {
    await _favorites.ensureInitialized();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadCachedCatalog() async {
    final cached = await _catalogRepository.getCachedCatalog();
    if (!mounted || cached == null) return;
    setState(() {
      _categories = cached.categories;
      _isLoading = false;
    });
  }

  Future<void> _loadCatalog({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (_categories.isEmpty || forceRefresh) {
        _isLoading = true;
      }
      _errorMessage = null;
    });
    try {
      final payload = await _catalogRepository.loadCatalog(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _categories = payload.categories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _handleBranchChange() {
    final branch = _branchState.activeBranch;
    if (!mounted || branch.id == _activeBranch.id) return;
    setState(() => _activeBranch = branch);
  }

  void _handleFavoritesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _openProductDetails({
    required CatalogCategory category,
    required CatalogItem item,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CatalogProductDetailsScreen(
          category: category,
          initialItem: item,
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  Future<void> _openBranchPicker() async {
    await showBranchPickerSheet(context);
  }

  CatalogCategory? get _activeCategory {
    final categoryId = _selectedCategoryId;
    for (final category in _categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  String? get _selectedCategoryId =>
      _activeCategoryId ?? (_categories.isEmpty ? null : _categories.first.id);

  CatalogPrice? _priceForActiveBranch(CatalogItem item) {
    final storeId = _activeBranch.storeId;
    if (storeId == null) return null;
    for (final price in item.prices) {
      if (price.storeId == storeId) return price;
    }
    return null;
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
    final isRu = l10n.locale == AppLocale.ru;
    final double bottomPadding = navAwareBottomPadding(context, extra: 24);

    final children = <Widget>[
      _CatalogHeader(
        title: _activeCategory?.name ?? l10n.catalogTitle,
        searchLabel: l10n.searchAction,
        onSearchTap: _openSearch,
      ),
      const SizedBox(height: 16),
      _BranchInfoCard(
        label: l10n.catalogBranchLabel,
        branch: _activeBranch,
        onTap: _openBranchPicker,
      ),
      const SizedBox(height: 20),
    ];

    if (_isLoading && _categories.isEmpty) {
      children.add(
        const SizedBox(
          height: 260,
          child: Center(
            child: CircularProgressIndicator(color: primaryColor),
          ),
        ),
      );
    } else if (_errorMessage != null) {
      children.add(
        _ErrorState(
          message: l10n.catalogLoadError,
          details: _errorMessage ?? '',
          onRetry: () => _loadCatalog(forceRefresh: true),
          retryLabel: l10n.catalogRetry,
        ),
      );
    } else if (_categories.isEmpty) {
      children.add(
        _EmptyState(message: l10n.catalogEmpty),
      );
    } else {
      children.add(
        _CategorySelector(
          categories: _categories,
          activeCategoryId: _selectedCategoryId,
          onChanged: (categoryId) {
            if (categoryId == _selectedCategoryId) return;
            setState(() => _activeCategoryId = categoryId);
          },
        ),
      );
      children.add(const SizedBox(height: 20));

      final selectedCategoryId = _selectedCategoryId;
      final selectedCategories = selectedCategoryId == null
          ? const <CatalogCategory>[]
          : _categories.where((category) => category.id == selectedCategoryId);
      if (selectedCategories.every((category) => category.items.isEmpty)) {
        children.add(_EmptyState(message: l10n.catalogEmpty));
      } else {
        final productWidgets = <Widget>[];
        for (final category in selectedCategories) {
          for (final item in category.items) {
            final branchPrice = _priceForActiveBranch(item);
            if (branchPrice == null) {
              continue;
            }
            final hasPrice = !branchPrice.disabled;
            final primaryText =
                hasPrice ? _formatPrice(branchPrice.price, isRu) : "-";
            final priceColor = hasPrice ? titleColor : bodyTextColor;

            productWidgets.add(
              _CatalogProductCard(
                key: ValueKey('catalog-product-${category.id}-${item.id}'),
                item: item,
                priceLabel: primaryText,
                priceColor: priceColor,
                hasPrice: hasPrice,
                isFavorite: _favorites.isFavorite(item.id),
                onToggleFavorite: () => _favorites.toggle(item.id),
                onTap: () => _openProductDetails(
                  category: category,
                  item: item,
                ),
              ),
            );
            productWidgets.add(const SizedBox(height: 14));
          }
        }

        if (productWidgets.isEmpty) {
          children.add(
            _EmptyState(message: l10n.catalogUnavailableInBranch),
          );
        } else {
          productWidgets.removeLast();
          children.addAll(productWidgets);
        }
      }
    }

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      body: ResponsiveViewport(
          child: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _loadCatalog(forceRefresh: true),
          color: primaryColor,
          child: ListView(
            controller: _productsScrollController,
            padding: EdgeInsets.fromLTRB(
              defaultPadding,
              20,
              defaultPadding,
              bottomPadding,
            ),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: children,
          ),
        ),
      )),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.title,
    required this.searchLabel,
    required this.onSearchTap,
  });

  final String title;
  final String searchLabel;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onSearchTap,
          tooltip: searchLabel,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            foregroundColor: primaryColor,
            backgroundColor: Colors.white,
            side: const BorderSide(color: appBorderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
          ),
          icon: const Icon(Icons.search_rounded, size: 22),
        ),
      ],
    );
  }
}

class _BranchInfoCard extends StatelessWidget {
  const _BranchInfoCard({
    required this.label,
    required this.branch,
    this.onTap,
  });

  final String label;
  final Branch branch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(right: onTap != null ? 36 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: bodyTextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            branch.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (branch.address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              branch.address,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: bodyTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: primaryColor,
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

class _CategorySelector extends StatefulWidget {
  const _CategorySelector({
    required this.categories,
    required this.activeCategoryId,
    required this.onChanged,
  });

  final List<CatalogCategory> categories;
  final String? activeCategoryId;
  final ValueChanged<String> onChanged;

  @override
  State<_CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<_CategorySelector> {
  final GlobalKey _activeChipKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealActiveChip();
  }

  @override
  void didUpdateWidget(covariant _CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeCategoryId != widget.activeCategoryId ||
        oldWidget.categories != widget.categories) {
      _revealActiveChip();
    }
  }

  void _revealActiveChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chipContext = _activeChipKey.currentContext;
      if (chipContext == null) return;
      // Reveal only the horizontal selector, not the outer product list.
      Scrollable.of(chipContext, axis: Axis.horizontal).position.ensureVisible(
            chipContext.findRenderObject()!,
            alignment: 0.5,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelHeight = MediaQuery.textScalerOf(context).scale(14) * 1.3;
    return SizedBox(
      height: (labelHeight + 32).clamp(52.0, double.infinity),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < widget.categories.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              _chip(context, widget.categories[index], colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(
      BuildContext context, CatalogCategory category, ColorScheme colors) {
    final isActive = category.id == widget.activeCategoryId;
    return ChoiceChip(
      key: isActive
          ? _activeChipKey
          : ValueKey('catalog-category-${category.id}'),
      avatar: _CategoryThumbnail(
        imageUrl: _findThumbnail(category),
        isActive: isActive,
      ),
      label: Text(category.name),
      selected: isActive,
      onSelected: (_) => widget.onChanged(category.id),
      backgroundColor: Colors.white,
      selectedColor: colors.primary,
      labelStyle: TextStyle(
        color: isActive ? colors.onPrimary : titleColor,
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: isActive ? colors.primary : Colors.black.withValues(alpha: 0.05),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: EdgeInsets.zero,
      showCheckmark: true,
      checkmarkColor: colors.onPrimary,
    );
  }

  String? _findThumbnail(CatalogCategory category) {
    final thumb = category.thumbnail;
    if (thumb != null && thumb.isNotEmpty) return thumb;
    for (final item in category.items) {
      if (item.images.isNotEmpty) return item.images.first;
    }
    return null;
  }
}

class _CategoryThumbnail extends StatelessWidget {
  const _CategoryThumbnail({
    required this.imageUrl,
    required this.isActive,
  });

  final String? imageUrl;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive ? Colors.white : Colors.transparent;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
              )
            : _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      color: screenBackgroundColor,
      alignment: Alignment.center,
      child: const Icon(
        Icons.fastfood_outlined,
        size: 20,
        color: bodyTextColor,
      ),
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({
    super.key,
    required this.item,
    required this.priceLabel,
    required this.priceColor,
    required this.hasPrice,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final CatalogItem item;
  final String priceLabel;
  final Color priceColor;
  final bool hasPrice;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cardColor = hasPrice ? Colors.white : const Color(0xFFF7F8FA);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: hasPrice ? 0.035 : 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: appBorderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: hasPrice ? 1 : 0.76,
                child: ProductImageBubble(
                  imageUrl: item.images.isNotEmpty ? item.images.first : null,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: hasPrice
                            ? const Color(0xFF142033)
                            : const Color(0xFF536174),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasPrice
                          ? l10n.catalogAvailableStatus
                          : l10n.catalogTemporarilyDisabled,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasPrice ? primaryColor : bodyTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InlinePriceText(
                      label: priceLabel,
                      hasPrice: hasPrice,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: priceColor,
                        fontWeight:
                            hasPrice ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _FavoriteButton(
                isFavorite: isFavorite,
                productName: item.name,
                onPressed: onToggleFavorite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductImageBubble extends StatelessWidget {
  const ProductImageBubble({super.key, required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF3F5F9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const _ImagePlaceholder.hasError(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _ImagePlaceholder.loading();
                },
              )
            : const _ImagePlaceholder.empty(),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.productName,
    required this.onPressed,
  });

  final bool isFavorite;
  final String productName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = isFavorite
        ? l10n.catalogFavoriteRemove(productName)
        : l10n.catalogFavoriteAdd(productName);
    return Semantics(
      button: true,
      toggled: isFavorite,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: 48,
          child: IconButton(
            onPressed: onPressed,
            style: IconButton.styleFrom(
              foregroundColor: isFavorite ? primaryColor : bodyTextColor,
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            icon: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder._(this.icon, this.color);

  const _ImagePlaceholder.empty()
      : this._(Icons.fastfood_outlined, bodyTextColor);
  const _ImagePlaceholder.loading()
      : this._(Icons.hourglass_empty_rounded, primaryColor);
  const _ImagePlaceholder.hasError()
      : this._(Icons.broken_image_outlined, bodyTextColor);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF5F7FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: bodyTextColor,
              fontWeight: FontWeight.w600,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.details,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final String details;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            details,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bodyTextColor,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              retryLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
