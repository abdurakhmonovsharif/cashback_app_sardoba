import 'package:flutter/material.dart';

import '../constants.dart';

class PointsBalanceCard extends StatelessWidget {
  const PointsBalanceCard({
    super.key,
    required this.title,
    required this.balanceLabel,
    this.balanceUnit,
    required this.helper,
    this.onTap,
    this.cardKey,
  });

  final String title;
  final String balanceLabel;
  final String? balanceUnit;
  final String helper;
  final VoidCallback? onTap;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final spokenBalance =
        balanceUnit == null ? balanceLabel : '$balanceLabel $balanceUnit';
    return LayoutBuilder(builder: (context, constraints) {
      final stackedContent = constraints.maxWidth < 320;
      final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          );
      final balanceStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      final unitStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          );
      final helperStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.96),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          );
      final balance = Text.rich(
        TextSpan(
          text: balanceLabel,
          children: [
            if (balanceUnit != null)
              TextSpan(text: ' $balanceUnit', style: unitStyle),
          ],
        ),
        softWrap: true,
        style: balanceStyle,
      );
      final titleWidget = Text(title, style: titleStyle, softWrap: true);
      final supportingText = Text(helper, style: helperStyle, softWrap: true);
      final icon = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          color: Colors.white,
          size: 22,
        ),
      );
      final chevron = onTap == null
          ? null
          : const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 24,
            );

      final content = stackedContent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    icon,
                    const SizedBox(width: 10),
                    Expanded(child: titleWidget),
                    if (chevron != null) ...[
                      const SizedBox(width: 4),
                      chevron,
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                balance,
                const SizedBox(height: 4),
                supportingText,
              ],
            )
          : Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      titleWidget,
                      const SizedBox(height: 2),
                      balance,
                      const SizedBox(height: 4),
                      supportingText,
                    ],
                  ),
                ),
                if (chevron != null) ...[
                  const SizedBox(width: 8),
                  chevron,
                ],
              ],
            );

      final card = ConstrainedBox(
        key: cardKey,
        constraints: const BoxConstraints(minHeight: 104),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppBrandColors.deepGreen, AppBrandColors.deepGreenShade],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: const [appCardShadow],
          ),
          child: content,
        ),
      );

      if (onTap == null) return card;
      return Semantics(
        button: true,
        label: '$title. $spokenBalance. $helper',
        onTap: onTap,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: card,
            ),
          ),
        ),
      );
    });
  }
}
