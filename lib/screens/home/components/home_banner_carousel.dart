import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_localizations.dart';
import '../../../constants.dart';

class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({super.key, required this.onOpenMenu});

  final VoidCallback onOpenMenu;

  static const slideCount = 3;
  static const autoplayInterval = Duration(seconds: 5);

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel>
    with WidgetsBindingObserver {
  static const _initialPage = 999;
  static const _pageDuration = Duration(milliseconds: 450);
  static const _assets = [
    'assets/images/home_banners/soup.webp',
    'assets/images/home_banners/kebab.webp',
    'assets/images/home_banners/manti.webp',
  ];

  final PageController _pageController =
      PageController(initialPage: _initialPage);
  Timer? _autoplayTimer;
  int _page = _initialPage;
  bool _foreground = true;
  bool _focused = false;
  bool _hovered = false;
  bool _reduceMotion = false;
  bool _tickerEnabled = true;

  int get _activeIndex => _page % HomeBannerCarousel.slideCount;

  bool get _canAutoplay =>
      _foreground && !_focused && !_hovered && !_reduceMotion && _tickerEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _restartAutoplay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _restartAutoplay();
  }

  void _restartAutoplay() {
    _autoplayTimer?.cancel();
    if (!_canAutoplay) return;
    _autoplayTimer = Timer.periodic(
      HomeBannerCarousel.autoplayInterval,
      (_) => _goTo(_page + 1),
    );
  }

  void _goTo(int page) {
    if (!_pageController.hasClients) return;
    if (_reduceMotion) {
      _pageController.jumpToPage(page);
    } else {
      unawaited(_pageController.animateToPage(
        page,
        duration: _pageDuration,
        curve: Curves.easeInOutCubic,
      ));
    }
    _restartAutoplay();
  }

  double _textHeight(
    BuildContext context,
    String text,
    TextStyle style,
    double width, {
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: math.max(1, width));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double _requiredSlideHeight(
    BuildContext context,
    double width,
    bool accessibleLayout,
  ) {
    final strings = AppLocalizations.of(context);
    final metrics = _BannerMetrics(width, accessibleLayout);
    final compact = metrics.compact;
    final textWidth = width - metrics.padding - metrics.rightInset;
    final logoSize = metrics.logoSize;
    final brandHeight = math.max(
      logoSize,
      _textHeight(
        context,
        'Sardoba',
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 16 / 12,
        ),
        textWidth - logoSize - 5,
      ),
    );
    final ctaHeight = math.max(
      metrics.ctaMinHeight,
      _textHeight(
            context,
            accessibleLayout ? strings.navMenu : strings.homeBannerOpenMenu,
            metrics.ctaStyle,
            textWidth - 45,
          ) +
          (compact ? 10 : 14),
    );
    var requiredHeight = 0.0;
    for (var index = 0; index < HomeBannerCarousel.slideCount; index++) {
      final titleHeight = _textHeight(
        context,
        strings.homeBannerTitle(index),
        metrics.titleStyle,
        textWidth,
      );
      final subtitleHeight = _textHeight(
        context,
        strings.homeBannerSubtitle(index),
        metrics.subtitleStyle,
        textWidth,
      );
      requiredHeight = math.max(
        requiredHeight,
        metrics.padding * 2 +
            brandHeight +
            titleHeight +
            metrics.copyGap +
            subtitleHeight +
            ctaHeight +
            (metrics.tablet ? 32 : (compact ? 0 : 8)),
      );
    }
    // TextPainter and RenderParagraph can differ by a fraction of a pixel
    // after font fallback and line-height rounding. Keep a small safety margin
    // so the banner's own column never paints an overflow stripe.
    return requiredHeight + 12;
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final accessibleLayout =
        MediaQuery.textScalerOf(context).scale(16) / 16 > 1.25;

    return LayoutBuilder(builder: (context, constraints) {
      const baseHeight = 150.0;
      final metrics = _BannerMetrics(constraints.maxWidth, accessibleLayout);
      final ratioHeight = constraints.maxWidth >= 360
          ? constraints.maxWidth / (metrics.tablet ? 3 : 2.5)
          : baseHeight;
      final height = math.max(
        math.max(baseHeight, ratioHeight),
        _requiredSlideHeight(
          context,
          constraints.maxWidth,
          accessibleLayout,
        ),
      );

      return SizedBox(
        key: const ValueKey('home-banner-carousel'),
        height: height,
        child: MouseRegion(
          onEnter: (_) {
            _hovered = true;
            _restartAutoplay();
          },
          onExit: (_) {
            _hovered = false;
            _restartAutoplay();
          },
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _goTo(_page + 1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _goTo(_page - 1);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            onFocusChange: (focused) {
              _focused = focused;
              _restartAutoplay();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Stack(
                children: [
                  Semantics(
                    container: true,
                    value: strings.bannerSlide(
                      _activeIndex + 1,
                      HomeBannerCarousel.slideCount,
                    ),
                    increasedValue: strings.bannerSlide(
                      (_activeIndex + 1) % HomeBannerCarousel.slideCount + 1,
                      HomeBannerCarousel.slideCount,
                    ),
                    decreasedValue: strings.bannerSlide(
                      (_activeIndex + HomeBannerCarousel.slideCount - 1) %
                              HomeBannerCarousel.slideCount +
                          1,
                      HomeBannerCarousel.slideCount,
                    ),
                    onIncrease: () => _goTo(_page + 1),
                    onDecrease: () => _goTo(_page - 1),
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (page) {
                        setState(() => _page = page);
                        _restartAutoplay();
                      },
                      itemBuilder: (context, page) {
                        final index = page % HomeBannerCarousel.slideCount;
                        return _BannerSlide(
                          asset: _assets[index],
                          title: strings.homeBannerTitle(index),
                          subtitle: strings.homeBannerSubtitle(index),
                          lightBackground: index == 1,
                          accessibleLayout: accessibleLayout,
                          onOpenMenu: widget.onOpenMenu,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: accessibleLayout ? null : 0,
                    right: accessibleLayout ? 56 : 0,
                    bottom: accessibleLayout ? 16 : (metrics.tablet ? 12 : 8),
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(HomeBannerCarousel.slideCount,
                            (index) {
                          final isCurrent = index == _activeIndex;
                          final dotColor = _activeIndex == 1
                              ? const Color(0xFF07533D)
                              : Colors.white;
                          return AnimatedContainer(
                            duration: _reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isCurrent
                                ? (metrics.tablet ? 20 : 14)
                                : (metrics.tablet ? 8 : 6),
                            height: metrics.tablet ? 8 : 6,
                            decoration: BoxDecoration(
                              color: dotColor.withValues(
                                alpha: isCurrent ? 1 : 0.5,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Shared by text measurement and rendering so large text can grow the banner.
class _BannerMetrics {
  const _BannerMetrics(this.width, this.accessibleLayout);

  final double width;
  final bool accessibleLayout;

  bool get tablet => width >= 600;
  bool get compact => width < 320 && !accessibleLayout;
  double get padding => tablet ? (width >= 840 ? 32 : 24) : 16;
  double get rightInset => accessibleLayout
      ? padding
      : width * (tablet ? 0.45 : (compact ? 0.27 : 0.28));
  double get logoSize => tablet ? 28 : (compact ? 16 : 22);
  double get copyGap => tablet ? 8 : (compact ? 2 : 3);
  double get ctaMinHeight => tablet ? 48 : 44;
  TextStyle get titleStyle => TextStyle(
        fontSize: tablet ? (width >= 840 ? 32 : 28) : 17,
        height: tablet ? 1.2 : 22 / 17,
        fontWeight: FontWeight.w600,
      );
  TextStyle get subtitleStyle => TextStyle(
        fontSize: tablet ? 16 : 13,
        height: tablet ? 1.4 : 18 / 13,
        fontWeight: FontWeight.w400,
      );
  TextStyle get ctaStyle => TextStyle(
        fontSize: tablet ? 16 : 15,
        height: tablet ? 1.25 : 20 / 15,
        fontWeight: FontWeight.w600,
      );
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.lightBackground,
    required this.accessibleLayout,
    required this.onOpenMenu,
  });

  final String asset;
  final String title;
  final String subtitle;
  final bool lightBackground;
  final bool accessibleLayout;
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final foreground = lightBackground ? const Color(0xFF073E30) : Colors.white;

    return LayoutBuilder(builder: (context, constraints) {
      final metrics = _BannerMetrics(constraints.maxWidth, accessibleLayout);
      final brand = Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: metrics.logoSize,
              height: metrics.logoSize,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Sardoba',
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      );
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              softWrap: true,
              style: metrics.titleStyle.copyWith(color: foreground)),
          SizedBox(height: metrics.copyGap),
          Text(subtitle,
              softWrap: true,
              style: metrics.subtitleStyle.copyWith(
                color: foreground.withValues(alpha: 0.92),
              )),
        ],
      );
      final cta = ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.ctaMinHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.tablet ? 16 : 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    accessibleLayout
                        ? strings.navMenu
                        : strings.homeBannerOpenMenu,
                    softWrap: true,
                    style: metrics.ctaStyle.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            cacheWidth:
                (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .round(),
            errorBuilder: (_, __, ___) => ColoredBox(
                color: lightBackground
                    ? const Color(0xFFF6F1E6)
                    : const Color(0xFF004D37)),
          ),
          if (accessibleLayout)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (lightBackground
                            ? const Color(0xFFF6F1E6)
                            : const Color(0xFF003B2B))
                        .withValues(alpha: 0.97),
                    (lightBackground
                            ? const Color(0xFFF6F1E6)
                            : const Color(0xFF003B2B))
                        .withValues(alpha: 0.84),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.72, 1],
                ),
              ),
            ),
          Material(
            type: MaterialType.transparency,
            child: Semantics(
              button: true,
              label: '$title. $subtitle. ${strings.homeBannerOpenMenu}',
              onTap: onOpenMenu,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: onOpenMenu,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      metrics.padding,
                      metrics.padding,
                      metrics.rightInset,
                      metrics.padding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        brand,
                        if (metrics.tablet) ...[
                          const SizedBox(height: 16),
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  copy,
                                  const SizedBox(height: 16),
                                  cta
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          copy,
                          cta
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
