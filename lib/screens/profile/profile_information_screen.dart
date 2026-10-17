import 'package:flutter/material.dart';

import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/account.dart';
import '../../navigation/app_navigator.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../../utils/snackbar_utils.dart';

class ProfileInformationScreen extends StatefulWidget {
  const ProfileInformationScreen({super.key, this.account});

  final Account? account;

  @override
  State<ProfileInformationScreen> createState() =>
      _ProfileInformationScreenState();
}

class _ProfileInformationScreenState extends State<ProfileInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _surnameFocus = FocusNode();
  final _firstNameFocus = FocusNode();
  final _middleNameFocus = FocusNode();
  final _dobFocus = FocusNode();
  final _dobFieldKey = GlobalKey();
  late final TextEditingController _firstNameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _referralController;
  bool _isSaving = false;
  bool _isDeletingAccount = false;
  DateTime? _selectedDob;
  String? _dobError;

  DateTime _ageCutoff() {
    final now = DateTime.now();
    return DateTime(now.year - 13, now.month, now.day);
  }

  bool _isUnderMinimumAge(DateTime date) => date.isAfter(_ageCutoff());

  Account? get _initialAccount => widget.account;

  @override
  void initState() {
    super.initState();
    final account = _initialAccount;
    _firstNameController = TextEditingController(text: account?.name ?? '');
    _surnameController = TextEditingController(text: account?.surname ?? '');
    _middleNameController =
        TextEditingController(text: account?.middleName ?? '');
    _phoneController = TextEditingController(
      text: _formatPhone(account?.phone ?? ''),
    );
    _referralController =
        TextEditingController(text: account?.referralCode ?? '');
    _selectedDob = account?.dateOfBirth;
  }

  Future<void> _confirmLogout() async {
    final l10n = AppLocalizations.of(context);
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileLogoutConfirmTitle),
        content: Text(l10n.profileLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.profileLogoutConfirmSecondary),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.profileLogoutConfirmPrimary),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      await AppNavigator.forceLogout();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (_isDeletingAccount) return;
    final l10n = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDeleteConfirmTitle),
        content: Text(l10n.profileDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.profileDeleteConfirmSecondary),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.profileDeleteConfirmPrimary),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    final l10n = AppLocalizations.of(context);
    final storage = AuthStorage.instance;
    final accessToken = await storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (!mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(l10n.profileLoginRequired),
      );
      return;
    }
    final tokenType = await storage.getTokenType();
    final authService = AuthService();
    if (mounted) {
      setState(() => _isDeletingAccount = true);
    }
    try {
      await authService.deleteAccount(
        accessToken: accessToken,
        tokenType: tokenType,
      );
      if (mounted) {
        showNavAwareSnackBar(
          context,
          content: Text(l10n.profileDeleteSuccess),
        );
      }
      await AppNavigator.forceLogout();
    } on AuthUnauthorizedException {
      await AppNavigator.forceLogout();
    } on AuthServiceException catch (error) {
      if (mounted) {
        showNavAwareSnackBar(
          context,
          content: Text(l10n.authError(error)),
        );
      }
    } finally {
      authService.dispose();
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _middleNameController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    _surnameFocus.dispose();
    _firstNameFocus.dispose();
    _middleNameFocus.dispose();
    _dobFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final account = _initialAccount;
    final l10n = AppLocalizations.of(context);
    if (account == null) {
      Navigator.of(context).maybePop(false);
      return;
    }
    final isFormValid = _formKey.currentState!.validate();
    final dobError = _selectedDob == null
        ? l10n.profileDobValidation
        : _isUnderMinimumAge(_selectedDob!)
            ? l10n.dobTooYoung
            : null;
    setState(() => _dobError = dobError);
    if (!isFormValid || dobError != null) {
      if (_surnameController.text.trim().length < 2) {
        _surnameFocus.requestFocus();
      } else if (_firstNameController.text.trim().length < 2) {
        _firstNameFocus.requestFocus();
      } else if (_middleNameController.text.trim().isNotEmpty &&
          _middleNameController.text.trim().length < 2) {
        _middleNameFocus.requestFocus();
      } else {
        final dateContext = _dobFieldKey.currentContext;
        if (dateContext != null) {
          await Scrollable.ensureVisible(
            dateContext,
            duration: const Duration(milliseconds: 180),
            alignment: 0.7,
          );
        }
        _dobFocus.requestFocus();
      }
      return;
    }
    final firstName = _firstNameController.text.trim();
    final surname = _surnameController.text.trim();
    final middleName = _middleNameController.text.trim();
    setState(() => _isSaving = true);
    final storage = AuthStorage.instance;
    final accessToken = await storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(l10n.profileLoginRequired),
      );
      return;
    }
    final tokenType = await storage.getTokenType();
    final authService = AuthService();
    try {
      final response = await authService.updateUserProfile(
        accessToken: accessToken,
        tokenType: tokenType,
        name: firstName,
        surname: surname.isEmpty ? null : surname,
        middleName: middleName.isEmpty ? null : middleName,
        dateOfBirth: _selectedDob,
        fallbackPhone: account.phone,
        fallbackName: account.name,
      );
      final referralValue = _referralController.text.trim();
      final merged = response.copyWith(
        referralCode: referralValue.isEmpty ? null : referralValue,
      );
      await storage.upsertAccount(merged.copyWith(isVerified: true));
      if (!mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(l10n.profileInfoSaveSuccess),
      );
      Navigator.of(context).pop(true);
    } on AuthUnauthorizedException {
      await AppNavigator.forceLogout();
    } on AuthServiceException catch (error) {
      if (mounted) {
        showNavAwareSnackBar(
          context,
          content: Text(l10n.authError(error)),
        );
      }
    } catch (_) {
      if (mounted) {
        showNavAwareSnackBar(
          context,
          content: Text(l10n.commonErrorTryAgain),
        );
      }
    } finally {
      authService.dispose();
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final approxInitial = DateTime(now.year - 18, now.month, now.day);
    final cutoff = _ageCutoff();
    final baseInitial = _selectedDob ??
        (approxInitial.isBefore(DateTime(1900))
            ? DateTime(1900)
            : (approxInitial.isAfter(now) ? now : approxInitial));
    final initial = baseInitial.isAfter(cutoff) ? cutoff : baseInitial;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: cutoff,
      helpText: l10n.profileDobLabel,
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasAccount = _initialAccount != null;

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.profileInfoMenuTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            defaultPadding,
            hasAccount ? 16 : 24,
            defaultPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hasAccount)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.profileInfoSignInHint,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: bodyTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!hasAccount) const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: const [appCardShadow],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding,
                  vertical: 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.profileInfoSectionTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      _LabeledField(
                        label: l10n.formSurnameLabel,
                        helper: '',
                        showLabel: false,
                        child: TextFormField(
                          controller: _surnameController,
                          focusNode: _surnameFocus,
                          enabled: hasAccount,
                          decoration: _fieldDecoration(
                            l10n.formSurnameLabel,
                            l10n.formSurnameHint,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final trimmed = (value ?? '').trim();
                            if (trimmed.isEmpty) {
                              return l10n.formSurnameRequired;
                            }
                            if (trimmed.length < 2) {
                              return l10n.formSurnameTooShort;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      _LabeledField(
                        label: l10n.formFirstNameLabel,
                        helper: '',
                        showLabel: false,
                        child: TextFormField(
                          controller: _firstNameController,
                          focusNode: _firstNameFocus,
                          enabled: hasAccount,
                          decoration: _fieldDecoration(
                            l10n.formFirstNameLabel,
                            l10n.formFirstNameHint,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final trimmed = (value ?? '').trim();
                            if (trimmed.isEmpty) {
                              return l10n.formFirstNameRequired;
                            }
                            if (trimmed.length < 2) {
                              return l10n.formFirstNameTooShort;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      _LabeledField(
                        label: l10n.formMiddleNameLabel,
                        helper: l10n.commonOptional,
                        showLabel: false,
                        child: TextFormField(
                          controller: _middleNameController,
                          focusNode: _middleNameFocus,
                          enabled: hasAccount,
                          decoration: _fieldDecoration(
                            l10n.formMiddleNameLabel,
                            l10n.formMiddleNameHint,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final trimmed = (value ?? '').trim();
                            if (trimmed.isNotEmpty && trimmed.length < 2) {
                              return l10n.formMiddleNameTooShort;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      _LabeledField(
                        label: l10n.formPhoneLabel,
                        helper: l10n.profilePhoneReadonlyHint,
                        showLabel: false,
                        child: TextFormField(
                          controller: _phoneController,
                          readOnly: true,
                          enabled: hasAccount,
                          decoration: _fieldDecoration(
                            l10n.formPhoneLabel,
                            '—',
                            suffixIcon: const Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      _LabeledField(
                        label: l10n.profileDobLabel,
                        helper: '',
                        error: _dobError,
                        child: _DobPicker(
                          key: _dobFieldKey,
                          focusNode: _dobFocus,
                          enabled: hasAccount,
                          label: l10n.profileDobLabel,
                          hint: l10n.profileDobPickerHint,
                          error: _dobError,
                          hasValue: _selectedDob != null,
                          displayText: _selectedDob != null
                              ? l10n.formatDateDdMMyyyy(_selectedDob!)
                              : l10n.profileDobPlaceholder,
                          showError: _dobError != null,
                          onTap: hasAccount ? _pickBirthDate : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: !hasAccount || _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.formSaveChanges),
              ),
              const SizedBox(height: 16),
              _ProfileInfoActionButtons(
                l10n: l10n,
                onLogout: _confirmLogout,
                onDelete: hasAccount ? _confirmDeleteAccount : null,
                isDeleting: _isDeletingAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    String label,
    String hint, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: screenBackgroundColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatPhone(String digits) {
    if (digits.isEmpty) return '+998 -- --- -- --';
    if (digits.startsWith('+')) return digits;
    return '+$digits';
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String helper;
  final Widget child;
  final String? error;
  final bool showLabel;

  const _LabeledField({
    required this.label,
    required this.helper,
    required this.child,
    this.error,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 6),
        child,
        if (helper.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              helper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: bodyTextColor,
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: TextStyle(color: Colors.red[600], fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _DobPicker extends StatelessWidget {
  const _DobPicker({
    super.key,
    required this.enabled,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.error,
    required this.displayText,
    required this.hasValue,
    this.showError = false,
    this.onTap,
  });

  final bool enabled;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final String? error;
  final String displayText;
  final bool hasValue;
  final bool showError;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final baseColor = hasValue ? titleColor : bodyTextColor;
    final textColor = enabled ? baseColor : bodyTextColor;
    return Focus(
      focusNode: focusNode,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        value: displayText,
        hint: showError ? error : hint,
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: screenBackgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: showError ? Colors.redAccent : Colors.transparent,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: textColor,
                            ),
                      ),
                    ),
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: textColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoActionButtons extends StatelessWidget {
  const _ProfileInfoActionButtons({
    required this.l10n,
    required this.onLogout,
    this.onDelete,
    required this.isDeleting,
  });

  final AppStrings l10n;
  final Future<void> Function() onLogout;
  final Future<void> Function()? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileInfoActionButton(
          icon: Icons.logout_rounded,
          title: l10n.profileLogout,
          accentColor: const Color(0xFFED5A5A),
          onTap: onLogout,
        ),
        if (onDelete != null) ...[
          const SizedBox(height: 12),
          _ProfileInfoActionButton(
            icon: Icons.delete_forever_rounded,
            title: l10n.profileDeleteAccount,
            accentColor: const Color(0xFFB3261E),
            onTap: onDelete!,
            isLoading: isDeleting,
          ),
        ],
      ],
    );
  }
}

class _ProfileInfoActionButton extends StatelessWidget {
  const _ProfileInfoActionButton({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final Color accentColor;
  final Future<void> Function() onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: isLoading ? null : () async => await onTap(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              isLoading
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(accentColor),
                      ),
                    )
                  : Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: accentColor,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
