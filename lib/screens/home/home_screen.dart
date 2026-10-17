import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/account.dart';
import '../../models/branch.dart';
import '../../models/catalog.dart';
import '../../components/branch_picker_sheet.dart';
import '../../components/points_balance_card.dart';
import '../../components/inline_price_text.dart';
import '../catalog/product_detail_images.dart';
import '../../services/account_stream.dart';
import '../../services/auth_storage.dart';
import '../../services/branch_state.dart';
import '../../services/catalog_repository.dart';
import '../../entry_point.dart';
import '../../services/session_sync_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_socket_service.dart';
import '../../models/app_notification.dart';
import '../catalog/catalog_screen.dart';
import '../catalog/product_details_screen.dart';
import '../auth/sign_in_screen.dart';
// import '../locations/locations_screen.dart'; // Restore with pickup below.
import '../points/points_screen.dart';
import '../notifications/notifications_screen.dart';
import '../search/search_screen.dart';
import 'components/home_banner_balance_layout.dart';
import 'components/home_banner_carousel.dart';
import 'components/home_category_strip.dart';

// Fulfillment is paused. Its assets are kept outside the bundled directories.
// Restore these declarations and the pubspec entry together with the section.
// const AssetImage _kDeliveryScooterImage =
//     AssetImage('assets/disabled/fulfillment/home_design_scooter.webp');
// const AssetImage _kPickupBagImage =
//     AssetImage('assets/disabled/fulfillment/home_design_bag.webp');

const Color _kHomePrimaryGreen = primaryColor;
const Color _kHomeAccentGreen = Color(0xFF0F8F4D);
// const Color _kHomeAccentOrange = Color(0xFFF59E0B); // Fulfillment only.
const Color _kHomeBorder = appBorderColor;
const Color _kHomeTextPrimary = Color(0xFF111827);
const Color _kHomeTextSecondary = Color(0xFF6B7280);

class _HomeBreakpoints {
  static const compact = 360.0;
  // static bool stackFulfillmentCards(double contentWidth) => contentWidth < 340;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _menuPreviewKey = GlobalKey<_HomeMenuPreviewState>();

  Future<void> _refreshHome() async {
    final preview = _menuPreviewKey.currentState;
    await Future.wait<void>([
      () async {
        final account = await SessionSyncService.instance.sync();
        if (account != null) {
          // Emit the latest profile (including points) to listening widgets.
          await AuthStorage.instance.updateCurrentAccount(account);
        }
      }(),
      if (preview != null) preview.refreshCatalog(),
    ]);
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _openDeliveryFlow() {
    _openCatalogCategory(null);
  }

  void _openCatalogCategory(String? categoryId) {
    final handled = EntryPoint.openCatalog(context, categoryId: categoryId);
    if (!handled) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CatalogScreen(initialCategoryId: categoryId),
        ),
      );
    }
  }

  /* Fulfillment is paused; keep this route for reactivation.
  Future<void> _openPickupFlow() async {
    final handled = EntryPoint.showShellScreen(
      context,
      const LocationsScreen(),
    );
    if (handled) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LocationsScreen()),
    );
  }

  */

  @override
  Widget build(BuildContext context) {
    // Match Profile's shared page inset on every phone size.
    const pageHorizontalPadding = defaultPadding;
    final double scrollBottomPadding =
        navAwareBottomPadding(context, extra: 16);

    return Scaffold(
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
              pageHorizontalPadding,
              4,
              pageHorizontalPadding,
              scrollBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RepaintBoundary(child: _HomeHeader()),
                      const SizedBox(height: AppSpacing.related),
                      _HomeSearchBar(
                        onTap: _openSearch,
                      ),
                      const SizedBox(height: AppSpacing.related),
                      HomeBannerBalanceLayout(
                        banner: RepaintBoundary(
                          child: HomeBannerCarousel(
                            onOpenMenu: _openDeliveryFlow,
                          ),
                        ),
                        balance: const _LoyaltyStats(),
                      ),
                      // Fulfillment is paused. Keep the section and its
                      // spacing out of the tree (no layout or image cost).
                      // _OrderMethodSection(
                      //   onDeliveryTap: _openDeliveryFlow,
                      //   onPickupTap: _openPickupFlow,
                      // ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                _HomeMenuPreview(
                  key: _menuPreviewKey,
                  onViewAll: _openDeliveryFlow,
                  onCategorySelected: _openCatalogCategory,
                ),
                // const SizedBox(height: 18),
                // _ActiveOrderCard(onTrack: _openDeliveryFlow),
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

  String _displayBranchName(String name) {
    return name
        .replaceAllMapped(RegExp(r'\s*\(([^)]+)\)'), (match) {
          return ' ${match.group(1)}';
        })
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final branchLabel =
        l10n.locale == AppLocale.ru ? 'Выбранный филиал' : 'Tanlangan filial';
    final textScaler = MediaQuery.textScalerOf(context);
    final branchLabelMaxLines = textScaler.scale(12) > 12 ? null : 1;
    final branchNameMaxLines = textScaler.scale(17) > 17 ? null : 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final branchTextMaxWidth = constraints.maxWidth > 72
                      ? constraints.maxWidth - 72
                      : constraints.maxWidth;

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openBranchPicker,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 34),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: branchTextMaxWidth,
                                  ),
                                  child: Text(
                                    branchLabel,
                                    maxLines: branchLabelMaxLines,
                                    overflow: branchLabelMaxLines == null
                                        ? null
                                        : TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: _kHomePrimaryGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 15 / 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: _kHomePrimaryGreen,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: branchTextMaxWidth,
                                    ),
                                    child: Text(
                                      _displayBranchName(_activeBranch.name),
                                      maxLines: branchNameMaxLines,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        color: _kHomeTextPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0,
                                        height: 22 / 17,
                                      ),
                                      overflow: branchNameMaxLines == null
                                          ? null
                                          : TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: _kHomeTextPrimary,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
            tooltip: l10n.notificationsTitle,
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
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount > 0;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: _kHomeBorder.withValues(alpha: 0.72),
              ),
              boxShadow: const [appCardShadow],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, color: _kHomeTextPrimary, size: 24),
                if (hasBadge)
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _kHomeAccentGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.3,
                        ),
                      ),
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

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hint = l10n.locale == AppLocale.ru
        ? 'Поиск блюд или категорий'
        : 'Taom yoki kategoriya izlash';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kHomeBorder),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(
                  Icons.search_rounded,
                  color: _kHomeTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _kHomeTextSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* Fulfillment widgets retained for reactivation. No runtime code while paused.
class _OrderMethodSection extends StatelessWidget {
  const _OrderMethodSection({
    required this.onDeliveryTap,
    required this.onPickupTap,
  });

  final VoidCallback onDeliveryTap;
  final VoidCallback onPickupTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final isSmallPhone = size.width <= 375 || size.height <= 700;
    final isTinyPhone = size.width <= 340;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow =
            _HomeBreakpoints.stackFulfillmentCards(constraints.maxWidth);
        final useCompactLayout = isSmallPhone || isNarrow;
        final cardHeight = useCompactLayout
            ? (isTinyPhone ? 72.0 : 76.0)
            : constraints.maxWidth >= 390
                ? 156.0
                : 148.0;
        final cards = [
          _OrderMethodCard(
            title: l10n.orderDeliveryTitle,
            description: l10n.orderDeliveryDescription,
            compactDescription:
                l10n.locale == AppLocale.ru ? '30–45 мин' : '30–45 daq',
            icon: Icons.delivery_dining_rounded,
            image: _kDeliveryScooterImage,
            accent: _kHomeAccentGreen,
            titleColor: Colors.white,
            descriptionColor: Colors.white.withValues(alpha: 0.9),
            ctaBackground: Colors.white,
            ctaForeground: _kHomePrimaryGreen,
            gradient: const LinearGradient(
              colors: [_kHomePrimaryGreen, _kHomeDarkGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            height: cardHeight,
            isPrimary: true,
            isCompact: useCompactLayout,
            onTap: onDeliveryTap,
          ),
          _OrderMethodCard(
            title: l10n.orderPickupTitle,
            description: l10n.orderPickupDescription,
            compactDescription:
                l10n.locale == AppLocale.ru ? '15–20 мин' : '15–20 daq',
            icon: Icons.shopping_bag_outlined,
            image: _kPickupBagImage,
            accent: _kHomeAccentOrange,
            titleColor: const Color(0xFF9A4B00),
            descriptionColor: _kHomeTextPrimary,
            ctaBackground: _kHomeAccentOrange,
            ctaForeground: Colors.white,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF9EA), Color(0xFFF8E8C8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            height: cardHeight,
            isPrimary: false,
            isCompact: useCompactLayout,
            onTap: onPickupTap,
          ),
        ];

        if (useCompactLayout) {
          return Column(
            children: [
              cards[0],
              SizedBox(height: isTinyPhone ? 8 : 10),
              cards[1],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _OrderMethodCard extends StatelessWidget {
  const _OrderMethodCard({
    required this.title,
    required this.description,
    required this.compactDescription,
    required this.icon,
    required this.image,
    required this.accent,
    required this.titleColor,
    required this.descriptionColor,
    required this.ctaBackground,
    required this.ctaForeground,
    required this.gradient,
    required this.height,
    required this.isPrimary,
    required this.isCompact,
    required this.onTap,
  });

  final String title;
  final String description;
  final String compactDescription;
  final IconData icon;
  final AssetImage image;
  final Color accent;
  final Color titleColor;
  final Color descriptionColor;
  final Color ctaBackground;
  final Color ctaForeground;
  final Gradient gradient;
  final double height;
  final bool isPrimary;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withValues(alpha: 0.08)
                  : _kHomeBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: (isPrimary ? _kHomeDarkGreen : Colors.black)
                    .withValues(alpha: isPrimary ? 0.18 : 0.055),
                blurRadius: isPrimary ? 24 : 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: isCompact
                ? _CompactOrderMethodContent(
                    title: title,
                    description: compactDescription,
                    icon: icon,
                    image: image,
                    titleColor: titleColor,
                    descriptionColor: descriptionColor,
                    accent: accent,
                    ctaBackground: ctaBackground,
                    ctaForeground: ctaForeground,
                    isPrimary: isPrimary,
                  )
                : _LargeOrderMethodContent(
                    title: title,
                    description: description,
                    icon: icon,
                    image: image,
                    titleColor: titleColor,
                    descriptionColor: descriptionColor,
                    accent: accent,
                    ctaBackground: ctaBackground,
                    ctaForeground: ctaForeground,
                    isPrimary: isPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _LargeOrderMethodContent extends StatelessWidget {
  const _LargeOrderMethodContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.image,
    required this.titleColor,
    required this.descriptionColor,
    required this.accent,
    required this.ctaBackground,
    required this.ctaForeground,
    required this.isPrimary,
  });

  final String title;
  final String description;
  final IconData icon;
  final AssetImage image;
  final Color titleColor;
  final Color descriptionColor;
  final Color accent;
  final Color ctaBackground;
  final Color ctaForeground;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final imageWidth = isPrimary ? 94.0 : 86.0;
        final imageHeight = isPrimary ? 90.0 : 94.0;
        final textWidth = cardWidth - 32;

        return Stack(
          children: [
            Positioned(
              right: isPrimary ? -2 : 8,
              bottom: isPrimary ? -14 : 8,
              width: imageWidth,
              height: imageHeight,
              child: Image(
                image: image,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            Positioned(
              right: -28,
              bottom: -28,
              child: Icon(
                icon,
                size: 92,
                color: (isPrimary ? Colors.white : accent)
                    .withValues(alpha: isPrimary ? 0.055 : 0.065),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: textWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: textWidth,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              maxLines: 1,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16.8,
                                height: 1.08,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: descriptionColor,
                            fontSize: 11.8,
                            height: 1.24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ctaBackground,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: ctaForeground,
                        size: 25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompactOrderMethodContent extends StatelessWidget {
  const _CompactOrderMethodContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.image,
    required this.titleColor,
    required this.descriptionColor,
    required this.accent,
    required this.ctaBackground,
    required this.ctaForeground,
    required this.isPrimary,
  });

  final String title;
  final String description;
  final IconData icon;
  final AssetImage image;
  final Color titleColor;
  final Color descriptionColor;
  final Color accent;
  final Color ctaBackground;
  final Color ctaForeground;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isPrimary ? 0.94 : 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(5),
            child: Image(
              image: image,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                icon,
                color: accent,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: descriptionColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ctaBackground,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: ctaForeground,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

*/

class _ShimmerSkeleton extends StatefulWidget {
  const _ShimmerSkeleton({
    this.height,
    this.borderRadius = 16,
  });

  final double? height;
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
        final width = constraints.maxWidth;
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
              final offset = (_controller.value *
                  ((width.isFinite && width > 0)
                      ? width
                      : MediaQuery.of(context).size.width));
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

// ignore: unused_element
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.onTrack});

  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _HomeBreakpoints.compact;
        final cardHeight = isCompact ? 128.0 : 108.0;
        final trackButtonMaxWidth = isCompact ? 96.0 : 126.0;

        return Container(
          height: cardHeight,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FCF9), Color(0xFFFFFFFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 28,
                top: 2,
                child: CustomPaint(
                  size: const Size(160, 38),
                  painter: _OrderRoutePainter(),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Faol buyurtma',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: titleColor,
                            fontSize: 12,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#12543',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF697386),
                            fontSize: 12,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kuryer yo‘lda',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: primaryColor,
                            fontSize: 12,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Yetkazish vaqti: 20–25 daqiqa',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF697386),
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: trackButtonMaxWidth),
                    child: SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: onTrack,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Buyurtmani kuzatish',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.72)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.1,
        size.width * 0.34,
        size.height * 0.1,
        size.width * 0.48,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.68,
        size.height,
        size.width * 0.72,
        0,
        size.width,
        size.height * 0.26,
      );
    canvas.drawPath(path, paint);
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dot = Offset(size.width * 0.43, size.height * 0.34);
    canvas.drawCircle(dot, 6, dotPaint);
    canvas.drawCircle(dot, 6, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeMenuPreview extends StatefulWidget {
  const _HomeMenuPreview({
    super.key,
    required this.onViewAll,
    required this.onCategorySelected,
  });

  final VoidCallback onViewAll;
  final ValueChanged<String?> onCategorySelected;

  @override
  State<_HomeMenuPreview> createState() => _HomeMenuPreviewState();
}

class _HomeMenuPreviewState extends State<_HomeMenuPreview> {
  final CatalogRepository _catalogRepository = CatalogRepository.instance;
  final BranchState _branchState = BranchState.instance;
  final ScrollController _productsController =
      ScrollController(keepScrollOffset: false);

  late Branch _activeBranch;
  List<CatalogCategory> _categories = const [];
  List<_OfferEntry> _entries = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _catalogLoadVersion = 0;

  @override
  void initState() {
    super.initState();
    _activeBranch = _branchState.activeBranch;
    _branchState.addListener(_handleBranchChange);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _applyCachedCatalog();
      await _loadCatalog();
    });
  }

  @override
  void dispose() {
    _branchState.removeListener(_handleBranchChange);
    _productsController.dispose();
    super.dispose();
  }

  void _handleBranchChange() {
    final branch = _branchState.activeBranch;
    if (!mounted || branch.id == _activeBranch.id) return;
    setState(() {
      _activeBranch = branch;
    });
    _reloadForBranch();
  }

  Future<void> _reloadForBranch() async {
    await _applyCachedCatalog();
    await _loadCatalog();
  }

  Future<void> refreshCatalog() => _loadCatalog(forceRefresh: true);

  Future<void> _applyCachedCatalog() async {
    final cached = await _catalogRepository.getCachedCatalog();
    if (!mounted || cached == null) return;
    _applyPayload(cached, isLoading: false);
  }

  Future<void> _loadCatalog({bool forceRefresh = false}) async {
    if (!mounted) return;
    final loadVersion = ++_catalogLoadVersion;
    setState(() {
      if (_entries.isEmpty || forceRefresh) {
        _isLoading = true;
      }
      _errorMessage = null;
    });
    try {
      final payload = await _catalogRepository.loadCatalog(
        forceRefresh: forceRefresh,
      );
      if (!mounted || loadVersion != _catalogLoadVersion) return;
      _applyPayload(payload, isLoading: false);
    } catch (error) {
      if (!mounted || loadVersion != _catalogLoadVersion) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _applyPayload(CatalogPayload payload, {required bool isLoading}) {
    final storeId = _activeBranch.storeId ?? 0;
    final entries = <_OfferEntry>[];
    final visibleCategories = <CatalogCategory>[];

    for (final category in payload.categories) {
      var hasAvailableProduct = false;
      for (final item in category.items) {
        final price = _priceForStore(item, storeId);
        if (price == null || price.disabled) continue;
        hasAvailableProduct = true;
        entries.add(_OfferEntry(category: category, item: item, price: price));
      }
      if (hasAvailableProduct) {
        visibleCategories.add(category);
      }
    }

    setState(() {
      _categories = visibleCategories;
      _entries = _orderedHomeEntries(entries);
      _isLoading = isLoading;
      _errorMessage = null;
    });
  }

  List<_OfferEntry> _orderedHomeEntries(List<_OfferEntry> entries) {
    final entriesByCategory = <String, List<_OfferEntry>>{};
    final categoryById = <String, CatalogCategory>{};
    for (final entry in entries) {
      entriesByCategory.putIfAbsent(entry.category.id, () => []).add(entry);
      categoryById[entry.category.id] = entry.category;
    }

    final categoryIds = entriesByCategory.keys.toList();
    String? firstCoursesId;
    for (final categoryId in categoryIds) {
      final category = categoryById[categoryId]!;
      if (category.slug.toLowerCase().contains('pervye') ||
          category.name.toLowerCase().contains('первые блюда')) {
        firstCoursesId = categoryId;
        break;
      }
    }
    if (firstCoursesId != null) {
      categoryIds.remove(firstCoursesId);
    }

    final ordered = <_OfferEntry>[];
    final nextIndexByCategory = <String, int>{};
    void takeFrom(String? categoryId) {
      if (categoryId == null) return;
      final categoryEntries = entriesByCategory[categoryId];
      final nextIndex = nextIndexByCategory[categoryId] ?? 0;
      if (categoryEntries == null || nextIndex >= categoryEntries.length) {
        return;
      }
      ordered.add(categoryEntries[nextIndex]);
      nextIndexByCategory[categoryId] = nextIndex + 1;
    }

    while (ordered.length < entries.length) {
      takeFrom(firstCoursesId);
      for (final categoryId in categoryIds) {
        takeFrom(categoryId);
      }
      takeFrom(firstCoursesId);
    }
    return ordered;
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

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    required String section,
  }) {
    final l10n = AppLocalizations.of(context);
    return Row(
      key: ValueKey('home-$section-header'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        TextButton(
          key: ValueKey('home-$section-view-all'),
          onPressed: widget.onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: bodyTextColor,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.viewAll,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 22),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRu = l10n.locale == AppLocale.ru;

    if (_isLoading && _entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, l10n.homeMenuPreviewTitle,
              section: 'dishes'),
          const SizedBox(height: AppSpacing.related),
          const _PopularProductsSkeleton(),
          const SizedBox(height: AppSpacing.section),
          _buildSectionHeader(context, l10n.categoriesTitle,
              section: 'categories'),
          const SizedBox(height: AppSpacing.related),
          const _CategoryStripSkeleton(),
        ],
      );
    }

    if (_errorMessage != null && _entries.isEmpty) {
      return _OfferError(
        message: l10n.catalogLoadError,
        details: _errorMessage!,
        onRetry: () => _loadCatalog(forceRefresh: true),
      );
    }

    if (_entries.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Text(
          l10n.catalogEmpty,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: bodyTextColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    final products = _entries.take(6).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final cardWidth = (ProductDetailTokens.cardWidth *
                textScaler.scale(ProductDetailTokens.cardTitleSize) /
                ProductDetailTokens.cardTitleSize)
            .clamp(ProductDetailTokens.cardWidth, constraints.maxWidth);
        final imageHeight = cardWidth / ProductDetailTokens.cardAspectRatio;
        var priceHeight = 0.0;
        for (final entry in products) {
          final label = _formatPrice(entry.price.price, isRu);
          final separator = label.lastIndexOf(' ');
          final painter = TextPainter(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: ProductDetailTokens.cardPriceSize,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
              children: [
                TextSpan(text: label.substring(0, separator)),
                TextSpan(
                    text: label.substring(separator),
                    style: const TextStyle(
                      fontSize: ProductDetailTokens.cardPriceSize * 0.8,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
            maxLines: 2,
          )..layout(maxWidth: cardWidth - AppSpacing.section * 2);
          if (painter.height > priceHeight) priceHeight = painter.height;
          painter.dispose();
        }
        final productListHeight = imageHeight +
            AppSpacing.section * 2 +
            textScaler.scale(ProductDetailTokens.cardTitleSize) * 1.3 * 2 +
            AppSpacing.related +
            priceHeight;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, l10n.homeMenuPreviewTitle,
                section: 'dishes'),
            const SizedBox(height: AppSpacing.related),
            SizedBox(
              height: productListHeight,
              child: ListView.separated(
                key: ValueKey('home-products-${_activeBranch.id}'),
                controller: _productsController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final entry = products[index];
                  return _PopularProductCard(
                    entry: entry,
                    price: _formatPrice(entry.price.price, isRu),
                    width: cardWidth,
                    imageHeight: imageHeight,
                    onTap: () => _openDetails(entry),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            _buildSectionHeader(context, l10n.categoriesTitle,
                section: 'categories'),
            const SizedBox(height: AppSpacing.related),
            HomeCategoryStrip(
              categories: _categories,
              activeIndex: -1,
              onChanged: (index) =>
                  widget.onCategorySelected(_categories[index].id),
            ),
          ],
        );
      },
    );
  }
}

class _PopularProductCard extends StatelessWidget {
  const _PopularProductCard({
    required this.entry,
    required this.price,
    required this.width,
    required this.imageHeight,
    required this.onTap,
  });

  final _OfferEntry entry;
  final String price;
  final double width;
  final double imageHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = ProductDetailImages.recommendation(entry.item.images);
    return SizedBox(
      key: ValueKey('home-product-${entry.item.id}'),
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            decoration: BoxDecoration(
              color: ProductDetailTokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.card),
                  ),
                  child: SizedBox(
                    key: ValueKey('home-product-image-${entry.item.id}'),
                    height: imageHeight,
                    width: double.infinity,
                    child: _NetworkFoodImage(
                      imageUrl: imageUrl,
                      fallbackUrl:
                          ProductDetailImages.original(entry.item.images),
                      targetWidth: width,
                      fallbackIcon: Icons.restaurant_menu_rounded,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.section),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                            fontSize: ProductDetailTokens.cardTitleSize,
                            height: 1.3,
                          ),
                        ),
                        const Spacer(),
                        InlinePriceText(
                          label: price,
                          hasPrice: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                            fontSize: ProductDetailTokens.cardPriceSize,
                            height: 1.3,
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
      ),
    );
  }
}

class _NetworkFoodImage extends StatelessWidget {
  const _NetworkFoodImage({
    required this.imageUrl,
    required this.targetWidth,
    this.fallbackUrl,
    required this.fallbackIcon,
  });

  final String? imageUrl;
  final String? fallbackUrl;
  final double targetWidth;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _FoodImageFallback(icon: fallbackIcon);
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      cacheWidth: (targetWidth * MediaQuery.devicePixelRatioOf(context))
          .ceil()
          .clamp(1, ProductDetailTokens.cardDecodeWidth),
      errorBuilder: (_, __, ___) =>
          fallbackUrl != null && fallbackUrl != imageUrl
              ? _NetworkFoodImage(
                  imageUrl: fallbackUrl,
                  targetWidth: targetWidth,
                  fallbackIcon: fallbackIcon)
              : _FoodImageFallback(icon: fallbackIcon),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ShimmerSkeleton(borderRadius: 0);
      },
    );
  }
}

class _FoodImageFallback extends StatelessWidget {
  const _FoodImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F4F1),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: primaryColor.withValues(alpha: 0.55),
      ),
    );
  }
}

class _CategoryStripSkeleton extends StatelessWidget {
  const _CategoryStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return _ShimmerSkeleton(
      height: HomeCategoryStrip.heightFor(context),
      borderRadius: AppRadius.card,
    );
  }
}

class _PopularProductsSkeleton extends StatelessWidget {
  const _PopularProductsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 212,
      child: Row(
        children: const [
          Expanded(child: _ShimmerSkeleton(borderRadius: AppRadius.card)),
          SizedBox(width: 14),
          Expanded(child: _ShimmerSkeleton(borderRadius: AppRadius.card)),
        ],
      ),
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
            borderRadius: BorderRadius.circular(AppRadius.card),
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
            borderRadius: BorderRadius.circular(AppRadius.card),
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
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
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
          borderRadius: BorderRadius.circular(AppRadius.card),
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
          borderRadius: BorderRadius.circular(AppRadius.card),
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
          borderRadius: BorderRadius.circular(AppRadius.card),
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

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SignInScreen(
          destinationAfterLogin: EntryPoint(),
        ),
      ),
    );
    if (!mounted) return;
    _loadAccount();
  }

  String _formatAmount(double value, {required bool isRu}) {
    if (value.isNaN || value.isInfinite) return '0';
    final isNegative = value < 0;
    final absValue = value.abs();

    final isWhole = absValue == absValue.truncateToDouble();
    final raw =
        isWhole ? absValue.toStringAsFixed(0) : absValue.toStringAsFixed(1);

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
            ? _formatAmount(balanceValue, isRu: isRu)
            : '—';
    return PointsBalanceCard(
      cardKey: const ValueKey('home-bonus-card'),
      title: l10n.pointsTitle,
      balanceLabel: balanceLabel,
      balanceUnit:
          !_isLoading && balanceValue != null ? (isRu ? 'балл' : 'ball') : null,
      helper: _account == null ? l10n.pointsLoginRequired : l10n.pointsHelper,
      onTap: _account == null ? _openLogin : () => _openPoints(_account!),
    );
  }
}
