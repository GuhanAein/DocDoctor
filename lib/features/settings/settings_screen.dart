import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/picker_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/recent_service.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outputDir = ref.watch(outputDirNotifierProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader(title: 'Storage'),
          _GroupCard(
            children: [
              _SettingsTile(
                leading: _IconBadge(
                  color: scheme.primary,
                  icon: Icons.folder_outlined,
                ),
                title: 'Output folder',
                subtitle: outputDir ?? 'Loading…',
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  final parent =
                      await ref.read(pickerServiceProvider).pickDirectory();
                  if (parent == null) return;
                  await ref
                      .read(outputDirNotifierProvider.notifier)
                      .setParent(parent);
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              'Files are saved to a dedicated “docdoctor” folder inside the '
              'location you choose.',
              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async =>
                ref.read(outputDirNotifierProvider.notifier).reset(),
            child: const Text('Reset to default folder'),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 8),
          _GroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: _ThemeSegmented(
                  value: themeMode,
                  onChanged: (m) =>
                      ref.read(appThemeModeProvider.notifier).setMode(m),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Data'),
          const SizedBox(height: 8),
          _GroupCard(
            children: [
              _SettingsTile(
                leading: const _IconBadge(
                  color: Colors.redAccent,
                  icon: Icons.history,
                ),
                title: 'Clear recent files',
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  await ref.read(recentsProvider.notifier).clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recents cleared')),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'About'),
          const SizedBox(height: 8),
          _GroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DocDoctor',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 6),
                    Text(
                      'All-in-one PDF, image and office toolkit.\n'
                      '100% offline — every operation runs on your device. '
                      'No accounts, no analytics, no network access.',
                      style: tt.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Text('Privacy by design',
                            style: tt.labelMedium
                                ?.copyWith(color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: 16,
                color: scheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tt.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.color, required this.icon});
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _ThemeSegmented extends StatelessWidget {
  const _ThemeSegmented({required this.value, required this.onChanged});
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: SegmentedButton<ThemeMode>(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainer,
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: Colors.white,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide.none,
          shape: const StadiumBorder(),
        ),
        segments: const [
          ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto),
              label: Text('System')),
          ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode),
              label: Text('Light')),
          ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode),
              label: Text('Dark')),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
