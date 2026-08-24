import 'package:flutter/material.dart';

import '../../core/widgets/app_logo.dart';

/// Animated launch screen: logo fades + scales in with a subtle bounce,
/// then invokes [onDone] (which routes to onboarding or the app shell).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1400);
  static const _holdAfter = Duration(milliseconds: 520);

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );
    _controller.forward();
    Future.delayed(_duration + _holdAfter, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _fade,
                child: AppLogo(size: 112),
              ),
            ),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: _fade,
              child: Text(
                'DocDoctor',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            FadeTransition(
              opacity: _fade,
              child: Text(
                'Documents, on your terms',
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 48),
            FadeTransition(
              opacity: _fade,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  strokeCap: StrokeCap.round,
                  color: scheme.primary.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
