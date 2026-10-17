import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  late final List<FocusNode> _nodes;
  late final List<TextEditingController> _controllers;
  bool _isSubmitting = false;
  bool _isDistributingCode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(4, (_) => FocusNode());
    _controllers = List.generate(4, (_) => TextEditingController());
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    for (final node in _nodes) {
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _allFieldsFilled() {
    return _controllers.every((c) => c.text.trim().isNotEmpty);
  }

  Future<void> _submitIfReady() async {
    if (_isSubmitting || !_allFieldsFilled()) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final code = _controllers.map((c) => c.text).join();

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final success = await widget.onSubmit(code);
    if (!mounted) return;

    if (!success) {
      setState(() {
        _isSubmitting = false;
        _error = widget.incorrectCodeLabel;
        for (final controller in _controllers) {
          controller.clear();
        }
        _nodes.first.requestFocus();
      });
    } else {
      setState(() => _isSubmitting = false);
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return false;
    }
    final FocusNode? currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) return false;
    final int currentIndex =
        _nodes.indexWhere((FocusNode node) => identical(node, currentFocus));
    if (currentIndex <= 0) return false;
    final controller = _controllers[currentIndex];
    if (controller.text.isNotEmpty) return false;
    final prevNode = _nodes[currentIndex - 1];
    final prevController = _controllers[currentIndex - 1];
    prevNode.requestFocus();
    prevController.selection =
        TextSelection.collapsed(offset: prevController.text.length);
    return false;
  }

  void _handleDigitChanged(int index, String rawValue) {
    if (_isDistributingCode) return;
    final digits = rawValue.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 1) {
      _isDistributingCode = true;
      for (var offset = 0;
          offset < digits.length && index + offset < 4;
          offset++) {
        _controllers[index + offset].value = TextEditingValue(
          text: digits[offset],
          selection: const TextSelection.collapsed(offset: 1),
        );
      }
      _isDistributingCode = false;
      _nodes[(index + digits.length - 1).clamp(0, 3)].unfocus();
    } else if (digits.isNotEmpty) {
      final nextNode = index < _nodes.length - 1 ? _nodes[index + 1] : null;
      nextNode?.requestFocus();
    }

    setState(() {});
    _submitIfReady();
  }

  Widget _buildDigitField(int index) {
    final node = _nodes[index];
    final controller = _controllers[index];
    const borderRadius = BorderRadius.all(Radius.circular(AppRadius.card));

    return Semantics(
      label:
          '${AppLocalizations.of(context).authOtpScreenTitle} ${index + 1}/4',
      textField: true,
      child: SizedBox(
        width: 56,
        height: 56,
        child: TextFormField(
          onChanged: (rawValue) => _handleDigitChanged(index, rawValue),
          validator: RequiredValidator(errorText: '').call,
          autofocus: index == 0,
          focusNode: node,
          obscureText: false,
          autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.zero,
            counterText: '',
            errorStyle: TextStyle(height: 0),
            filled: true,
            fillColor: screenBackgroundColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: appBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          controller: controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i < 4; i++) _buildDigitField(i),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: defaultPadding),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else
              const SizedBox(height: defaultPadding * 2),
            // Continue Button
            PrimaryButton(
              text: l10n.authContinue,
              isLoading: _isSubmitting,
              press: _allFieldsFilled() ? _submitIfReady : null,
              uppercase: false,
            ),
          ],
        ),
      ),
    );
  }
}
