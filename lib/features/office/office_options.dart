import 'package:flutter/material.dart';

import '../tools/tool_handler.dart';
import '../tools/registrar.dart';
import '../pdf/options/options_shell.dart';

class OfficeOptionsRegistrar {
  static void registerAll(ToolRegistryReader read) {
    _with('ofc_zip', (c, i, o, run) => _ZipOptions(inputs: i, onRun: run));
  }

  static void _with(String id, OptionsPageBuilder builder) {
    final existing = ToolHandlerRegistry.handlerFor(id);
    ToolHandlerRegistry.register(id, ToolHandler(
      processor: existing?.processor ?? _delegated,
      optionsBuilder: builder,
    ));
  }

  static Future<ToolResult> _delegated(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    return ToolResult(error: 'unused');
  }
}

class _ZipOptions extends StatefulWidget {
  const _ZipOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_ZipOptions> createState() => _ZipOptionsState();
}

class _ZipOptionsState extends State<_ZipOptions> {
  String _name = 'archive';

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'name': _name}),
      previewHeight: 100,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Archive name',
            hintText: 'archive',
          ),
          onChanged: (v) => _name = v,
        ),
      ],
    );
  }
}
