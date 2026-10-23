import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_localizations.dart';
import '../../../components/app_input_decoration.dart';
import '../../../components/buttons/primary_button.dart';
import '../../../components/profile_dob_picker.dart';
import '../../../components/uzbek_phone_input.dart';
import '../../../constants.dart';
import '../../../entry_point.dart';
import '../../../services/auth_storage.dart';
import '../../../services/auth_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/date_input_formatter.dart';
import '../../phoneLogin/number_verify_screen.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();

  bool _isPhoneValid = false;
  bool _isSubmitting = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  DateTime? _selectedDob;
  String? _dobError;

  DateTime _ageCutoff() {
    final now = DateTime.now();
    return DateTime(now.year - 13, now.month, now.day);
  }

  bool _isUnderMinimumAge(DateTime date) => date.isAfter(_ageCutoff());

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
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final approx = DateTime(now.year - 18, now.month, now.day);
    final cutoff = _ageCutoff();
    final firstDate = DateTime(1900);
    final baseInitial = _selectedDob ?? approx;
    final initial = baseInitial.isBefore(firstDate)
        ? firstDate
        : baseInitial.isAfter(cutoff)
            ? cutoff
            : baseInitial;
    final picked = await showProfileDobPicker(
      context: context,
      l10n: l10n,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: cutoff,
    );
    if (picked != null) {
      if (_isUnderMinimumAge(picked)) {
        setState(() {
          _dobError = l10n.dobTooYoung;
          _selectedDob = null;
        });
        return;
      }
      setState(() {
        _selectedDob = picked;
        _dobError = null;
        _dobController.text = formatDateOfBirth(picked);
      });
    }
  }

  void _handleDobChanged(String value) {
    final parsed = parseDateOfBirthInput(value);
    setState(() {
      _selectedDob = parsed;
      _dobError = null;
    });
  }

  void _handlePhoneChanged() {
    final nextIsValid = uzbekPhoneDigits(_phoneController.text).length == 9;

    if (nextIsValid != _isPhoneValid) {
      setState(() {
        _isPhoneValid = nextIsValid;
      });
    }
  }

  InputDecoration _buildInputDecoration(
    String hint, {
    Widget? suffix,
    Widget? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: suffix,
            )
          : null,
      suffixIconConstraints: const BoxConstraints(minHeight: 24, minWidth: 24),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minHeight: 48, minWidth: 88),
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
    if (_isUnderMinimumAge(_selectedDob!)) {
      setState(() => _dobError = l10n.dobTooYoung);
      return;
    }

    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final storage = AuthStorage.instance;
    final name = _nameController.text.trim();
    final phoneRaw = '$defaultPhoneInputPrefix${_phoneController.text}';
    final normalizedPhone = storage.normalizePhone(phoneRaw);
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
    final labelStyle = AppInputDecoration.labelTextStyle(context);

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
            validator: (value) => uzbekPhoneDigits(value ?? '').length == 9
                ? null
                : l10n.authPhoneInvalid,
            onSaved: (value) {},
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
            controller: _phoneController,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              const UzbekPhoneFormatter(),
            ],
            decoration: _buildInputDecoration(
              l10n.authPhoneLocalHint,
              prefix: const UzbekPhonePrefix(),
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
          const SizedBox(height: 24),
          PrimaryButton(
            text: l10n.authContinue,
            isLoading: _isSubmitting,
            press: _handleSubmit,
            uppercase: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDobSelector(AppStrings l10n) {
    return TextField(
      controller: _dobController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: const [DateInputFormatter()],
      onChanged: _handleDobChanged,
      decoration: InputDecoration(
        hintText: l10n.authDobHint,
        enabledBorder:
            _dobError != null ? AppInputDecoration.errorBorder : null,
        focusedBorder:
            _dobError != null ? AppInputDecoration.focusedErrorBorder : null,
        suffixIcon: IconButton(
          tooltip: l10n.authDobLabel,
          onPressed: _pickDob,
          icon: const Icon(Icons.calendar_today_rounded, size: 18),
        ),
      ),
    );
  }
}
