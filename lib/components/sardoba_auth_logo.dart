import 'package:flutter/material.dart';

import '../constants.dart';

class SardobaAuthLogo extends StatelessWidget {
  const SardobaAuthLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Sardoba Restaurant',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Image.asset(
          'assets/branding/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
