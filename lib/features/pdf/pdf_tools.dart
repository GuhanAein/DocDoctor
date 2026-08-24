import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/utils/file_utils.dart';
import '../tools/run_output.dart';
import '../tools/tool_handler.dart';
import '../tools/registrar.dart';
import 'services/converters.dart';
import 'services/ocr_service.dart';
import 'services/pdf_raster_service.dart';
import 'services/pdf_service.dart';

final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());
final convertersProvider = Provider<DocumentConverters>((ref) => DocumentConverters());

class PdfToolRegistrar {
  PdfToolRegistrar(this.read);

  final ToolRegistryReader read;

  void registerAll() {
    // ── Organize ──────────────────────────────────────────────
    _register('pdf_merge', _merge);
    _register('pdf_scan', _scan);
    _register('pdf_split', _split);
    _register('pdf_extract', _extract);
    _register('pdf_remove', _remove);
    _register('pdf_reorder', _reorder);
    _register('pdf_insert', _insert);

    // ── Optimize / convert ────────────────────────────────────
    _register('pdf_compress', _compress);
    _register('pdf_repair', _repair);
    _register('pdf_from_image', _fromImage);
    _register('pdf_from_word', _fromWord);
    _register('pdf_from_excel', _fromExcel);
    _register('pdf_from_ppt', _fromPpt);
    _register('pdf_from_txt', _fromTxt);
    _register('pdf_from_html', _fromHtml);
    _register('pdf_from_csv', _fromCsv);
    _register('pdf_to_image', _toImage);
    _register('pdf_to_word', _toWord);
    _register('pdf_to_excel', _toExcel);
    _register('pdf_to_text', _toText);
    _register('pdf_to_ppt', _toPpt);
    _register('pdf_to_pdfa', _toPdfA);

    // ── Edit ──────────────────────────────────────────────────
    _register('pdf_watermark', _watermark);
    _register('pdf_page_numbers', _pageNumbers);
    _register('pdf_crop', _crop);
    _register('pdf_flatten', _flatten);
    _register('pdf_metadata', _metadata);
    _register('pdf_resize', _resize);
    _register('pdf_grayscale', _grayscale);
    _register('pdf_stamp', _stamp);

    // ── Security ──────────────────────────────────────────────
    _register('pdf_password', _password);
    _register('pdf_unlock', _unlock);
    _register('pdf_ocr', _ocr);

    // ── Interactive tools (handled by dedicated pages) ─────────
    _register('pdf_annotate', _delegated('pdf_annotate'));
    _register('pdf_redact', _delegated('pdf_redact'));
    _register('pdf_sign', _delegated('pdf_sign'));
    _register('pdf_forms', _delegated('pdf_forms'));
    _register('pdf_compare', _delegated('pdf_compare'));
  }

  ToolProcessor _delegated(String id) {
    return (inputs, options, {onProgress}) async =>
        ToolResult(error: 'Handled by $id page');
  }

  void _register(String id, ToolProcessor processor) {
    ToolHandlerRegistry.register(id, ToolHandler(processor: processor));
  }

  Future<ToolResult> _wrapIsolate(
    List<String> inputs,
    Map<String, dynamic> options,
    Future<Uint8List> Function(PdfService svc) op,
    String outName,
  ) async {
    final runDir = await newRunDir();
    final bytes = await runInIsolate(() async {
      final svc = PdfService();
      return op(svc);
    });
    final path = await writeRunFile(runDir, outName, bytes);
    return ToolResult(outputPaths: [path]);
  }

  // ════ Organize ════════════════════════════════════════════════
  Future<ToolResult> _scan(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    return ToolResult(error: 'Handled by camera flow');
  }

  Future<ToolResult> _merge(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    onProgress?.call('Merging ${inputs.length} files…', 0.3);
    final runDir = await newRunDir();
    final bytes = await runInIsolate(() => PdfService().merge(inputs));
    final path = await writeRunFile(
      runDir,
      '${baseNameWithoutExt(inputs.first)}_merged.pdf',
      bytes,
    );
    onProgress?.call('Done', 1);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _split(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final input = inputs.first;
    final mode = options['mode'] as String? ?? 'every';
    final ranges = options['ranges'] as String? ?? '';
    final runDir = await newRunDir();
    final name = baseNameWithoutExt(input);
    final outputs = <String>[];
    if (mode == 'every') {
      final pages = await runInIsolate(() => PdfService().splitEveryPage(input));
      for (var i = 0; i < pages.length; i++) {
        outputs.add(await writeRunFile(runDir, '${name}_page_${i + 1}.pdf', pages[i]));
      }
    } else {
      // ranges like "1-3,5,7-9"
      final service = PdfService();
      for (final part in ranges.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final m = RegExp(r'^(\d+)-(\d+)$').firstMatch(trimmed);
        if (m != null) {
          final a = int.parse(m.group(1)!);
          final b = int.parse(m.group(2)!);
          final pages = List.generate(b - a + 1, (i) => a + i);
          final bytes = await runInIsolate(() => service.extractPages(input, pages));
          outputs.add(await writeRunFile(runDir, '${name}_pages_$a-$b.pdf', bytes));
        } else {
          final p = int.tryParse(trimmed);
          if (p != null) {
            final bytes = await runInIsolate(() => service.extractPages(input, [p]));
            outputs.add(await writeRunFile(runDir, '${name}_page_$p.pdf', bytes));
          }
        }
      }
    }
    return ToolResult(outputPaths: outputs);
  }

  Future<ToolResult> _extract(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    return _wrapIsolate(
      inputs, options,
      (svc) => svc.extractPages(inputs.first, (options['pages'] as List? ?? []).cast<int>()),
      '${baseNameWithoutExt(inputs.first)}_extracted.pdf',
    );
  }

  Future<ToolResult> _remove(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    return _wrapIsolate(
      inputs, options,
      (svc) => svc.removePages(inputs.first, (options['pages'] as List? ?? []).cast<int>()),
      '${baseNameWithoutExt(inputs.first)}_cleaned.pdf',
    );
  }

  Future<ToolResult> _reorder(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    return _wrapIsolate(
      inputs, options,
      (svc) => svc.reorder(inputs.first, (options['order'] as List? ?? []).cast<int>()),
      '${baseNameWithoutExt(inputs.first)}_reordered.pdf',
    );
  }

  Future<ToolResult> _insert(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final insertPath = options['insertPath'] as String?;
    if (insertPath == null || insertPath.isEmpty) {
      return ToolResult(error: 'Pick a PDF to insert first');
    }
    final position = (options['position'] as num?)?.toInt() ?? 0;
    final runDir = await newRunDir();
    final bytes = await runInIsolate(
      () => PdfService().insertPages(inputs.first, [(insertPath, 0, position)]),
    );
    final path = await writeRunFile(
      runDir,
      '${baseNameWithoutExt(inputs.first)}_with_insert.pdf',
      bytes,
    );
    return ToolResult(outputPaths: [path]);
  }

  // ════ Optimize / convert ══════════════════════════════════════
  Future<ToolResult> _compress(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final input = inputs.first;
    final mode = options['mode'] as String? ?? 'lossless';
    final dpi = (options['dpi'] as num?)?.toInt() ?? 130;
    final quality = (options['quality'] as num?)?.toInt() ?? 60;
    final runDir = await newRunDir();
    Uint8List bytes;
    if (mode == 'lossy') {
      bytes = await read(pdfRasterServiceProvider).compressLossy(
            input,
            dpi: dpi,
            quality: quality,
            onProgress: onProgress,
          );
    } else {
      bytes = await runInIsolate(() => PdfService().recompress(input));
    }
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(input)}_compressed.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _repair(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    onProgress?.call('Repairing…', 0.5);
    final bytes = await runInIsolate(() => PdfService().repair(inputs.first));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}_repaired.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _fromImage(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final sizeId = options['pageSize'] as String? ?? 'auto';
    final quality = (options['quality'] as num?)?.toInt() ?? 85;
    final bytes = await read(pdfRasterServiceProvider).pdfFromImages(
          inputs,
          pageSizeId: sizeId,
          quality: quality,
          onProgress: onProgress,
        );
    final runDir = await newRunDir();
    final path = await writeRunFile(
      runDir,
      inputs.length == 1 ? '${baseNameWithoutExt(inputs.first)}.pdf' : 'images.pdf',
      bytes,
    );
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _fromTxt(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final text = await File(inputs.first).readAsString();
    final size = (options['fontSize'] as num?)?.toDouble() ?? 11;
    final bytes = await runInIsolate(() => DocumentConverters().txtToPdf(text, fontSize: size));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _fromHtml(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final html = await File(inputs.first).readAsString();
    final bytes = await runInIsolate(() => DocumentConverters().htmlToPdf(html));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _fromCsv(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final csv = await File(inputs.first).readAsString();
    final bytes = await runInIsolate(
      () => DocumentConverters().csvToPdf(csv, title: baseNameWithoutExt(inputs.first)),
    );
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _fromWord(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final src = await File(inputs.first).readAsBytes();
    final bytes = await runInIsolate(() => DocumentConverters().docxToPdf(src));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _fromExcel(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final src = await File(inputs.first).readAsBytes();
    final bytes = await runInIsolate(() => DocumentConverters().xlsxToPdf(src));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _fromPpt(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final src = await File(inputs.first).readAsBytes();
    final bytes = await runInIsolate(() => DocumentConverters().pptxToPdf(src));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _toImage(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final dpi = (options['dpi'] as num?)?.toInt() ?? 150;
    final format = options['format'] as String? ?? 'png';
    final pdfxFormat = format == 'jpeg'
        ? pdfx.PdfPageImageFormat.jpeg
        : format == 'webp'
            ? pdfx.PdfPageImageFormat.webp
            : pdfx.PdfPageImageFormat.png;
    final images = await read(pdfRasterServiceProvider).pdfToImages(
          inputs.first,
          dpi: dpi,
          format: pdfxFormat,
          onProgress: onProgress,
        );
    final runDir = await newRunDir();
    final name = baseNameWithoutExt(inputs.first);
    final outputs = <String>[];
    for (var i = 0; i < images.length; i++) {
      outputs.add(await writeRunFile(runDir, '${name}_page_${i + 1}.$format', images[i]));
    }
    return ToolResult(outputPaths: outputs);
  }

  Future<ToolResult> _toWord(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final src = await File(inputs.first).readAsBytes();
    final bytes = await runInIsolate(() => DocumentConverters().pdfToDocx(src));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}.docx', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _toExcel(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final src = await File(inputs.first).readAsBytes();
    final bytes = await runInIsolate(() => DocumentConverters().pdfToXlsx(src));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}.xlsx', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _toText(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final src = await File(inputs.first).readAsBytes();
    final text = await runInIsolate(() => DocumentConverters().pdfToText(src));
    final runDir = await newRunDir();
    final path = await writeRunFile(
      runDir,
      '${baseNameWithoutExt(inputs.first)}.txt',
      Uint8List.fromList(text.codeUnits),
    );
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _toPpt(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final images = await read(pdfRasterServiceProvider).pdfToImages(
      inputs.first,
      dpi: 110,
      format: pdfx.PdfPageImageFormat.png,
      onProgress: onProgress,
    );
    final bytes = await runInIsolate(() => DocumentConverters().buildPptxFromImages(images));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}.pptx', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _toPdfA(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    onProgress?.call('Converting to PDF/A-1b…', 0.4);
    final bytes = await runInIsolate(() => PdfService().toPdfA(inputs.first));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}_pdfa.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  // ════ Edit ════════════════════════════════════════════════════
  Future<ToolResult> _watermark(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final spec = WatermarkSpec(
      text: options['text'] as String? ?? 'CONFIDENTIAL',
      fontSize: (options['fontSize'] as num?)?.toDouble() ?? 48,
      opacity: (options['opacity'] as num?)?.toDouble() ?? 0.25,
      colorRgb: (options['color'] as num?)?.toInt() ?? 0x000000,
      angle: (options['angle'] as num?)?.toDouble() ?? -45,
      tiled: options['tiled'] as bool? ?? false,
      pages: (options['pages'] as List? ?? []).cast<int>(),
    );
    return _wrapIsolate(
      inputs, options,
      (svc) => svc.addWatermark(inputs.first, spec),
      '${baseNameWithoutExt(inputs.first)}_watermarked.pdf',
    );
  }

  Future<ToolResult> _pageNumbers(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final spec = PageNumberSpec(
      format: options['format'] as String? ?? 'Page {0} of {1}',
      fontSize: (options['fontSize'] as num?)?.toDouble() ?? 10,
      alignment: options['alignment'] as String? ?? 'bottom-center',
      skipFirst: options['skipFirst'] as bool? ?? false,
    );
    return _wrapIsolate(
      inputs, options,
      (svc) => svc.addPageNumbers(inputs.first, spec),
      '${baseNameWithoutExt(inputs.first)}_numbered.pdf',
    );
  }

  Future<ToolResult> _crop(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final bytes = await read(pdfRasterServiceProvider).cropPdf(
          inputs.first,
          left: (options['left'] as num?)?.toDouble() ?? 0,
          top: (options['top'] as num?)?.toDouble() ?? 0,
          right: (options['right'] as num?)?.toDouble() ?? 0,
          bottom: (options['bottom'] as num?)?.toDouble() ?? 0,
          onProgress: onProgress,
        );
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}_cropped.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _flatten(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    return _wrapIsolate(
      inputs, options,
      (svc) => svc.flatten(inputs.first),
      '${baseNameWithoutExt(inputs.first)}_flattened.pdf',
    );
  }

  Future<ToolResult> _metadata(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    return _wrapIsolate(
      inputs, options,
      (svc) => svc.setMetadata(inputs.first, {
        'title': options['title'] as String? ?? '',
        'author': options['author'] as String? ?? '',
        'subject': options['subject'] as String? ?? '',
        'keywords': options['keywords'] as String? ?? '',
        'creator': options['creator'] as String? ?? '',
      }),
      '${baseNameWithoutExt(inputs.first)}_meta.pdf',
    );
  }

  Future<ToolResult> _resize(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final sizeId = options['size'] as String? ?? 'a4';
    final size = switch (sizeId) {
      'a5' => PdfPageSize.a5,
      'a3' => PdfPageSize.a3,
      'letter' => PdfPageSize.letter,
      'legal' => PdfPageSize.legal,
      'b5' => PdfPageSize.b5,
      _ => PdfPageSize.a4,
    };
    final bytes = await runInIsolate(() => PdfService().resizePages(inputs.first, size));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}_$sizeId.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _grayscale(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final bytes = await read(pdfRasterServiceProvider).grayscalePdf(
          inputs.first,
          dpi: (options['dpi'] as num?)?.toInt() ?? 180,
          onProgress: onProgress,
        );
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}_gray.pdf', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _stamp(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final spec = StampSpec(
      text: options['text'] as String? ?? 'APPROVED',
      colorRgb: (options['color'] as num?)?.toInt() ?? 0x1B5E20,
      fontSize: (options['fontSize'] as num?)?.toDouble() ?? 18,
      position: options['position'] as String? ?? 'top-right',
      pages: (options['pages'] as List? ?? []).cast<int>(),
    );
    return _wrapIsolate(
      inputs, options,
      (svc) => svc.addStamp(inputs.first, spec),
      '${baseNameWithoutExt(inputs.first)}_stamped.pdf',
    );
  }

  // ════ Security ═════════════════════════════════════════════════
  Future<ToolResult> _password(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final password = options['password'] as String?;
    if (password == null || password.isEmpty) {
      return ToolResult(error: 'Enter a password');
    }
    return _wrapIsolate(
      inputs, options,
      (svc) => svc.passwordProtect(
        inputs.first,
        userPassword: password,
        ownerPassword: options['ownerPassword'] as String?,
        algorithm: options['algorithm'] as String? ?? 'aes256',
      ),
      '${baseNameWithoutExt(inputs.first)}_protected.pdf',
    );
  }

  Future<ToolResult> _unlock(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final password = options['password'] as String? ?? '';
    try {
      final bytes = await runInIsolate(() => PdfService().unlock(inputs.first, password));
      final runDir = await newRunDir();
      final path = await writeRunFile(runDir, '${baseNameWithoutExt(inputs.first)}_unlocked.pdf', bytes);
      return ToolResult(outputPaths: [path]);
    } catch (e) {
      return ToolResult(error: 'Could not unlock (wrong password or unsupported encryption)');
    }
  }

  // ════ OCR ══════════════════════════════════════════════════════
  Future<ToolResult> _ocr(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    final input = inputs.first;
    final pages = options['pages'] as List?;
    final dpi = (options['dpi'] as num?)?.toInt() ?? 200;
    final raster = read(pdfRasterServiceProvider);
    final ocr = read(ocrServiceProvider);
    final images = await raster.pdfToImages(
      input,
      dpi: dpi,
      format: pdfx.PdfPageImageFormat.png,
      pages: pages?.cast<int>(),
      onProgress: (m, p) => onProgress?.call('Rendering: $m', p * 0.4),
    );
    final pageNumbers = pages?.cast<int>() ?? List.generate(images.length, (i) => i + 1);
    final ocrData = <PageOcrData>[];
    for (var i = 0; i < images.length; i++) {
      onProgress?.call('OCR page ${pageNumbers[i]} (${i + 1}/${images.length})', 0.4 + 0.55 * (i / images.length));
      final renderWidth = (dpi * 595 / 72).round(); // approx width at dpi for A4-ish
      final words = await ocr.recognizeWords(images[i], _approxRenderWidth(images[i], renderWidth));
      ocrData.add(PageOcrData(
        page: pageNumbers[i],
        words: [
          for (final w in words)
            PageOcrWord(text: w.text, x: w.x, y: w.y, w: w.w, h: w.h),
        ],
      ));
    }
    onProgress?.call('Embedding text layer…', 0.97);
    final bytes = await runInIsolate(() => PdfService().addOcrTextLayer(input, ocrData));
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '${baseNameWithoutExt(input)}_ocr.pdf', bytes);
    onProgress?.call('Done', 1);
    return ToolResult(outputPaths: [path]);
  }

  int _approxRenderWidth(Uint8List png, int fallback) {
    final decoded = img.decodeImage(png);
    return decoded?.width ?? fallback;
  }
}

