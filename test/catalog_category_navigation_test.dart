import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/components/floating_nav_bar.dart';
import 'package:sardoba_app/components/inline_price_text.dart';
import 'package:sardoba_app/entry_point.dart';
import 'package:sardoba_app/models/catalog.dart';
import 'package:sardoba_app/screens/catalog/catalog_screen.dart';
import 'package:sardoba_app/screens/home/components/home_banner_carousel.dart';
import 'package:sardoba_app/screens/home/components/home_category_strip.dart';
import 'package:sardoba_app/screens/home/home_screen.dart';
import 'package:sardoba_app/screens/search/search_screen.dart';
import 'package:sardoba_app/services/auth_storage.dart';
import 'package:sardoba_app/services/catalog_storage.dart';
import 'package:sardoba_app/services/notification_socket_service.dart';

void main() {
  // Real public catalog snapshot captured on 2026-10-14, limited to one item
  // in each of four categories. No invented products or prices enter the app.
  final payload = CatalogPayload.fromJson(jsonDecode(
    File('test/fixtures/catalog_navigation_snapshot.json').readAsStringSync(),
  ) as Map<String, dynamic>);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AuthStorage.instance.resetForTesting();
    await AuthStorage.instance.ensureInitialized();
  });

  setUp(() async {
    await CatalogStorage.instance.save(payload);
  });

  Future<void> showScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AppLocalizations(
      locale: AppLocale.uz,
      child: MaterialApp(home: screen),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> showHomeWithNav(
    WidgetTester tester, {
    required Size viewport,
    required EdgeInsets safePadding,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AppLocalizations(
      locale: AppLocale.uz,
      child: MaterialApp(
        home: Builder(builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: safePadding,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Stack(children: [
              const HomeScreen(),
              Align(
                alignment: Alignment.bottomCenter,
                child: FloatingNavBar(
                  selectedIndex: 0,
                  onItemSelected: (_) {},
                  onQrPressed: () {},
                ),
              ),
            ]),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder product(CatalogCategory category) => find.byKey(ValueKey(
        'catalog-product-${category.id}-${category.items.first.id}',
      ));

  ChoiceChip selectedChip(WidgetTester tester) => tester
      .widgetList<ChoiceChip>(find.byType(ChoiceChip))
      .singleWhere((chip) => chip.selected);

  ScrollPosition homeScrollPosition(WidgetTester tester) {
    final homeScroll = find.descendant(
      of: find.byType(HomeScreen),
      matching: find.byType(SingleChildScrollView),
    );
    final scrollable = find
        .descendant(
          of: homeScroll,
          matching: find.byType(Scrollable),
        )
        .first;
    return tester.state<ScrollableState>(scrollable).position;
  }

  testWidgets(
      'Home category opens its products instead of filtering the preview',
      (tester) async {
    final category = payload.categories[1];
    await showScreen(tester, const HomeScreen());
    expect(
      find.text(payload.categories[2].items.first.name),
      findsOneWidget,
      reason:
          'Home should feature a product from Первые блюда, not only salads.',
    );
    final categoryTile = find.descendant(
      of: find.byType(HomeCategoryStrip),
      matching: find.text(category.name),
    );
    await tester.ensureVisible(categoryTile);
    await tester.tap(categoryTile);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CatalogScreen>(find.byType(CatalogScreen))
            .initialCategoryId,
        category.id);
    expect(product(category), findsOneWidget);
    expect(product(payload.categories.first), findsNothing);
    expect((selectedChip(tester).label as Text).data, category.name);
    Navigator.of(tester.element(find.byType(CatalogScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomeCategoryStrip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home category strip contains only real categories',
      (tester) async {
    await showScreen(tester, const HomeScreen());
    expect(
      find.descendant(
        of: find.byType(HomeCategoryStrip),
        matching: find.text('Barchasi'),
      ),
      findsNothing,
    );
    for (final category in payload.categories.take(3)) {
      expect(
        find.descendant(
          of: find.byType(HomeCategoryStrip),
          matching: find.text(category.name),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Home uses honest dish and category headings', (tester) async {
    await showScreen(tester, const HomeScreen());
    expect(find.text('Menyudan'), findsOneWidget);
    expect(find.text('Kategoriyalar'), findsOneWidget);
    expect(find.text('Mashhur taomlar'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('home-categories-view-all')),
    );
    await tester.tap(find.byKey(const ValueKey('home-categories-view-all')));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 375.0, 390.0, 430.0]) {
    testWidgets('Home aligns the first product at ${width.toInt()}dp',
        (tester) async {
      await showHomeWithNav(
        tester,
        viewport: Size(width, 812),
        safePadding: const EdgeInsets.only(top: 47, bottom: 34),
      );

      final firstProduct = find.byKey(
        ValueKey('home-product-${payload.categories[2].items.first.id}'),
      );
      final firstRect = tester.getRect(firstProduct);
      final bannerRect = tester.getRect(find.byType(HomeBannerCarousel));
      final imageRect = tester.getRect(find.byKey(
        ValueKey('home-product-image-${payload.categories[2].items.first.id}'),
      ));
      expect(firstRect.left, closeTo(16, 0.5));
      expect(bannerRect.left, closeTo(16, 0.5));
      expect(bannerRect.right, closeTo(width - 16, 0.5));
      expect(firstRect.right, lessThan(width - 16));
      expect(imageRect.width / imageRect.height, closeTo(508 / 392, 0.01));
      final prices = find.byType(InlinePriceText);
      expect(tester.getRect(prices.at(0)).bottom,
          closeTo(tester.getRect(prices.at(1)).bottom, 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (viewport: const Size(320, 568), scale: 2.0),
    (viewport: const Size(375, 812), scale: 2.0),
    (viewport: const Size(430, 932), scale: 2.0),
  ]) {
    testWidgets('Home remains usable at ${scenario.viewport} with large text',
        (tester) async {
      await showHomeWithNav(
        tester,
        viewport: scenario.viewport,
        safePadding: const EdgeInsets.only(top: 24, bottom: 34),
        textScale: scenario.scale,
      );
      final scrollPosition = homeScrollPosition(tester);
      scrollPosition.jumpTo(scrollPosition.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(HomeCategoryStrip)).bottom,
          lessThan(tester.getRect(find.byType(FloatingNavBar)).top));
    });
  }

  testWidgets('first dish price scrolls clear of the nav at 375x812',
      (tester) async {
    await showHomeWithNav(
      tester,
      viewport: const Size(375, 812),
      safePadding: const EdgeInsets.only(top: 47, bottom: 34),
    );
    final firstProduct = find.byKey(
      ValueKey('home-product-${payload.categories[2].items.first.id}'),
    );
    final price = find.descendant(
      of: firstProduct,
      matching: find.text("45 000 so'm", findRichText: true),
    );
    expect(find.descendant(of: firstProduct, matching: find.text('Хаш')),
        findsOneWidget);
    expect(price, findsOneWidget);
    final position = homeScrollPosition(tester);
    final navTop = tester.getRect(find.byType(FloatingNavBar)).top;
    final requiredScroll = tester.getRect(price).bottom - navTop + 16;
    position.jumpTo(requiredScroll.clamp(0, position.maxScrollExtent));
    await tester.pumpAndSettle();
    expect(tester.getRect(price).bottom,
        lessThan(tester.getRect(find.byKey(const ValueKey('nav-panel'))).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull-to-refresh reapplies the latest branch catalog order',
      (tester) async {
    await showScreen(tester, const HomeScreen());
    final salad = find.byKey(
      ValueKey('home-product-${payload.categories.first.items.first.id}'),
    );
    final snack = find.byKey(
      ValueKey('home-product-${payload.categories[1].items.first.id}'),
    );
    expect(tester.getRect(salad).left, lessThan(tester.getRect(snack).left));

    await CatalogStorage.instance.save(CatalogPayload(
      success: true,
      categories: payload.categories.reversed.toList(),
    ));
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, 300));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.getRect(snack).left, lessThan(tester.getRect(salad).left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home banner opens the real Menu screen', (tester) async {
    await showScreen(tester, const HomeScreen());
    await tester.tap(find.text('Birlashtiradigan taʼm'));
    await tester.pumpAndSettle();

    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home sections clear the floating navigation at scroll end',
      (tester) async {
    addTearDown(NotificationSocketManager.instance.stop);
    await showScreen(tester, const EntryPoint());
    unawaited(NotificationSocketManager.instance.stop());
    await tester.pump(const Duration(seconds: 9));

    final scrollPosition = homeScrollPosition(tester);
    scrollPosition.jumpTo(scrollPosition.maxScrollExtent);
    await tester.pumpAndSettle();

    final firstProduct = find.text(payload.categories[2].items.first.name);
    expect(firstProduct, findsOneWidget);
    expect(
      tester.getRect(firstProduct).bottom,
      lessThan(tester.getRect(find.byType(FloatingNavBar)).top),
    );
    expect(
      tester.getRect(find.byType(HomeCategoryStrip)).bottom,
      lessThan(tester.getRect(find.byType(FloatingNavBar)).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Home banner precedes points and price remains reachable at 375x812',
      (tester) async {
    await showHomeWithNav(
      tester,
      viewport: const Size(375, 812),
      safePadding: const EdgeInsets.only(top: 47, bottom: 34),
    );

    final price = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data ?? widget.textSpan?.toPlainText() ?? '')
                    .endsWith("so'm"),
          ),
        )
        .first;
    final banner = tester.getRect(find.byType(HomeBannerCarousel));
    final points =
        tester.getRect(find.byKey(const ValueKey('home-bonus-card')));
    final navTop = tester.getRect(find.byType(FloatingNavBar)).top;
    expect(banner.bottom, lessThan(points.top));
    expect(points.bottom, lessThan(navTop));

    final scrollPosition = homeScrollPosition(tester);
    final requiredScroll = tester.getRect(price).bottom - navTop + 16;
    scrollPosition
        .jumpTo(requiredScroll.clamp(0, scrollPosition.maxScrollExtent));
    await tester.pumpAndSettle();
    expect(tester.getRect(price).bottom, lessThan(navTop - 8));
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      name: '320x568 large text',
      viewport: const Size(320, 568),
      safePadding: const EdgeInsets.only(top: 24, bottom: 16),
      textScale: 2.0,
    ),
    (
      name: '812x375 landscape',
      viewport: const Size(812, 375),
      safePadding: const EdgeInsets.only(bottom: 21),
      textScale: 1.5,
    ),
  ]) {
    testWidgets('Home remains scrollable at ${scenario.name}', (tester) async {
      await showHomeWithNav(
        tester,
        viewport: scenario.viewport,
        safePadding: scenario.safePadding,
        textScale: scenario.textScale,
      );

      final scrollPosition = homeScrollPosition(tester);
      scrollPosition.jumpTo(scrollPosition.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(HomeCategoryStrip)).bottom,
        lessThan(tester.getRect(find.byType(FloatingNavBar)).top),
      );
    });
  }

  testWidgets(
      'shell selects Menu and back returns to Home after category entry',
      (tester) async {
    addTearDown(NotificationSocketManager.instance.stop);
    await showScreen(tester, const EntryPoint());
    // The widget test exercises navigation, not the unrelated socket service.
    unawaited(NotificationSocketManager.instance.stop());
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('QR orqali to‘lash'), findsNothing);
    expect(find.byKey(const ValueKey('nav-qr')), findsOneWidget);
    final category = payload.categories[1];
    final categoryTile = find.descendant(
      of: find.byType(HomeCategoryStrip),
      matching: find.text(category.name),
    );
    await tester.ensureVisible(categoryTile);
    await tester.tap(categoryTile);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FloatingNavBar>(find.byType(FloatingNavBar))
            .selectedIndex,
        1);
    expect(product(category), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeCategoryStrip), findsOneWidget);
    expect(
        tester
            .widget<FloatingNavBar>(find.byType(FloatingNavBar))
            .selectedIndex,
        0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category ID survives reordered cached categories',
      (tester) async {
    final category = payload.categories[2];
    await CatalogStorage.instance.save(CatalogPayload(
      success: true,
      categories: payload.categories.reversed.toList(),
    ));
    await showScreen(tester, CatalogScreen(initialCategoryId: category.id));
    expect(product(category), findsOneWidget);
    expect(product(payload.categories.first), findsNothing);
    final chip = find.byWidget(selectedChip(tester));
    expect(tester.getRect(chip).left, greaterThanOrEqualTo(16));
    expect(tester.getRect(chip).right, lessThanOrEqualTo(359));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menu header search opens the search screen', (tester) async {
    await showScreen(
        tester, CatalogScreen(initialCategoryId: payload.categories.first.id));

    await tester
        .tap(find.byTooltip(const AppStrings(AppLocale.uz).searchAction));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an updated category argument replaces an already mounted filter',
      (tester) async {
    await showScreen(
        tester, CatalogScreen(initialCategoryId: payload.categories.first.id));
    expect(product(payload.categories.first), findsOneWidget);
    await showScreen(
        tester, CatalogScreen(initialCategoryId: payload.categories[1].id));
    expect(product(payload.categories[1]), findsOneWidget);
    expect(product(payload.categories.first), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'missing category does not display products from another category',
      (tester) async {
    final category = payload.categories.last;
    await CatalogStorage.instance.save(CatalogPayload(
      success: true,
      categories: payload.categories.take(3).toList(),
    ));
    await showScreen(tester, CatalogScreen(initialCategoryId: category.id));
    for (final candidate in payload.categories) {
      expect(product(candidate), findsNothing);
    }
    expect(
        find.text(const AppStrings(AppLocale.uz).catalogEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
