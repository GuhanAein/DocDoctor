import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_shell.dart';
import 'core/services/settings_service.dart';
import 'core/services/share_intent_service.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/tools/registrar.dart';

class DocDoctorApp extends ConsumerStatefulWidget {
  const DocDoctorApp({super.key});

  @override
  ConsumerState<DocDoctorApp> createState() => _DocDoctorAppState();
}

class _DocDoctorAppState extends ConsumerState<DocDoctorApp> {
  @override
  void initState() {
    super.initState();
    registerAllTools(<T>(dynamic p) => ref.read(p) as T);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shareIntentServiceProvider).startListening(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    return MaterialApp(
      title: 'DocDoctor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeOutCubic,
      home: const _LaunchGate(),
    );
  }
}

/// Decides the first screen: animated splash → onboarding (first run) → app.
class _LaunchGate extends ConsumerStatefulWidget {
  const _LaunchGate();

  @override
  ConsumerState<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends ConsumerState<_LaunchGate> {
  bool _showSplash = true;
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    final value = await ref.read(settingsServiceProvider).isOnboarded();
    if (mounted) setState(() => _onboarded = value);
  }

  void _onSplashDone() {
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  Future<void> _onOnboardingDone() async {
    await ref.read(settingsServiceProvider).setOnboarded(true);
    if (!mounted) return;
    setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onDone: _onSplashDone);
    }
    if (_onboarded == true) {
      return const AppShell();
    }
    if (_onboarded == false) {
      return OnboardingScreen(onDone: _onOnboardingDone);
    }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}
