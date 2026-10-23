import 'package:flutter/services.dart';

/// Formats a date of birth as the user types: DD.MM.YYYY.
class DateInputFormatter extends TextInputFormatter {
  const DateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    final removedOnlySeparator =
        newValue.text.length < oldValue.text.length && digits == oldDigits;
    if (removedOnlySeparator && digits.isNotEmpty) {
      final isBackspace =
          newValue.selection.extentOffset < oldValue.selection.extentOffset;
      final oldCursor =
          oldValue.selection.extentOffset.clamp(0, oldValue.text.length);
      final digitIndex = oldValue.text
          .substring(0, oldCursor)
          .replaceAll(RegExp(r'\D'), '')
          .length;
      final removeAt = isBackspace ? digitIndex - 1 : digitIndex;
      if (removeAt >= 0 && removeAt < digits.length) {
        digits = digits.replaceRange(removeAt, removeAt + 1, '');
      }
    }
    final limitedDigits = digits.length > 8 ? digits.substring(0, 8) : digits;
    final cursorDigitCount = newValue.text
        .substring(
            0, newValue.selection.extentOffset.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'\D'), '')
        .length
        .clamp(0, limitedDigits.length);

    final formatted = formatDateDigits(limitedDigits);
    var cursorOffset = 0;
    var seenDigits = 0;
    while (cursorOffset < formatted.length && seenDigits < cursorDigitCount) {
      if (RegExp(r'\d').hasMatch(formatted[cursorOffset])) seenDigits++;
      cursorOffset++;
    }
    // Keep the caret after a newly inserted separator when typing at the end.
    if (cursorDigitCount == limitedDigits.length &&
        cursorOffset < formatted.length) {
      cursorOffset = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}

String formatDateDigits(String digits) {
  if (digits.length <= 2) {
    return digits.length == 2 ? '$digits.' : digits;
  }
  if (digits.length <= 4) {
    final date = '${digits.substring(0, 2)}.${digits.substring(2)}';
    return digits.length == 4 ? '$date.' : date;
  }
  return '${digits.substring(0, 2)}.${digits.substring(2, 4)}.${digits.substring(4)}';
}

DateTime? parseDateOfBirthInput(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) return null;
  final day = int.tryParse(digits.substring(0, 2));
  final month = int.tryParse(digits.substring(2, 4));
  final year = int.tryParse(digits.substring(4));
  if (day == null || month == null || year == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String formatDateOfBirth(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().padLeft(4, '0')}';
