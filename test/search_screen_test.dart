import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/models/catalog.dart';
import 'package:sardoba_app/screens/search/search_screen.dart';
import 'package:sardoba_app/services/auth_storage.dart';
import 'package:sardoba_app/services/catalog_storage.dart';

void main() {
  final payload = CatalogPayload.fromJson(jsonDecode(
    File('test/fixtures/catalog_navigation_snapshot.json').readAsStringSync(),
  ) as Map<String, dynamic>);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AuthStorage.instance.resetForTesting();
    await AuthStorage.instance.ensureInitialized();
  });

  Future<void> showSearch(WidgetTester tester, Size size,
      {double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await CatalogStorage.instance.save(payload);
    await tester.pumpWidget(
      AppLocalizations(
        locale: AppLocale.ru,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('initial prompt fits compact and large iPhone layouts',
      (tester) async {
    await showSearch(tester, const Size(320, 640), textScale: 1.8);

    expect(find.text('Найдите блюдо в меню'), findsOneWidget);
    expect(find.text('Введите название блюда или напитка.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await showSearch(tester, const Size(430, 932));
    expect(find.text('Найдите блюдо в меню'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search results show category, item and price in one list',
      (tester) async {
    await showSearch(tester, const Size(390, 844));

    await tester.enterText(find.byType(TextField), 'Айран');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Найдено: 1'), findsOneWidget);
    expect(find.text('Айран (1л)'), findsOneWidget);
    expect(find.text('Салаты'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
