import 'package:flutter/material.dart';

/// Keeps the Home banner and points balance aligned to the available window.
class HomeBannerBalanceLayout extends StatelessWidget {
  const HomeBannerBalanceLayout({
    super.key,
    required this.banner,
    required this.balance,
  });

  final Widget banner;
  final Widget balance;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        key: const ValueKey('home-feature-stacked'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: const ValueKey('home-feature-banner'),
            child: banner,
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: const ValueKey('home-feature-balance'),
            child: balance,
          ),
        ],
      ),
    );
  }
}
