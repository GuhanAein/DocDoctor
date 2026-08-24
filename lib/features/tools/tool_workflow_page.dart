import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/tool.dart';
import '../../core/services/open_service.dart';
import '../../core/services/picker_service.dart';
import '../../core/services/recent_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/file_utils.dart';
import '../files/widgets/file_previews.dart';
import 'tool_handler.dart';

enum WorkflowStep { pick, options, process, done }

class ToolWorkflowPage extends ConsumerStatefulWidget {
  const ToolWorkflowPage({super.key, required this.tool, this.initialInputs = const []});

  final ToolDefinition tool;
  final List<String> initialInputs;

  @override
  ConsumerState<ToolWorkflowPage> createState() => _ToolWorkflowPageState();
}

class _ToolWorkflowPageState extends ConsumerState<ToolWorkflowPage> {
  late WorkflowStep _step;
  List<String> _inputs = [];
  Map<String, dynamic> _options = {};
  String _status = 'Preparing…';
  double _progress = 0;
  ToolResult? _result;
  String? _error;
  List<String> _savedPaths = [];

  @override
  void initState() {
    super.initState();
    _inputs = List.of(widget.initialInputs);
    if (widget.tool.inputType == ToolInputType.none) {
      _step = WorkflowStep.options;
    } else {
      _step = _inputs.isEmpty ? WorkflowStep.pick : WorkflowStep.options;
    }
  }

  Future<void> _pick() async {
    final multiple = widget.tool.allowsMultiple;
    final paths = await ref
        .read(pickerServiceProvider)
        .pickForType(widget.tool.inputType, multiple: multiple);
    if (paths.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _inputs = paths;
      _step = WorkflowStep.options;
    });
  }

  Future<void> _run() async {
    final handler = ToolHandlerRegistry.handlerFor(widget.tool.id);
    if (handler == null) {
      setState(() {
        _error = 'Tool not implemented yet';
        _step = WorkflowStep.done;
      });
      return;
    }
    setState(() {
      _step = WorkflowStep.process;
      _progress = 0;
      _status = 'Processing…';
    });
    try {
      final result = await handler.processor(
        _inputs,
        _options,
        onProgress: (msg, p) {
          if (mounted) {
            setState(() {
              _status = msg;
              _progress = p.clamp(0.0, 1.0);
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _error = result.error;
        _step = WorkflowStep.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _result = null;
        _step = WorkflowStep.done;
      });
    }
  }

  Future<void> _saveOutputs() async {
    final outDir = await ref.read(settingsServiceProvider).getOutputDir();
    final saved = <String>[];
    for (final p in _result?.outputPaths ?? const <String>[]) {
      try {
        final name = p.split(Platform.pathSeparator).last;
        final dest = await uniquePath(outDir, name);
        final content = await File(p).readAsBytes();
        await File(dest).writeAsBytes(content);
        saved.add(dest);
      } catch (_) {}
    }
    if (!mounted) return;
    final recents = ref.read(recentsProvider.notifier);
    for (final s in saved) {
      await recents.add(FileRecord(
        path: s,
        name: s.split(Platform.pathSeparator).last,
        toolId: widget.tool.id,
        toolName: widget.tool.name,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        sizeBytes: await fileSize(s),
      ));
    }
    setState(() => _savedPaths = [..._savedPaths, ...saved]);
    if (saved.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${saved.length} file(s) to $outDir'),
          action: SnackBarAction(label: 'OPEN', onPressed: _open),
        ),
      );
    }
  }

  Future<void> _share() async {
    final files = _result?.outputPaths.map((p) => XFile(p)).toList() ?? [];
    if (files.isEmpty) return;
    await SharePlus.instance.share(ShareParams(files: files));
  }

  Future<void> _open() async {
    final saved = _savedPaths;
    final outputs = _result?.outputPaths ?? const <String>[];
    final path = saved.isNotEmpty ? saved.first : outputs.firstOrNull;
    if (path == null) return;
    final ok = await ref.read(openServiceProvider).openFile(path);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app available to open this file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tool.name),
        actions: [
          if (_inputs.isNotEmpty)
            IconButton(
              tooltip: 'Pick different files',
              icon: const Icon(Icons.folder_open),
              onPressed: _step == WorkflowStep.process ? null : _pick,
            ),
        ],
      ),
      body: switch (_step) {
        WorkflowStep.pick => _PickStep(tool: widget.tool, onPick: _pick, inputs: _inputs),
        WorkflowStep.options => _OptionsStep(
            tool: widget.tool,
            inputs: _inputs,
            initialOptions: _options,
            onRun: (options) {
              _options = options;
              _run();
            },
          ),
        WorkflowStep.process => _ProcessStep(status: _status, progress: _progress),
        WorkflowStep.done => _DoneStep(
            tool: widget.tool,
            inputs: _inputs,
            result: _result,
            error: _error,
            savedPaths: _savedPaths,
            onSave: _saveOutputs,
            onOpen: _open,
            onShare: _share,
            onRetry: () => setState(() => _step = WorkflowStep.options),
          ),
      },
    );
  }
}

class _PickStep extends StatelessWidget {
  const _PickStep({required this.tool, required this.onPick, required this.inputs});

  final ToolDefinition tool;
  final VoidCallback onPick;
  final List<String> inputs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tool.icon, size: 96, color: scheme.primary),
            const SizedBox(height: 24),
            Text(tool.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              tool.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.folder_open),
              label: Text('Choose ${tool.allowsMultiple ? 'files' : 'a file'}'),
            ),
            const SizedBox(height: 12),
            if (tool.category == ToolCategory.pdf && tool.id == 'pdf_scan')
              const Text('Tip: open the camera to scan a document'),
          ],
        ),
      ),
    );
  }
}

class _OptionsStep extends StatelessWidget {
  const _OptionsStep({
    required this.tool,
    required this.inputs,
    required this.initialOptions,
    required this.onRun,
  });

  final ToolDefinition tool;
  final List<String> inputs;
  final Map<String, dynamic> initialOptions;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  Widget build(BuildContext context) {
    final handler = ToolHandlerRegistry.handlerFor(tool.id);
    final builder = handler?.optionsBuilder;
    if (builder == null) {
      return _QuickRun(tool: tool, inputs: inputs, onRun: () => onRun(initialOptions));
    }
    return builder(context, inputs, initialOptions, onRun);
  }
}

class _QuickRun extends StatelessWidget {
  const _QuickRun({required this.tool, required this.inputs, required this.onRun});

  final ToolDefinition tool;
  final List<String> inputs;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FileChips(paths: inputs),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRun,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Run'),
        ),
      ],
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({required this.status, required this.progress});

  final String status;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: progress <= 0 ? null : progress,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Working on-device — nothing leaves your phone',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneStep extends ConsumerWidget {
  const _DoneStep({
    required this.tool,
    required this.inputs,
    required this.result,
    required this.error,
    required this.savedPaths,
    required this.onSave,
    required this.onOpen,
    required this.onShare,
    required this.onRetry,
  });

  final ToolDefinition tool;
  final List<String> inputs;
  final ToolResult? result;
  final String? error;
  final List<String> savedPaths;
  final VoidCallback onSave;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (error != null || result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text('Operation failed', style: tt.titleLarge),
              const SizedBox(height: 8),
              Text(
                error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final outputs = result!.outputPaths;
    final allSaved = savedPaths.length >= outputs.length && outputs.isNotEmpty;

    return Container(
      color: scheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: allSaved ? scheme.tertiary : scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    allSaved ? Icons.check_rounded : Icons.bolt_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(allSaved ? 'Saved' : 'Ready to save', style: tt.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${outputs.length} file${outputs.length == 1 ? '' : 's'} produced on-device',
                  style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _CompareRow(input: inputs.firstOrNull, output: outputs.firstOrNull),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
                  child: Text(
                    'OUTPUT FILES',
                    style: tt.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.6),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < outputs.length; i++) ...[
                        _OutputFileTile(
                          path: outputs[i],
                          saved: _isSavedPath(outputs[i], savedPaths),
                        ),
                        if (i < outputs.length - 1)
                          Divider(height: 1, indent: 60, color: scheme.outlineVariant),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (allSaved)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onSave,
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Save to docdoctor'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share'),
                    ),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('Start over')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isSavedPath(String output, List<String> savedPaths) {
  final name = output.split(Platform.pathSeparator).last;
  return savedPaths.any((p) => p.split(Platform.pathSeparator).last == name);
}

class _OutputFileTile extends StatelessWidget {
  const _OutputFileTile({required this.path, required this.saved});

  final String path;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = path.split(Platform.pathSeparator).last;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _FileTypeIcon(name: name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge),
                const SizedBox(height: 2),
                FutureBuilder<int>(
                  future: fileSize(path),
                  builder: (c, s) => Text(
                    formatBytes(s.data ?? 0),
                    style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          if (saved)
            const Icon(Icons.check_circle, color: Colors.green, size: 22)
          else
            Icon(Icons.radio_button_unchecked, color: scheme.outline, size: 22),
        ],
      ),
    );
  }
}

class _FileTypeIcon extends StatelessWidget {
  const _FileTypeIcon({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final IconData data;
    final Color bg;
    if (ext == 'pdf') {
      data = Icons.picture_as_pdf;
      bg = Colors.red;
    } else if (['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'].contains(ext)) {
      data = Icons.image;
      bg = Colors.blue;
    } else if (['doc', 'docx', 'txt', 'rtf'].contains(ext)) {
      data = Icons.description;
      bg = Colors.indigo;
    } else if (['xls', 'xlsx', 'csv'].contains(ext)) {
      data = Icons.table_chart;
      bg = Colors.green;
    } else if (['zip', 'rar', '7z', 'gz'].contains(ext)) {
      data = Icons.archive_outlined;
      bg = Colors.amber;
    } else {
      data = Icons.insert_drive_file;
      bg = scheme.primary;
    }
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(data, color: Colors.white, size: 18),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({this.input, this.output});

  final String? input;
  final String? output;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget label(String t) => Text(
          t,
          style: tt.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.6),
        );

    Widget preview(String? path) {
      if (path == null) {
        return Container(
          height: 220,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 220,
          color: scheme.surfaceContainer,
          child: FileThumbnail(path: path, width: 320),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label('BEFORE'), const SizedBox(height: 8), preview(input)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label('AFTER'), const SizedBox(height: 8), preview(output)],
          ),
        ),
      ],
    );
  }
}

class _FileChips extends StatelessWidget {
  const _FileChips({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in paths.take(12))
          Chip(
            avatar: const Icon(Icons.insert_drive_file, size: 18),
            label: Text(p.split(Platform.pathSeparator).last, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if (paths.length > 12) Chip(label: Text('+${paths.length - 12} more')),
      ],
    );
  }
}
