import 'package:flutter/material.dart';

import '../../core/widgets/app_logo.dart';

/// Shown the first time the app launches. Emphasises that every operation
/// runs locally on the device.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(child: AppLogo(size: 96)),
              const SizedBox(height: 24),
              Text('Welcome to DocDoctor',
                  textAlign: TextAlign.center, style: tt.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Your private document toolkit.',
                textAlign: TextAlign.center,
                style:
                    tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              _PrivacyHero(),
              const SizedBox(height: 20),
              _Bullet(
                icon: Icons.phone_iphone_outlined,
                text: 'All processing happens on your phone',
              ),
              _Bullet(
                icon: Icons.cloud_off_outlined,
                text: 'No cloud, no network access',
              ),
              _Bullet(
                icon: Icons.lock_outline,
                text: 'No accounts, no analytics',
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onDone,
                  child: const Text('Get started'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.tertiary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Everything local',
                    style: tt.titleMedium
                        ?.copyWith(color: scheme.tertiary)),
                const SizedBox(height: 2),
                Text(
                  'All processes are done in your phone — nothing ever leaves it.',
                  style: tt.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: tt.bodyLarge)),
        ],
      ),
    );
  }
}
