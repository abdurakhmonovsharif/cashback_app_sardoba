import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:sardoba_app/app_localizations.dart';

import '../../../constants.dart';

import '../../../components/buttons/primary_button.dart';

class OtpForm extends StatefulWidget {
  const OtpForm({
    super.key,
    required this.onSubmit,
    this.incorrectCodeLabel = 'Incorrect code',
  });

  final Future<bool> Function(String code) onSubmit;
  final String incorrectCodeLabel;

  @override
  State<OtpForm> createState() => _OtpFormState();
}

class _OtpFormState extends State<OtpForm> {
  final _formKey = GlobalKey<FormState>();

  FocusNode? _pin1Node;
  FocusNode? _pin2Node;
  FocusNode? _pin3Node;
  FocusNode? _pin4Node;
  final TextEditingController _pin1Controller = TextEditingController();
  final TextEditingController _pin2Controller = TextEditingController();
  final TextEditingController _pin3Controller = TextEditingController();
  final TextEditingController _pin4Controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pin1Node = FocusNode();
    _pin2Node = FocusNode();
    _pin3Node = FocusNode();
    _pin4Node = FocusNode();
  }

  @override
  void dispose() {
    super.dispose();
    _pin1Node!.dispose();
    _pin2Node!.dispose();
    _pin3Node!.dispose();
    _pin4Node!.dispose();
    _pin1Controller.dispose();
    _pin2Controller.dispose();
    _pin3Controller.dispose();
    _pin4Controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  onChanged: (value) {
                    if (value.length == 1) _pin2Node!.requestFocus();
                  },
                  validator: RequiredValidator(errorText: '').call,
                  autofocus: true,
                  maxLength: 1,
                  focusNode: _pin1Node,
                  obscureText: false,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  controller: _pin1Controller,
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  onChanged: (value) {
                    if (value.length == 1) _pin3Node!.requestFocus();
                  },
                  validator: RequiredValidator(errorText: '').call,
                  maxLength: 1,
                  focusNode: _pin2Node,
                  obscureText: false,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  controller: _pin2Controller,
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  onChanged: (value) {
                    if (value.length == 1) _pin4Node!.requestFocus();
                  },
                  validator: RequiredValidator(errorText: '').call,
                  maxLength: 1,
                  focusNode: _pin3Node,
                  obscureText: false,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  controller: _pin3Controller,
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  onChanged: (value) {
                    if (value.length == 1) _pin4Node!.unfocus();
                  },
                  validator: RequiredValidator(errorText: '').call,
                  maxLength: 1,
                  focusNode: _pin4Node,
                  obscureText: false,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  controller: _pin4Controller,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: defaultPadding),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFED5A5A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            const SizedBox(height: defaultPadding * 2),
          // Continue Button
          PrimaryButton(
            text:l10n.authContinue ,
            isLoading: _isSubmitting,
            press: () async {
              if (!(_formKey.currentState?.validate() ?? false) ||
                  _isSubmitting) {
                return;
              }
              final code = _pin1Controller.text +
                  _pin2Controller.text +
                  _pin3Controller.text +
                  _pin4Controller.text;
              setState(() {
                _isSubmitting = true;
                _error = null;
              });
              final success = await widget.onSubmit(code);
              if (!mounted) {
                _isSubmitting = false;
                return;
              }
              if (!success) {
                setState(() {
                  _isSubmitting = false;
                  _error = widget.incorrectCodeLabel;
                  _pin1Controller.clear();
                  _pin2Controller.clear();
                  _pin3Controller.clear();
                  _pin4Controller.clear();
                  _pin1Node!.requestFocus();
                });
              } else {
                setState(() => _isSubmitting = false);
              }
            },
          )
        ],
      ),
    );
  }
}
