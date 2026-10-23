import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/components/floating_nav_bar.dart';
import 'package:sardoba_app/constants.dart';
import 'package:sardoba_app/navigation/app_nav_bar_layout.dart';

void main() {
  Future<void> showNav(
    WidgetTester tester, {
    Size size = const Size(375, 812),
    double scale = 1,
    AppLocale locale = AppLocale.uz,
    Brightness brightness = Brightness.light,
    bool reducedMotion = false,
    EdgeInsets safeArea = const EdgeInsets.only(bottom: 34),
    VoidCallback? onQrPressed,
    ValueChanged<int>? onTabSelected,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selectedIndex = 0;
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
            padding: safeArea,
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
          ),
          child: AppNavBarViewport(
              child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppNavBarLayout.maxWidth),
                child: StatefulBuilder(builder: (context, setState) {
                  return FloatingNavBar(
                    selectedIndex: selectedIndex,
                    onItemSelected: (index) {
                      setState(() => selectedIndex = index);
                      onTabSelected?.call(index);
                    },
                    onQrPressed: onQrPressed ?? () {},
                  );
                }),
              ),
            ),
          )),
        ),
      ),
    ));
  }

  testWidgets(
      'tabs have readable labels, selection semantics and stable indexes',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final selectedTabs = <int>[];
      await showNav(tester, onTabSelected: selectedTabs.add);
      expect(find.text('Asosiy'), findsOneWidget);
      expect(find.text('Filiallar'), findsOneWidget);
      expect(find.textContaining('Buyurtma'), findsNothing);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      for (final (label, index) in [
        ('Menyu', 1),
        ('Filiallar', 2),
        ('Profil', 3),
        ('Asosiy', 0),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final semanticLabel = index == 0 ? 'Bosh sahifa' : label;
        final selected =
            tester.getSemantics(find.bySemanticsLabel(semanticLabel));
        expect(selected.flagsCollection.isSelected, Tristate.isTrue);
        expect(selected.flagsCollection.isButton, isTrue);
      }
      expect(selectedTabs, [1, 2, 3, 0]);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Filiallar'))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('QR opens immediately as an action without selecting a tab',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var qrCalls = 0;
      final selectedTabs = <int>[];
      await showNav(tester,
          onQrPressed: () => qrCalls++, onTabSelected: selectedTabs.add);
      await tester.tap(find.text('QR-kod'));
      // The previous implementation waited for two animations before opening QR.
      expect(qrCalls, 1);
      expect(selectedTabs, isEmpty);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Mening QR-kodim'))
            .flagsCollection
            .isSelected,
        Tristate.none,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Bosh sahifa'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('raised QR stays centered above the navigation panel',
      (tester) async {
    await showNav(tester);

    final panel = tester.getRect(find.byKey(const ValueKey('nav-panel')));
    final qr = tester.getRect(find.byKey(const ValueKey('nav-qr-visual')));
    final nav = tester.getRect(find.byType(FloatingNavBar));

    expect(qr.top, lessThan(panel.top));
    expect(qr.center.dx, closeTo(panel.center.dx, 0.5));
    expect(qr.width, 60);
    expect(panel.bottom, lessThan(nav.bottom));
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0),
    (size: const Size(375, 812), scale: 1.0),
    (size: const Size(375, 812), scale: 2.0),
    (size: const Size(375, 812), scale: 3.2),
    (size: const Size(440, 956), scale: 3.2),
    (size: const Size(600, 960), scale: 2.0),
    (size: const Size(812, 375), scale: 2.0),
    (size: const Size(768, 1024), scale: 1.0),
    (size: const Size(1024, 768), scale: 2.0),
  ]) {
    testWidgets('nav fits ${scenario.size} at ${scenario.scale}x in UZ and RU',
        (tester) async {
      for (final locale in AppLocale.values) {
        final isLandscape = scenario.size.width > scenario.size.height;
        final safeArea = isLandscape
            ? const EdgeInsets.fromLTRB(44, 0, 44, 21)
            : const EdgeInsets.only(bottom: 34);
        await showNav(
          tester,
          size: scenario.size,
          scale: scenario.scale,
          locale: locale,
          safeArea: safeArea,
        );
        expect(tester.takeException(), isNull);
        final navContext = tester.element(find.byType(FloatingNavBar));
        final layout = AppNavBarLayout.of(navContext);
        final navRect = tester.getRect(find.byType(FloatingNavBar));
        expect(navAwareBottomPadding(navContext), navRect.height);
        expect(navRect.top, greaterThan(0));
        for (final label in layout.labels) {
          final textFinder = find.text(label);
          final text = tester.widget<Text>(textFinder);
          expect(text.style!.fontSize, 12);
          expect(text.overflow, isNot(TextOverflow.ellipsis));
          final paragraph = tester.renderObject<RenderParagraph>(textFinder);
          expect(paragraph.didExceedMaxLines, isFalse);
          final rect = tester.getRect(textFinder);
          expect(rect.left, greaterThanOrEqualTo(navRect.left + safeArea.left));
          expect(rect.right, lessThanOrEqualTo(navRect.right - safeArea.right));
          expect(
              rect.bottom, lessThanOrEqualTo(navRect.bottom - safeArea.bottom));
        }
        for (final key in [
          'nav-tab-0',
          'nav-tab-1',
          'nav-qr',
          'nav-tab-2',
          'nav-tab-3'
        ]) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        await tester.tap(find.text(AppStrings(locale).navLocations));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('$brightness has labeled targets and readable contrast',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await showNav(tester, brightness: brightness);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('reduced motion disables selection animation', (tester) async {
    await showNav(tester, reducedMotion: true);
    await tester.tap(find.text('Filiallar'));
    await tester.pump();
    for (final container in tester.widgetList<AnimatedContainer>(
      find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.byType(AnimatedContainer)),
    )) {
      expect(container.duration, Duration.zero);
    }
    expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
