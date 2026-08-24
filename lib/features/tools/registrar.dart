
import '../image/image_options.dart';
import '../image/image_tools.dart';
import '../office/office_options.dart';
import '../office/office_tools.dart';
import '../pdf/pdf_tools.dart';
import '../pdf/options/pdf_interactive.dart';
import '../pdf/options/pdf_options_pages.dart';
import '../pdf/options/pdf_page_tools.dart';

typedef ToolRegistryReader = T Function<T>(dynamic provider);

/// Triggers registration of every tool handler at app startup.
void registerAllTools(ToolRegistryReader read) {
  PdfToolRegistrar(read).registerAll();
  PdfOptionsRegistrar.registerAll(read);
  PdfPageToolsRegistrar.registerAll(read);
  PdfInteractiveRegistrar.registerAll(read);
  ImageToolRegistrar(read).registerAll();
  ImageOptionsRegistrar.registerAll(read);
  OfficeToolRegistrar(read).registerAll();
  OfficeOptionsRegistrar.registerAll(read);
}
