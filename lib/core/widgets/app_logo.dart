import 'package:flutter/material.dart';

/// The DocDoctor logo. Loads `assets/logo.png`; if the asset is missing it
/// renders a branded squircle fallback so the app never crashes before the
/// logo file is added.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary,
                scheme.primary.withValues(alpha: 0.65),
              ],
            ),
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          child: Icon(
            Icons.description_outlined,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
