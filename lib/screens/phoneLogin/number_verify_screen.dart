import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_localizations.dart';
import '../../components/sardoba_auth_logo.dart';
import '../../constants.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_utils.dart';
import 'components/otp_form.dart';

class NumberVerifyScreen extends StatefulWidget {
  const NumberVerifyScreen({
    super.key,
    required this.phone,
    required this.onVerified,
    this.displayPhone,
    this.title,
    this.subtitle,
    this.demoCode,
    this.onResend,
  });

  final String phone;
  final Future<bool> Function(BuildContext context, String code) onVerified;
  final Future<void> Function()? onResend;
  final String? displayPhone;
  final String? title;
  final String? subtitle;
  final String? demoCode;

  @override
  State<NumberVerifyScreen> createState() => _NumberVerifyScreenState();
}

class _NumberVerifyScreenState extends State<NumberVerifyScreen> {
  bool _isResending = false;

  String _buildDefaultSubtitle(AppStrings strings, String phoneLabel) {
    final buffer = StringBuffer(strings.authOtpSubtitle(phoneLabel));
    if (widget.demoCode != null && widget.demoCode!.isNotEmpty) {
      buffer.write('\n${strings.authOtpDemoHelper(widget.demoCode!)}');
    }
    return buffer.toString();
  }

  Future<void> _handleResend(AppStrings strings) async {
    if (widget.onResend == null || _isResending) return;
    setState(() => _isResending = true);
    try {
      await widget.onResend!.call();
      if (!mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(strings.authOtpResent),
      );
    } on AuthServiceException catch (error) {
      if (mounted) {
        showNavAwareSnackBar(
          context,
          content: Text(strings.authError(error)),
        );
      }
    } catch (_) {
      if (mounted) {
        showNavAwareSnackBar(
          context,
          content: Text(strings.authOtpResendFailed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final phoneLabel = widget.displayPhone ?? '+${widget.phone}';
    final subtitle =
        widget.subtitle ?? _buildDefaultSubtitle(strings, phoneLabel);

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: titleColor,
            size: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            defaultPadding,
            12,
            defaultPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(child: SardobaAuthLogo()),
              const SizedBox(height: 24),
              Text(
                widget.title ?? strings.authOtpScreenTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        ) ??
                    const TextStyle(
                      color: titleColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: bodyTextColor,
                          height: 1.45,
                        ) ??
                    const TextStyle(
                      color: bodyTextColor,
                      fontSize: 14,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  border: const Border.fromBorderSide(
                    BorderSide(color: appBorderColor),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: OtpForm(
                  incorrectCodeLabel: strings.authOtpIncorrect,
                  onSubmit: (code) async {
                    try {
                      final success = await widget.onVerified(context, code);
                      if (!success && context.mounted) {
                        showNavAwareSnackBar(
                          context,
                          content: Text(strings.authOtpIncorrect),
                        );
                      }
                      return success;
                    } on AuthServiceException catch (error) {
                      if (context.mounted) {
                        showNavAwareSnackBar(
                          context,
                          content: Text(strings.authError(error)),
                        );
                      }
                      return false;
                    } catch (_) {
                      if (context.mounted) {
                        showNavAwareSnackBar(
                          context,
                          content: Text(strings.commonErrorTryAgain),
                        );
                      }
                      return false;
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      strings.authOtpResendQuestion,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    TextButton(
                      onPressed: widget.onResend == null || _isResending
                          ? null
                          : () => _handleResend(strings),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _isResending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(strings.authOtpResendCta),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  strings.authOtpTerms,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: bodyTextColor.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
