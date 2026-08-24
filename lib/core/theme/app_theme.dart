import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings_service.dart';

class AppTheme {
  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static const _accent = Color(0xFF007AFF); // Apple systemBlue

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: brightness,
    ).copyWith(
      primary: _accent,
      onPrimary: Colors.white,
      secondary: const Color(0xFF32ADE6),
      onSecondary: Colors.white,
      tertiary: const Color(0xFF34C759), // systemGreen
      onTertiary: Colors.white,
      error: const Color(0xFFFF3B30), // systemRed
      onError: Colors.white,
      surface: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E),
      onSurface: isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      onSurfaceVariant:
          isLight ? const Color(0xFF6B6B70) : const Color(0xFFAEAEB2),
      surfaceContainerLowest:
          isLight ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      surfaceContainerLow:
          isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E),
      surfaceContainer:
          isLight ? const Color(0xFFF2F2F7) : const Color(0xFF2C2C2E),
      surfaceContainerHigh:
          isLight ? const Color(0xFFE5E5EA) : const Color(0xFF3A3A3C),
      surfaceContainerHighest:
          isLight ? const Color(0xFFDEDEE3) : const Color(0xFF48484A),
      outline: isLight ? const Color(0xFFC6C6C8) : const Color(0xFF38383A),
      outlineVariant:
          isLight ? const Color(0xFFE5E5EA) : const Color(0xFF262628),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF2F2F7) : const Color(0xFF000000),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: scheme.primary, size: 24),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: 26,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isLight ? const Color(0xFFF2F2F7) : const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline, width: 1),
          textStyle:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          foregroundColor: scheme.primary,
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor:
            isLight ? const Color(0xFFE5E5EA) : const Color(0xFF2C2C2E),
        labelStyle: TextStyle(
            color: scheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor:
            isLight ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
        contentTextStyle:
            TextStyle(color: isLight ? Colors.white : const Color(0xFF1C1C1E)),
        actionTextColor: scheme.primary,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall
            ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        titleLarge: base.textTheme.titleLarge
            ?.copyWith(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleMedium: base.textTheme.titleMedium
            ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        titleSmall: base.textTheme.titleSmall
            ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.4),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.35),
        labelLarge:
            base.textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: base.textTheme.labelMedium
            ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        labelSmall: base.textTheme.labelSmall
            ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
      ),
    );
  }
}

final appThemeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final mode = await ref.read(settingsServiceProvider).getThemeMode();
    state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsServiceProvider).setThemeMode(mode);
  }
}
