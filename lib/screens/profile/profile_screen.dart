import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../components/combined_card_widget.dart';
import '../../constants.dart';
import '../../models/account.dart';
import '../../navigation/app_navigator.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../../services/session_sync_service.dart';
import '../../utils/snackbar_utils.dart';
import '../cashback/cashback_screen.dart';
import '../notifications/notifications_screen.dart';
import 'change_pin_screen.dart';
import 'help_center_screen.dart';
import 'profile_information_screen.dart';
import 'refer_friends_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: screenBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.profileTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: const _ProfileBody(),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody();

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  late Future<Account?> _accountFuture;
  static const int _cashbackThreshold = 30000;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _accountFuture = _loadCachedAccount();
  }

  Future<void> _refreshAccount() async {
    final future = _requestRemoteAccount();
    if (!mounted) return;
    setState(() {
      _accountFuture = future;
    });
    await future;
  }

  Future<Account?> _loadCachedAccount() =>
      AuthStorage.instance.getCurrentAccount();

  Future<Account?> _requestRemoteAccount() async {
    await SessionSyncService.instance.sync(fallbackName: '-');
    return AuthStorage.instance.getCurrentAccount();
  }

  Future<void> _openProfileInfo(Account? account) async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileInformationScreen(account: account),
      ),
    );
    if (shouldRefresh == true) {
      unawaited(_refreshAccount());
    }
  }

  Future<void> _openChangePin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChangePinScreen()),
    );
  }

  Future<void> _openHelpCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
    );
  }

  Future<void> _openReferFriends(Account? account) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReferFriendsScreen(account: account),
      ),
    );
    if (!mounted) return;
    unawaited(_refreshAccount());
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  Future<void> _openCashback(Account? account) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CashbackScreen(
          account: account,
          threshold: _cashbackThreshold,
          initialBalance: account?.cashbackBalance ?? 0,
          initialEntries: account?.cashbackHistory,
          initialLoyalty: account?.loyalty,
        ),
      ),
    );
    if (!mounted) return;
    unawaited(_refreshAccount());
  }

  Future<ImageSource?> _selectImageSource() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.profileAvatarActionCamera),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profileAvatarActionGallery),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;

    // On iOS, the system prompt is handled by image_picker itself.
    if (!Platform.isIOS) {
      final granted = source == ImageSource.camera
          ? await _handleCameraPermission()
          : await _handleGalleryPermission();
      if (!mounted || !granted) return null;
    }
    return source;
  }

  Future<bool> _handleCameraPermission() async {
    final l10n = AppLocalizations.of(context);
    return _requestPermission(
      Permission.camera,
      l10n.profileAvatarCameraPermissionDenied,
    );
  }

  Future<bool> _handleGalleryPermission() async {
    final l10n = AppLocalizations.of(context);
    final permission = Platform.isIOS ? Permission.photos : Permission.storage;
    return _requestPermission(
      permission,
      l10n.profileAvatarGalleryPermissionDenied,
    );
  }

  Future<bool> _requestPermission(
    Permission permission,
    String deniedMessage,
  ) async {
    final status = await permission.status;
    if (_isPermissionGranted(status)) return true;

    final result = await permission.request();
    if (_isPermissionGranted(result)) return true;

    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }

    if (!mounted) return false;
    showNavAwareSnackBar(
      context,
      content: Text(deniedMessage),
    );
    return false;
  }

  bool _isPermissionGranted(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  Future<void> _changeAvatar() async {
    if (_isUploadingAvatar) return;
    final source = await _selectImageSource();
    if (source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;
    final storage = AuthStorage.instance;
    final accessToken = await storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showNavAwareSnackBar(
        context,
        content: Text(l10n.profileLoginRequired),
      );
      return;
    }
    final tokenType = await storage.getTokenType();
    final fallbackPhone = await storage.getCurrentUser();
    final cachedAccount = await storage.getCurrentAccount();
    final authService = AuthService();
    if (!mounted) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final updated = await authService.uploadProfilePhoto(
        accessToken: accessToken,
        tokenType: tokenType,
        file: File(picked.path),
        fallbackPhone: fallbackPhone,
        fallbackName: cachedAccount?.name,
      );
      await storage.upsertAccount(updated.copyWith(isVerified: true));
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showNavAwareSnackBar(
        context,
        content: Text(l10n.profileAvatarUploadSuccess),
      );
      unawaited(_refreshAccount());
    } on AuthUnauthorizedException {
      await AppNavigator.forceLogout();
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showNavAwareSnackBar(
        context,
        content: Text(l10n.authError(error)),
      );
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showNavAwareSnackBar(
        context,
        content: Text(l10n.profileAvatarUploadError),
      );
    } finally {
      authService.dispose();
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Account?>(
      future: _accountFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final account = snapshot.data;
        final double scrollBottomPadding =
            navAwareBottomPadding(context, extra: 24);
        return SafeArea(
          top: true,
          bottom: false,
          child: RefreshIndicator(
            color: primaryColor,
            onRefresh: _refreshAccount,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                defaultPadding,
                0,
                defaultPadding,
                scrollBottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(
                    account: account,
                    onEdit: () => _openProfileInfo(account),
                    onAvatarTap: account == null ? null : () => _changeAvatar(),
                    isAvatarUploading: _isUploadingAvatar,
                  ),
                  const SizedBox(height: 20),
                  _LoyaltyHighlight(
                    account: account,
                    onCashbackTap:
                        account == null ? null : () => _openCashback(account),
                  ),
                  const SizedBox(height: 24),
                  _SettingsSection(
                    onProfileInfoTap: () => _openProfileInfo(account),
                    onChangePinTap: _openChangePin,
                    onNotificationsTap: _openNotifications,
                  ),
                  const SizedBox(height: 24),
                  _SupportSection(
                    onHelpCenterTap: _openHelpCenter,
                    onReferFriendsTap: () => _openReferFriends(account),
                    showRefer: false,
                  ),
                  const SizedBox(height: 24),
                  const _LanguageSwitcher(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    this.account,
    required this.onEdit,
    this.onAvatarTap,
    required this.isAvatarUploading,
  });

  final Account? account;
  final VoidCallback onEdit;
  final VoidCallback? onAvatarTap;
  final bool isAvatarUploading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final displayName = (account?.name.trim().isEmpty ?? true)
        ? l10n.profileGuestName
        : account!.name.trim();
    final displayPhone = account == null ? '—' : _formatPhone(account?.phone);
    final initials = _initials(displayName);
    final hasPhoto = (account?.profilePhotoUrl ?? '').isNotEmpty;
    final dob = account?.dateOfBirth;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        children: [
          InkWell(
            onTap: onAvatarTap,
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0DD277), Color(0xFF0AA35D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    backgroundImage: hasPhoto
                        ? NetworkImage(account!.profilePhotoUrl!)
                        : null,
                    child: !hasPhoto
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: isAvatarUploading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 15,
                            color: primaryColor,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayPhone,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (dob != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.profileDobLabel}: ${l10n.formatDateDdMMyyyy(dob)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: bodyTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (account == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.profileLoginRequired,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: bodyTextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: primaryColor),
          ),
        ],
      ),
    );
  }

  String _formatPhone(String? digits) {
    if (digits == null || digits.isEmpty) return '+998 -- --- -- --';
    final buffer = StringBuffer('+');
    buffer.write(digits);
    return buffer.toString();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'GU';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final result = (first + second).toUpperCase();
    return result.isEmpty ? 'GU' : result;
  }
}

class _LoyaltyHighlight extends StatelessWidget {
  const _LoyaltyHighlight({
    required this.account,
    required this.onCashbackTap,
  });

  final Account? account;
  final VoidCallback? onCashbackTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRu = l10n.locale == AppLocale.ru;
    final balanceValue = account?.cashbackBalance;
    final balanceLabel =
        balanceValue != null ? _formatCurrency(balanceValue, isRu) : '—';
    final helper = account == null
        ? l10n.cashbackLoginRequired
        : l10n.cashbackHelper;

    return CombinedCardWidget(
      balanceLabel: l10n.cashbackTitle,
      balanceValue: balanceLabel,
      balanceNote: helper,
      tierTitle: '',
      tierNote: '',
      showTier: false,
      currentPointsText: null,
      onTap: onCashbackTap,
    );
  }

  String _formatCurrency(double value, bool isRu) {
    final formatted = _formatAmount(value, isRu: isRu);
    final suffix = isRu ? 'сум' : 'soʻm';
    return '$formatted $suffix';
  }

  String _formatAmount(double value, {required bool isRu}) {
    if (value.isNaN || value.isInfinite) return '0';
    final isNegative = value < 0;
    final absValue = value.abs();

    final isWhole = absValue == absValue.truncateToDouble();
    final raw =
        isWhole ? absValue.toStringAsFixed(0) : absValue.toStringAsFixed(1);

    final parts = raw.split('.');
    final intPart = parts.first;
    final formattedInt = _groupDigits(intPart);

    if (parts.length == 1) {
      return isNegative ? '-$formattedInt' : formattedInt;
    }

    final fractional = parts[1].replaceFirst(RegExp(r'0+$'), '');
    if (fractional.isEmpty) {
      return isNegative ? '-$formattedInt' : formattedInt;
    }

    final decimalSeparator = isRu ? ',' : '.';
    final formatted = '$formattedInt$decimalSeparator$fractional';
    return isNegative ? '-$formatted' : formatted;
  }

  String _groupDigits(String digits) {
    final reversed = digits.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < reversed.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(reversed[i]);
    }
    return buffer.toString().split('').reversed.join();
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.onProfileInfoTap,
    required this.onChangePinTap,
    required this.onNotificationsTap,
  });

  final VoidCallback onProfileInfoTap;
  final VoidCallback onChangePinTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: l10n.profileAccountSection),
        const SizedBox(height: 12),
        _ProfileMenuCard(
          icon: Icons.person_outline,
          title: l10n.profileInfoMenuTitle,
          subtitle: l10n.profileInfoMenuSubtitle,
          onTap: onProfileInfoTap,
        ),
        _ProfileMenuCard(
          icon: Icons.lock_outline,
          title: l10n.profilePinMenuTitle,
          subtitle: l10n.profilePinMenuSubtitle,
          onTap: onChangePinTap,
        ),
        _ProfileMenuCard(
          icon: Icons.notifications_active_outlined,
          title: l10n.profileNotificationsMenuTitle,
          subtitle: l10n.profileNotificationsMenuSubtitle,
          onTap: onNotificationsTap,
        ),
      ],
    );
  }
}

class _SupportSection extends StatelessWidget {
  const _SupportSection({
    required this.onHelpCenterTap,
    this.onReferFriendsTap,
    this.showRefer = true,
  });

  final VoidCallback onHelpCenterTap;
  final VoidCallback? onReferFriendsTap;
  final bool showRefer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: l10n.profileSupportSection),
        const SizedBox(height: 12),
        _ProfileMenuCard(
          icon: Icons.headset_mic_outlined,
          title: l10n.profileHelpMenuTitle,
          subtitle: l10n.profileHelpMenuSubtitle,
          onTap: onHelpCenterTap,
        ),
        if (showRefer && onReferFriendsTap != null)
          _ProfileMenuCard(
            icon: Icons.card_giftcard_outlined,
            title: l10n.profileReferMenuTitle,
            subtitle: l10n.profileReferMenuSubtitle,
            onTap: onReferFriendsTap!,
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: primaryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: bodyTextColor,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: bodyTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: l10n.profileLanguageSectionTitle),
        const SizedBox(height: 8),
        Text(
          l10n.profileLanguageSectionSubtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: bodyTextColor,
              ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: AppLanguage.instance,
          builder: (context, _) {
            final current = AppLanguage.instance.locale;
            return Row(
              children: [
                Expanded(
                  child: _LanguageButton(
                    label: "O'zbekcha",
                    isActive: current == AppLocale.uz,
                    onTap: () => AppLanguage.instance.setLocale(AppLocale.uz),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LanguageButton(
                    label: 'Русский',
                    isActive: current == AppLocale.ru,
                    onTap: () => AppLanguage.instance.setLocale(AppLocale.ru),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = isActive ? primaryColor : Colors.white;
    final foreground = isActive ? Colors.white : titleColor;
    final borderColor = isActive ? primaryColor : const Color(0xFFCBD4E1);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        side: BorderSide(color: borderColor, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      child: Text(label),
    );
  }
}
