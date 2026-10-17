import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/account.dart';
import '../../entry_point.dart';
import '../../services/auth_storage.dart';
import '../../services/session_sync_service.dart';
import '../auth/sign_in_screen.dart';
import '../catalog/product_detail_pressable.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key, this.loadAccount});

  /// Optional repository seam for deterministic widget tests.
  final Future<Account?> Function()? loadAccount;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> with WidgetsBindingObserver {
  late Future<Account?> _accountFuture;
  Timer? _pollTimer;
  int _pollCount = 0;
  int _generation = 0;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accountFuture = _loadAccount();
  }

  Future<Account?> _loadAccount() async {
    final generation = ++_generation;
    final Account? account;
    if (widget.loadAccount != null) {
      account = await widget.loadAccount!();
    } else {
      final token = await AuthStorage.instance.getAccessToken();
      if (token == null || token.isEmpty) return null;
      account = await SessionSyncService.instance.sync();
      if (account == null &&
          await AuthStorage.instance.getAccessToken() != null) {
        throw StateError('QR profile unavailable');
      }
    }
    if (mounted &&
        _active &&
        generation == _generation &&
        account?.loyaltyQr?.status == 'pending' &&
        _pollCount < 6) {
      _pollTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted || !_active) return;
        _pollCount++;
        _refresh(resetPoll: false);
      });
    }
    return account;
  }

  void _refresh({bool resetPoll = true}) {
    _pollTimer?.cancel();
    if (resetPoll) _pollCount = 0;
    setState(() {
      _accountFuture = _loadAccount();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _pollTimer?.cancel();
    if (_active) _refresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: screenBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.qrScreenTitle),
      ),
      body: SafeArea(
          top: false,
          child: FutureBuilder<Account?>(
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
                  onRetry: _refresh,
                  retryLabel: l10n.commonRetry,
                );
              }

              final account = snapshot.data;
              if (account == null) {
                return _QrLoginPrompt(
                  onLogin: _openLogin,
                  l10n: l10n,
                );
              }
              final phone = account.phone;
              final normalizedPhone = _formatPhone(phone);
              final qrData = account.loyaltyQr?.confirmedPayload;
              final phoneLabel = normalizedPhone ?? '';
              if (qrData == null) {
                final pending = account.loyaltyQr?.status == 'pending';
                return _QrMessage(
                  icon: pending
                      ? Icons.schedule_outlined
                      : Icons.credit_card_outlined,
                  title: pending
                      ? l10n.qrScreenPendingTitle
                      : l10n.qrScreenUnavailableTitle,
                  subtitle: pending
                      ? l10n.qrScreenPendingSubtitle
                      : l10n.qrScreenUnavailableSubtitle,
                  onRetry: _refresh,
                  retryLabel: l10n.commonRetry,
                );
              }

              return _QrContent(
                qrData: qrData,
                phoneLabel: phoneLabel,
                displayName: account.name,
                l10n: l10n,
              );
            },
          )),
    );
  }

  String? _formatPhone(String digits) {
    final cleaned = digits.replaceAll(RegExp(r'[^+\d]'), '');
    if (cleaned.isEmpty) return null;
    final digitsOnly = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    if (digitsOnly.isEmpty) return null;
    return '+$digitsOnly';
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SignInScreen(
          destinationAfterLogin: EntryPoint(initialShellScreen: QrScreen()),
        ),
      ),
    );
    if (!mounted) return;
    _refresh();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.min(
          QrWalletTokens.maxContentWidth,
          constraints.maxWidth - defaultPadding * 2,
        );
        // Inspect the existing encoding only to reserve at least four modules
        // of white space. The payload and QrImageView generation stay unchanged.
        final moduleCount = QrValidator.validate(
          data: qrData,
          version: QrVersions.auto,
          errorCorrectionLevel: QrErrorCorrectLevel.H,
        ).qrCode?.moduleCount;
        final quietZoneRatio =
            QrWalletTokens.quietZoneModules / (moduleCount ?? 21);
        // Keep the white QR surface inside the card's rounded corners without
        // clipping either the code or its quiet zone.
        final maxQrWidth = contentWidth - AppSpacing.related * 2;
        final codeSize = math.min(
          QrWalletTokens.regularQrSize,
          math.min(
            maxQrWidth - QrWalletTokens.quietZone * 2,
            maxQrWidth / (1 + quietZoneRatio * 2),
          ),
        );
        final quietZone = math.max(
          QrWalletTokens.quietZone,
          codeSize * quietZoneRatio,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  math.max(0, constraints.maxHeight - defaultPadding * 2),
            ),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  key: const ValueKey('qr-wallet-content'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.qrScreenInstruction,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: QrWalletTokens.instructionSize,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.related),
                    Text(
                      l10n.qrScreenExplanation,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: bodyTextColor,
                      ),
                    ),
                    const SizedBox(height: defaultPadding),
                    Container(
                      key: const ValueKey('qr-wallet-card'),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(QrWalletTokens.cardRadius),
                        boxShadow: const [appCardShadow],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: AppSpacing.related),
                          RepaintBoundary(
                            key: const ValueKey('loyalty-qr'),
                            child: QrImageView(
                              key: const ValueKey('loyalty-qr-image'),
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
                              padding: EdgeInsets.all(quietZone),
                              semanticsLabel: l10n.qrScreenCodeSemantics,
                              size: codeSize + quietZone * 2,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              defaultPadding,
                              0,
                              defaultPadding,
                              defaultPadding,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Divider(
                                  color: appBorderColor,
                                  height: defaultPadding,
                                ),
                                Text(
                                  displayName.isEmpty
                                      ? l10n.qrScreenAccountFallback
                                      : displayName,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: titleColor,
                                  ),
                                ),
                                if (phoneLabel.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.related),
                                  Text(
                                    _maskedPhone(phoneLabel),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: bodyTextColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: defaultPadding),
                    Text(
                      l10n.qrScreenFooter,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: bodyTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _maskedPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final visible = digits.substring(math.max(0, digits.length - 4));
  final prefix = phone.startsWith('+998') ? '+998 ' : '';
  return '$prefix•• ••• $visible';
}

class _QrMessage extends StatelessWidget {
  const _QrMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRetry,
    required this.retryLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight:
                  math.max(0, constraints.maxHeight - defaultPadding * 2)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: QrWalletTokens.maxContentWidth),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(QrWalletTokens.statusCardPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(QrWalletTokens.cardRadius),
                  border: Border.all(color: appBorderColor),
                  boxShadow: const [appCardShadow],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ExcludeSemantics(
                    child: Container(
                      width: QrWalletTokens.statusIconContainerSize,
                      height: QrWalletTokens.statusIconContainerSize,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: QrWalletTokens.statusIconSize,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: QrWalletTokens.instructionSize,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.related),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: bodyTextColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: ProductDetailTokens.sectionGap),
                  SizedBox(
                    width: double.infinity,
                    child: ProductDetailPressable(
                      key: const ValueKey('qr-retry'),
                      label: retryLabel,
                      onPressed: onRetry,
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: ProductDetailTokens.touchTarget,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: defaultPadding,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
                        ),
                        child: Text(
                          retryLabel,
                          textAlign: TextAlign.center,
                          style: kButtonTextStyle,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _QrLoginPrompt extends StatelessWidget {
  const _QrLoginPrompt({
    required this.onLogin,
    required this.l10n,
  });

  final VoidCallback onLogin;
  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: bodyTextColor),
            const SizedBox(height: 12),
            Text(
              l10n.qrScreenPhoneMissingTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.qrScreenPhoneMissingSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),
            ProductDetailPressable(
              key: const ValueKey('qr-login'),
              label: l10n.authSignInCta,
              onPressed: onLogin,
              child: Container(
                width: QrWalletTokens.loginButtonWidth,
                constraints: const BoxConstraints(
                    minHeight: ProductDetailTokens.touchTarget),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(AppSpacing.section),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Text(l10n.authSignInCta,
                    textAlign: TextAlign.center, style: kButtonTextStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
