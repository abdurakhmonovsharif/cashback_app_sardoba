import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/models/branch.dart';
import 'package:sardoba_app/models/catalog.dart';
import 'package:sardoba_app/navigation/app_nav_bar_layout.dart';
import 'package:sardoba_app/screens/home/home_screen.dart';
import 'package:sardoba_app/screens/notifications/notifications_screen.dart';
import 'package:sardoba_app/screens/search/search_screen.dart';
import 'package:sardoba_app/services/auth_storage.dart';
import 'package:sardoba_app/services/branch_state.dart';
import 'package:sardoba_app/services/catalog_storage.dart';
import 'package:sardoba_app/services/notification_socket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final branchState = BranchState.instance;
  final originalBranch = branchState.activeBranch;
  final catalog = CatalogPayload.fromJson(jsonDecode(
    File('test/fixtures/catalog_navigation_snapshot.json').readAsStringSync(),
  ) as Map<String, dynamic>);
  const longBranchName =
      'Sardoba (Geofizika Buxoro markazidagi juda uzun filial nomi)';
  const displayedLongBranchName =
      'Sardoba Geofizika Buxoro markazidagi juda uzun filial nomi';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AuthStorage.instance.resetForTesting();
    await AuthStorage.instance.ensureInitialized();
    final fontLoader = FontLoader('SF Pro Text');
    for (final weight in ['Regular', 'Medium', 'Semibold', 'Bold']) {
      fontLoader.addFont(
        rootBundle.load('assets/font/SF Pro Text/SFProText-$weight.ttf'),
      );
    }
    await fontLoader.load();
  });

  setUp(() async {
    await CatalogStorage.instance.save(catalog);
  });

  tearDown(() async {
    branchState.selectBranch(originalBranch);
    await NotificationSocketManager.instance.stop();
  });

  Future<void> showHome(
    WidgetTester tester, {
    required AppLocale locale,
    required double width,
    required double textScale,
    bool useLongBranch = true,
  }) async {
    if (useLongBranch) {
      branchState.selectBranch(Branch(
        id: 'phase1-long-branch',
        storeId: originalBranch.storeId,
        name: longBranchName,
        address: originalBranch.address,
        point: originalBranch.point,
      ));
    }

    tester.view.physicalSize = Size(width, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AppLocalizations(
      locale: locale,
      child: MaterialApp(
        theme: ThemeData(
          platform: TargetPlatform.iOS,
          fontFamily: 'SF Pro Text',
        ),
        builder: (context, child) {
          final media = MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 47, bottom: 34),
            textScaler: TextScaler.linear(textScale),
          );
          return MediaQuery(
            data: media,
            child: AppNavBarViewport(child: child!),
          );
        },
        home: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder privateWidget(String name) => find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == name,
        description: name,
      );

  final widths = [320.0, 360.0, 390.0, 440.0, 600.0, 840.0];
  final scales = [1.0, 1.3, 2.0];

  for (final locale in [AppLocale.ru, AppLocale.uz]) {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets(
          'Header and Search ${locale.name} ${width.toInt()}dp text ${scale}x',
          (tester) async {
            await showHome(
              tester,
              locale: locale,
              width: width,
              textScale: scale,
            );

            final header = privateWidget('_HomeHeader');
            final search = privateWidget('_HomeSearchBar');
            final headerTexts = find.descendant(
              of: header,
              matching: find.byType(Text),
            );
            final label = headerTexts.first;
            final branchName = headerTexts.last;
            final hint = find.descendant(
              of: search,
              matching: find.byType(Text),
            );
            final labelStyle = tester.widget<Text>(label).style!;
            final labelWidget = tester.widget<Text>(label);
            final titleWidget = tester.widget<Text>(branchName);
            final titleStyle = titleWidget.style!;
            final hintWidget = tester.widget<Text>(hint);
            final hintStyle = hintWidget.style!;

            expect(labelStyle.fontSize, 12);
            expect(labelStyle.fontWeight, FontWeight.w400);
            expect(labelStyle.height, 15 / 12);
            if (scale == 1) {
              expect(labelWidget.maxLines, 1);
              expect(labelWidget.overflow, TextOverflow.ellipsis);
            } else {
              expect(labelWidget.maxLines, isNull);
              expect(labelWidget.overflow, isNull);
            }
            expect(titleStyle.fontSize, 17);
            expect(titleStyle.fontWeight, FontWeight.w600);
            expect(titleStyle.height, 22 / 17);
            expect(titleStyle.letterSpacing, 0);
            expect(hintStyle.fontSize,
                Theme.of(tester.element(hint)).textTheme.bodyLarge!.fontSize);
            expect(hintStyle.fontWeight, FontWeight.w400);
            expect(titleWidget.textScaler, isNull);
            expect(hintWidget.textScaler, isNull);
            expect(
              MediaQuery.textScalerOf(tester.element(hint)).scale(15),
              closeTo(15 * scale, 0.001),
            );

            if (scale == 1) {
              expect(titleWidget.maxLines, 1);
              expect(titleWidget.overflow, TextOverflow.ellipsis);
            } else {
              expect(titleWidget.maxLines, isNull);
              expect(titleWidget.overflow, isNull);
            }

            final titleParagraph = tester.renderObject<RenderParagraph>(
              branchName,
            );
            final labelParagraph = tester.renderObject<RenderParagraph>(label);
            final hintParagraph = tester.renderObject<RenderParagraph>(hint);
            expect(titleParagraph.text.toPlainText(), displayedLongBranchName);
            if (scale > 1) {
              expect(labelParagraph.didExceedMaxLines, isFalse);
              expect(titleParagraph.didExceedMaxLines, isFalse);
            }
            final semantics = tester.ensureSemantics();
            try {
              expect(
                tester.getSemantics(branchName).label,
                contains(displayedLongBranchName),
              );
              expect(
                tester
                    .getSemantics(branchName)
                    .getSemanticsData()
                    .hasAction(SemanticsAction.tap),
                isTrue,
              );
              expect(
                tester
                    .getSemantics(hint)
                    .getSemanticsData()
                    .hasAction(SemanticsAction.tap),
                isTrue,
              );
            } finally {
              semantics.dispose();
            }
            expect(hintParagraph.size.height,
                lessThanOrEqualTo(tester.getSize(search).height));

            final headerRect = tester.getRect(header);
            final searchRect = tester.getRect(search);
            final notification = privateWidget('_HeaderActionButton');
            final notificationRect = tester.getRect(notification);
            final branchTarget = find
                .descendant(of: header, matching: find.byType(InkWell))
                .first;
            final branchTargetRect = tester.getRect(branchTarget);
            final expectedInset = width >= 600 ? 40.0 : 16.0;
            expect(searchRect.height, greaterThanOrEqualTo(48));
            expect(searchRect.left, closeTo(expectedInset, 0.5));
            expect(searchRect.right, closeTo(width - expectedInset, 0.5));
            expect(searchRect.top - headerRect.bottom, closeTo(8, 0.5));
            expect(notificationRect.width, 48);
            expect(notificationRect.height, 48);
            expect(branchTargetRect.width, greaterThanOrEqualTo(44));
            expect(branchTargetRect.height, greaterThanOrEqualTo(44));
            expect(
              branchTargetRect.right,
              lessThanOrEqualTo(notificationRect.left - 12 + 0.5),
            );
            expect(
                notificationRect.left, greaterThanOrEqualTo(headerRect.left));
            expect(tester.takeException(), isNull);

            await tester.tap(search);
            await tester.pumpAndSettle();
            final searchField = find.byType(TextField).first;
            const longQuery =
                'long search query with enough words to exceed the visible input width';
            await tester.enterText(searchField, longQuery);
            await tester.pump(const Duration(milliseconds: 500));
            expect(
              tester.widget<TextField>(searchField).controller!.text,
              longQuery,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final locale in [AppLocale.ru, AppLocale.uz]) {
    testWidgets('Header branch, notification and Search actions ${locale.name}',
        (tester) async {
      final strings = AppStrings(locale);
      await showHome(
        tester,
        locale: locale,
        width: 390,
        textScale: 1,
        useLongBranch: false,
      );

      final header = privateWidget('_HomeHeader');
      final title = find
          .descendant(
            of: header,
            matching: find.byType(Text),
          )
          .last;
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text(strings.changeBranch), findsOneWidget);
      final nextBranch = branchState.branches[1];
      await tester.tap(find.text(nextBranch.name));
      await tester.pumpAndSettle();
      expect(find.text('Sardoba Gʻijdivon'), findsOneWidget);

      await tester.tap(find.byTooltip(strings.notificationsTitle));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(NotificationsScreen))).pop();
      await tester.pumpAndSettle();

      final search = privateWidget('_HomeSearchBar');
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      final query = List.filled(24, 'long').join(' ');
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pumpAndSettle();
      expect(find.byType(TextField).first, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
