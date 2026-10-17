import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants.dart';
import '../../entry_point.dart';
import '../../services/auth_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isCompleting = false;

  Future<void> _startJourney() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    await AuthStorage.instance.setOnboardingCompleted(true);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const EntryPoint()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: screenBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/getstart.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0, 0.46, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 5),
                Text(
                  "Sardobaga\nxush kelibsiz!",
                  style: theme.textTheme.displaySmall?.copyWith(
                        color: const Color(0xFF00C160),
                        fontWeight: FontWeight.w800,
                        height: 1.04,
                        letterSpacing: -0.7,
                      ) ??
                      const TextStyle(
                        color: Color(0xFF00C160),
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.04,
                        letterSpacing: -0.7,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Har bir taom — bu sayohat. Sardoba ta’mlari orqali yangi lazzatlarni kashf eting.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ) ??
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCompleting ? null : _startJourney,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          primaryColor.withValues(alpha: 0.65),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isCompleting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Boshlash',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
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
