import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../constants.dart';
import '../../components/combined_card_widget.dart';
import '../../models/account.dart';
import '../../models/branch.dart';
import '../../models/catalog.dart';
import '../../models/news.dart';
import '../../components/branch_picker_sheet.dart';
import '../../services/account_stream.dart';
import '../../services/auth_storage.dart';
import '../../services/branch_state.dart';
import '../../services/catalog_repository.dart';
import '../../services/news_service.dart';
import '../../entry_point.dart';
import '../../services/session_sync_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_socket_service.dart';
import '../../models/app_notification.dart';
import '../catalog/catalog_screen.dart';
import '../catalog/product_details_screen.dart';
import '../points/points_screen.dart';
import '../notifications/notifications_screen.dart';
import '../qr/qr_screen.dart';
import '../search/search_screen.dart';

const AssetImage _kCheesecakeBannerImage =
    AssetImage('assets/images/cheesecake_banner.jpg');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<_CheesecakePromoBannerState> _newsBannerKey =
      GlobalKey<_CheesecakePromoBannerState>();

  Future<void> _refreshHome() async {
    final account = await SessionSyncService.instance.sync();
    if (account != null) {
      // Emit the latest profile (including points) to listening widgets.
      await AuthStorage.instance.updateCurrentAccount(account);
    }
    // Refresh featured news on pull-to-refresh.
    await _newsBannerKey.currentState?.reloadNews();
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  InputDecoration _buildSearchDecoration(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InputDecoration(
        hintText: l10n.searchHint,
        hintStyle: const TextStyle(color: Color(0xFFB0B6C3), fontSize: 15),
        filled: true,
        fillColor: const Color.fromARGB(255, 235, 236, 240),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: const Icon(
              Icons.search_rounded,
              color: Color(0xFF8D97A8),
            )));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final double scrollBottomPadding =
        navAwareBottomPadding(context, extra: 20);

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: _refreshHome,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              defaultPadding,
              12,
              defaultPadding,
              scrollBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RepaintBoundary(child: _HomeHeader()),
                        const SizedBox(height: 24),
                        TextField(
                          readOnly: true,
                          onTap: _openSearch,
                          decoration: _buildSearchDecoration(context),
                        ),
                        const SizedBox(height: 14),
                        _CheesecakePromoBanner(key: _newsBannerKey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.loyaltyTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                RepaintBoundary(
                  child: const _LoyaltyStats(),
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () {
                    final handled = EntryPoint.selectTab(context, 1);
                    if (!handled) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CatalogScreen(),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.offersTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: titleColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _OffersCarousel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatefulWidget {
  const _HomeHeader();

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader>
    with SingleTickerProviderStateMixin {
  final BranchState _branchState = BranchState.instance;
  late Branch _activeBranch;
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<AppNotification>? _notifSubscription;
  int _unreadCount = 0;
  bool _isFetchingUnread = false;

  late final AnimationController _notifController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    lowerBound: 0.0,
    upperBound: 0.1,
  );

  @override
  void initState() {
    super.initState();
    _activeBranch = _branchState.activeBranch;
    _branchState.addListener(_handleBranchChange);
    _loadUnreadCount();
    _notifSubscription =
        NotificationSocketManager.instance.notificationStream.listen(
      (AppNotification notification) {
        if (!mounted) return;
        setState(() {
          _unreadCount = (_unreadCount + 1).clamp(0, 9999).toInt();
        });
      },
    );
  }

  Future<void> _loadUnreadCount() async {
    if (_isFetchingUnread) return;
    _isFetchingUnread = true;
    try {
      final response = await _notificationService.fetchNotifications(limit: 1);
      if (!mounted) return;
      setState(() {
        _unreadCount = response.unreadCount.clamp(0, 9999).toInt();
      });
    } catch (_) {
      // Ignore errors; badge is non-blocking.
    } finally {
      _isFetchingUnread = false;
    }
  }

  void _handleBranchChange() {
    final branch = _branchState.activeBranch;
    if (!mounted || branch.id == _activeBranch.id) return;
    setState(() => _activeBranch = branch);
  }

  @override
  void dispose() {
    _branchState.removeListener(_handleBranchChange);
    _notifSubscription?.cancel();
    _notificationService.dispose();
    _notifController.dispose();
    super.dispose();
  }

  Future<void> _openBranchPicker() async {
    await showBranchPickerSheet(context);
  }

  Future<void> _openNotifications() async {
    await _notifController.forward(from: 0);
    await _notifController.reverse();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
    if (!mounted) return;
    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.changeBranch,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openBranchPicker,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _activeBranch.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AnimatedBuilder(
          animation: _notifController,
          builder: (context, child) {
            final scale = 1 + _notifController.value;
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: _HeaderActionButton(
            icon: Icons.notifications_none_rounded,
            onTap: _openNotifications,
            badgeCount: _unreadCount,
          ),
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount > 0;
    final badgeText = badgeCount > 99 ? '99+' : badgeCount.toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: titleColor),
              if (hasBadge)
                Positioned(
                  right: -9,
                  top: -13,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      badgeText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
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

class _CheesecakePromoBanner extends StatefulWidget {
  const _CheesecakePromoBanner({super.key});

  @override
  State<_CheesecakePromoBanner> createState() => _CheesecakePromoBannerState();
}

class _CheesecakePromoBannerState extends State<_CheesecakePromoBanner> {
  final NewsService _newsService = NewsService();
  // Slightly reduced viewport to peek adjacent cards minimally.
  final PageController _pageController = PageController(viewportFraction: 0.97);
  List<NewsItem> _news = const [];
  int _activeIndex = 0;
  bool _isLoading = true;
  bool _showGift = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(_kCheesecakeBannerImage, context);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        _loadNews();
      });
      _loadGiftEligibility();
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    // Reset legacy state after hot reload to avoid type mismatches.
    _news = const [];
    _activeIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadNews();
      _loadGiftEligibility();
    });
  }

  @override
  void dispose() {
    _newsService.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadNews() async {
    setState(() => _isLoading = true);
    try {
      final items = await _newsService.fetchNews();
      items.sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return b.createdAt.compareTo(a.createdAt);
      });
      if (!mounted) return;
      setState(() {
        _news = items;
        _activeIndex = 0;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _news = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> reloadNews() async {
    if (!mounted) return;
    setState(() {
      _news = const [];
      _activeIndex = 0;
      _isLoading = true;
    });
    await _loadNews();
    await _loadGiftEligibility();
  }

  Future<void> _loadGiftEligibility() async {
    // Refresh profile to ensure latest gift flag.
    await SessionSyncService.instance.sync();
    final account = await AuthStorage.instance.getCurrentAccount();
    if (!mounted) return;
    setState(() {
      _showGift = !(account?.giftget ?? false);
    });
  }

  void _openQrScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScreen()),
    );
  }

  void _showNewsDetails(NewsItem news) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (news.imageUrl != null && news.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      news.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Image(
                        image: _kCheesecakeBannerImage,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                news.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                news.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: bodyTextColor,
                  height: 1.4,
                ),
              ),
              if (news.startsAt != null || news.endsAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  _formatNewsPeriod(news),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: bodyTextColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final giftSlides = _showGift ? 1 : 0;
    final totalSlides = _news.length + giftSlides;
    if (_isLoading) {
      return const _NewsCarouselSkeleton();
    }
    if (totalSlides == 0) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            itemCount: totalSlides,
            onPageChanged: (index) {
              setState(() => _activeIndex = index.clamp(0, totalSlides - 1));
            },
            itemBuilder: (context, index) {
              final padding = index == totalSlides - 1 ? 0.0 : 4.0;
              if (_showGift && index == 0) {
                return Padding(
                  padding: EdgeInsets.only(right: padding),
                  child: _StaticCheesecakeBanner(onCta: _openQrScreen),
                );
              } else {
                final newsIndex = _showGift ? index - 1 : index;
                final news = _news[newsIndex];
                return Padding(
                  padding: EdgeInsets.only(right: padding),
                  child: _NewsBanner(
                    news: news,
                    onDetails: () => _showNewsDetails(news),
                  ),
                );
              }
            },
          ),
        ),
        if (totalSlides > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalSlides, (index) {
              final isActive = index == _activeIndex;
              return AnimatedContainer(
                duration: kDefaultDuration,
                curve: Curves.easeOut,
                width: isActive ? 18 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? primaryColor
                      : primaryColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  String _formatNewsPeriod(NewsItem news) {
    String format(DateTime? date) {
      if (date == null) return '—';
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day.$month.$year';
    }

    final start = format(news.startsAt);
    final end = format(news.endsAt);
    return '$start • $end';
  }
}

class _StaticCheesecakeBanner extends StatelessWidget {
  const _StaticCheesecakeBanner({required this.onCta});

  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: const DecorationImage(
            image: _kCheesecakeBannerImage,
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// TITLE
            Text(
              l10n.cheesecakeBannerTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),

            const SizedBox(height: 4),

            /// SUBTITLE
            Text(
              l10n.cheesecakeBannerSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 10),

            /// CTA BUTTON
            SizedBox(
              width: 150,
              child: ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  l10n.cheesecakeBannerButton,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsBanner extends StatelessWidget {
  const _NewsBanner({required this.news, required this.onDetails});

  final NewsItem news;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasImage = news.imageUrl != null && news.imageUrl!.isNotEmpty;
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 190),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: hasImage
                    ? Image.network(
                        news.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Image(
                          image: _kCheesecakeBannerImage,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Image(
                        image: _kCheesecakeBannerImage,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.28),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        news.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        news.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 160,
                          child: ElevatedButton(
                            onPressed: onDetails,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: Colors.white,
                              foregroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: Text(l10n.newsBannerButton),
                          ),
                        ),
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

class _NewsCarouselSkeleton extends StatelessWidget {
  const _NewsCarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Row(
        children: const [
          Expanded(child: _NewsCardSkeleton()),
          SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: _NewsCardSkeleton(shrink: true),
          ),
        ],
      ),
    );
  }
}

class _NewsCardSkeleton extends StatelessWidget {
  const _NewsCardSkeleton({this.shrink = false});

  final bool shrink;

  @override
  Widget build(BuildContext context) {
    return _ShimmerSkeleton(
      borderRadius: 24,
      height: 210,
      width: shrink ? double.infinity : null,
    );
  }
}

class _ShimmerSkeleton extends StatefulWidget {
  const _ShimmerSkeleton({
    this.height,
    this.width,
    this.borderRadius = 16,
  });

  final double? height;
  final double? width;
  final double borderRadius;

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade200;
    final highlight = Colors.grey.shade100;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = widget.width ?? constraints.maxWidth;
        final height = widget.height ?? constraints.maxHeight;
        return Container(
          width: width > 0 ? width : null,
          height: height > 0 ? height : null,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final shimmerWidth = (width.isFinite && width > 0)
                  ? width * 0.6
                  : MediaQuery.of(context).size.width * 0.3;
              final offset =
                  (_controller.value * ((width.isFinite && width > 0) ? width : MediaQuery.of(context).size.width));
              return Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: base),
                  ),
                  Positioned(
                    left: offset - shimmerWidth,
                    top: -height,
                    bottom: -height,
                    child: Container(
                      width: shimmerWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            base.withValues(alpha: 0.0),
                            highlight.withValues(alpha: 0.8),
                            base.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _OffersCarousel extends StatefulWidget {
  const _OffersCarousel();

  @override
  State<_OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends State<_OffersCarousel> {
  final CatalogRepository _catalogRepository = CatalogRepository.instance;
  final BranchState _branchState = BranchState.instance;

  late Branch _activeBranch;
  final PageController _pageController = PageController(viewportFraction: 0.88);

  List<_OfferEntry> _offers = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _activeBranch = _branchState.activeBranch;
    _branchState.addListener(_handleBranchChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 140), () async {
        if (!mounted) return;
        await _applyCachedOffers();
      });
      Future.delayed(const Duration(milliseconds: 170), () async {
        if (!mounted) return;
        await _loadOffers();
      });
    });
  }

  @override
  void dispose() {
    _branchState.removeListener(_handleBranchChange);
    _pageController.dispose();
    super.dispose();
  }

  void _handleBranchChange() {
    final branch = _branchState.activeBranch;
    if (!mounted || branch.id == _activeBranch.id) return;
    setState(() {
      _activeBranch = branch;
    });
    _applyCachedOffers();
    _loadOffers();
  }

  Future<void> _applyCachedOffers() async {
    final cached = await _catalogRepository.getCachedCatalog();
    if (!mounted || cached == null) return;
    final offers = await _buildOffersFromPayload(cached);
    if (!mounted) return;
    setState(() {
      _offers = offers;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  Future<void> _loadOffers({bool forceRefresh = false}) async {
    setState(() {
      if (_offers.isEmpty || forceRefresh) {
        _isLoading = true;
      }
      _errorMessage = null;
    });
    try {
      final payload = await _catalogRepository.loadCatalog(
        forceRefresh: forceRefresh,
      );
      final offers = await _buildOffersFromPayload(payload);
      if (!mounted) return;
      setState(() {
        _offers = offers;
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

  Future<List<_OfferEntry>> _buildOffersFromPayload(
    CatalogPayload payload,
  ) async {
    final params = {
      'payload': payload.toJson(),
      'storeId': _activeBranch.storeId ?? 0,
      'maxOffers': _offersCarouselMaxOffers,
    };
    final computed = await compute(_extractOffers, params);
    return computed.map((entry) {
      final category = CatalogCategory.fromJson(
        Map<String, dynamic>.from(entry['category'] as Map<String, dynamic>),
      );
      final item = CatalogItem.fromJson(
        Map<String, dynamic>.from(entry['item'] as Map<String, dynamic>),
      );
      final price = CatalogPrice.fromJson(
        Map<String, dynamic>.from(entry['price'] as Map<String, dynamic>),
      );
      return _OfferEntry(category: category, item: item, price: price);
    }).toList();
  }

  String _formatPrice(double value, bool isRu) {
    final intValue = value.round();
    final reversed = intValue.toString().split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < reversed.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(reversed[i]);
    }
    final formatted = buffer.toString().split('').reversed.join();
    final suffix = isRu ? 'сум' : "so'm";
    return '$formatted $suffix';
  }

  void _openDetails(_OfferEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CatalogProductDetailsScreen(
          category: entry.category,
          initialItem: entry.item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRu = l10n.locale == AppLocale.ru;

    if (_isLoading) {
      return RepaintBoundary(
        child: Container(
          height: 180,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_errorMessage != null) {
      return _OfferError(
        message: l10n.catalogLoadError,
        details: _errorMessage!,
        onRetry: () => _loadOffers(forceRefresh: true),
      );
    }

    if (_offers.isEmpty) {
      return RepaintBoundary(
        child: Container(
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            l10n.catalogEmpty,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: bodyTextColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _offers.length,
            padEnds: false,
            onPageChanged: (index) {
              Future.microtask(() {
                if (!mounted) return;
                setState(() => _activeIndex = index);
              });
            },
            itemBuilder: (context, index) {
              final entry = _offers[index];
              final padding = index == _offers.length - 1 ? 0.0 : 12.0;
              return Padding(
                padding: EdgeInsets.only(right: padding, bottom: 12.0),
                child: _OfferCard(
                  entry: entry,
                  price: _formatPrice(entry.price.price, isRu),
                  onTap: () => _openDetails(entry),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _offers.length,
            (index) {
              final isActive = index == _activeIndex;
              return AnimatedContainer(
                duration: kDefaultDuration,
                curve: Curves.easeOut,
                width: isActive ? 18 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? primaryColor
                      : primaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OfferEntry {
  const _OfferEntry({
    required this.category,
    required this.item,
    required this.price,
  });

  final CatalogCategory category;
  final CatalogItem item;
  final CatalogPrice price;
}

const int _offersCarouselMaxOffers = 6;

List<Map<String, dynamic>> _extractOffers(Map<String, dynamic> args) {
  final payload = CatalogPayload.fromJson(
    Map<String, dynamic>.from(args['payload'] as Map<String, dynamic>),
  );
  final storeId = args['storeId'] as int;
  final maxOffers = args['maxOffers'] as int;
  final offers = <Map<String, dynamic>>[];
  for (final category in payload.categories) {
    for (final item in category.items) {
      final price = _priceForStore(item, storeId);
      if (price == null || price.disabled) continue;
      offers.add({
        'category': category.toJson(),
        'item': item.toJson(),
        'price': price.toJson(),
      });
      if (offers.length >= maxOffers) break;
    }
    if (offers.length >= maxOffers) break;
  }
  return offers;
}

CatalogPrice? _priceForStore(CatalogItem item, int storeId) {
  if (storeId <= 0) return null;
  for (final price in item.prices) {
    if (price.storeId == storeId) return price;
  }
  return null;
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.entry,
    required this.price,
    required this.onTap,
  });

  final _OfferEntry entry;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl =
        entry.item.images.isNotEmpty ? entry.item.images.first : null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _OfferImage(imageUrl: imageUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111111),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.category.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        price,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferError extends StatelessWidget {
  const _OfferError({
    required this.message,
    required this.details,
    required this.onRetry,
  });

  final String message;
  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
            const SizedBox(height: 6),
            Text(
              details,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                  ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onRetry,
              child: Text(
                AppLocalizations.of(context).catalogRetry,
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferImage extends StatelessWidget {
  const _OfferImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF7F3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: imageUrl != null
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _OfferImagePlaceholder(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _OfferImagePlaceholder(isLoading: true);
                  },
                )
              : const _OfferImagePlaceholder(),
        ),
      ),
    );
  }
}

class _OfferImagePlaceholder extends StatelessWidget {
  const _OfferImagePlaceholder({this.isLoading = false});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F4FB),
      alignment: Alignment.center,
      child: Icon(
        isLoading
            ? Icons.hourglass_empty_rounded
            : Icons.image_not_supported_outlined,
        color: bodyTextColor.withValues(alpha: 0.4),
      ),
    );
  }
}

class _LoyaltyStats extends StatefulWidget {
  const _LoyaltyStats();

  @override
  State<_LoyaltyStats> createState() => _LoyaltyStatsState();
}

class _LoyaltyStatsState extends State<_LoyaltyStats> {
  static const int _pointsThreshold = 30000;
  final AuthStorage _storage = AuthStorage.instance;
  Account? _account;
  bool _isLoading = true;
  late final StreamSubscription<Account> _accountSubscription;

  @override
  void initState() {
    super.initState();
    final latestAccount = accountStream.latest;
    if (latestAccount != null) {
      _account = latestAccount;
      _isLoading = false;
    }
    _accountSubscription = accountStream.stream.listen((account) {
      if (!mounted) return;
      setState(() {
        _account = account;
        _isLoading = false;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        _loadAccount();
      });
    });
  }

  Future<void> _loadAccount() async {
    final account = await _storage.getCurrentAccount();
    if (!mounted) return;
    setState(() {
      _account = account;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _accountSubscription.cancel();
    super.dispose();
  }

  Future<void> _openPoints(Account account) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PointsScreen(
          account: account,
          threshold: _pointsThreshold,
          initialBalance: account.pointsBalance ?? 0,
          initialEntries: account.pointsHistory,
          initialLoyalty: account.loyalty,
        ),
      ),
    );
    if (!mounted) return;
    _loadAccount();
  }

  String _formatCurrency(double value, bool isRu) {
    final formatted = _formatAmount(value, isRu: isRu);
    final suffix = isRu ? 'балл' : 'ball';
    return '$formatted $suffix';
  }

  String _formatAmount(double value, {required bool isRu}) {
    if (value.isNaN || value.isInfinite) return '0';
    final isNegative = value < 0;
    final absValue = value.abs();

    final isWhole = absValue == absValue.truncateToDouble();
    final raw = isWhole ? absValue.toStringAsFixed(0) : absValue.toStringAsFixed(1);

    final parts = raw.split('.');
    final intPart = parts.first;
    final formattedInt = _groupDigits(intPart);

    if (parts.length == 1) {
      return isNegative ? '-$formattedInt' : formattedInt;
    }

    final fractional = parts[1].replaceFirst(RegExp(r'0+$'), '');
    if (fractional.isEmpty) {
      return isNegative ? '-$formattedInt' : formattedInt;
    }
    final decimalSeparator = isRu ? ',' : '.';
    final formatted = '$formattedInt$decimalSeparator$fractional';
    return isNegative ? '-$formatted' : formatted;
  }

  String _groupDigits(String digits) {
    final reversed = digits.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < reversed.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(reversed[i]);
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRu = l10n.locale == AppLocale.ru;
    final balanceValue = _account?.pointsBalance;
    final balanceLabel = _isLoading
        ? '-'
        : balanceValue != null
            ? _formatCurrency(balanceValue, isRu)
            : '-';
    final helper = _account == null
        ? l10n.pointsLoginRequired
        : l10n.pointsHelper;
    return CombinedCardWidget(
      balanceLabel: l10n.pointsTitle,
      balanceValue: balanceLabel,
      balanceNote: helper,
      tierTitle: '',
      tierNote: '',
      showTier: false,
      currentPointsText: null,
      onTap: _account == null ? null : () => _openPoints(_account!),
    );
  }
}
