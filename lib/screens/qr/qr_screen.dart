import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/account.dart';
import '../../services/auth_storage.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  late Future<Account?> _accountFuture;

  @override
  void initState() {
    super.initState();
    _accountFuture = AuthStorage.instance.getCurrentAccount();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.qrScreenTitle),
      ),
      body: FutureBuilder<Account?>(
        future: _accountFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _QrMessage(
              icon: Icons.error_outline,
              title: l10n.qrScreenErrorTitle,
              subtitle: l10n.qrScreenErrorSubtitle,
            );
          }

          final account = snapshot.data;
          final phone = account?.phone ?? '';
          final normalizedPhone = _formatPhone(phone);
          final cardTrack = (account?.cardTracks?.isNotEmpty ?? false)
              ? account!.cardTracks!.last
              : null;
          final qrData = cardTrack ?? normalizedPhone;
          final phoneLabel = normalizedPhone ?? '';
          if (qrData == null || qrData.isEmpty) {
            return _QrMessage(
              icon: Icons.phone_iphone_outlined,
              title: l10n.qrScreenPhoneMissingTitle,
              subtitle: l10n.qrScreenPhoneMissingSubtitle,
            );
          }

          return _QrContent(
            qrData: qrData,
            phoneLabel: phoneLabel, 
            displayName: account?.name ?? '',
            l10n: l10n,
          );
        },
      ),
    );
  }

  String? _formatPhone(String digits) {
    final cleaned = digits.replaceAll(RegExp(r'[^+\d]'), '');
    if (cleaned.isEmpty) return null;
    final digitsOnly = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    if (digitsOnly.isEmpty) return null;
    return '+$digitsOnly';
  }
}

class _QrContent extends StatelessWidget {
  const _QrContent({
    required this.qrData,
    required this.phoneLabel,
    required this.displayName,
    required this.l10n,
  });

  final String qrData;
  final String phoneLabel;
  final String displayName;
  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.qrScreenInstruction,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  displayName.isEmpty
                      ? l10n.qrScreenAccountFallback
                      : displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                if (phoneLabel.isNotEmpty)
                  Column(
                    children: [
                      Text(
                        phoneLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: bodyTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: const QrEyeStyle(
                        color: Colors.black,
                        eyeShape: QrEyeShape.square,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        color: Colors.black,
                        dataModuleShape: QrDataModuleShape.square,
                      ),
                      backgroundColor: Colors.white,
                      gapless: false,
                      size: 320,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.qrScreenFooter,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bodyTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QrMessage extends StatelessWidget {
  const _QrMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: bodyTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
