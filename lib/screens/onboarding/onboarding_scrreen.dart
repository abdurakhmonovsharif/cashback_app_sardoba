import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/sign_in_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  Animation<double>? _slideAnimation;
  double _progress = 0.0;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(
        () {
          if (_slideAnimation != null) {
            setState(() => _progress = _slideAnimation!.value);
          }
        },
      );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _startJourney() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  Future<void> _animateTo(double target) async {
    _slideAnimation = Tween<double>(begin: _progress, end: target).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    await _slideController.forward(from: 0);
    _slideAnimation = null;
    if (mounted) {
      setState(() => _progress = target);
    }
  }

  void _onDragUpdate(double deltaFraction) {
    if (_isCompleting) return;
    setState(() {
      _progress = (_progress + deltaFraction).clamp(0.0, 1.0);
    });
  }

  Future<void> _onDragEnd() async {
    if (_progress >= 0.9) {
      await _animateTo(1.0);
      await Future.delayed(const Duration(milliseconds: 150));
      await _startJourney();
    } else {
      await _animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1217),
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
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 80, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    "Sardobaga\nXush kelibsiz!",
                    style: theme.textTheme.displaySmall?.copyWith(
                          color: const Color(0xFF00C160),
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ) ??
                        const TextStyle(
                          color: Color(0xFF00C160),
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Har bir taom — bu sayohat! Sardoba ta’mlari orqali yangi lazzatlarni kashf eting.",
                    style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.5,
                        ) ??
                        const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 32),
                  _SwipeToStartButton(
                    progress: _progress,
                    onProgressDragged: _onDragUpdate,
                    onDragEnd: _onDragEnd,
                    isDisabled: _isCompleting,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeToStartButton extends StatefulWidget {
  const _SwipeToStartButton({
    required this.progress,
    required this.onProgressDragged,
    required this.onDragEnd,
    required this.isDisabled,
  });

  final double progress;
  final ValueChanged<double> onProgressDragged;
  final Future<void> Function() onDragEnd;
  final bool isDisabled;

  @override
  State<_SwipeToStartButton> createState() => _SwipeToStartButtonState();
}

class _SwipeToStartButtonState extends State<_SwipeToStartButton> {
  double? _lastLocalDx;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        const knobSize = 58.0;
        const sliderPadding = EdgeInsets.symmetric(horizontal: 4, vertical: 0);
        final innerTrackWidth =
            (trackWidth - sliderPadding.horizontal).clamp(0.0, double.infinity);
        final maxOffset =
            (innerTrackWidth - knobSize).clamp(0.0, double.infinity);
        final knobOffset = maxOffset * widget.progress.clamp(0.0, 1.0);

        return Container(
          height: 66,
          padding: sliderPadding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(42),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Text(
                  widget.progress >= 0.9
                      ? 'Oldinga'
                      : 'Boshlash',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                left: knobOffset,
                child: GestureDetector(
                  onHorizontalDragStart: widget.isDisabled
                      ? null
                      : (details) {
                          _lastLocalDx = details.localPosition.dx;
                        },
                  onHorizontalDragUpdate: widget.isDisabled
                      ? null
                      : (details) {
                          final dx = details.localPosition.dx;
                          final delta = dx - (_lastLocalDx ?? dx);
                          _lastLocalDx = dx;
                          if (maxOffset <= 0) return;
                          widget.onProgressDragged(delta / maxOffset);
                        },
                  onHorizontalDragEnd: widget.isDisabled
                      ? null
                      : (_) async {
                          _lastLocalDx = null;
                          await widget.onDragEnd();
                        },
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00B050),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF00B050).withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
