import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/open_service.dart';
import '../../core/services/picker_service.dart';
import '../../core/services/recent_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/file_utils.dart';
import 'widgets/file_previews.dart';

enum FileTab { all, pdf, image, office, archive, text, processed, favorites }

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key, this.initialDir, this.initialTab = FileTab.all});

  final String? initialDir;
  final FileTab initialTab;

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  String? _dir;
  String _query = '';
  late FileTab _tab;
  List<FileSystemEntity> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    if (widget.initialDir != null) {
      final f = File(widget.initialDir!);
      _dir = f.parent.path;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initDirIfNeeded();
  }

  Future<void> _initDirIfNeeded() async {
    if (_dir != null) {
      _load();
      return;
    }
    final out = await ref.read(settingsServiceProvider).getOutputDir();
    _dir = out;
    _load();
  }

  Future<void> _load() async {
    final dir = _dir;
    if (dir == null) return;
    setState(() => _loading = true);
    try {
      final entries = Directory(dir).listSync();
      entries.sort((a, b) {
        final ad = a is Directory;
        final bd = b is Directory;
        if (ad != bd) return ad ? -1 : 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open folder: $e')),
      );
    }
  }

  bool _matches(FileSystemEntity e) {
    final name = e.path.split(Platform.pathSeparator).last;
    if (_query.isNotEmpty && !name.toLowerCase().contains(_query.toLowerCase())) {
      return false;
    }
    if (_tab == FileTab.all) return true;
    if (e is Directory) return _tab == FileTab.all;
    final ext = fileExtension(e.path);
    switch (_tab) {
      case FileTab.pdf: return ext == 'pdf';
      case FileTab.image: return ['jpg','jpeg','png','webp','bmp','gif','heic'].contains(ext);
      case FileTab.office: return ['xlsx','xls','csv','docx','doc','pptx','ppt','ods','odt','odp'].contains(ext);
      case FileTab.archive: return ['zip'].contains(ext);
      case FileTab.text: return ['txt','md','html','htm','json','xml','csv'].contains(ext);
      case FileTab.processed: return _processedPaths.contains(e.path);
      case FileTab.favorites: return _favoritePaths.contains(e.path);
      case FileTab.all: return true;
    }
  }

  AsyncValue<List<FileRecord>> get _recents => ref.read(recentsProvider);
  AsyncValue<List<FileRecord>> get _favorites => ref.read(favoritesProvider);

  Set<String> get _processedPaths => _recents.value?.map((r) => r.path).toSet() ?? {};
  Set<String> get _favoritePaths => _favorites.value?.map((r) => r.path).toSet() ?? {};

  void _up() {
    final dir = _dir;
    if (dir == null) return;
    final parent = Directory(dir).parent.path;
    if (parent != dir) {
      setState(() {
        _dir = parent;
        _query = '';
      });
      _load();
    }
  }

  Future<void> _pickDir() async {
    final dir = await ref.read(pickerServiceProvider).pickDirectory();
    if (dir != null) {
      setState(() => _dir = dir);
      _load();
    }
  }

  Future<void> _openInFilesApp() async {
    final dir = _dir;
    if (dir == null) return;
    final ok = await ref.read(openServiceProvider).openFolder(dir);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file manager app available')),
      );
    }
  }

  Future<void> _openExternal(FileSystemEntity e) async {
    if (e is Directory) {
      setState(() => _dir = e.path);
      _load();
      return;
    }
    final ok = await ref.read(openServiceProvider).openFile(e.path);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app available to open this file')),
      );
    }
  }

  Future<void> _actions(FileSystemEntity e) async {
    final path = e.path;
    final name = path.split(Platform.pathSeparator).last;
    final isDir = e is Directory;
    final favs = ref.read(favoritesProvider.notifier);
    final isFav = _favoritePaths.contains(path);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              leading: const Icon(Icons.insert_drive_file),
            ),
            const Divider(height: 1),
            if (!isDir) ...[
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share / Open with'),
                onTap: () {
                  Navigator.pop(context);
                  SharePlus.instance.share(ShareParams(files: [XFile(path)]));
                },
              ),
            ],
            ListTile(
              leading: Icon(isFav ? Icons.star : Icons.star_border),
              title: Text(isFav ? 'Remove from favorites' : 'Add to favorites'),
              onTap: () async {
                Navigator.pop(context);
                await favs.toggle(FileRecord(
                  path: path,
                  name: name,
                  toolId: '',
                  toolName: '',
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _rename(e);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(context);
                _details(e);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _delete(e);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(FileSystemEntity e) async {
    final controller = TextEditingController(text: e.path.split(Platform.pathSeparator).last);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    final parent = e.parent.path;
    try {
      await e.rename('$parent${Platform.pathSeparator}$newName');
      _load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rename failed: $err')));
      }
    }
  }

  void _details(FileSystemEntity e) {
    final stat = e.statSync();
    final name = e.path.split(Platform.pathSeparator).last;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $name'),
            Text('Path: ${e.path}'),
            Text('Size: ${formatBytes(stat.size)}'),
            Text('Modified: ${stat.modified.toString()}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _delete(FileSystemEntity e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete "${e.path.split(Platform.pathSeparator).last}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await e.delete(recursive: true);
      _load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $err')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(recentsProvider);
    ref.watch(favoritesProvider);
    final visible = _entries.where(_matches).toList();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(
              _dir ?? 'Loading…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search in this folder',
            icon: const Icon(Icons.search),
            onPressed: () async {
              final q = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Search'),
                  content: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'File name…'),
                    onSubmitted: (v) => Navigator.pop(context, v),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, ''),
                      child: const Text('Search'),
                    ),
                  ],
                ),
              );
              if (q != null) setState(() => _query = q);
            },
          ),
          IconButton(tooltip: 'Go up', icon: const Icon(Icons.arrow_upward), onPressed: _up),
          IconButton(tooltip: 'Open in Files app', icon: const Icon(Icons.open_in_new), onPressed: _openInFilesApp),
          IconButton(tooltip: 'Choose folder', icon: const Icon(Icons.folder_open), onPressed: _pickDir),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final tab in FileTab.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(_tabLabel(tab)),
                      selected: _tab == tab,
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
          if (_query.isNotEmpty)
            ListTile(
              dense: true,
              leading: const Icon(Icons.search),
              title: Text('"$_query"'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _query = ''),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? const Center(child: Text('Nothing here'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final e = visible[i];
                          final name = e.path.split(Platform.pathSeparator).last;
                          final isDir = e is Directory;
                          return ListTile(
                            leading: isDir
                                ? const Icon(Icons.folder, color: Color(0xFFF57C00))
                                : SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        child: ['jpg','jpeg','png','webp','bmp','gif','heic','pdf'].contains(fileExtension(e.path))
                                            ? FileThumbnail(path: e.path, width: 120)
                                            : Icon(_iconFor(fileExtension(e.path)), size: 24),
                                      ),
                                    ),
                                  ),
                            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              isDir
                                  ? 'Folder'
                                  : '${formatBytes(e.statSync().size)} · ${_fmtDate(e.statSync().modified)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            trailing: _favoritePaths.contains(e.path)
                                ? const Icon(Icons.star, size: 20, color: Colors.amber)
                                : null,
                            onTap: () => _openExternal(e),
                            onLongPress: () => _actions(e),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _tabLabel(FileTab tab) => switch (tab) {
        FileTab.all => 'All',
        FileTab.pdf => 'PDF',
        FileTab.image => 'Images',
        FileTab.office => 'Office',
        FileTab.archive => 'Archives',
        FileTab.text => 'Text',
        FileTab.processed => 'Processed',
        FileTab.favorites => 'Favorites',
      };

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

IconData _iconFor(String ext) {
  switch (ext) {
    case 'pdf': return Icons.picture_as_pdf;
    case 'xlsx': case 'xls': case 'ods': case 'csv': return Icons.table_chart;
    case 'docx': case 'doc': case 'odt': return Icons.description;
    case 'pptx': case 'ppt': case 'odp': return Icons.slideshow;
    case 'zip': return Icons.folder_zip;
    case 'txt': case 'md': return Icons.notes;
    case 'html': case 'htm': return Icons.code;
    default: return Icons.insert_drive_file;
  }
}
