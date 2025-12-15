import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_localizations.dart';
import '../../constants.dart';
import '../../utils/snackbar_utils.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const String _phoneNumberDisplay = '+998 78 333 73 33';
  static final Uri _callUri = Uri(scheme: 'tel', path: '+998783337333');

  Future<void> _callSupport(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final launched = await launchUrl(_callUri);
    if (!launched) {
      if (!context.mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(l10n.helpCenterCallError),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.helpCenterTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        color: primaryColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '☎️ ${l10n.helpCenterCallTitle}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _SupportLanguageBlock(
                    title: l10n.helpCenterCallTitle,
                    description: l10n.helpCenterCallDescription,
                    phoneNumber: _phoneNumberDisplay,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _callSupport(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    icon: const Icon(Icons.call_rounded),
                    label: Text(l10n.helpCenterCallButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportLanguageBlock extends StatelessWidget {
  const _SupportLanguageBlock({
    required this.title,
    required this.description,
    required this.phoneNumber,
  });

  final String title;
  final String description;
  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: bodyTextColor,
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          phoneNumber,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: primaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
