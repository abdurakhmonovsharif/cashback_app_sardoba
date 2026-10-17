import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';

String uzbekPhoneDigits(String value) =>
    value.replaceAll(RegExp(r'[^0-9]'), '');

class UzbekPhonePrefix extends StatelessWidget {
  const UzbekPhonePrefix({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '+998',
              style: TextStyle(
                color: titleColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 24, color: appBorderColor),
          ],
        ),
      );
}

class UzbekPhoneFormatter extends TextInputFormatter {
  const UzbekPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = uzbekPhoneDigits(newValue.text);
    if (digits.startsWith('998') && digits.length > 9) {
      digits = digits.substring(3);
    }
    digits = digits.substring(0, digits.length.clamp(0, 9));
    final groups = <String>[
      if (digits.isNotEmpty) digits.substring(0, digits.length.clamp(0, 2)),
      if (digits.length > 2) digits.substring(2, digits.length.clamp(2, 5)),
      if (digits.length > 5) digits.substring(5, digits.length.clamp(5, 7)),
      if (digits.length > 7) digits.substring(7, digits.length.clamp(7, 9)),
    ];
    final text = groups.join(' ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
