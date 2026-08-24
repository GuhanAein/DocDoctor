import 'package:flutter/material.dart';
import '../../tools/registrar.dart';

import '../../../core/models/tool.dart';
import '../../tools/tool_handler.dart';
import '../../files/widgets/file_previews.dart';
import '../pdf_annotate_page.dart';
import '../pdf_compare_page.dart';
import '../pdf_forms_page.dart';
import '../pdf_redact_page.dart';
import '../pdf_scan_page.dart';
import '../pdf_sign_page.dart';

class PdfInteractiveRegistrar {
  static void registerAll(ToolRegistryReader read) {
    _register('pdf_annotate', 'annotated.pdf',
        (c, input, onDone) => PdfAnnotatePage(inputPath: input, onDone: onDone));
    _register('pdf_redact', 'redacted.pdf',
        (c, input, onDone) => PdfRedactPage(inputPath: input, onDone: onDone));
    _register('pdf_sign', 'signed.pdf',
        (c, input, onDone) => PdfSignPage(inputPath: input, onDone: onDone));
    _register('pdf_forms', 'form.pdf',
        (c, input, onDone) => PdfFormsPage(inputPath: input, onDone: onDone));

    // Compare takes two inputs.
    ToolHandlerRegistry.register('pdf_compare', ToolHandler(
      processor: _fromResult,
      optionsBuilder: (context, inputs, initial, onRun) => _CompareLauncher(
        inputs: inputs,
        onRun: onRun,
      ),
    ));

    // Scan produces pages from the camera.
    ToolHandlerRegistry.register('pdf_scan', ToolHandler(
      processor: _fromResult,
      optionsBuilder: (context, inputs, initial, onRun) => _ScanLauncher(onRun: onRun),
    ));
  }

  static void _register(
    String id,
    String suffix,
    Widget Function(BuildContext, String, ValueChanged<String>) pageBuilder,
  ) {
    ToolHandlerRegistry.register(id, ToolHandler(
      processor: _fromResult,
      optionsBuilder: (context, inputs, initial, onRun) => _EditorLauncher(
        toolName: (findTool(id)?.name ?? id),
        inputPath: inputs.first,
        pageBuilder: pageBuilder,
        onRun: onRun,
      ),
    ));
  }

  static Future<ToolResult> _fromResult(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final path = options['resultPath'] as String?;
    if (path != null && path.isNotEmpty) {
      return ToolResult(outputPaths: [path]);
    }
    return ToolResult(error: 'No result produced');
  }
}

class _EditorLauncher extends StatelessWidget {
  const _EditorLauncher({
    required this.toolName,
    required this.inputPath,
    required this.pageBuilder,
    required this.onRun,
  });

  final String toolName;
  final String inputPath;
  final Widget Function(BuildContext, String, ValueChanged<String>) pageBuilder;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 200,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: FileThumbnail(path: inputPath, width: 400),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The editor opens with a full-page view. Draw, place or fill, '
                'then save — you will get a before/after preview here.',
                style: Theme.of(context).textTheme.bodySmall,
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
                icon: const Icon(Icons.open_in_new),
                label: Text('Open $toolName editor'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => pageBuilder(context, inputPath, (resultPath) {
                        Navigator.of(context).pop();
                        onRun({'resultPath': resultPath});
                      }),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareLauncher extends StatelessWidget {
  const _CompareLauncher({required this.inputs, required this.onRun});

  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 180,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: FileThumbnail(path: inputs[0], width: 300),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('A', style: Theme.of(context).textTheme.labelLarge),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 180,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: FileThumbnail(path: inputs[1], width: 300),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('B', style: Theme.of(context).textTheme.labelLarge),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Pages are rendered and compared pixel by pixel. Red marks the differences.',
                style: Theme.of(context).textTheme.bodySmall,
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
                icon: const Icon(Icons.compare),
                label: const Text('Start comparison'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PdfComparePage(
                        inputs: inputs,
                        onDone: (resultPath) {
                          Navigator.of(context).pop();
                          onRun({'resultPath': resultPath});
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanLauncher extends StatelessWidget {
  const _ScanLauncher({required this.onRun});

  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.document_scanner_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Point the camera at a document. Edges are detected and the page is straightened automatically.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Open camera'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PdfScanPage(
                        onDone: (resultPath) {
                          Navigator.of(context).pop();
                          onRun({'resultPath': resultPath});
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
