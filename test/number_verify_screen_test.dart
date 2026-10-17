import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/components/sardoba_auth_logo.dart';
import 'package:sardoba_app/screens/phoneLogin/number_verify_screen.dart';

void main() {
  testWidgets('OTP screen keeps the shared auth layout on a compact phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AppLocalizations(
          locale: AppLocale.ru,
          child: NumberVerifyScreen(
            phone: '998901234567',
            onVerified: (_, __) async => false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SardobaAuthLogo), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
