import 'package:flutter/material.dart';

import '../../constants.dart';
import '../catalog/product_detail_pressable.dart';

/// Home's grouping/decimal convention for balances; transactions retain every
/// fractional digit supplied by the model instead of rounding the amount.
String formatWalletPoints(double value,
    {required bool isRu, bool balance = false}) {
  if (!value.isFinite) return '0';
  final absolute = value.abs();
  var raw = balance ? absolute.toStringAsFixed(1) : absolute.toString();
  if (raw.contains('e')) {
    final exponentParts = raw.split('e');
    final mantissa = exponentParts.first.split('.');
    final digits = mantissa.join();
    final point = mantissa.first.length + int.parse(exponentParts.last);
    raw = point <= 0
        ? '0.${'0' * -point}$digits'
        : point >= digits.length
            ? '$digits${'0' * (point - digits.length)}'
            : '${digits.substring(0, point)}.${digits.substring(point)}';
  }
  final parts = raw.split('.');
  final integer =
      parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  final fraction =
      parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  return '${value < 0 ? '−' : ''}$integer${fraction.isEmpty ? '' : '${isRu ? ',' : '.'}$fraction'}';
}

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard(
      {super.key,
      required this.title,
      required this.balanceLabel,
      required this.unit,
      required this.helper,
      required this.progress,
      required this.thresholdLabel,
      required this.remainingLabel,
      required this.canView,
      required this.onView,
      required this.ctaLabel});

  final String title,
      balanceLabel,
      unit,
      helper,
      thresholdLabel,
      remainingLabel,
      ctaLabel;
  final double progress;
  final bool canView;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('wallet-balance'),
      padding: const EdgeInsets.all(WalletTokens.cardPadding),
      decoration: BoxDecoration(
        color: AppBrandColors.deepGreen,
        borderRadius: BorderRadius.circular(WalletTokens.balanceRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: text.titleSmall?.copyWith(
                color: WalletTokens.surface,
                fontSize: WalletTokens.titleSize,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacing.related),
        Text.rich(
            TextSpan(text: balanceLabel, children: [
              TextSpan(
                  text: ' $unit',
                  style: text.titleMedium?.copyWith(
                      color: WalletTokens.surface,
                      fontSize: WalletTokens.amountSize,
                      fontWeight: FontWeight.w500)),
            ]),
            style: text.headlineMedium?.copyWith(
                color: WalletTokens.surface,
                fontSize: WalletTokens.balanceSize,
                height: 1.2,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: WalletTokens.sectionGap),
        ExcludeSemantics(
            child: LinearProgressIndicator(
          key: const ValueKey('wallet-progress'),
          value: progress,
          minHeight: WalletTokens.progressHeight,
          color: WalletTokens.surface,
          backgroundColor: WalletTokens.surface.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadius.control),
        )),
        const SizedBox(height: AppSpacing.section),
        Text(thresholdLabel,
            semanticsLabel: '$thresholdLabel. ${(progress * 100).round()}%',
            style: text.bodyMedium?.copyWith(
                color: WalletTokens.surface,
                fontSize: WalletTokens.titleSize,
                height: 1.4)),
        if (!canView) ...[
          const SizedBox(height: AppSpacing.related),
          Text(remainingLabel,
              key: const ValueKey('wallet-locked-info'),
              style: text.bodySmall?.copyWith(
                  color: WalletTokens.surface,
                  fontSize: WalletTokens.dateSize,
                  height: 1.4)),
        ],
        if (helper.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.related),
          Text(helper,
              style: text.bodySmall
                  ?.copyWith(color: WalletTokens.surface, height: 1.4)),
        ],
        if (canView) ...[
          const SizedBox(height: defaultPadding),
          ProductDetailPressable(
            key: const ValueKey('wallet-view'),
            label: ctaLabel,
            onPressed: onView,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                  minHeight: ProductDetailTokens.touchTarget),
              padding: const EdgeInsets.all(AppSpacing.section),
              decoration: BoxDecoration(
                  color: WalletTokens.surface,
                  borderRadius: BorderRadius.circular(AppRadius.control)),
              alignment: Alignment.center,
              child: Text(ctaLabel,
                  textAlign: TextAlign.center,
                  style: text.labelLarge?.copyWith(
                      color: primaryColor, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }
}

class WalletTransactionRow extends StatelessWidget {
  const WalletTransactionRow(
      {super.key,
      required this.title,
      required this.date,
      required this.amount,
      required this.isRu,
      this.groupLabel,
      this.first = false,
      this.last = false});

  final String title, date;
  final String? groupLabel;
  final double amount;
  final bool isRu, first, last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final positive = amount >= 0;
    final color = positive ? primaryColor : WalletTokens.debit;
    final amountLabel =
        '${positive ? '+' : '−'}${formatWalletPoints(amount.abs(), isRu: isRu)}';
    final unit = isRu ? 'балл' : 'ball';
    final amountStyle = text.titleMedium!.copyWith(
        color: color,
        fontSize: WalletTokens.amountSize,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()]);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${groupLabel == null ? '' : '${groupLabel!}. '}$title. $amountLabel $unit. $date',
      child: Container(
        constraints: const BoxConstraints(minHeight: WalletTokens.rowHeight),
        decoration: BoxDecoration(
            color: WalletTokens.surface,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(first ? AppRadius.card : 0),
                bottom: Radius.circular(last ? AppRadius.card : 0))),
        child: Column(children: [
          if (groupLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  defaultPadding, defaultPadding, defaultPadding, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  groupLabel!,
                  style: text.labelLarge?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: WalletTokens.iconSize,
                  height: WalletTokens.iconSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.control)),
                  child: Icon(
                      positive
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: color,
                      size: WalletTokens.iconGlyph)),
              const SizedBox(width: AppSpacing.section),
              Expanded(child: LayoutBuilder(builder: (context, constraints) {
                final painter = TextPainter(
                    text: TextSpan(text: amountLabel, style: amountStyle),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context))
                  ..layout();
                final stack = painter.width > constraints.maxWidth * 0.46 ||
                    MediaQuery.textScalerOf(context)
                            .scale(WalletTokens.titleSize) >
                        20;
                painter.dispose();
                final amountText = Text(amountLabel,
                    textAlign: TextAlign.right, style: amountStyle);
                final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: text.titleSmall?.copyWith(
                              color: titleColor,
                              fontSize: WalletTokens.titleSize,
                              fontWeight: FontWeight.w500,
                              height: 1.35)),
                      const SizedBox(height: WalletTokens.progressHeight),
                      const SizedBox(height: AppSpacing.related),
                    ]);
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stack) ...[
                        details,
                        const SizedBox(height: AppSpacing.related),
                        Align(
                            alignment: Alignment.centerRight,
                            child: amountText),
                      ] else
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: details),
                              const SizedBox(width: AppSpacing.related),
                              amountText,
                            ]),
                      const SizedBox(height: WalletTokens.progressHeight),
                      Text(date,
                          style: text.bodySmall?.copyWith(
                              color: bodyTextColor,
                              fontSize: WalletTokens.dateSize,
                              height: 1.4)),
                    ]);
              })),
            ]),
          ),
          if (!last)
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Divider(height: 1, thickness: 1, color: appBorderColor)),
        ]),
      ),
    );
  }
}

class WalletSummaryCard extends StatelessWidget {
  const WalletSummaryCard({
    super.key,
    required this.creditLabel,
    required this.debitLabel,
    required this.credited,
    required this.debited,
    required this.isRu,
  });

  final String creditLabel, debitLabel;
  final double credited, debited;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget metric(String label, String value, Color color) => Semantics(
          container: true,
          label: '$label. $value',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: text.bodySmall?.copyWith(color: bodyTextColor)),
              const SizedBox(height: AppSpacing.related),
              Text(value,
                  style: text.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        );
    return Container(
      key: const ValueKey('wallet-summary'),
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: WalletTokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: appBorderColor),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked =
            MediaQuery.textScalerOf(context).scale(WalletTokens.amountSize) >
                24;
        final creditValue = formatWalletPoints(credited, isRu: isRu);
        final debitValue = formatWalletPoints(debited, isRu: isRu);
        final credit = metric(creditLabel,
            credited == 0 ? creditValue : '+$creditValue', primaryColor);
        final debit = metric(debitLabel,
            debited == 0 ? debitValue : '−$debitValue', WalletTokens.debit);
        if (stacked) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                credit,
                const SizedBox(height: defaultPadding),
                debit,
              ]);
        }
        return Row(children: [
          Expanded(child: credit),
          const SizedBox(width: defaultPadding),
          Expanded(child: debit),
        ]);
      }),
    );
  }
}

class WalletFilterButton extends StatelessWidget {
  const WalletFilterButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ProductDetailPressable(
      label: label,
      selected: selected,
      onPressed: onPressed,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: ProductDetailTokens.touchTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: defaultPadding,
          vertical: AppSpacing.section,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? primaryColor : WalletTokens.surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: selected ? primaryColor : appBorderColor),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? WalletTokens.surface : titleColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
