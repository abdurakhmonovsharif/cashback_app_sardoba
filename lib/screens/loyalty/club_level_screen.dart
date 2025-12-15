import 'package:flutter/material.dart';

import '../../app_localizations.dart';
import '../../constants.dart';

class ClubLevelScreen extends StatelessWidget {
  const ClubLevelScreen({super.key});

  static const String _currentLevel = 'Silver';
  static const int _pointsToNext = 3000;
  static const int _nextLevelRequirement = 15000;

  double get _progress =>
      (_nextLevelRequirement - _pointsToNext) / _nextLevelRequirement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final benefits = [
      _ClubBenefit(
        icon: Icons.flash_on_rounded,
        color: primaryColor,
        title: l10n.clubLevelBenefitPriority,
        description: l10n.clubLevelBenefitPriorityDesc,
      ),
      _ClubBenefit(
        icon: Icons.cake_rounded,
        color: accentColor,
        title: l10n.clubLevelBenefitBirthday,
        description: l10n.clubLevelBenefitBirthdayDesc,
      ),
      _ClubBenefit(
        icon: Icons.percent_rounded,
        color: const Color(0xFF6B6BE8),
        title: l10n.clubLevelBenefitDiscount,
        description: l10n.clubLevelBenefitDiscountDesc,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clubLevelScreenTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          defaultPadding,
          24,
          defaultPadding,
          32,
        ),
        children: [
          _LevelHero(
            level: _currentLevel,
            progress: _progress,
            pointsToNext: _pointsToNext,
            description: l10n.clubLevelScreenDescription,
            l10n: l10n,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.clubLevelBenefitsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 14),
          ...benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BenefitTile(benefit: benefit),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelHero extends StatelessWidget {
  const _LevelHero({
    required this.level,
    required this.progress,
    required this.pointsToNext,
    required this.description,
    required this.l10n,
  });

  final String level;
  final double progress;
  final int pointsToNext;
  final String description;
  final AppStrings l10n;

  String get _remainingLabel {
    final buffer = StringBuffer();
    final reversed = pointsToNext.toString().split('').reversed.toList();
    for (var i = 0; i < reversed.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(reversed[i]);
    }
    final formatted = buffer.toString().split('').reversed.join();
    return l10n.clubLevelPointsToNext(formatted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress.clamp(0, 1) * 100).round();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBF7), Color(0xFFF7F7FF)],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 34,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.clubLevelCurrentLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: bodyTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    level,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l10n.clubLevelNextLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: bodyTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.4),
              valueColor: const AlwaysStoppedAnimation(accentColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percent%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _remainingLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: bodyTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bodyTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubBenefit {
  const _ClubBenefit({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.benefit});

  final _ClubBenefit benefit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: benefit.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(benefit.icon, color: benefit.color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  benefit.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
