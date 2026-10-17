import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/models/catalog.dart';
import 'package:sardoba_app/screens/catalog/product_detail_images.dart';
import 'package:sardoba_app/screens/catalog/product_details_screen.dart';
import 'package:sardoba_app/services/favorite_products.dart';

void main() {
  const original = 'https://images.example.org/item.JPEG';
  const small = 'https://images.example.org/item-88x88x100.webp';
  const card = 'https://images.example.org/item-508x392x100.webp?version=2';
  test('renditions are selected by URL path regardless of order', () {
    expect(ProductDetailImages.original([small, card, original]), original);
    expect(ProductDetailImages.recommendation([small, original, card]), card);
    expect(ProductDetailImages.recommendation([small, original]), original);
    expect(ProductDetailImages.recommendation([small]), isNull);
    expect(
        ProductDetailImages.recommendation([
          'file:///item-508x392x100.webp',
          'https://images.example.org/item-508x392x100.webp.exe',
          original,
        ]),
        original);
  });

  CatalogItem item(String id, {bool disabled = false, bool missing = false}) =>
      CatalogItem(
          id: id,
          name: '$id Очень длинное название ресторанного блюда с гарниром',
          images: const [],
          prices: missing
              ? []
              : [
                  CatalogPrice(
                      storeId: 139235,
                      storeName: 'Sardoba_Geofizika',
                      price: 15000,
                      disabled: disabled)
                ]);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FavoriteProducts.instance.ensureInitialized();
  });

  Future<void> show(WidgetTester tester, Size size, double scale,
      {bool disabled = false, bool missing = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = [
      item('main', disabled: disabled, missing: missing),
      item('second'),
      item('third', disabled: true)
    ];
    await tester.pumpWidget(AppLocalizations(
        locale: AppLocale.ru,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(top: 59, bottom: 34)),
                child: child!),
            home: CatalogProductDetailsScreen(
                category: CatalogCategory(
                    id: 'salads', name: 'Салаты', slug: 'salads', items: items),
                initialItem: items.first))));
    await tester.pumpAndSettle();
  }

  for (final width in [390.0, 440.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final state in ['available', 'disabled', 'missing']) {
        testWidgets('$width at $scale text scale, $state', (tester) async {
          await show(tester, Size(width, 956), scale,
              disabled: state == 'disabled', missing: state == 'missing');
          final hero =
              tester.getRect(find.byKey(const ValueKey('product-hero')));
          expect(hero.left, 16);
          expect(hero.right, width - 16);
          expect(hero.width, hero.height);
          expect(
              tester
                  .getSize(find.byKey(const ValueKey('product-favorite')))
                  .width,
              greaterThanOrEqualTo(44));
          expect(tester.takeException(), isNull);
          await tester.drag(find.byKey(const ValueKey('product-detail-scroll')),
              const Offset(0, -900));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(
              find.byKey(const ValueKey('product-recommendations')),
              const Offset(-160, 0));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('related favorite preserves active item; card changes it',
      (tester) async {
    await show(tester, const Size(440, 956), 1);
    await tester
        .ensureVisible(find.byKey(const ValueKey('related-favorite-second')));
    await tester.tap(find.byKey(const ValueKey('related-favorite-second')));
    await tester.pumpAndSettle();
    expect(FavoriteProducts.instance.isFavorite('second'), isTrue);
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('product-title'))).data,
        startsWith('main'));
    await tester
        .ensureVisible(find.byKey(const ValueKey('related-open-second')));
    await tester.tap(find.byKey(const ValueKey('related-open-second')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('product-title'))).data,
        startsWith('second'));
    expect(tester.takeException(), isNull);
    await FavoriteProducts.instance.setFavorite('second', false);
  });
}
