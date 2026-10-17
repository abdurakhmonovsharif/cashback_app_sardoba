import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/constants.dart';
import 'package:sardoba_app/screens/home/components/home_banner_carousel.dart';

void main() {
  Future<void> showCarousel(
    WidgetTester tester, {
    Size size = const Size(375, 812),
    double textScale = 1,
    bool reduceMotion = false,
    Brightness brightness = Brightness.light,
    VoidCallback? onOpenMenu,
    AppLocale locale = AppLocale.ru,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AppLocalizations(
      locale: locale,
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: brightness,
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: HomeBannerCarousel(onOpenMenu: onOpenMenu ?? () {}),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  PageController pageController(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;

  testWidgets('real banner opens the menu destination', (tester) async {
    var menuOpens = 0;
    await showCarousel(tester, onOpenMenu: () => menuOpens++);

    expect(find.text('Вкус, который объединяет'), findsOneWidget);
    await tester.tap(find.text('Смотреть меню'));
    expect(menuOpens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carousel advances automatically without a play control',
      (tester) async {
    await showCarousel(tester);
    final controller = pageController(tester);
    final initialPage = controller.page!;

    expect(find.byKey(const ValueKey('banner-autoplay')), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);

    await tester.pump(HomeBannerCarousel.autoplayInterval);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.page, greaterThan(initialPage));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion stops autoplay but allows swiping',
      (tester) async {
    await showCarousel(tester, reduceMotion: true);
    final controller = pageController(tester);
    final initialPage = controller.page!;

    await tester.pump(const Duration(seconds: 6));
    expect(controller.page, initialPage);
    expect(find.byKey(const ValueKey('banner-autoplay')), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(controller.page, greaterThan(initialPage));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard arrow moves between banners', (tester) async {
    await showCarousel(tester, reduceMotion: true);
    final controller = pageController(tester);
    final initialPage = controller.page!;

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(controller.page, initialPage + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner has accessible tap targets', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await showCarousel(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('all banner copy fits at 320dp in both languages',
      (tester) async {
    for (final locale in AppLocale.values) {
      await showCarousel(
        tester,
        size: const Size(320, 568),
        locale: locale,
      );
      final strings = AppStrings(locale);
      for (var index = 0; index < HomeBannerCarousel.slideCount; index++) {
        pageController(tester).jumpToPage(999 + index);
        await tester.pump();
        final title = tester.renderObject<RenderParagraph>(
          find.text(strings.homeBannerTitle(index)),
        );
        final subtitle = tester.renderObject<RenderParagraph>(
          find.text(strings.homeBannerSubtitle(index)),
        );
        expect(title.didExceedMaxLines, isFalse,
            reason: '${locale.name} title $index');
        expect(subtitle.didExceedMaxLines, isFalse,
            reason: '${locale.name} subtitle $index');
      }
      expect(tester.takeException(), isNull);
    }
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0, brightness: Brightness.light),
    (size: const Size(360, 780), scale: 1.0, brightness: Brightness.light),
    (size: const Size(320, 568), scale: 2.0, brightness: Brightness.light),
    (size: const Size(375, 812), scale: 1.0, brightness: Brightness.light),
    (size: const Size(390, 844), scale: 1.0, brightness: Brightness.light),
    (size: const Size(440, 900), scale: 1.0, brightness: Brightness.light),
    (size: const Size(430, 932), scale: 1.0, brightness: Brightness.light),
    (size: const Size(600, 900), scale: 1.0, brightness: Brightness.light),
    (size: const Size(840, 1000), scale: 1.0, brightness: Brightness.light),
    (size: const Size(1024, 900), scale: 1.0, brightness: Brightness.light),
    (size: const Size(800, 1280), scale: 2.0, brightness: Brightness.light),
    (size: const Size(1280, 800), scale: 1.0, brightness: Brightness.light),
    (size: const Size(1032, 1376), scale: 3.0, brightness: Brightness.light),
    (size: const Size(812, 375), scale: 1.5, brightness: Brightness.light),
    (size: const Size(375, 812), scale: 2.0, brightness: Brightness.dark),
    (size: const Size(320, 568), scale: 3.0, brightness: Brightness.dark),
  ]) {
    testWidgets('banner fits ${scenario.size} at ${scenario.scale}x',
        (tester) async {
      await showCarousel(
        tester,
        size: scenario.size,
        textScale: scenario.scale,
        brightness: scenario.brightness,
        locale: AppLocale.uz,
      );

      final banner = tester.getRect(
        find.byKey(const ValueKey('home-banner-carousel')),
      );
      final contentWidth = scenario.size.width - 32;
      final minimumHeight = math.max(
        150.0,
        contentWidth >= 360
            ? contentWidth / (contentWidth >= 600 ? 3 : 2.5)
            : 150.0,
      );
      expect(banner.height, greaterThanOrEqualTo(minimumHeight));
      expect(find.text('Sardoba'), findsWidgets);
      expect(
          find.text('Anʼanaviy taomlar. Haqiqiy taassurotlar.'), findsWidgets);
      expect(find.byKey(const ValueKey('banner-autoplay')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [600.0, 1280.0, 1366.0]) {
    testWidgets('banner uses the adaptive ratio at $width dp when copy fits',
        (tester) async {
      await showCarousel(
        tester,
        size: Size(width, 900),
        locale: AppLocale.uz,
      );
      final banner = tester.getRect(
        find.byKey(const ValueKey('home-banner-carousel')),
      );
      expect(banner.height,
          closeTo((width - 32) / (width - 32 >= 600 ? 3 : 2.5), 1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('Russian copy fits a 320dp banner at ${scale}x',
        (tester) async {
      await showCarousel(
        tester,
        size: const Size(320, 568),
        textScale: scale,
        locale: AppLocale.ru,
      );
      expect(find.text('Sardoba'), findsWidgets);
      expect(find.text('Традиционные блюда. Настоящие эмоции.'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
