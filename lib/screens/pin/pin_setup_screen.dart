import 'package:flutter/material.dart';

import '../../app_localizations.dart';
import '../../constants.dart';
import '../../services/auth_storage.dart';
import 'components/pin_widgets.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({
    super.key,
    required this.onCompleted,
  });

  final void Function(BuildContext context) onCompleted;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _PinStep { enter, confirm }

class _PinSetupScreenState extends State<PinSetupScreen> {
  _PinStep _step = _PinStep.enter;
  String _currentPin = '';
  String? _firstPin;
  String? _error;
  bool _isSaving = false;

  void _handleDigitTap(String digit) {
    if (_currentPin.length >= 4 || _isSaving) return;
    setState(() {
      _currentPin += digit;
      _error = null;
    });
    if (_currentPin.length == 4) {
      _onPinCompleted();
    }
  }

  void _handleBackspace() {
    if (_currentPin.isEmpty || _isSaving) return;
    setState(() {
      _currentPin = _currentPin.substring(0, _currentPin.length - 1);
    });
  }

  Future<void> _onPinCompleted() async {
    if (_step == _PinStep.enter) {
      setState(() {
        _firstPin = _currentPin;
        _currentPin = '';
        _step = _PinStep.confirm;
      });
      return;
    }

    if (_firstPin != _currentPin) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _error = l10n.pinSetupMismatch;
        _currentPin = '';
        _firstPin = null;
        _step = _PinStep.enter;
      });
      return;
    }

    setState(() => _isSaving = true);
    await AuthStorage.instance.savePin(_currentPin);
    if (!mounted) return;
    widget.onCompleted(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isConfirm = _step == _PinStep.confirm;
    final title =
        isConfirm ? l10n.pinSetupConfirmTitle : l10n.pinSetupCreateTitle;
    final subtitle = isConfirm
        ? l10n.pinSetupConfirmSubtitle
        : l10n.pinSetupCreateSubtitle;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F2),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(defaultPadding, 48, defaultPadding, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.shield_outlined, size: 52, color: primaryColor),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: titleColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 28),
              PinDots(count: 4, filled: _currentPin.length),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFED5A5A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                const SizedBox(height: 32),
              Expanded(
                child: PinKeypad(
                  onDigitPressed: _handleDigitTap,
                  onBackspacePressed: _handleBackspace,
                  isBusy: _isSaving,
                ),
              ),
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _step = _PinStep.enter;
                          _firstPin = null;
                          _currentPin = '';
                          _error = null;
                        });
                      },
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: Text(isConfirm ? l10n.pinSetupReset : l10n.pinSetupClear),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
