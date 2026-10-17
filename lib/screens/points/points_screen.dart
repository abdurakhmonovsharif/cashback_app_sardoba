import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/account.dart';
import '../../models/points_entry.dart';
import '../../models/points_transaction_page.dart';
import '../../models/loyalty_summary.dart';
import '../../navigation/app_navigator.dart';
import '../../services/auth_service.dart';
import '../../services/auth_session_guard.dart';
import '../../services/auth_storage.dart';
import '../../services/points_service.dart';
import '../../utils/snackbar_utils.dart';
import '../catalog/product_detail_pressable.dart';
import 'wallet_calendar.dart';
import 'wallet_widgets.dart';

enum _TransactionDirection { all, credit, debit }

enum _TransactionPeriod { all, sevenDays, thirtyDays, custom }

class PointsScreen extends StatefulWidget {
  const PointsScreen({
    super.key,
    this.account,
    required this.threshold,
    this.initialBalance,
    this.initialEntries,
    this.initialLoyalty,
    this.pointsService,
  });

  final Account? account;
  final int threshold;
  final double? initialBalance;
  final List<PointsEntry>? initialEntries;
  final LoyaltySummary? initialLoyalty;
  final PointsService? pointsService;

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  late final PointsService _pointsService;
  late final bool _ownsPointsService;
  final AuthStorage _storage = AuthStorage.instance;
  final ScrollController _scrollController = ScrollController();

  Account? _account;
  LoyaltySummary? _loyalty;
  double _balance = 0;
  bool _isLoading = true;
  String? _errorMessage;
  List<PointsEntry> _entries = const [];
  PointsTransactionSummary _summary = const PointsTransactionSummary();
  _TransactionDirection _direction = _TransactionDirection.all;
  _TransactionPeriod _period = _TransactionPeriod.all;
  DateTimeRange? _customRange;
  String? _nextCursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _loadMoreFailed = false;
  int _requestGeneration = 0;
  (DateTime?, DateTime?) _activeDates = (null, null);

  @override
  void initState() {
    super.initState();
    _ownsPointsService = widget.pointsService == null;
    _pointsService = widget.pointsService ?? PointsService();
    _account = widget.account;
    _loyalty = widget.account?.loyalty ?? widget.initialLoyalty;
    _entries = widget.initialEntries ?? const [];
    _balance = widget.initialBalance ?? widget.account?.pointsBalance ?? 0.0;
    _isLoading = _entries.isEmpty;
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    if (_ownsPointsService) _pointsService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (!mounted) return;
    final generation = ++_requestGeneration;
    final dates = _selectedDates;
    _activeDates = dates;
    if (!refresh) {
      setState(() {
        _isLoading = _entries.isEmpty;
        _isLoadingMore = false;
        _loadMoreFailed = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }
    try {
      var account = _account ?? await _storage.getCurrentAccount();
      if (account == null) {
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          _account = null;
          _entries = const [];
          _loyalty = null;
          _balance = widget.initialBalance ?? 0;
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context).pointsLoginRequired;
        });
        return;
      }
      account = await _syncAccount(account);
      final resolvedAccount = account;
      if (resolvedAccount == null || resolvedAccount.id == null) {
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          _account = null;
          _entries = const [];
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context).pointsLoginRequired;
        });
        return;
      }

      if (!refresh &&
          _direction == _TransactionDirection.all &&
          _period == _TransactionPeriod.all &&
          (resolvedAccount.pointsHistory?.isNotEmpty ?? false) &&
          _entries.isEmpty) {
        if (!mounted || generation != _requestGeneration) return;
        setState(() {
          _account = resolvedAccount;
          _entries = resolvedAccount.pointsHistory!;
          _loyalty = resolvedAccount.loyalty ?? _loyalty;
          _balance = resolvedAccount.pointsBalance ?? _balance;
          _isLoading = false;
          _errorMessage = null;
        });
      }

      final history = await _fetchTransactionsWithRefresh(dates: dates);

      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _account = resolvedAccount;
        _entries = history.items;
        _loyalty = history.loyalty;
        _summary = history.summary;
        _nextCursor = history.nextCursor;
        _hasMore = history.hasMore;
        _loadMoreFailed = false;
        _balance = history.loyalty.pointsBalance ??
            resolvedAccount.pointsBalance ??
            (history.items.isNotEmpty
                ? history.items.first.balanceAfter
                : _balance);
        _isLoading = false;
        _errorMessage = null;
      });
    } on PointsUnauthorizedException {
      if (generation != _requestGeneration) return;
      await AppNavigator.forceLogout();
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context).pointsLoginRequired;
        _isLoading = false;
      });
      return;
    } on PointsServiceException catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<Account?> _syncAccount(Account? fallback) async {
    if (fallback == null) return null;
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      return fallback;
    }
    final tokenType = await _storage.getTokenType();
    final currentPhone = await _storage.getCurrentUser();
    final authService = AuthService();
    try {
      final profile = await authService.fetchProfileWithToken(
        accessToken: token,
        tokenType: tokenType,
        fallbackPhone: currentPhone,
        fallbackName: fallback.name,
      );
      if (profile != null) {
        await _storage.upsertAccount(profile.copyWith(isVerified: true));
        return profile;
      }
    } on AuthUnauthorizedException {
      if (await AuthSessionGuard.instance.logoutIfTokensMissing()) {
        return null;
      }
      final refreshed = await _storage.refreshTokens();
      if (!refreshed) {
        await AppNavigator.forceLogout();
        return null;
      }
      final newToken = await _storage.getAccessToken();
      final newType = await _storage.getTokenType();
      if (newToken == null || newToken.isEmpty) {
        await AppNavigator.forceLogout();
        return null;
      }
      try {
        final profile = await authService.fetchProfileWithToken(
          accessToken: newToken,
          tokenType: newType,
          fallbackPhone: currentPhone,
          fallbackName: fallback.name,
        );
        if (profile != null) {
          await _storage.upsertAccount(profile.copyWith(isVerified: true));
          return profile;
        }
      } on AuthUnauthorizedException {
        if (await AuthSessionGuard.instance.logoutIfTokensMissing()) {
          return null;
        }
        await AppNavigator.forceLogout();
        return null;
      }
    } catch (_) {
      // ignore sync errors
    } finally {
      authService.dispose();
    }
    return fallback;
  }

  Future<PointsTransactionPage> _fetchTransactionsWithRefresh(
      {String? cursor, required (DateTime?, DateTime?) dates}) async {
    try {
      final token = await _storage.getAccessToken();
      final tokenType = await _storage.getTokenType();
      return await _pointsService.fetchTransactions(
        direction: _direction.name,
        fromDate: dates.$1,
        toDate: dates.$2,
        cursor: cursor,
        accessToken: token,
        tokenType: tokenType,
      );
    } on PointsUnauthorizedException {
      if (await AuthSessionGuard.instance.logoutIfTokensMissing()) {
        throw const PointsUnauthorizedException('Unauthorized');
      }
      final refreshed = await _storage.refreshTokens();
      if (!refreshed) {
        await AppNavigator.forceLogout();
        throw const PointsUnauthorizedException('Unauthorized');
      }
      final token = await _storage.getAccessToken();
      final tokenType = await _storage.getTokenType();
      try {
        return await _pointsService.fetchTransactions(
          direction: _direction.name,
          fromDate: dates.$1,
          toDate: dates.$2,
          cursor: cursor,
          accessToken: token,
          tokenType: tokenType,
        );
      } on PointsUnauthorizedException {
        if (await AuthSessionGuard.instance.logoutIfTokensMissing()) {
          throw const PointsUnauthorizedException('Unauthorized');
        }
        await AppNavigator.forceLogout();
        throw const PointsUnauthorizedException('Unauthorized');
      }
    }
  }

  (DateTime?, DateTime?) get _selectedDates {
    final today = walletTashkentDate(DateTime.now());
    return switch (_period) {
      _TransactionPeriod.sevenDays => (
          DateTime(today.year, today.month, today.day - 6),
          today
        ),
      _TransactionPeriod.thirtyDays => (
          DateTime(today.year, today.month, today.day - 29),
          today
        ),
      _TransactionPeriod.custom => (_customRange?.start, _customRange?.end),
      _TransactionPeriod.all => (null, null),
    };
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 320) _loadMore();
  }

  Future<void> _loadMore({bool retry = false}) async {
    if (_isLoading ||
        _isLoadingMore ||
        (_loadMoreFailed && !retry) ||
        !_hasMore ||
        _nextCursor == null) {
      return;
    }
    final generation = _requestGeneration;
    setState(() {
      _isLoadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final page = await _fetchTransactionsWithRefresh(
          cursor: _nextCursor, dates: _activeDates);
      if (!mounted || generation != _requestGeneration) return;
      final known = _entries.map((entry) => entry.id).toSet();
      setState(() {
        _entries = [
          ..._entries,
          ...page.items.where((entry) => known.add(entry.id)),
        ];
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _summary = page.summary;
        _isLoadingMore = false;
      });
    } on PointsUnauthorizedException {
      await AppNavigator.forceLogout();
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreFailed = true;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  Future<void> _handleView(AppStrings l10n, bool canView) async {
    if (!canView) return;
    if (!mounted) return;
    showNavAwareSnackBar(
      context,
      content: Text(l10n.pointsUpdatedSuccess),
    );
  }

  void _selectDirection(_TransactionDirection value) {
    if (value == _direction) return;
    setState(() {
      _direction = value;
      _entries = const [];
      _isLoading = true;
      _isLoadingMore = false;
    });
    _loadData();
  }

  Future<void> _selectPeriod(_TransactionPeriod value) async {
    DateTimeRange? range = _customRange;
    if (value == _TransactionPeriod.custom) {
      final now = walletTashkentDate(DateTime.now());
      range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange: _customRange,
        helpText: AppLocalizations.of(context).pointsPeriodCustom,
        cancelText: AppLocalizations.of(context).commonCancel,
        saveText: AppLocalizations.of(context).commonSave,
      );
      if (range == null || !mounted) return;
    }
    if (value == _period && range == _customRange) return;
    setState(() {
      _period = value;
      _customRange = range;
      _entries = const [];
      _isLoading = true;
      _isLoadingMore = false;
    });
    _loadData();
  }

  String _loyaltyHelper(AppStrings l10n) {
    final loyalty = _loyalty;
    if (_account == null || loyalty == null) {
      return l10n.pointsHelper;
    }
    if (loyalty.isMaxLevel) {
      return l10n.loyaltyMaxLevelHelper;
    }
    final next = loyalty.nextLevel;
    final points = loyalty.pointsToNext;
    if (next == null || next.isEmpty || points == null) {
      return l10n.pointsHelper;
    }
    return l10n.loyaltyPointsToNextHelper(
      _formatPoints(points),
      next,
    );
  }

  String _formatPoints(double value) {
    final text =
        value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    final reversed = text.split('').reversed;
    final buffer = StringBuffer();
    var count = 0;
    for (final char in reversed) {
      if (count != 0 && count % 3 == 0) buffer.write(' ');
      buffer.write(char);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  Future<void> _refresh() => _loadData(refresh: true);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isRu = l10n.locale == AppLocale.ru;
    final balanceInt = _balance.round();
    final canView = balanceInt >= widget.threshold;

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _refresh,
            color: primaryColor,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(defaultPadding,
                      WalletTokens.sectionGap, defaultPadding, 0),
                  sliver: SliverToBoxAdapter(
                    child: WalletBalanceCard(
                      title: l10n.pointsTitle,
                      balanceLabel: formatWalletPoints(_balance,
                          isRu: isRu, balance: true),
                      unit: isRu ? 'балл' : 'ball',
                      helper: _loyaltyHelper(l10n) == l10n.pointsHelper
                          ? ''
                          : _loyaltyHelper(l10n),
                      progress: widget.threshold > 0
                          ? (_balance / widget.threshold).clamp(0.0, 1.0)
                          : 1,
                      thresholdLabel: l10n.pointsWalletThreshold(
                          formatWalletPoints(widget.threshold.toDouble(),
                              isRu: isRu)),
                      remainingLabel: l10n.pointsWalletRemaining(
                          formatWalletPoints(widget.threshold - _balance,
                              isRu: isRu, balance: true)),
                      canView: canView,
                      onView: () => _handleView(l10n, canView),
                      ctaLabel: l10n.pointsViewButton,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(defaultPadding,
                      WalletTokens.sectionGap, defaultPadding, defaultPadding),
                  sliver: SliverToBoxAdapter(
                    child: Semantics(
                      header: true,
                      child: Text(l10n.pointsHistoryTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700, color: titleColor)),
                    ),
                  ),
                ),
                if (_errorMessage == null) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        defaultPadding, 0, defaultPadding, 0),
                    sliver: SliverToBoxAdapter(
                      child: WalletSummaryCard(
                        creditLabel: l10n.pointsSummaryCredit,
                        debitLabel: l10n.pointsSummaryDebit,
                        credited: _summary.credited,
                        debited: _summary.debited,
                        isRu: isRu,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        defaultPadding, defaultPadding, defaultPadding, 0),
                    sliver: SliverToBoxAdapter(child: _buildFilters(l10n)),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: defaultPadding)),
                ],
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: defaultPadding),
                  sliver: _buildHistorySection(l10n, isRu),
                ),
                _buildPaginationSliver(l10n),
                SliverToBoxAdapter(
                    child: SizedBox(
                        height: WalletTokens.sectionGap +
                            MediaQuery.paddingOf(context).bottom)),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.pointsScreenTitle),
        centerTitle: true,
      ),
      body: SafeArea(top: false, bottom: false, child: body),
    );
  }

  Widget _buildFilters(AppStrings l10n) {
    Widget row(List<Widget> children) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.related),
                children[index],
              ],
            ],
          ),
        );
    final customLabel = _period == _TransactionPeriod.custom &&
            _customRange != null
        ? '${_formatShortDate(_customRange!.start)}–${_formatShortDate(_customRange!.end)}'
        : l10n.pointsPeriodCustom;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row([
        WalletFilterButton(
            key: const ValueKey('wallet-filter-all'),
            label: l10n.pointsFilterAll,
            selected: _direction == _TransactionDirection.all,
            onPressed: () => _selectDirection(_TransactionDirection.all)),
        WalletFilterButton(
            key: const ValueKey('wallet-filter-credit'),
            label: l10n.pointsFilterCredit,
            selected: _direction == _TransactionDirection.credit,
            onPressed: () => _selectDirection(_TransactionDirection.credit)),
        WalletFilterButton(
            key: const ValueKey('wallet-filter-debit'),
            label: l10n.pointsFilterDebit,
            selected: _direction == _TransactionDirection.debit,
            onPressed: () => _selectDirection(_TransactionDirection.debit)),
      ]),
      const SizedBox(height: AppSpacing.related),
      row([
        WalletFilterButton(
            key: const ValueKey('wallet-period-all'),
            label: l10n.pointsPeriodAll,
            selected: _period == _TransactionPeriod.all,
            onPressed: () => _selectPeriod(_TransactionPeriod.all)),
        WalletFilterButton(
            key: const ValueKey('wallet-period-7'),
            label: l10n.pointsPeriodSevenDays,
            selected: _period == _TransactionPeriod.sevenDays,
            onPressed: () => _selectPeriod(_TransactionPeriod.sevenDays)),
        WalletFilterButton(
            key: const ValueKey('wallet-period-30'),
            label: l10n.pointsPeriodThirtyDays,
            selected: _period == _TransactionPeriod.thirtyDays,
            onPressed: () => _selectPeriod(_TransactionPeriod.thirtyDays)),
        WalletFilterButton(
            key: const ValueKey('wallet-period-custom'),
            label: customLabel,
            selected: _period == _TransactionPeriod.custom,
            onPressed: () => _selectPeriod(_TransactionPeriod.custom)),
      ]),
    ]);
  }

  Widget _buildPaginationSliver(AppStrings l10n) {
    if (_isLoadingMore) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_loadMoreFailed) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              defaultPadding, AppSpacing.related, defaultPadding, 0),
          child: _PointsErrorCard(
            message: l10n.pointsLoadMoreError,
            onRetry: () => _loadMore(retry: true),
            retryLabel: l10n.commonRetry,
          ),
        ),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildHistorySection(AppStrings l10n, bool isRu) {
    if (_errorMessage != null) {
      return SliverToBoxAdapter(
          child: _PointsErrorCard(
        message: _errorMessage == l10n.pointsLoginRequired
            ? l10n.pointsLoginRequired
            : l10n.pointsHistoryLoadError,
        onRetry: () => _loadData(refresh: true),
        retryLabel: l10n.catalogRetry,
      ));
    }
    final count = _entries.length;
    if (count == 0) {
      return SliverToBoxAdapter(
          child: _EmptyHistoryCard(message: l10n.pointsHistoryEmpty));
    }
    // Each row is built on demand. Only the outer corners are rounded, so the
    // history reads as a single surface without eagerly laying out all entries.
    return SliverList.builder(
      itemCount: count,
      itemBuilder: (context, index) {
        final entry = _mapEntryToHistory(_entries[index], l10n, isRu);
        return WalletTransactionRow(
          key: ValueKey('wallet-transaction-${_entries[index].id}'),
          title: entry.title,
          date: entry.date,
          amount: entry.amount,
          groupLabel: index == 0 ||
                  !_isSameDay(
                      _entries[index - 1].createdAt, _entries[index].createdAt)
              ? _dateGroupLabel(_entries[index].createdAt, l10n)
              : null,
          isRu: isRu,
          first: index == 0,
          last: index == count - 1,
        );
      },
    );
  }

  String _dateGroupLabel(DateTime value, AppStrings l10n) {
    final today = walletTashkentDate(DateTime.now());
    final day = walletTashkentDate(value);
    if (day == today) return l10n.pointsToday;
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return l10n.pointsYesterday;
    }
    return _formatShortDate(day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      walletTashkentDate(a) == walletTashkentDate(b);

  String _formatShortDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  _PointsHistoryEntry _mapEntryToHistory(
    PointsEntry entry,
    AppStrings l10n,
    bool isRu,
  ) {
    final isCredit = entry.amount >= 0;
    final title = isCredit ? l10n.pointsHistoryAdded : l10n.pointsHistorySpent;
    final dateText = _formatDate(walletTashkentWallTime(entry.createdAt), isRu);
    return _PointsHistoryEntry(
      title: title,
      date: dateText,
      amount: entry.amount,
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WalletTokens.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            '—',
            style: TextStyle(color: bodyTextColor),
          ),
        ],
      ),
    );
  }
}

class _PointsErrorCard extends StatelessWidget {
  const _PointsErrorCard({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(WalletTokens.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: defaultPadding),
          ProductDetailPressable(
            key: const ValueKey('wallet-retry'),
            label: retryLabel,
            onPressed: onRetry,
            child: Container(
              constraints: const BoxConstraints(
                  minHeight: ProductDetailTokens.touchTarget),
              padding: const EdgeInsets.all(defaultPadding),
              decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(AppRadius.control)),
              child: Text(retryLabel, style: kButtonTextStyle),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsHistoryEntry {
  const _PointsHistoryEntry({
    required this.title,
    required this.date,
    required this.amount,
  });

  final String title;
  final String date;
  final double amount;
}

String _formatDate(DateTime date, bool isRu) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  final datePart = '$day.$month.$year';
  final timePart = '$hour:$minute';
  final separator = isRu ? ' • ' : ' • ';
  return '$datePart$separator$timePart';
}
