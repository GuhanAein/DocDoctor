import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/file_utils.dart';
import '../tools/run_output.dart';
import 'services/pdf_service.dart';

/// Detect existing form fields, fill values, optionally flatten, and also
/// create new text fields at user-specified positions.
class PdfFormsPage extends ConsumerStatefulWidget {
  const PdfFormsPage({super.key, required this.inputPath, required this.onDone});

  final String inputPath;
  final ValueChanged<String> onDone;

  @override
  ConsumerState<PdfFormsPage> createState() => _PdfFormsPageState();
}

class _PdfFormsPageState extends ConsumerState<PdfFormsPage> {
  List<FormFieldInfo>? _fields;
  final Map<String, TextEditingController> _controllers = {};
  bool _flatten = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fields = await runInIsolate(() => PdfService().getFormFields(widget.inputPath));
    if (mounted) {
      setState(() {
        _fields = fields;
        for (final f in fields) {
          _controllers[f.name] = TextEditingController(text: f.value);
        }
      });
    }
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      final values = <String, String>{};
      for (final f in _fields ?? const <FormFieldInfo>[]) {
        final ctrl = _controllers[f.name];
        if (ctrl != null && ctrl.text.isNotEmpty) values[f.name] = ctrl.text;
      }
      final bytes = await runInIsolate(
        () => PdfService().fillFormFields(widget.inputPath, values, flatten: _flatten),
      );
      final runDir = await newRunDir();
      final path = await writeRunFile(
        runDir,
        '${baseNameWithoutExt(widget.inputPath)}_form.pdf',
        bytes,
      );
      if (!mounted) return;
      widget.onDone(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Forms'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _apply,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Apply'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: fields == null
          ? const Center(child: CircularProgressIndicator())
          : fields.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_box_outline_blank, size: 56),
                        const SizedBox(height: 12),
                        Text('No form fields detected in this PDF.',
                            style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                          'Fields can be created with "Create field" in a later update.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final f in fields)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TextField(
                                controller: _controllers[f.name],
                                decoration: InputDecoration(
                                  labelText: f.name,
                                  hintText: f.type == 'checkbox' ? 'true / false' : 'Value',
                                  prefixIcon: Icon(_iconFor(f.type)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Flatten fields (make them permanent)'),
                          value: _flatten,
                          onChanged: (v) => setState(() => _flatten = v),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'checkbox' => Icons.check_box_outlined,
        'combobox' => Icons.arrow_drop_down_circle_outlined,
        'listbox' => Icons.view_list_outlined,
        _ => Icons.text_fields,
      };
}
