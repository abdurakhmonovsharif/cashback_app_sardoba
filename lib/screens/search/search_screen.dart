import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/branch.dart';
import '../../models/catalog.dart';
import '../../services/branch_state.dart';
import '../../services/catalog_repository.dart';
import '../catalog/product_details_screen.dart';
import '../catalog/product_detail_pressable.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final CatalogRepository _catalogRepository = CatalogRepository.instance;
  final BranchState _branchState = BranchState.instance;
  final TextEditingController _controller = TextEditingController();

  List<CatalogCategory> _categories = const [];
  List<_SearchResult> _results = const [];
  Branch? _activeBranch;
  bool _isCatalogLoading = true;
  bool _isSearching = false;
  String? _catalogError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _activeBranch = _branchState.activeBranch;
    _branchState.addListener(_handleBranchChange);
    _loadCatalog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _branchState.removeListener(_handleBranchChange);
    super.dispose();
  }

  void _handleBranchChange() {
    final branch = _branchState.activeBranch;
    if (!mounted || branch.id == _activeBranch?.id) return;
    setState(() => _activeBranch = branch);
    if (_controller.text.trim().isNotEmpty) {
      _performSearch();
    }
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isCatalogLoading = true;
      _catalogError = null;
    });
    try {
      final payload = await _catalogRepository.loadCatalog();
      if (!mounted) return;
      setState(() {
        _categories = payload.categories;
        _isCatalogLoading = false;
      });
      if (_controller.text.trim().isNotEmpty) _performSearch();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _catalogError = error.toString();
        _isCatalogLoading = false;
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 250), _performSearch);
  }

  void _performSearch() {
    if (!mounted) return;
    _debounce?.cancel();
    if (_isCatalogLoading) return;
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _isSearching = false;
      });
      return;
    }

    final normalizedQueries = _queryForms(query);
    final matches = <_SearchResult>[];

    for (final category in _categories) {
      for (final item in category.items) {
        final name = item.name.toLowerCase();
        final matched = normalizedQueries.any(
          (needle) => needle.isNotEmpty && name.contains(needle),
        );
        if (matched) {
          matches.add(_SearchResult(category: category, item: item));
        }
      }
    }

    setState(() {
      _results = matches;
      _isSearching = false;
    });
  }

  void _clearSearch() {
    _controller.clear();
    _onQueryChanged('');
  }

  List<String> _queryForms(String raw) {
    final lower = raw.toLowerCase();
    final forms = <String>{
      lower,
      _latinToCyrillic(lower),
      _cyrillicToLatin(lower),
    };
    return forms.where((value) => value.trim().isNotEmpty).toList();
  }

  String _latinToCyrillic(String input) {
    const apostrophes = ["'", "’", "ʼ", "`"];
    final text = input.toLowerCase();
    final buffer = StringBuffer();

    var index = 0;
    while (index < text.length) {
      final current = text[index];
      final hasNext = index + 1 < text.length;
      final next = hasNext ? text[index + 1] : '';
      final pair = hasNext ? text.substring(index, index + 2) : '';

      if (pair == 'sh') {
        buffer.write('ш');
        index += 2;
        continue;
      }
      if (pair == 'ch') {
        buffer.write('ч');
        index += 2;
        continue;
      }
      if (current == 'g' && hasNext && apostrophes.contains(next)) {
        buffer.write('ғ');
        index += 2;
        continue;
      }
      if (current == 'o' && hasNext && apostrophes.contains(next)) {
        buffer.write('ў');
        index += 2;
        continue;
      }
      if (pair == 'yo') {
        buffer.write('ё');
        index += 2;
        continue;
      }
      if (pair == 'yu') {
        buffer.write('ю');
        index += 2;
        continue;
      }
      if (pair == 'ye') {
        buffer.write('е');
        index += 2;
        continue;
      }
      if (pair == 'ya') {
        buffer.write('я');
        index += 2;
        continue;
      }
      if (pair == 'ts') {
        buffer.write('ц');
        index += 2;
        continue;
      }
      if (pair == 'ng') {
        buffer.write('нг');
        index += 2;
        continue;
      }

      switch (current) {
        case 'a':
          buffer.write('а');
          break;
        case 'b':
          buffer.write('б');
          break;
        case 'c':
          buffer.write('к');
          break;
        case 'd':
          buffer.write('д');
          break;
        case 'e':
          buffer.write('е');
          break;
        case 'f':
          buffer.write('ф');
          break;
        case 'g':
          buffer.write('г');
          break;
        case 'h':
          buffer.write('ҳ');
          break;
        case 'i':
          buffer.write('и');
          break;
        case 'j':
          buffer.write('ж');
          break;
        case 'k':
          buffer.write('к');
          break;
        case 'l':
          buffer.write('л');
          break;
        case 'm':
          buffer.write('м');
          break;
        case 'n':
          buffer.write('н');
          break;
        case 'o':
          buffer.write('о');
          break;
        case 'p':
          buffer.write('п');
          break;
        case 'q':
          buffer.write('қ');
          break;
        case 'r':
          buffer.write('р');
          break;
        case 's':
          buffer.write('с');
          break;
        case 't':
          buffer.write('т');
          break;
        case 'u':
          buffer.write('у');
          break;
        case 'v':
          buffer.write('в');
          break;
        case 'x':
          buffer.write('х');
          break;
        case 'y':
          buffer.write('й');
          break;
        case 'z':
          buffer.write('з');
          break;
        default:
          buffer.write(current);
      }
      index++;
    }

    return buffer.toString();
  }

  String _cyrillicToLatin(String input) {
    const map = {
      'ш': 'sh',
      'ч': 'ch',
      'ё': 'yo',
      'ю': 'yu',
      'я': 'ya',
      'ц': 'ts',
      'ң': 'ng',
      'ғ': "g'",
      'ў': "o'",
      'қ': 'q',
      'ҳ': 'h',
      'й': 'y',
      'ж': 'j',
      'а': 'a',
      'б': 'b',
      'в': 'v',
      'г': 'g',
      'д': 'd',
      'е': 'e',
      'з': 'z',
      'и': 'i',
      'к': 'k',
      'л': 'l',
      'м': 'm',
      'н': 'n',
      'о': 'o',
      'п': 'p',
      'р': 'r',
      'с': 's',
      'т': 't',
      'у': 'u',
      'ф': 'f',
      'х': 'x',
      'ъ': '',
      'ь': '',
      'э': 'e',
      'ы': 'i',
    };

    final buffer = StringBuffer();
    for (final char in input.runes) {
      final ch = String.fromCharCode(char);
      final lower = ch.toLowerCase();
      buffer.write(map[lower] ?? ch);
    }
    return buffer.toString();
  }

  CatalogPrice? _priceForActiveBranch(CatalogItem item) {
    final storeId = _activeBranch?.storeId;
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
    if (price == null) {
      return _PriceInfo(
        label: l10n.catalogUnavailableInBranch,
        color: bodyTextColor,
        hasPrice: false,
      );
    }
    if (price.disabled) {
      return _PriceInfo(
        label: l10n.catalogTemporarilyDisabled,
        color: accentColor,
        hasPrice: false,
      );
    }
    return _PriceInfo(
      label: _formatPrice(price.price, isRu),
      color: titleColor,
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

  void _openProductDetails(_SearchResult result) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CatalogProductDetailsScreen(
          category: result.category,
          initialItem: result.item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchAction),
        centerTitle: true,
      ),
      backgroundColor: screenBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(defaultPadding, 12, defaultPadding, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _performSearch(),
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: defaultPadding,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: const BorderSide(color: appBorderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: const BorderSide(color: appBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide:
                        const BorderSide(color: primaryColor, width: 1.5),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: bodyTextColor,
                  ),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearSearch,
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: defaultPadding),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _ResultsPanel(
                    query: _controller.text,
                    l10n: l10n,
                    isCatalogLoading: _isCatalogLoading,
                    isSearching: _isSearching,
                    error: _catalogError,
                    results: _results,
                    resolvePriceInfo: (item) => _resolvePriceInfo(item, l10n),
                    onRetry: _loadCatalog,
                    onSelect: _openProductDetails,
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

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({
    required this.query,
    required this.l10n,
    required this.isCatalogLoading,
    required this.isSearching,
    required this.error,
    required this.results,
    required this.resolvePriceInfo,
    required this.onRetry,
    required this.onSelect,
  });

  final String query;
  final AppStrings l10n;
  final bool isCatalogLoading;
  final bool isSearching;
  final String? error;
  final List<_SearchResult> results;
  final _PriceInfo Function(CatalogItem item) resolvePriceInfo;
  final VoidCallback onRetry;
  final void Function(_SearchResult result) onSelect;

  @override
  Widget build(BuildContext context) {
    if (isCatalogLoading) {
      return _LoadingState(label: l10n.commonLoading);
    }
    if (error != null) {
      return _ErrorState(
        message: l10n.catalogLoadError,
        retryLabel: l10n.catalogRetry,
        onRetry: onRetry,
      );
    }
    if (isSearching) {
      return _LoadingState(label: l10n.searchLoading);
    }
    if (query.trim().isEmpty) {
      return _EmptyResults(
        icon: Icons.search_rounded,
        label: l10n.searchStartTitle,
        subtitle: l10n.searchStartSubtitle,
      );
    }
    if (results.isEmpty) {
      return _EmptyResults(
        icon: Icons.search_off_rounded,
        label: l10n.searchNoResultsTitle,
        subtitle: l10n.searchNoResultsSubtitle,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desiredHeight = SearchTokens.resultHeaderHeight +
            results.length * SearchTokens.resultRowMinHeight;
        final panelHeight = math.min(
          constraints.maxHeight,
          math.min(SearchTokens.resultPanelMaxHeight, desiredHeight),
        );
        return Container(
          width: double.infinity,
          height: panelHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: appBorderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    defaultPadding,
                    defaultPadding,
                    defaultPadding,
                    AppSpacing.related,
                  ),
                  child: Text(
                    l10n.searchResultCount(results.length),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: bodyTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: appBorderColor,
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.related,
                    ),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      final priceInfo = resolvePriceInfo(result.item);
                      return _SearchResultCard(
                        result: result,
                        priceInfo: priceInfo,
                        onTap: () => onSelect(result),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 1,
                      indent: SearchTokens.resultThumbSize + 24,
                      endIndent: defaultPadding,
                      color: appBorderColor,
                    ),
                    itemCount: results.length,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.priceInfo,
    required this.onTap,
  });

  final _SearchResult result;
  final _PriceInfo priceInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        result.item.images.isNotEmpty ? result.item.images.first : null;

    return ProductDetailPressable(
      label: '${result.item.name}, ${result.category.name}, ${priceInfo.label}',
      onPressed: onTap,
      child: ColoredBox(
        color: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: SearchTokens.resultRowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: defaultPadding,
              vertical: AppSpacing.related,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProductThumb(imageUrl: imageUrl),
                const SizedBox(width: AppSpacing.related),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.item.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.category.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: bodyTextColor,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.related),
                      Text(
                        priceInfo.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: priceInfo.color,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.related),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: bodyTextColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SearchTokens.resultThumbSize,
      height: SearchTokens.resultThumbSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        color: screenBackgroundColor,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) =>
                    const _ThumbPlaceholder(icon: Icons.broken_image_outlined),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _ThumbPlaceholder(icon: Icons.hourglass_empty);
                },
              )
            : const _ThumbPlaceholder(icon: Icons.fastfood_outlined),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: screenBackgroundColor,
      alignment: Alignment.center,
      child: ExcludeSemantics(child: Icon(icon, color: bodyTextColor)),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.related),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                    fontWeight: FontWeight.w600,
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

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - defaultPadding * 2),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: screenBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: primaryColor, size: 28),
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.related),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: bodyTextColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.cloud_off_outlined,
                  color: bodyTextColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.related),
              Text(
                message,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.related),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceInfo {
  const _PriceInfo({
    required this.label,
    required this.color,
    required this.hasPrice,
  });

  final String label;
  final Color color;
  final bool hasPrice;
}

class _SearchResult {
  const _SearchResult({
    required this.category,
    required this.item,
  });

  final CatalogCategory category;
  final CatalogItem item;
}
