import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants.dart';

/// Branded press feedback scoped to Product Detail, with keyboard and semantics.
class ProductDetailPressable extends StatefulWidget {
  const ProductDetailPressable(
      {super.key,
      required this.child,
      required this.label,
      this.onPressed,
      this.selected,
      this.preserveChildSemantics = false});
  final Widget child;
  final String label;
  final VoidCallback? onPressed;
  final bool? selected;
  final bool preserveChildSemantics;

  @override
  State<ProductDetailPressable> createState() => _ProductDetailPressableState();
}

class _ProductDetailPressableState extends State<ProductDetailPressable> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      label: widget.label,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      excludeSemantics: !widget.preserveChildSemantics,
      explicitChildNodes: widget.preserveChildSemantics,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: enabled,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          }),
        },
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: enabled && _pressed ? ProductDetailTokens.pressedScale : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : kDefaultDuration,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: _focused ? Border.all(color: primaryColor) : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
