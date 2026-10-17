import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_localizations.dart';
import '../../components/sardoba_auth_logo.dart';
import '../../constants.dart';
import 'components/sign_in_form.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, this.destinationAfterLogin});

  final Widget? destinationAfterLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            defaultPadding,
            12,
            defaultPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: SardobaAuthLogo(),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.authSignInTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.authSignInSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: bodyTextColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  border: const Border.fromBorderSide(
                    BorderSide(color: appBorderColor),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SignInForm(destinationAfterLogin: destinationAfterLogin),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w500,
                    ),
                    text: '${l10n.authNoAccountQuestion} ',
                    children: <TextSpan>[
                      TextSpan(
                        text: l10n.authCreateAccountCta,
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
