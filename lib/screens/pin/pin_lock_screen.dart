import 'dart:async';
import 'package:flutter/material.dart';

import '../../app_localizations.dart';
import '../../constants.dart';
import '../../services/auth_storage.dart';
import '../onboarding/onboarding_scrreen.dart';
import 'components/pin_widgets.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    required this.onUnlocked,
  });

  final void Function(BuildContext context) onUnlocked;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _currentPin = '';
  String? _error;
  bool _isVerifying = false;
  bool _showSuccessLoading = false;

  Future<void> _handleDigitTap(String digit) async {
    if (_currentPin.length >= 4 || _isVerifying) return;

    setState(() {
      _currentPin += digit;
      _error = null;
    });

    if (_currentPin.length == 4) {
      _verifyPinSmooth();
    }
  }

  Future<void> _verifyPinSmooth() async {
    if (_isVerifying) return;
    if (!mounted) return;

    setState(() => _isVerifying = true);

    // kichik UX pauza (minimal)
    await Future.delayed(const Duration(milliseconds: 30));

    final isValid = await AuthStorage.instance.verifyPin(_currentPin);
    if (!mounted) return;

    if (!isValid) {
      setState(() {
        _error = AppLocalizations.of(context).pinLockError;
        _currentPin = '';
        _isVerifying = false;
        _showSuccessLoading = false;
      });
      return;
    }

    setState(() => _showSuccessLoading = true);

    // navigation oldidan juda kichik delay
    await Future.delayed(const Duration(milliseconds: 70));

    if (!mounted) return;

    widget.onUnlocked(context);

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _showSuccessLoading = false;
    });
  }

  void _handleBackspace() {
    if (_currentPin.isEmpty || _isVerifying) return;

    setState(() {
      _currentPin = _currentPin.substring(0, _currentPin.length - 1);
    });
  }

  Future<void> _switchAccount() async {
    await AuthStorage.instance.clearPin();
    await AuthStorage.instance.clearCurrentUser();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F2),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                defaultPadding,
                48,
                defaultPadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 52,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 18),

                  // TITLE
                  Text(
                    l10n.pinLockTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // SUBTITLE
                  Text(
                    l10n.pinLockSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: titleColor.withValues(alpha: 0.6),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // DOTS – RepaintBoundary bilan
                  RepaintBoundary(
                    child: PinDots(
                      count: 4,
                      filled: _currentPin.length,
                    ),
                  ),

                  // ERROR
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFED5A5A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : const SizedBox(height: 32),
                  ),

                  const SizedBox(height: 12),

                  // KEYPAD – GPU-friendly
                  Expanded(
                    child: RepaintBoundary(
                      child: PinKeypad(
                        onDigitPressed: _handleDigitTap,
                        onBackspacePressed: _handleBackspace,
                        isBusy: _isVerifying,
                      ),
                    ),
                  ),

                  // SWITCH ACCOUNT
                  TextButton(
                    onPressed: _isVerifying ? null : _switchAccount,
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    child: Text(l10n.pinSwitchAccount),
                  ),
                ],
              ),
            ),
          ),

          // SUCCESS OVERLAY
          if (_showSuccessLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha:  0.45),
                  child: const Center(
                    child: SizedBox(
                      height: 60,
                      width: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
