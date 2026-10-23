import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/components/profile_dob_picker.dart';

void main() {
  testWidgets('iOS date picker sheet reaches the bottom edge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(_pickerTestApp());
    await tester.tap(find.byKey(const ValueKey('open-dob-picker')));
    await tester.pumpAndSettle();

    final sheetRect = tester.getRect(
      find.byKey(const ValueKey('profile-dob-picker-sheet')),
    );
    expect(sheetRect.bottom, 844);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS date picker stays within keyboard visible area',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(_pickerTestApp());
    await tester.tap(find.byKey(const ValueKey('open-dob-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ввести дату'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    final sheetRect = tester.getRect(
      find.byKey(const ValueKey('profile-dob-picker-sheet')),
    );
    expect(sheetRect.bottom, 524);
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _pickerTestApp() {
  return AppLocalizations(
    locale: AppLocale.ru,
    child: MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open-dob-picker'),
              onPressed: () => showProfileDobPicker(
                context: context,
                l10n: AppLocalizations.of(context),
                initialDate: DateTime(1994, 4, 13),
                firstDate: DateTime(1900),
                lastDate: DateTime(2013, 10, 19),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}
