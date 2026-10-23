import 'package:flutter/material.dart';

import '../../app_localizations.dart';
import '../../components/buttons/primary_button.dart';
import '../../components/sardoba_auth_logo.dart';
import '../../constants.dart';

class AppUpdateCheckScreen extends StatelessWidget {
  const AppUpdateCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: screenBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SardobaAuthLogo(size: 64),
              const SizedBox(height: AppSpacing.section),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
              const SizedBox(height: AppSpacing.related),
              Text(
                strings.updateCheckMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: bodyTextColor, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppUpdateRequiredScreen extends StatelessWidget {
  const AppUpdateRequiredScreen({super.key, required this.onUpdate});

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 64),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SardobaAuthLogo(size: 76),
                      const SizedBox(height: 36),
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.09),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.system_update_alt_rounded,
                          size: 48,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        strings.updateRequiredTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 26,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        strings.updateRequiredMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: bodyTextColor,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      PrimaryButton(
                        key: const ValueKey<String>('required-app-update'),
                        text: strings.updateAction,
                        press: onUpdate,
                        uppercase: false,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        strings.updateStoreHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: bodyTextColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
