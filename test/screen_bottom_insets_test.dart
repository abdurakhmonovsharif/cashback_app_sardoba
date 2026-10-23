import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/models/account.dart';
import 'package:sardoba_app/models/catalog.dart';
import 'package:sardoba_app/screens/catalog/product_details_screen.dart';
import 'package:sardoba_app/screens/profile/profile_information_screen.dart';
import 'package:sardoba_app/services/favorite_products.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FavoriteProducts.instance.ensureInitialized();
  });

  Future<void> show(WidgetTester tester, Widget screen, Size size,
      {double scale = 1, double bottomInset = 34, double keyboard = 0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AppLocalizations(
      locale: AppLocale.uz,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(
                top: 59, bottom: keyboard > 0 ? 0 : bottomInset),
            viewPadding: EdgeInsets.only(top: 59, bottom: bottomInset),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  final items = ['main', 'related']
      .map((id) => CatalogItem(
            id: id,
            name: '$id Uzun nomli taom va qo‘shimcha garnir',
            images: const [],
            prices: [
              CatalogPrice(
                  storeId: 139235,
                  storeName: 'Geofizika',
                  price: 25000,
                  disabled: false)
            ],
          ))
      .toList();

  for (final width in [320.0, 390.0, 440.0, 600.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('product viewport reaches bottom: $width / $scale',
          (tester) async {
        final size = Size(width, 956);
        await show(
            tester,
            CatalogProductDetailsScreen(
              category: CatalogCategory(
                  id: 'food', name: 'Taomlar', slug: 'food', items: items),
              initialItem: items.first,
            ),
            size,
            scale: scale);
        final scroll = find.byKey(const ValueKey('product-detail-scroll'));
        expect(tester.getRect(scroll).bottom, size.height);
        await tester.drag(scroll, const Offset(0, -3000));
        await tester.pumpAndSettle();
        final card =
            tester.getRect(find.byKey(const ValueKey('related-open-related')));
        expect(card.bottom, lessThanOrEqualTo(size.height - 34));
        expect(
            find
                .byKey(const ValueKey('related-favorite-related'))
                .hitTestable(),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final bottomInset in [0.0, 34.0]) {
    for (final keyboard in [0.0, 300.0]) {
      testWidgets(
          'profile edit reaches bottom: inset $bottomInset / keyboard $keyboard',
          (tester) async {
        const size = Size(320, 740);
        await show(
            tester,
            ProfileInformationScreen(
                account: Account(
              name: 'Sinov',
              phone: '998900000000',
            )),
            size,
            scale: 1.8,
            bottomInset: bottomInset,
            keyboard: keyboard);
        final scroll = find.byType(SingleChildScrollView);
        expect(tester.getRect(scroll).bottom, size.height - keyboard);
        await tester.drag(scroll, const Offset(0, -3000));
        await tester.pumpAndSettle();
        final deleteAction = find.text('Profilni o‘chirish');
        expect(deleteAction.hitTestable(), findsOneWidget);
        expect(
            tester.getRect(deleteAction).bottom,
            lessThanOrEqualTo(
                size.height - keyboard - (keyboard > 0 ? 0 : bottomInset)));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
