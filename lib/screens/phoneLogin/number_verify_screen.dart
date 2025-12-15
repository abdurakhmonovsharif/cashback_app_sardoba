import 'package:flutter/material.dart';

import '../../app_localizations.dart';
import '../../components/welcome_text.dart';
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
      appBar: AppBar(
        title: Text(widget.title ?? strings.authOtpScreenTitle),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WelcomeText(
                title: widget.title ?? strings.authOtpScreenTitle,
                text: subtitle,
              ),
              OtpForm(
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
              const SizedBox(height: defaultPadding),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    strings.authOtpResendQuestion,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  TextButton(
                    onPressed: widget.onResend == null || _isResending
                        ? null
                        : () => _handleResend(strings),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
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
              const SizedBox(height: defaultPadding),
              Center(
                child: Text(
                  strings.authOtpTerms,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: defaultPadding),
            ],
          ),
        ),
      ),
    );
  }
}
