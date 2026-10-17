import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/screens/phoneLogin/components/otp_form.dart';

void main() {
  testWidgets('pasted OTP is distributed and submitted', (tester) async {
    String? submittedCode;

    await tester.pumpWidget(
      MaterialApp(
        home: AppLocalizations(
          locale: AppLocale.ru,
          child: Scaffold(
            body: OtpForm(
              onSubmit: (code) async {
                submittedCode = code;
                return true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '1234');
    await tester.pumpAndSettle();

    expect(submittedCode, '1234');
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.map((field) => field.controller?.text), ['1', '2', '3', '4']);
  });
}
