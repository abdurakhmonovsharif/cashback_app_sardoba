import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/screens/auth/components/sign_in_form.dart';
import 'package:sardoba_app/screens/signUp/components/sign_up_form.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester, Widget form) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLocalizations(
          locale: AppLocale.ru,
          child: Scaffold(body: SingleChildScrollView(child: form)),
        ),
      ),
    );
  }

  testWidgets('login phone input keeps Uzbekistan calling code fixed',
      (tester) async {
    await pumpForm(tester, const SignInForm());

    final phoneField = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(phoneField.controller?.text, isEmpty);
    expect(find.text('+998'), findsOneWidget);
    expect(phoneField.validator?.call('90 123 45 67'), isNull);
    expect(phoneField.validator?.call('90 123 45'), isNotNull);
  });

  testWidgets('registration phone input keeps Uzbekistan calling code fixed',
      (tester) async {
    await pumpForm(tester, const SignUpForm());

    final phoneFields = tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    );
    final phoneField = phoneFields.elementAt(1);
    expect(phoneField.controller?.text, isEmpty);
    expect(find.text('+998'), findsOneWidget);
    expect(phoneField.validator?.call('90 123 45 67'), isNull);
    expect(phoneField.validator?.call('90 123 45'), isNotNull);
  });

  testWidgets('login phone input accepts consecutive digits', (tester) async {
    await pumpForm(tester, const SignInForm());

    final phoneField = find.byType(TextFormField);
    await tester.enterText(phoneField, '9');
    await tester.pump();
    expect(tester.widget<TextFormField>(phoneField).controller?.text, '9');

    await tester.enterText(phoneField, '90');
    await tester.pump();
    expect(tester.widget<TextFormField>(phoneField).controller?.text, '90');
  });

  testWidgets('registration phone input accepts consecutive digits',
      (tester) async {
    await pumpForm(tester, const SignUpForm());

    final phoneField = find.byType(TextFormField).at(1);
    await tester.enterText(phoneField, '9');
    await tester.pump();
    expect(tester.widget<TextFormField>(phoneField).controller?.text, '9');

    await tester.enterText(phoneField, '90');
    await tester.pump();
    expect(tester.widget<TextFormField>(phoneField).controller?.text, '90');
  });
}
