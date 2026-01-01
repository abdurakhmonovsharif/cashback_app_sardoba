import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
   
    _controller.forward();
    _finishTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: screenBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash.webp',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
          const _BottomProgress(),
        ],
      ),
    );
  }
}

class _BottomProgress extends StatelessWidget {
  const _BottomProgress();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final progressBottom = 64 + (bottomInset > 0 ? bottomInset : 0);

    return Positioned(
      left: 0,
      right: 0,
      bottom: progressBottom.toDouble(),
      child: const Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      ),
    );
  }
}
