import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_localizations.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../constants.dart';
import '../../../entry_point.dart';
import '../../../navigation/app_navigator.dart';
import '../../../services/auth_storage.dart';
import '../../../services/auth_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../phoneLogin/number_verify_screen.dart';
import '../../pin/pin_setup_screen.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({super.key});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey = GlobalKey<FormState>();

  bool _isPhoneValid = false;
  bool _isSubmitting = false;
  final TextEditingController _phoneController = TextEditingController();
  bool _isAdjustingPhone = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_handlePhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_handlePhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _handlePhoneChanged() {
    _enforceLeadingPlus();
    final digitsOnly =
        _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final nextIsValid = digitsOnly.length >= 10;

    if (nextIsValid != _isPhoneValid) {
      setState(() {
        _isPhoneValid = nextIsValid;
      });
    }
  }

  void _enforceLeadingPlus() {
    if (_isAdjustingPhone) return;
    final text = _phoneController.text;
    if (text.isEmpty) return;
    // Ensure exactly one leading "+" and keep the rest of the input as-is.
    final normalized = text.startsWith('+')
        ? text.replaceFirst(RegExp(r'^\++'), '+')
        : '+$text';
    if (normalized == text) return;
    _isAdjustingPhone = true;
    _phoneController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    _isAdjustingPhone = false;
  }

  InputDecoration _buildInputDecoration(
    String hint, {
    Widget? suffix,
  }) {
    const borderRadius = BorderRadius.all(Radius.circular(14));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0B6C3), fontSize: 15),
      filled: true,
      fillColor: const Color(0xFFF6F8FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.transparent),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.transparent),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Color(0xFF8FD7B6), width: 1.2),
      ),
      suffixIcon: suffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: suffix,
            )
          : null,
      suffixIconConstraints: const BoxConstraints(minHeight: 24, minWidth: 24),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: titleColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ) ??
          const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
    );
  }

  Widget _buildVerifiedIcon({Key? key}) {
    return Container(
      key: key,
      height: 24,
      width: 24,
      decoration: const BoxDecoration(
        color: primaryColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.check, color: Colors.white, size: 14),
    );
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final strings = AppLocalizations.of(context);
    final storage = AuthStorage.instance;
    final phoneRaw = _phoneController.text;
    final phone = storage.normalizePhone(phoneRaw);
    final authService = AuthService();
    try {
      await authService.requestOtp(phone: phone, purpose: 'login');
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(strings.authError(error)),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(strings.commonErrorTryAgain),
      );
      return;
    } finally {
      authService.dispose();
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }

    if (!mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => NumberVerifyScreen(
          phone: phone,
          displayPhone: phoneRaw,
          onResend: () async {
            final service = AuthService();
            try {
              await service.requestOtp(phone: phone, purpose: 'login');
            } finally {
              service.dispose();
            }
          },
          onVerified: (ctx, code) async {
            final localStrings = AppLocalizations.of(ctx);
            final authService = AuthService();
            try {
              final session = await authService.verifyOtp(
                phone: phone,
                code: code,
                purpose: 'login',
              );
              await storage.upsertAccount(
                session.account.copyWith(isVerified: true),
              );
              await storage.setCurrentUser(session.account.phone);
              await storage.saveAuthTokens(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                tokenType: session.tokenType,
              );
              await storage.markVerified(session.account.phone);
              final hasPin = await storage.hasPin();
              if (!ctx.mounted) return false;
              final rootNavigator = AppNavigator.navigatorKey.currentState;
              if (rootNavigator == null || !rootNavigator.mounted) return false;
              if (!hasPin) {
                rootNavigator.pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => PinSetupScreen(
                      onCompleted: (innerCtx) {
                        Navigator.of(innerCtx).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const EntryPoint()),
                          (_) => false,
                        );
                      },
                    ),
                  ),
                );
              } else {
                rootNavigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const EntryPoint()),
                  (_) => false,
                );
              }
              return true;
            } on AuthUnauthorizedException catch (error) {
              await storage.logout();
              if (!ctx.mounted) return false;
              showNavAwareSnackBar(
                ctx,
                content: Text(error.message),
              );
              return false;
            } on AuthServiceException catch (error) {
              if (!ctx.mounted) return false;
              showNavAwareSnackBar(
                ctx,
                content: Text(localStrings.authError(error)),
              );
              return false;
            } catch (error) {
              if (!ctx.mounted) return false;
              showNavAwareSnackBar(
                ctx,
                content: const Text('Failed to verify. Please try again.'),
              );
              return false;
            } finally {
              authService.dispose();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(context, l10n.authEnterPhone),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            validator: phoneNumberValidator.call,
            onSaved: (value) {},
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            decoration: _buildInputDecoration(
              l10n.authPhoneHint,
              suffix: AnimatedSwitcher(
                duration: kDefaultDuration,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: _isPhoneValid
                    ? _buildVerifiedIcon(key: const ValueKey("valid"))
                    : const SizedBox(
                        key: ValueKey("invalid"),
                        height: 24,
                        width: 24,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.authOtpInfoLogin,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: bodyTextColor.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: l10n.authSendCode,
            isLoading: _isSubmitting,
            press: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
