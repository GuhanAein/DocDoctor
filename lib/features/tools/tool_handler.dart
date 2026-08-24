import 'package:flutter/material.dart';


class ToolResult {
  ToolResult({this.outputPaths = const [], this.error});

  final List<String> outputPaths;
  final String? error;

  bool get ok => error == null && outputPaths.isNotEmpty;
}

typedef ToolProcessor = Future<ToolResult> Function(
  List<String> inputs,
  Map<String, dynamic> options, {
  void Function(String message, double progress)? onProgress,
});

typedef OptionsPageBuilder = Widget Function(
  BuildContext context,
  List<String> inputs,
  Map<String, dynamic> initialOptions,
  ValueChanged<Map<String, dynamic>> onRun,
);

class ToolHandler {
  const ToolHandler({required this.processor, this.optionsBuilder});

  final ToolProcessor processor;
  final OptionsPageBuilder? optionsBuilder;
}

class ToolHandlerRegistry {
  static final Map<String, ToolHandler> _handlers = {};

  static void register(String toolId, ToolHandler handler) {
    _handlers[toolId] = handler;
  }

  static ToolHandler? handlerFor(String toolId) => _handlers[toolId];

  static void init() {}
}
