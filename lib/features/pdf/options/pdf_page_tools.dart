import '../../tools/registrar.dart';

import '../../../core/models/tool.dart';
import '../../tools/tool_handler.dart';
import '../widgets/pdf_page_selector.dart';

class PdfPageToolsRegistrar {
  static void registerAll(ToolRegistryReader read) {
    ToolHandlerRegistry.register('pdf_extract', ToolHandler(
      processor: (inputs, options, {onProgress}) async => ToolResult(error: 'delegated'),
      optionsBuilder: (context, inputs, initial, onRun) => PdfPageSelector(
        tool: findTool('pdf_extract')!,
        inputPath: inputs.first,
        mode: PageSelectMode.select,
        onRun: (pages) => onRun({'pages': pages}),
      ),
    ));
    ToolHandlerRegistry.register('pdf_remove', ToolHandler(
      processor: (inputs, options, {onProgress}) async => ToolResult(error: 'delegated'),
      optionsBuilder: (context, inputs, initial, onRun) => PdfPageSelector(
        tool: findTool('pdf_remove')!,
        inputPath: inputs.first,
        mode: PageSelectMode.select,
        title: 'Select pages to remove',
        onRun: (pages) => onRun({'pages': pages}),
      ),
    ));
    ToolHandlerRegistry.register('pdf_reorder', ToolHandler(
      processor: (inputs, options, {onProgress}) async => ToolResult(error: 'delegated'),
      optionsBuilder: (context, inputs, initial, onRun) => PdfPageSelector(
        tool: findTool('pdf_reorder')!,
        inputPath: inputs.first,
        mode: PageSelectMode.reorder,
        onRun: (pages) => onRun({'order': pages}),
      ),
    ));
  }
}
