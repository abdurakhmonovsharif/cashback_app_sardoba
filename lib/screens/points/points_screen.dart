import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/account.dart';
import '../../models/points_entry.dart';
import '../../models/points_history.dart';
import '../../models/loyalty_summary.dart';
import '../../navigation/app_navigator.dart';
import '../../services/auth_service.dart';
import '../../services/auth_session_guard.dart';
import '../../services/auth_storage.dart';
import '../../services/branch_state.dart';
import '../../services/points_service.dart';
import '../../utils/snackbar_utils.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({
    super.key,
    this.account,
    required this.threshold,
    this.initialBalance,
    this.initialEntries,
    this.initialLoyalty,
  });

  final Account? account;
  final int threshold;
  final double? initialBalance;
  final List<PointsEntry>? initialEntries;
  final LoyaltySummary? initialLoyalty;

  static const List<_PointsHistoryEntry> _demoHistory = [
    _PointsHistoryEntry(
      title: 'Начисление баллов',
      subtitle: 'QR скан',
      date: '12.09.2024',
      amount: 12000,
    ),
    _PointsHistoryEntry(
      title: 'Баллы за визит',
      subtitle: 'Филиал',
      date: '09.09.2024',
      amount: 8000,
    ),
    _PointsHistoryEntry(
      title: 'Промо начисление',
      subtitle: 'Акция',
      date: '02.09.2024',
      amount: 5500,
      pending: true,
    ),
  ];

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  final PointsService _pointsService = PointsService();
  final AuthStorage _storage = AuthStorage.instance;
  final BranchState _branchState = BranchState.instance;

  Account? _account;
  LoyaltySummary? _loyalty;
  double _balance = 0;
  bool _isLoading = true;
  String? _errorMessage;
  List<PointsEntry> _entries = const [];
  bool _usingDemo = false;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _loyalty = widget.account?.loyalty ?? widget.initialLoyalty;
    _entries = widget.initialEntries ?? const [];
    _balance = widget.initialBalance ??
        widget.account?.pointsBalance ??
        0.0;
    _isLoading = _entries.isEmpty;
    _usingDemo = _entries.isEmpty && widget.account == null;
    _loadData();
  }

  @override
  void dispose() {
    _pointsService.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (!mounted) return;
    if (!refresh) {
      setState(() {
        _isLoading = _entries.isEmpty;
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
        if (!mounted) return;
        setState(() {
          _account = null;
          _entries = const [];
          _loyalty = null;
          _balance = widget.initialBalance ?? 0;
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context).pointsLoginRequired;
          _usingDemo = true;
        });
        return;
      }
      account = await _syncAccount(account);
      final resolvedAccount = account;
      if (resolvedAccount == null || resolvedAccount.id == null) {
        if (!mounted) return;
        setState(() {
          _account = null;
          _entries = const [];
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context).pointsLoginRequired;
          _usingDemo = true;
        });
        return;
      }

      if (!refresh &&
          (resolvedAccount.pointsHistory?.isNotEmpty ?? false) &&
          _entries.isEmpty) {
        if (!mounted) return;
        setState(() {
          _account = resolvedAccount;
          _entries = resolvedAccount.pointsHistory!;
          _loyalty = resolvedAccount.loyalty ?? _loyalty;
          _balance = resolvedAccount.pointsBalance ??
              _balance;
          _isLoading = false;
          _errorMessage = null;
          _usingDemo = false;
        });
      }

      final history = await _fetchHistoryWithRefresh(resolvedAccount.id!);

      if (!mounted) return;
      setState(() {
        _account = resolvedAccount;
        _entries = history.transactions;
        _loyalty = history.loyalty;
        _balance = resolvedAccount.pointsBalance ??
            (history.transactions.isNotEmpty
                ? history.transactions.first.balanceAfter
                : _balance);
        _isLoading = false;
        _errorMessage = null;
        _usingDemo = false;
      });
    } on PointsUnauthorizedException {
      await AppNavigator.forceLogout();
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context).pointsLoginRequired;
        _isLoading = false;
        _usingDemo = true;
      });
      return;
    } on PointsServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
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

  Future<PointsHistory> _fetchHistoryWithRefresh(int userId) async {
    try {
      final token = await _storage.getAccessToken();
      final tokenType = await _storage.getTokenType();
      return await _pointsService.fetchUserPoints(
        userId: userId,
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
        return await _pointsService.fetchUserPoints(
          userId: userId,
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

  Future<void> _handleView(AppStrings l10n, bool canView) async {
    if (!canView) return;
    if (!mounted) return;
    showNavAwareSnackBar(
      context,
      content: Text(l10n.pointsUpdatedSuccess),
    );
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                defaultPadding,
                24,
                defaultPadding,
                32,
              ),
              children: [
                _PointsHero(
                  title: l10n.pointsTitle,
                  balanceLabel: _formatCurrency(balanceInt, isRu),
                  helper: _loyaltyHelper(l10n),
                  canView: canView,
                  onView: () => _handleView(l10n, canView),
                  ctaLabel: canView
                      ? l10n.pointsViewButton
                      : l10n.pointsViewLocked,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.pointsHistoryTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.pointsScreenDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                _buildHistorySection(l10n, isRu),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.pointsScreenTitle),
        centerTitle: true,
      ),
      body: body,
    );
  }

  Widget _buildHistorySection(AppStrings l10n, bool isRu) {
    if (_errorMessage != null) {
      return _PointsErrorCard(
        message: l10n.pointsHistoryLoadError,
        details: _errorMessage!,
        onRetry: () => _loadData(refresh: true),
        retryLabel: l10n.catalogRetry,
      );
    }

    final entries = _entries.isNotEmpty
        ? _entries
            .map((entry) => _mapEntryToHistory(entry, l10n, isRu))
            .toList()
        : (_usingDemo ? PointsScreen._demoHistory : const []);

    if (entries.isEmpty) {
      return _EmptyHistoryCard(message: l10n.pointsHistoryEmpty);
    }

    return Column(
      children: [
        if (_usingDemo)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l10n.pointsHistoryDemoLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        if (_usingDemo) const SizedBox(height: 14),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HistoryTile(
              entry: entry,
              isRu: isRu,
              l10n: l10n,
            ),
          ),
        ),
      ],
    );
  }

  _PointsHistoryEntry _mapEntryToHistory(
    PointsEntry entry,
    AppStrings l10n,
    bool isRu,
  ) {
    final branchName = _branchNameForStore(entry.branchId);
    final isCredit = entry.amount >= 0;
    final title = isCredit
        ? l10n.pointsHistoryAdded
        : l10n.pointsHistorySpent;
    final dateText = _formatDate(entry.createdAt, isRu);
    final subtitle =
        entry.source == PointsSource.visit ? l10n.pointsSourceVisit : branchName;
    return _PointsHistoryEntry(
      title: title,
      subtitle: subtitle,
      date: dateText,
      amount: entry.amount.round(),
      pending: false,
    );
  }

  String _branchNameForStore(int? storeId) {
    if (storeId == null) return 'Sardoba';
    final match = _branchState.branches
        .where((branch) => branch.storeId == storeId)
        .toList();
    if (match.isEmpty) return 'Sardoba';
    return match.first.name;
  }

}

class _PointsHero extends StatelessWidget {
  const _PointsHero({
    required this.title,
    required this.balanceLabel,
    required this.helper,
    required this.canView,
    required this.onView,
    required this.ctaLabel,
  });

  final String title;
  final String balanceLabel;
  final String helper;
  final bool canView;
  final VoidCallback onView;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9FBFF), Color(0xFFEFF4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.loyalty_rounded,
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: bodyTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    balanceLabel,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            helper,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bodyTextColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canView ? onView : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canView ? primaryColor : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.white70,
              ),
              child: Text(
                ctaLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.isRu,
    required this.l10n,
  });

  final _PointsHistoryEntry entry;
  final bool isRu;
  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = entry.amount >= 0;
    final amountLabel = _formatCurrency(entry.amount.abs(), isRu);
    final valueColor =
        entry.pending ? accentColor : (isPositive ? primaryColor : accentColor);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              entry.pending
                  ? Icons.timer_rounded
                  : Icons.add_circle_outline_rounded,
              color: entry.pending ? accentColor : primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.pointsHistoryEarned(entry.subtitle),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.date,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: bodyTextColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : '−'}$amountLabel',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: valueColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.pending
                      ? l10n.pointsStatusPending
                      : (isPositive
                          ? l10n.pointsStatusCompleted
                          : l10n.pointsStatusSpent),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
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
          const SizedBox(height: 8),
          Text(
            details,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bodyTextColor,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}

class _PointsHistoryEntry {
  const _PointsHistoryEntry({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
    this.pending = false,
  });

  final String title;
  final String subtitle;
  final String date;
  final int amount;
  final bool pending;
}

String _formatCurrency(int value, bool isRu) {
  final chars = value.toString().split('').reversed;
  final buffer = StringBuffer();
  var count = 0;
  for (final char in chars) {
    if (count != 0 && count % 3 == 0) buffer.write(' ');
    buffer.write(char);
    count++;
  }
  final formatted = buffer.toString().split('').reversed.join();
  final suffix = isRu ? 'балл' : 'ball';
  return '$formatted $suffix';
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
