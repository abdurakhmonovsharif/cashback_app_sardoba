import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_language.dart';
import '../../app_localizations.dart';
import '../../components/points_balance_card.dart';
import '../../constants.dart';
import '../../utils/responsive_layout.dart';
import '../../entry_point.dart';
import '../../models/account.dart';
import '../../navigation/app_navigator.dart';
import '../../services/app_update_service.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../../services/session_sync_service.dart';
import '../../utils/snackbar_utils.dart';
import '../auth/sign_in_screen.dart';
import '../points/points_screen.dart';
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: screenBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: defaultPadding,
        title: Text(
          l10n.profileTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: const ResponsiveViewport(child: _ProfileBody()),
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
  static const int _pointsThreshold = 30000;
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

  Future<void> _openPoints(Account? account) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PointsScreen(
          account: account,
          threshold: _pointsThreshold,
          initialBalance: account?.pointsBalance ?? 0,
          initialEntries: account?.pointsHistory,
          initialLoyalty: account?.loyalty,
        ),
      ),
    );
    if (!mounted) return;
    unawaited(_refreshAccount());
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SignInScreen(
          destinationAfterLogin: EntryPoint(initialIndex: 3),
        ),
      ),
    );
    if (!mounted) return;
    unawaited(_refreshAccount());
  }

  Future<void> _confirmLogout() async {
    final l10n = AppLocalizations.of(context);
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileLogoutConfirmTitle),
        content: Text(l10n.profileLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileLogoutConfirmSecondary),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileLogoutConfirmPrimary),
          ),
        ],
      ),
    );
    if (shouldLogout == true) await AppNavigator.forceLogout();
  }

  Future<ImageSource?> _selectImageSource() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.panel)),
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
            color: Theme.of(context).colorScheme.primary,
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
                  if (account == null)
                    _ProfileHeader(
                      account: null,
                      onEdit: _openLogin,
                      onCardTap: _openLogin,
                      onAvatarTap: _openLogin,
                      isAvatarUploading: false,
                    )
                  else
                    _ProfileHeader(
                      account: account,
                      onEdit: () => _openProfileInfo(account),
                      onAvatarTap: _changeAvatar,
                      isAvatarUploading: _isUploadingAvatar,
                    ),
                  const SizedBox(height: 24),
                  _LoyaltyHighlight(
                    account: account,
                    onPointsTap: account == null
                        ? _openLogin
                        : () => _openPoints(account),
                  ),
                  const SizedBox(height: 24),
                  if (account != null) ...[
                    _SettingsSection(
                      onProfileInfoTap: () => _openProfileInfo(account),
                      onChangePinTap: _openChangePin,
                      onNotificationsTap: _openNotifications,
                    ),
                    const SizedBox(height: 24),
                  ],
                  _SupportSection(
                    onHelpCenterTap: _openHelpCenter,
                    onReferFriendsTap: () => _openReferFriends(account),
                    showRefer: false,
                  ),
                  const SizedBox(height: 24),
                  const _LanguageSwitcher(),
                  if (account != null) ...[
                    const SizedBox(height: 24),
                    _LogoutAction(onTap: _confirmLogout),
                  ],
                  const _AppVersionFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppVersionFooter extends StatefulWidget {
  const _AppVersionFooter();

  @override
  State<_AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<_AppVersionFooter> {
  late final Future<InstalledAppInfo> _appInfo =
      AppUpdateService.installedAppInfo();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InstalledAppInfo>(
      future: _appInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text(
            'Sardoba · ${AppLocalizations.of(context).profileAppVersion(info.version)}',
            key: const ValueKey('profile-app-version'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: bodyTextColor,
                ),
          ),
        );
      },
    );
  }
}

class _GuestProfileContent extends StatelessWidget {
  const _GuestProfileContent({
    required this.onLoginTap,
    required this.description,
    required this.loginLabel,
    required this.guestName,
    required this.initials,
  });

  final VoidCallback onLoginTap;
  final String description;
  final String loginLabel;
  final String guestName;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.primaryContainer,
              child: Text(
                initials,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guestName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: onLoginTap,
            icon: const Icon(Icons.login_rounded, size: 18),
            label: Text(loginLabel),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    this.account,
    required this.onEdit,
    this.onCardTap,
    this.onAvatarTap,
    required this.isAvatarUploading,
  });

  final Account? account;
  final VoidCallback onEdit;
  final VoidCallback? onCardTap;
  final VoidCallback? onAvatarTap;
  final bool isAvatarUploading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final displayName = (account?.name.trim().isNotEmpty ?? false)
        ? account!.name.trim()
        : l10n.profileGuestName;
    final displayPhone = _formatPhone(account?.phone);
    final initials = _initials(displayName);
    final hasPhoto = (account?.profilePhotoUrl ?? '').isNotEmpty;
    final dob = account?.dateOfBirth;
    final colors = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          key: ValueKey(
            account == null ? 'profile-guest-card' : 'profile-account-card',
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: appBorderColor),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: account == null
              ? _GuestProfileContent(
                  onLoginTap: onEdit,
                  description: l10n.profileGuestDescription,
                  loginLabel: l10n.profileGuestLoginCta,
                  guestName: l10n.profileGuestName,
                  initials: _initials(l10n.profileGuestName),
                )
              : Row(
                  children: [
                    InkWell(
                      onTap: onAvatarTap,
                      borderRadius: BorderRadius.circular(40),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 56,
                            width: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  AppBrandColors.deepGreen,
                                  AppBrandColors.deepGreenShade,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.14),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: colors.surface,
                              child: hasPhoto
                                  ? ClipOval(
                                      child: Image.network(
                                        account!.profilePhotoUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Text(
                                          initials,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: colors.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: colors.primary,
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              height: 24,
                              width: 24,
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
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: colors.primary,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 2,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            displayPhone,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (dob != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${l10n.profileDobLabel}: ${l10n.formatDateDdMMyyyy(dob)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      tooltip: l10n.profileInfoMenuTitle,
                      icon: Icon(Icons.edit_outlined, color: colors.primary),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
                        ),
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ],
                ),
        ),
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
    required this.onPointsTap,
  });

  final Account? account;
  final VoidCallback? onPointsTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRu = l10n.locale == AppLocale.ru;
    final balanceValue = account?.pointsBalance;
    final balanceLabel =
        balanceValue != null ? _formatAmount(balanceValue, isRu: isRu) : '—';
    final helper =
        account == null ? l10n.pointsLoginRequired : l10n.pointsHelper;

    return PointsBalanceCard(
      cardKey: const ValueKey('profile-bonus-card'),
      title: l10n.pointsTitle,
      balanceLabel: balanceLabel,
      balanceUnit: balanceValue != null ? (isRu ? 'балл' : 'ball') : null,
      helper: helper,
      onTap: onPointsTap,
    );
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
          surfaceKey: const ValueKey('profile-support-card'),
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
    final colors = Theme.of(context).colorScheme;
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _LogoutAction extends StatelessWidget {
  const _LogoutAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.logout_rounded),
      label: Text(l10n.profileLogout),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.error,
        side: BorderSide(color: colors.errorContainer),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Key? surfaceKey;

  const _ProfileMenuCard({
    this.surfaceKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: onTap,
            child: Container(
              key: surfaceKey,
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: appBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      color: colors.primaryContainer,
                    ),
                    alignment: Alignment.center,
                    child:
                        Icon(icon, color: colors.onPrimaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: colors.onSurface,
                                    fontSize: 16,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 13,
                                    height: 1.25,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: colors.onSurfaceVariant,
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

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: l10n.profileLanguageSectionTitle),
        const SizedBox(height: 8),
        Text(
          l10n.profileLanguageSectionSubtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 13,
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
                    buttonKey: const ValueKey('profile-language-uz'),
                    onTap: () => AppLanguage.instance.setLocale(AppLocale.uz),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LanguageButton(
                    label: 'Русский',
                    isActive: current == AppLocale.ru,
                    buttonKey: const ValueKey('profile-language-ru'),
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
    this.buttonKey,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background =
        isActive ? colors.primary : colors.surfaceContainerLowest;
    final foreground = isActive ? colors.onPrimary : colors.onSurface;
    final borderColor = isActive ? colors.primary : appBorderColor;
    return Semantics(
      button: true,
      selected: isActive,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: borderColor, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
        ),
        child: ExcludeSemantics(child: Text(label)),
      ),
    );
  }
}
