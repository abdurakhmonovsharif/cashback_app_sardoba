import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/models/account.dart';
import 'package:sardoba_app/screens/profile/profile_information_screen.dart';

void main() {
  testWidgets('profile fields stay readable on a compact large-text screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppLocalizations(
        locale: AppLocale.ru,
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
              ),
              child: ProfileInformationScreen(
                account: Account(
                  name: 'Sharifjon',
                  surname: 'Abduraxmonov',
                  middleName: '..',
                  phone: '+998931434413',
                  dateOfBirth: DateTime(1994, 4, 13),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Необязательно'), findsOneWidget);
    expect(find.text('Номер телефона нельзя изменить здесь'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
