import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/tool.dart';
import '../../core/services/open_service.dart';
import '../../core/services/recent_service.dart';
import '../../core/services/share_intent_service.dart';
import '../../core/widgets/app_logo.dart';
import '../batch/batch_screen.dart';
import '../files/file_manager_screen.dart';
import '../files/widgets/file_previews.dart';
import '../settings/settings_screen.dart';
import '../tools/tool_handler.dart';
import '../tools/tool_workflow_page.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _searching = false;
  final _searchController = TextEditingController();
  String _query = '';
  StreamSubscription<SharedIntentData>? _intentSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _intentSub = ref.read(shareIntentServiceProvider).stream.listen(_onSharedFiles);
    });
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSharedFiles(SharedIntentData data) {
    if (!mounted || data.files.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SharedFilesSheet(data: data),
    );
  }

  void _openTool(ToolDefinition tool) {
    final handler = ToolHandlerRegistry.handlerFor(tool.id);
    if (handler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${tool.name}" is coming in a later phase')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ToolWorkflowPage(tool: tool)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = searchTools(_query);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tools…',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 28),
                  const SizedBox(width: 10),
                  const Text('DocDoctor'),
                ],
              ),
        actions: [
          if (_searching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _searching = false;
                  _query = '';
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          IconButton(
            tooltip: 'Files',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FileManagerScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _searching && _query.isNotEmpty
          ? _ToolSearchResults(tools: tools, onOpen: _openTool)
          : RefreshIndicator(
              onRefresh: () async {
                ref.read(recentsProvider.notifier).refresh();
                ref.read(favoritesProvider.notifier).refresh();
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BatchScreen()),
                      ),
                      icon: const Icon(Icons.playlist_play),
                      label: const Text('Batch mode — run a tool on many files'),
                    ),
                  ),
                  _SectionHeader(
                    title: 'Recent',
                    icon: Icons.history,
                    onTapMore: () => _openFiles(tab: FileTab.processed),
                  ),
                  const _RecentStrip(),
                  _SectionHeader(
                    title: 'Favorites',
                    icon: Icons.star_outline,
                    onTapMore: () => _openFiles(tab: FileTab.favorites),
                  ),
                  const _FavoritesStrip(),
                  for (final category in ToolCategory.values) ...[
                    _SectionHeader(title: category.label, icon: category.icon),
                    _ToolGrid(category: category, onOpen: _openTool),
                  ],
                ],
              ),
            ),
    );
  }

  void _openFiles({FileTab tab = FileTab.all}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FileManagerScreen(initialTab: tab)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon, this.onTapMore});

  final String title;
  final IconData icon;
  final VoidCallback? onTapMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (onTapMore != null)
            TextButton(onPressed: onTapMore, child: const Text('More')),
        ],
      ),
    );
  }
}

class _RecentStrip extends ConsumerWidget {
  const _RecentStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentsProvider);
    return SizedBox(
      height: 116,
      child: recents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SizedBox.shrink(),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No processed files yet'));
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _FileCard(
              record: items[i],
              onTap: () => _openFile(context, ref, items[i].path),
            ),
          );
        },
      ),
    );
  }
}

class _FavoritesStrip extends ConsumerWidget {
  const _FavoritesStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    return SizedBox(
      height: 116,
      child: favs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SizedBox.shrink(),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Star files to pin them here'));
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _FileCard(
              record: items[i],
              onTap: () => _openFile(context, ref, items[i].path),
            ),
          );
        },
      ),
    );
  }
}

void _openFile(BuildContext context, WidgetRef ref, String path) async {
  final ok = await ref.read(openServiceProvider).openFile(path);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No app available to open this file')),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.record, this.onTap});

  final FileRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: FileThumbnail(path: record.path, width: 200),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            record.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.category, required this.onOpen});

  final ToolCategory category;
  final ValueChanged<ToolDefinition> onOpen;

  @override
  Widget build(BuildContext context) {
    final tools = toolsForCategory(category);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      childAspectRatio: 0.92,
      children: [
        for (final tool in tools)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpen(tool),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(tool.icon, color: category.color, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tool.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToolSearchResults extends StatelessWidget {
  const _ToolSearchResults({required this.tools, required this.onOpen});

  final List<ToolDefinition> tools;
  final ValueChanged<ToolDefinition> onOpen;

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) {
      return const Center(child: Text('No tools match your search'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tools.length,
      itemBuilder: (context, i) {
        final tool = tools[i];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tool.category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(tool.icon, color: tool.category.color),
          ),
          title: Text(tool.name),
          subtitle: Text(tool.description, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(tool.category.label, style: Theme.of(context).textTheme.labelSmall),
          onTap: () => onOpen(tool),
        );
      },
    );
  }
}

class _SharedFilesSheet extends ConsumerWidget {
  const _SharedFilesSheet({required this.data});

  final SharedIntentData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = <ToolDefinition>[];
    for (final f in data.files.take(3)) {
      final t = suggestToolForFile(f.name);
      if (t != null) suggestions.add(t);
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Received ${data.files.length} file(s)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              data.files.map((f) => f.name).join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const Text('What do you want to do?'),
            const SizedBox(height: 8),
            if (suggestions.isNotEmpty) ...[
              for (final tool in suggestions)
                ListTile(
                  leading: Icon(tool.icon, color: tool.category.color),
                  title: Text(tool.name),
                  onTap: () {
                    Navigator.of(context).pop();
                    final paths = data.files.map((f) => f.path).toList();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ToolWorkflowPage(tool: tool, initialInputs: paths),
                      ),
                    );
                  },
                ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Just view in file manager'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FileManagerScreen(
                      initialDir: data.files.firstOrNull?.path,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
