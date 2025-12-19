import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_localizations.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../constants.dart';
import '../../../entry_point.dart';
import '../../../services/auth_storage.dart';
import '../../../services/auth_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../phoneLogin/number_verify_screen.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  bool _showReferralField = false;
  bool _isPhoneValid = false;
  bool _isSubmitting = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  DateTime? _selectedDob;
  String? _dobError;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_handlePhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_handlePhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final approx = DateTime(now.year - 18, now.month, now.day);
    final initial = _selectedDob ??
        (approx.isBefore(DateTime(1900)) ? DateTime(1900) : approx);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: l10n.authDobLabel,
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobError = null;
      });
    }
  }

  void _handlePhoneChanged() {
    final digitsOnly =
        _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final nextIsValid = digitsOnly.length >= 10;

    if (nextIsValid != _isPhoneValid) {
      setState(() {
        _isPhoneValid = nextIsValid;
      });
    }
  }

  InputDecoration _buildInputDecoration(String hint, {Widget? suffix}) {
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

  Widget _buildLabel(String text, TextStyle style) {
    return Text(text, style: style);
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
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDob == null) {
      setState(() => _dobError = l10n.authDobValidation);
      return;
    }

    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final storage = AuthStorage.instance;
    final name = _nameController.text.trim();
    final phoneRaw = _phoneController.text;
    final normalizedPhone = storage.normalizePhone(phoneRaw);
    final referral = _referralController.text.trim().isEmpty
        ? null
        : _referralController.text.trim();

    final authService = AuthService();
    try {
      await authService.requestOtp(
        phone: normalizedPhone,
        purpose: 'register',
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(l10n.authError(error)),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(l10n.commonErrorTryAgain),
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
          phone: normalizedPhone,
          displayPhone: phoneRaw,
          onResend: () async {
            final service = AuthService();
            try {
              await service.requestOtp(
                phone: normalizedPhone,
                purpose: 'register',
              );
            } finally {
              service.dispose();
            }
          },
          onVerified: (ctx, code) async {
            final localL10n = AppLocalizations.of(ctx);
            final authService = AuthService();
            try {
              final session = await authService.verifyOtp(
                phone: normalizedPhone,
                code: code,
                name: name,
                purpose: 'register',
                referralCode: referral,
                dateOfBirth: _selectedDob,
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
              if (!ctx.mounted) return false;
              final innerNavigator = Navigator.of(ctx);
              innerNavigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const EntryPoint()),
                (_) => false,
              );
              return true;
            } on AuthServiceException catch (error) {
              if (!ctx.mounted) return false;
              showNavAwareSnackBar(
                ctx,
                content: Text(localL10n.authError(error)),
              );
              return false;
            } catch (error) {
              if (!ctx.mounted) return false;
              showNavAwareSnackBar(
                ctx,
                content: Text(localL10n.commonErrorTryAgain),
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
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: titleColor.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ) ??
        const TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(l10n.authEnterName, labelStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            validator: requiredValidator.call,
            textInputAction: TextInputAction.next,
            decoration: _buildInputDecoration(l10n.authNameHint),
          ),
          const SizedBox(height: 16),
          _buildLabel(l10n.authEnterPhone, labelStyle),
          const SizedBox(height: 8),
          TextFormField(
            validator: phoneNumberValidator.call,
            onSaved: (value) {},
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
            controller: _phoneController,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            decoration: _buildInputDecoration(
              l10n.authPhoneHint,
              suffix: AnimatedSwitcher(
                duration: kDefaultDuration,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
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
          const SizedBox(height: 16),
          _buildLabel('${l10n.authDobLabel} *', labelStyle),
          const SizedBox(height: 8),
          _buildDobSelector(l10n),
          if (_dobError != null) ...[
            const SizedBox(height: 6),
            Text(
              _dobError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.authOtpInfoRegister,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: bodyTextColor.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _showReferralField = !_showReferralField;
              });
            },
            child: AnimatedContainer(
              duration: kDefaultDuration,
              curve: Curves.easeInOut,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _showReferralField
                      ? primaryColor.withValues(alpha: 0.45)
                      : Colors.transparent,
                ),
                boxShadow: _showReferralField
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.15),
                          offset: const Offset(0, 12),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.authReferralToggle,
                    style: const TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showReferralField ? 0.5 : 0,
                    duration: kDefaultDuration,
                    curve: Curves.easeInOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF8D97A8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: kDefaultDuration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _showReferralField
                ? Column(
                    children: [
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _referralController,
                        decoration:
                            _buildInputDecoration(l10n.authReferralHint),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            text: l10n.authContinue,
            isLoading: _isSubmitting,
            press: _handleSubmit,
          ),
        ],
      ),
    );
  }

  Widget _buildDobSelector(AppStrings l10n) {
    final hasValue = _selectedDob != null;
    final text =
        hasValue ? l10n.formatDateDdMMyyyy(_selectedDob!) : l10n.authDobHint;
    final borderColor =
        _dobError != null ? Colors.redAccent : Colors.transparent;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _pickDob,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasValue ? titleColor : bodyTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: (hasValue ? titleColor : bodyTextColor)
                  .withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}
