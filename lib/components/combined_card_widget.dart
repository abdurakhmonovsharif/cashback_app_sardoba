import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CombinedCardWidget extends StatelessWidget {
  const CombinedCardWidget({
    super.key,
    required this.balanceLabel,
    required this.balanceValue,
    required this.balanceNote,
    required this.tierTitle,
    required this.tierNote,
    this.currentPointsText,
    this.onTap,
  });

  final String balanceLabel;
  final String balanceValue;
  final String balanceNote;
  final String tierTitle;
  final String tierNote;
  final String? currentPointsText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(
      Theme.of(context).textTheme,
    );
    final card = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDFDFE), Color(0xFFF3F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 360;
          final balanceSection = _BalanceSection(
            label: balanceLabel,
            value: balanceValue,
            note: balanceNote,
            theme: theme,
          );
          final tierSection = _TierSection(
            title: tierTitle,
            note: tierNote,
            currentPointsText: currentPointsText,
            theme: theme,
          );

          if (isCompact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                balanceSection,
                const SizedBox(height: 18),
                tierSection,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: balanceSection),
              Container(
                width: 1,
                height: 68,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: const Color(0xFFE2E7EE),
              ),
              Expanded(child: tierSection),
            ],
          );
        },
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: card,
      ),
    );
  }
}

class _BalanceSection extends StatelessWidget {
  const _BalanceSection({
    required this.label,
    required this.value,
    required this.note,
    required this.theme,
  });

  final String label;
  final String value;
  final String note;
  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _IconBadge(
          colors: [Color(0xFFB9F4D2), Color(0xFF7EE5AE)],
          icon: Icons.account_balance_wallet_rounded,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.labelMedium?.copyWith(
                  color: const Color(0xFF6F7789),
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.headlineSmall?.copyWith(
                  color: const Color(0xFF1F2333),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note,
                style: theme.bodySmall?.copyWith(
                  color: const Color(0xFF7C8598),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TierSection extends StatelessWidget {
  const _TierSection({
    required this.title,
    required this.note,
    required this.theme,
    this.currentPointsText,
  });

  final String title;
  final String note;
  final TextTheme theme;
  final String? currentPointsText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _IconBadge(
          colors: [Color(0xFFFFE3C1), Color(0xFFFFB875)],
          icon: Icons.workspace_premium_rounded,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.titleMedium?.copyWith(
                  color: const Color(0xFF1F2333),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: theme.bodyMedium?.copyWith(
                  color: const Color(0xFFE28A39),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (currentPointsText != null &&
                  currentPointsText!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  currentPointsText!,
                  style: theme.bodySmall?.copyWith(
                    color: const Color(0xFF7C8598),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.colors,
    required this.icon,
  });

  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }
}
