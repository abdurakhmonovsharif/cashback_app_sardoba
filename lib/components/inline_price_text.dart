import 'package:flutter/material.dart';

/// Renders a localized price with a quieter currency unit.
class InlinePriceText extends StatelessWidget {
  const InlinePriceText({
    required this.label,
    required this.style,
    required this.hasPrice,
    this.currencyFontSize,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String label;
  final TextStyle? style;
  final bool hasPrice;
  final double? currencyFontSize;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final separator = label.lastIndexOf(' ');
    if (!hasPrice || separator <= 0) {
      return Text(label, style: style, maxLines: maxLines, overflow: overflow);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label.substring(0, separator)),
          TextSpan(
            text: label.substring(separator),
            style: TextStyle(
              fontSize: currencyFontSize ?? (style?.fontSize ?? 16) * 0.8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
