import 'package:flutter/material.dart';

import '../../../constants.dart';

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.count, required this.filled});

  final int count;
  final int filled;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isFilled = index < filled;
        return AnimatedContainer(
          duration: kDefaultDuration,
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          height: 16,
          width: 16,
          decoration: BoxDecoration(
            color: isFilled ? primaryColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isFilled
                  ? primaryColor
                  : const Color(0xFFBBC3D0).withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    this.isBusy = false,
  });

  final void Function(String digit) onDigitPressed;
  final VoidCallback onBackspacePressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_PinKey>>[
      [
        _PinKey.label('1'),
        _PinKey.label('2'),
        _PinKey.label('3'),
      ],
      [
        _PinKey.label('4'),
        _PinKey.label('5'),
        _PinKey.label('6'),
      ],
      [
        _PinKey.label('7'),
        _PinKey.label('8'),
        _PinKey.label('9'),
      ],
      [
        _PinKey.empty(),
        _PinKey.label('0'),
        _PinKey.backspace(),
      ],
    ];

    const double rowSpacing = 20;
    const double minKeySize = 60;
    const double maxKeySize = 78;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        double keySize = maxKeySize;
        if (availableHeight.isFinite) {
          final candidate =
              (availableHeight - (rowSpacing * rows.length)) / rows.length;
          keySize = candidate.clamp(minKeySize, maxKeySize);
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rows
              .map(
                (row) => Padding(
                  padding: EdgeInsets.symmetric(vertical: rowSpacing / 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: row
                        .map((key) => _buildKey(context, key, keySize))
                        .toList(),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKey(BuildContext context, _PinKey key, double size) {
    if (key.type == _PinKeyType.empty) {
      return SizedBox(width: size, height: size);
    }

    final theme = Theme.of(context);
    final disabled = isBusy;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled
              ? null
              : () {
                  if (key.type == _PinKeyType.backspace) {
                    onBackspacePressed();
                  } else {
                    onDigitPressed(key.label!);
                  }
                },
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFD7DDE5),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: key.type == _PinKeyType.backspace
                ? Icon(
                    Icons.backspace_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  )
                : Text(
                    key.label!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

enum _PinKeyType { digit, backspace, empty }

class _PinKey {
  const _PinKey._(this.type, this.label);

  final _PinKeyType type;
  final String? label;

  factory _PinKey.label(String value) => _PinKey._(_PinKeyType.digit, value);
  factory _PinKey.backspace() => _PinKey._(_PinKeyType.backspace, null);
  factory _PinKey.empty() => const _PinKey._(_PinKeyType.empty, null);
}
