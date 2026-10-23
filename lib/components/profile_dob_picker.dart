import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_localizations.dart';
import 'app_input_decoration.dart';
import '../constants.dart';
import '../utils/date_input_formatter.dart';

/// Opens the platform-native date picker with a shared DD.MM.YYYY input mode.
Future<DateTime?> showProfileDobPicker({
  required BuildContext context,
  required AppStrings l10n,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final arguments = _DobPickerArguments(
    title: l10n.profileDobLabel,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    cancelLabel: l10n.commonCancel,
    confirmLabel: l10n.profileDobConfirm,
    invalidDateMessage: l10n.profileDobInvalid,
    calendarLabel: l10n.profileDobCalendarMode,
    inputLabel: l10n.profileDobInputMode,
    switchToCalendarLabel: l10n.profileDobSwitchToCalendar,
    switchToInputLabel: l10n.profileDobSwitchToInput,
  );

  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (_) => _CupertinoProfileDobPickerSheet(arguments: arguments),
    );
  }

  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MaterialProfileDobPickerDialog(arguments: arguments),
  );
}

class _DobPickerArguments {
  const _DobPickerArguments({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.invalidDateMessage,
    required this.calendarLabel,
    required this.inputLabel,
    required this.switchToCalendarLabel,
    required this.switchToInputLabel,
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String cancelLabel;
  final String confirmLabel;
  final String invalidDateMessage;
  final String calendarLabel;
  final String inputLabel;
  final String switchToCalendarLabel;
  final String switchToInputLabel;
}

DateTime? _validDobInput(String value, _DobPickerArguments arguments) {
  final parsed = parseDateOfBirthInput(value);
  if (parsed == null ||
      parsed.isBefore(arguments.firstDate) ||
      parsed.isAfter(arguments.lastDate)) {
    return null;
  }
  return parsed;
}

bool _isCompleteInvalidDob(String value) =>
    value.replaceAll(RegExp(r'\D'), '').length == 8;

class _MaterialProfileDobPickerDialog extends StatefulWidget {
  const _MaterialProfileDobPickerDialog({required this.arguments});

  final _DobPickerArguments arguments;

  @override
  State<_MaterialProfileDobPickerDialog> createState() =>
      _MaterialProfileDobPickerDialogState();
}

class _MaterialProfileDobPickerDialogState
    extends State<_MaterialProfileDobPickerDialog> {
  late final TextEditingController _dateController;
  late DateTime? _selectedDate;
  bool _inputMode = false;
  bool _showInvalidDate = false;

  _DobPickerArguments get _args => widget.arguments;

  @override
  void initState() {
    super.initState();
    _selectedDate = _args.initialDate;
    _dateController = TextEditingController(
      text: formatDateOfBirth(_args.initialDate),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  void _handleDateInput(String value) {
    final parsed = _validDobInput(value, _args);
    setState(() {
      _selectedDate = parsed;
      _showInvalidDate = _isCompleteInvalidDob(value) && parsed == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDate = _selectedDate;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            defaultPadding,
            AppSpacing.section + AppSpacing.related,
            defaultPadding,
            AppSpacing.related,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_args.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.section),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? _dateController.text
                          : formatDateOfBirth(selectedDate),
                      style: theme.textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: _inputMode
                        ? _args.switchToCalendarLabel
                        : _args.switchToInputLabel,
                    onPressed: () {
                      if (_inputMode) FocusScope.of(context).unfocus();
                      setState(() => _inputMode = !_inputMode);
                    },
                    icon: Icon(
                      _inputMode
                          ? Icons.calendar_today_outlined
                          : Icons.edit_outlined,
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              if (_inputMode) ...[
                const SizedBox(height: AppSpacing.section + AppSpacing.related),
                TextField(
                  controller: _dateController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [DateInputFormatter()],
                  onChanged: _handleDateInput,
                  decoration: InputDecoration(
                    hintText: 'DD.MM.YYYY',
                    errorText:
                        _showInvalidDate ? _args.invalidDateMessage : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.related),
              ] else
                CalendarDatePicker(
                  initialDate: selectedDate ?? _args.initialDate,
                  firstDate: _args.firstDate,
                  lastDate: _args.lastDate,
                  onDateChanged: (date) {
                    setState(() {
                      _selectedDate = date;
                      _dateController.text = formatDateOfBirth(date);
                      _showInvalidDate = false;
                    });
                  },
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_args.cancelLabel),
                  ),
                  const SizedBox(width: AppSpacing.related),
                  TextButton(
                    onPressed: selectedDate == null
                        ? null
                        : () => Navigator.of(context).pop(selectedDate),
                    child: Text(_args.confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CupertinoProfileDobPickerSheet extends StatefulWidget {
  const _CupertinoProfileDobPickerSheet({required this.arguments});

  final _DobPickerArguments arguments;

  @override
  State<_CupertinoProfileDobPickerSheet> createState() =>
      _CupertinoProfileDobPickerSheetState();
}

class _CupertinoProfileDobPickerSheetState
    extends State<_CupertinoProfileDobPickerSheet> {
  late final TextEditingController _dateController;
  late final FocusNode _dateFocusNode;
  late DateTime? _selectedDate;
  bool _inputMode = false;
  bool _showInvalidDate = false;

  _DobPickerArguments get _args => widget.arguments;

  @override
  void initState() {
    super.initState();
    _selectedDate = _args.initialDate;
    _dateController = TextEditingController(
      text: formatDateOfBirth(_args.initialDate),
    );
    _dateFocusNode = FocusNode()..addListener(_handleDateFocusChanged);
  }

  void _handleDateFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _dateFocusNode
      ..removeListener(_handleDateFocusChanged)
      ..dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _handleDateInput(String value) {
    final parsed = _validDobInput(value, _args);
    setState(() {
      _selectedDate = parsed;
      _showInvalidDate = _isCompleteInvalidDob(value) && parsed == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final inputTextStyle = Theme.of(context).textTheme.bodyLarge;
    final selectedDate = _selectedDate;

    return AnimatedPadding(
      duration: kThemeAnimationDuration,
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        key: const ValueKey('profile-dob-picker-sheet'),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.panel),
          ),
        ),
        constraints: BoxConstraints(
          maxHeight: mediaSize.height - mediaPadding.top - AppSpacing.section,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                defaultPadding,
                AppSpacing.related,
                defaultPadding,
                AppSpacing.related,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3.resolveFrom(context),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(
                      height: AppSpacing.section + AppSpacing.related),
                  Text(
                    _args.title,
                    style:
                        CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                  ),
                  const SizedBox(height: AppSpacing.section),
                  CupertinoSlidingSegmentedControl<bool>(
                    groupValue: _inputMode,
                    children: {
                      false: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.related,
                        ),
                        child: Text(
                          _args.calendarLabel,
                          style: CupertinoTheme.of(context).textTheme.textStyle,
                        ),
                      ),
                      true: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.related,
                        ),
                        child: Text(
                          _args.inputLabel,
                          style: CupertinoTheme.of(context).textTheme.textStyle,
                        ),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value == null) return;
                      if (_inputMode && !value) {
                        FocusScope.of(context).unfocus();
                      }
                      setState(() => _inputMode = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.section),
                  if (_inputMode)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CupertinoTextField(
                          controller: _dateController,
                          focusNode: _dateFocusNode,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: const [DateInputFormatter()],
                          onChanged: _handleDateInput,
                          placeholder: 'DD.MM.YYYY',
                          style: inputTextStyle,
                          placeholderStyle: inputTextStyle?.copyWith(
                            color: CupertinoColors.placeholderText
                                .resolveFrom(context),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: defaultPadding,
                            vertical: AppSpacing.related + 6,
                          ),
                          decoration: AppInputDecoration.cupertino(
                            focused: _dateFocusNode.hasFocus,
                            hasError: _showInvalidDate,
                          ),
                        ),
                        if (_showInvalidDate) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              _args.invalidDateMessage,
                              style: TextStyle(
                                color: CupertinoColors.systemRed
                                    .resolveFrom(context),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    SizedBox(
                      height: 216,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: selectedDate ?? _args.initialDate,
                        minimumDate: _args.firstDate,
                        maximumDate: _args.lastDate,
                        onDateTimeChanged: (date) {
                          final selected = DateTime(
                            date.year,
                            date.month,
                            date.day,
                          );
                          setState(() {
                            _selectedDate = selected;
                            _dateController.text = formatDateOfBirth(selected);
                            _showInvalidDate = false;
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: AppSpacing.related),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(_args.cancelLabel),
                      ),
                      CupertinoButton.filled(
                        onPressed: selectedDate == null
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                Navigator.of(context).pop(selectedDate);
                              },
                        child: Text(_args.confirmLabel),
                      ),
                    ],
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
