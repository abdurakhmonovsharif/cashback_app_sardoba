import 'dart:ui' show Tristate;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/models/catalog.dart';
import 'package:sardoba_app/screens/home/components/home_category_strip.dart';

void main() {
  // Category labels from the existing catalog; no API or product-price stubs.
  final categories = ['Салаты', 'Закуски', 'Первые блюда']
      .map((name) => CatalogCategory(
            id: name,
            name: name,
            slug: name,
            items: const [],
          ))
      .toList();

  Future<void> showStrip(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var activeIndex = -1;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(builder: (context, setState) {
                return HomeCategoryStrip(
                  categories: categories,
                  activeIndex: activeIndex,
                  onChanged: (index) => setState(() => activeIndex = index),
                );
              }),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('category selection exposes full labels and selected state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await showStrip(tester, const Size(375, 812), 1);
      expect(find.text('Barchasi'), findsNothing);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Салаты'))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      await tester.tap(find.text('Салаты'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Салаты'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('category uses and caches the third product image',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final salad = CatalogCategory(
      id: 'salads',
      name: 'Салаты',
      slug: 'salaty',
      thumbnail: 'https://example.com/category-thumbnail.jpg',
      items: [
        CatalogItem(
          id: 'product-1',
          name: 'Биринчи маҳсулот',
          prices: const [],
          images: const [
            'https://example.com/first-1.jpg',
            'https://example.com/first-2.jpg',
            'https://example.com/first-3.jpg',
          ],
        ),
        CatalogItem(
          id: 'product-2',
          name: 'Иккинчи маҳсулот',
          prices: const [],
          images: const [
            'https://example.com/second-1.jpg',
            'https://example.com/second-2.jpg',
            'https://example.com/second-3.jpg',
          ],
        ),
        CatalogItem(
          id: 'product-3',
          name: 'Учинчи маҳсулот',
          prices: const [],
          images: const [
            'https://example.com/third-1.jpg',
            'https://example.com/third-2.jpg',
            'https://example.com/third-3.jpg',
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeCategoryStrip(
          categories: [salad],
          activeIndex: -1,
          onChanged: (_) {},
        ),
      ),
    ));

    final cachedImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(cachedImage.imageUrl, 'https://example.com/third-3.jpg');
    expect(cachedImage.memCacheWidth, 64);
    final card = find.descendant(
      of: find.byType(HomeCategoryStrip),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(card).width, 112);
    expect(tester.getSize(card).height, 126);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one and two-line labels keep image and label top edges aligned',
      (tester) async {
    await showStrip(tester, const Size(440, 956), 1);
    final first = tester
        .getRect(find.byKey(const ValueKey('home-category-image-Салаты')));
    final third = tester.getRect(
        find.byKey(const ValueKey('home-category-image-Первые блюда')));
    expect(first.size, const Size(64, 64));
    expect(third.size, first.size);
    expect(first.top, third.top);
    expect(tester.getTopLeft(find.text('Салаты')).dy,
        tester.getTopLeft(find.text('Первые блюда')).dy);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0),
    (size: const Size(375, 812), scale: 2.0),
    (size: const Size(440, 956), scale: 3.0),
    (size: const Size(812, 375), scale: 2.0),
  ]) {
    testWidgets('categories fit ${scenario.size} at ${scenario.scale}x text',
        (tester) async {
      await showStrip(tester, scenario.size, scenario.scale);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Первые блюда'),
        150,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Первые блюда'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(HomeCategoryStrip)).height,
          lessThan(scenario.size.height - 32));
    });
  }
}
