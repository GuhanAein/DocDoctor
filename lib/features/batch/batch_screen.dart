import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/tool.dart';
import '../../core/services/picker_service.dart';
import '../../core/services/recent_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/file_utils.dart';
import '../files/widgets/file_previews.dart';
import '../tools/tool_handler.dart';

enum BatchStep { pick, tool, options, run, done }

class BatchItemResult {
  const BatchItemResult({required this.input, this.outputs = const [], this.error});

  final String input;
  final List<String> outputs;
  final String? error;
}

class BatchScreen extends ConsumerStatefulWidget {
  const BatchScreen({super.key});

  @override
  ConsumerState<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends ConsumerState<BatchScreen> {
  BatchStep _step = BatchStep.pick;
  List<String> _inputs = [];
  ToolDefinition? _tool;
  Map<String, dynamic> _options = {};
  final List<BatchItemResult> _results = [];
  int _progress = 0;
  String _status = '';

  List<ToolDefinition> get _candidates {
    if (_inputs.isEmpty) return [];
    final exts = _inputs.map(fileExtension).toSet();
    return allTools.where((t) {
      if (!t.allowsBatch) return false;
      return switch (t.inputType) {
        ToolInputType.pdf => exts.contains('pdf'),
        ToolInputType.image => exts.any((e) => ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic'].contains(e)),
        ToolInputType.xlsx => exts.contains('xlsx') || exts.contains('xls'),
        ToolInputType.csv => exts.contains('csv'),
        ToolInputType.docx => exts.contains('docx'),
        ToolInputType.pptx => exts.contains('pptx'),
        ToolInputType.txt => exts.contains('txt'),
        ToolInputType.html => exts.contains('html'),
        ToolInputType.zip => exts.contains('zip'),
        _ => false,
      };
    }).toList();
  }

  Future<void> _pick() async {
    final paths = await ref.read(pickerServiceProvider).pickAny(multiple: true);
    if (paths.isEmpty) return;
    setState(() {
      _inputs = paths;
      _step = BatchStep.tool;
    });
  }

  Future<void> _run() async {
    final tool = _tool!;
    final handler = ToolHandlerRegistry.handlerFor(tool.id)!;
    setState(() {
      _step = BatchStep.run;
      _progress = 0;
      _results.clear();
    });
    for (var i = 0; i < _inputs.length; i++) {
      setState(() => _status = '${i + 1} of ${_inputs.length}: ${_inputs[i].split(Platform.pathSeparator).last}');
      try {
        final result = await handler.processor(
          [_inputs[i]],
          _options,
          onProgress: (msg, p) {
            if (mounted) setState(() => _status = '$msg (${i + 1}/${_inputs.length})');
          },
        );
        _results.add(BatchItemResult(
          input: _inputs[i],
          outputs: result.outputPaths,
          error: result.error,
        ));
      } catch (e) {
        _results.add(BatchItemResult(input: _inputs[i], error: e.toString()));
      }
      if (mounted) setState(() => _progress = i + 1);
    }
    if (mounted) setState(() => _step = BatchStep.done);
  }

  Future<void> _saveAll() async {
    final outDir = await ref.read(settingsServiceProvider).getOutputDir();
    var count = 0;
    final recents = ref.read(recentsProvider.notifier);
    for (final r in _results) {
      for (final p in r.outputs) {
        try {
          final name = p.split(Platform.pathSeparator).last;
          final dest = await uniquePath(outDir, name);
          await File(dest).writeAsBytes(await File(p).readAsBytes());
          await recents.add(FileRecord(
            path: dest,
            name: name,
            toolId: _tool!.id,
            toolName: _tool!.name,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
          count++;
        } catch (_) {}
      }
    }
    if (mounted && count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $count file(s) to $outDir')),
      );
    }
  }

  Future<void> _shareAll() async {
    final files = [
      for (final r in _results)
        for (final p in r.outputs) XFile(p),
    ];
    if (files.isEmpty) return;
    await SharePlus.instance.share(ShareParams(files: files.take(20).toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch mode')),
      body: switch (_step) {
        BatchStep.pick => _PickStep(onPick: _pick),
        BatchStep.tool => _ToolStep(
            inputs: _inputs,
            candidates: _candidates,
            onSelect: (t) => setState(() {
              _tool = t;
              _step = BatchStep.options;
            }),
          ),
        BatchStep.options => _OptionsStep(
            tool: _tool!,
            inputs: _inputs,
            onRun: (options) {
              _options = options;
              _run();
            },
          ),
        BatchStep.run => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LinearProgressIndicator(
                    value: _inputs.isEmpty ? null : _progress / _inputs.length,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 24),
                  Text(_status, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Working on-device, nothing leaves your phone',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        BatchStep.done => _DoneStep(
            results: _results,
            tool: _tool!,
            onSaveAll: _saveAll,
            onShareAll: _shareAll,
            onAgain: () => setState(() {
              _step = BatchStep.tool;
              _results.clear();
            }),
          ),
      },
    );
  }
}

class _PickStep extends StatelessWidget {
  const _PickStep({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_add_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Batch mode', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Select multiple files and run one tool across all of them in a single queue.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose files'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolStep extends StatelessWidget {
  const _ToolStep({
    required this.inputs,
    required this.candidates,
    required this.onSelect,
  });

  final List<String> inputs;
  final List<ToolDefinition> candidates;
  final ValueChanged<ToolDefinition> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${inputs.length} file(s) selected'),
        const SizedBox(height: 4),
        Text(
          inputs.map((p) => p.split(Platform.pathSeparator).last).join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text('Choose a tool', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (candidates.isEmpty)
          const Text('No batch-capable tools match these file types.')
        else
          for (final tool in candidates)
            Card(
              child: ListTile(
                leading: Icon(tool.icon, color: tool.category.color),
                title: Text(tool.name),
                subtitle: Text(tool.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => onSelect(tool),
              ),
            ),
      ],
    );
  }
}

class _OptionsStep extends StatelessWidget {
  const _OptionsStep({required this.tool, required this.inputs, required this.onRun});

  final ToolDefinition tool;
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  Widget build(BuildContext context) {
    final handler = ToolHandlerRegistry.handlerFor(tool.id);
    final builder = handler?.optionsBuilder;
    if (builder == null) {
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${inputs.length} file(s) will be processed with "${tool.name}"'),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 160,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: FileThumbnail(path: inputs.first, width: 400),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run batch'),
                  onPressed: () => onRun(const {}),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return builder(context, inputs, const {}, onRun);
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.results,
    required this.tool,
    required this.onSaveAll,
    required this.onShareAll,
    required this.onAgain,
  });

  final List<BatchItemResult> results;
  final ToolDefinition tool;
  final VoidCallback onSaveAll;
  final VoidCallback onShareAll;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final okCount = results.where((r) => r.error == null).length;
    final totalOutputs = results.fold<int>(0, (a, r) => a + r.outputs.length);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                okCount == results.length ? Icons.check_circle : Icons.info_outline,
                color: okCount == results.length ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$okCount of ${results.length} succeeded · $totalOutputs output file(s)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            itemBuilder: (context, i) {
              final r = results[i];
              final name = r.input.split(Platform.pathSeparator).last;
              return ExpansionTile(
                leading: Icon(
                  r.error == null ? Icons.check_circle_outline : Icons.error_outline,
                  color: r.error == null ? Colors.green : Colors.redAccent,
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  r.error == null ? '${r.outputs.length} output(s)' : r.error!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                children: [
                  if (r.error == null && r.outputs.isNotEmpty)
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: r.outputs.length,
                        itemBuilder: (context, j) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 90,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: FileThumbnail(path: r.outputs[j], width: 160),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: totalOutputs == 0 ? null : onShareAll,
                    icon: const Icon(Icons.share),
                    label: const Text('Share all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: totalOutputs == 0 ? null : onSaveAll,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save all'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
