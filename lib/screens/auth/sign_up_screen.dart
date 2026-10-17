import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_localizations.dart';
import '../../components/sardoba_auth_logo.dart';
import '../../constants.dart';
import '../signUp/components/sign_up_form.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

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
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: titleColor,
            size: 20,
          ),
        ),
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
              const SizedBox(height: 8),
              const Center(child: SardobaAuthLogo()),
              const SizedBox(height: 24),
              Text(
                l10n.authSignUpTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(
                      color: titleColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.authSignUpSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: bodyTextColor,
                      height: 1.45,
                    ) ??
                    const TextStyle(
                      color: bodyTextColor,
                      fontSize: 14,
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
                child: const SignUpForm(),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: '${l10n.authHaveAccountQuestion} ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w500,
                        ) ??
                        const TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                    children: <TextSpan>[
                      TextSpan(
                        text: l10n.authSignInCta,
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignInScreen(),
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
