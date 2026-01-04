import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../constants.dart';
import '../../components/branch_picker_sheet.dart';
import '../../models/branch.dart';
import '../../models/catalog.dart';
import '../../services/branch_state.dart';
import '../../services/catalog_repository.dart';
import '../../services/favorite_products.dart';
import 'product_details_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

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
  int _activeCategoryIndex = 0;
  late Branch _activeBranch;

  @override
  void initState() {
    super.initState();
    _activeBranch = _branchState.activeBranch;
    _branchState.addListener(_handleBranchChange);
    _favorites.addListener(_handleFavoritesChanged);
    _initializeFavorites();
    _loadCachedCatalog();
    _loadCatalog();
  }

  @override
  void dispose() {
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
        if (_categories.isEmpty) {
          _activeCategoryIndex = 0;
        } else if (_activeCategoryIndex >= _categories.length) {
          _activeCategoryIndex = 0;
        }
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

  Future<void> _openBranchPicker() async {
    await showBranchPickerSheet(context);
  }

  CatalogCategory? get _activeCategory {
    if (_categories.isEmpty) return null;
    final index = _activeCategoryIndex.clamp(0, _categories.length - 1);
    return _categories[index];
  }

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
      _CatalogHeader(title: l10n.catalogTitle),
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
          activeIndex: _activeCategoryIndex,
          onChanged: (index) {
            if (index == _activeCategoryIndex) return;
            setState(() => _activeCategoryIndex = index);
          },
        ),
      );
      children.add(const SizedBox(height: 20));

      final category = _activeCategory;
      if (category == null || category.items.isEmpty) {
        children.add(_EmptyState(message: l10n.catalogEmpty));
      } else {
        final productWidgets = <Widget>[];
        for (final item in category.items) {
          final branchPrice = _priceForActiveBranch(item);
          if (branchPrice == null) {
            continue;
          }
          final hasPrice = !branchPrice.disabled;
          final primaryText = hasPrice
              ? _formatPrice(branchPrice.price, isRu)
              : "-";
          final priceColor = hasPrice ? titleColor : accentColor;

          productWidgets.add(
            _CatalogProductCard(
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
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _loadCatalog(forceRefresh: true),
          color: primaryColor,
          child: ListView(
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
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
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
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
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
              if (onTap != null) ...[
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: primaryColor,
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

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<CatalogCategory> categories;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = index == activeIndex;
          final thumbnail = _findThumbnail(category);
          return ChoiceChip(
            avatar: _CategoryThumbnail(
              imageUrl: thumbnail,
              isActive: isActive,
            ),
            label: Text(category.name),
            selected: isActive,
            onSelected: (_) => onChanged(index),
            backgroundColor: Colors.white,
            selectedColor: primaryColor,
            labelStyle: TextStyle(
              color: isActive ? Colors.white : titleColor,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: isActive
                  ? primaryColor
                  : Colors.black.withValues(alpha: 0.05),
            ),
            labelPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: EdgeInsets.zero,
            showCheckmark: false,
          );
        },
      ),
    );
  }

  String? _findThumbnail(CatalogCategory category) {
    final thumb = category.thumbnail;
    if (thumb != null && thumb.isNotEmpty) return thumb;
    for (final item in category.items) {
      if (item.images.isNotEmpty) {
        return item.images.first;
      }
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFAFBFF),
                Color(0xFFF4F2FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D6BE0).withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 20),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProductImageBubble(
                imageUrl:
                    item.images.isNotEmpty ? item.images.first : null,
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
                        color: const Color(0xFF142033),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasPrice ? 'Mavjud' : 'Vaqtincha mavjud emas',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasPrice
                            ? bodyTextColor.withValues(alpha: 0.5)
                            : accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      priceLabel,
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
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF7F3FF),
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
        borderRadius: BorderRadius.circular(22),
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
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
            size: 24,
            color: isFavorite ? primaryColor : const Color(0xFF7C84B2),
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
        borderRadius: BorderRadius.circular(24),
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
        borderRadius: BorderRadius.circular(22),
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
        borderRadius: BorderRadius.circular(22),
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
