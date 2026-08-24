import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide TextSpan;

import '../../core/utils/file_utils.dart';
import '../pdf/services/converters.dart';
import '../tools/registrar.dart';
import '../tools/run_output.dart';
import '../tools/tool_handler.dart';

class OfficeToolRegistrar {
  OfficeToolRegistrar(this.read);

  final ToolRegistryReader read;

  void registerAll() {
    _reg('ofc_excel_to_csv', _excelToCsv);
    _reg('ofc_csv_to_excel', _csvToExcel);
    _reg('ofc_excel_to_image', _excelToImage);
    _reg('ofc_zip', _zip);
    _reg('ofc_unzip', _unzip);
  }

  void _reg(String id, ToolProcessor processor) {
    ToolHandlerRegistry.register(id, ToolHandler(processor: processor));
  }

  Future<ToolResult> _excelToCsv(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final runDir = await newRunDir();
    final outputs = <String>[];
    for (var i = 0; i < inputs.length; i++) {
      onProgress?.call('Converting ${i + 1} of ${inputs.length}', i / inputs.length);
      final src = await File(inputs[i]).readAsBytes();
      final csv = await runInIsolate(() => DocumentConverters().xlsxToCsv(src));
      outputs.add(await writeRunFile(
        runDir,
        '${baseNameWithoutExt(inputs[i])}.csv',
        Uint8List.fromList(csv.codeUnits),
      ));
    }
    onProgress?.call('Done', 1);
    return ToolResult(outputPaths: outputs);
  }

  Future<ToolResult> _csvToExcel(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final runDir = await newRunDir();
    final outputs = <String>[];
    for (var i = 0; i < inputs.length; i++) {
      onProgress?.call('Converting ${i + 1} of ${inputs.length}', i / inputs.length);
      final csv = await File(inputs[i]).readAsString();
      final xlsx = await runInIsolate(() => DocumentConverters().csvToXlsx(csv));
      outputs.add(await writeRunFile(
        runDir,
        '${baseNameWithoutExt(inputs[i])}.xlsx',
        xlsx,
      ));
    }
    onProgress?.call('Done', 1);
    return ToolResult(outputPaths: outputs);
  }

  Future<ToolResult> _excelToImage(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final input = inputs.first;
    final src = await File(input).readAsBytes();
    final excel = Excel.decodeBytes(src);
    final runDir = await newRunDir();
    final outputs = <String>[];
    final sheetNames = excel.tables.keys.toList();
    for (var s = 0; s < sheetNames.length; s++) {
      onProgress?.call('Rendering sheet ${s + 1} of ${sheetNames.length}', s / sheetNames.length);
      final sheet = excel.tables[sheetNames[s]]!;
      final png = await _renderSheet(sheetNames[s], sheet);
      outputs.add(await writeRunFile(
        runDir,
        '${baseNameWithoutExt(input)}_${sanitizeFileName(sheetNames[s])}.png',
        png,
      ));
    }
    return ToolResult(outputPaths: outputs);
  }

  /// Renders a sheet to PNG with Flutter's text engine (main isolate).
  Future<Uint8List> _renderSheet(String title, Sheet sheet) async {
    const cellW = 120.0;
    const cellH = 26.0;
    const maxCols = 24;
    const maxRows = 120;
    final cols = sheet.maxColumns.clamp(1, maxCols);
    final rows = sheet.maxRows.clamp(1, maxRows);

    final width = (cols * cellW + 1).toInt();
    final height = (rows * cellH + cellH + 1).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );

    void cellText(int r, int c, String text, {bool header = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text.length > 28 ? text.substring(0, 28) : text,
          style: TextStyle(
            fontSize: header ? 12 : 11,
            fontWeight: header ? FontWeight.bold : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: cellW - 8);
      tp.paint(
        canvas,
        Offset(
          c * cellW + 4,
          (header ? 0 : r + 1) * cellH + (cellH - tp.height) / 2,
        ),
      );
    }

    // Header row
    for (var c = 0; c < cols; c++) {
      canvas.drawRect(
        Rect.fromLTWH(c * cellW, 0, cellW, cellH),
        Paint()..color = const Color(0xFFE3F2FD),
      );
      cellText(0, c, 'Col ${c + 1}', header: true);
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * cellW, (r + 1) * cellH, cellW, cellH);
        canvas.drawRect(
          rect,
          Paint()
            ..color = r.isEven ? Colors.white : const Color(0xFFFAFAFA)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(rect, Paint()..color = Colors.black12..style = PaintingStyle.stroke);
        final cell = sheet.rows[r][c];
        final value = cell?.value;
        var text = '';
        if (value is TextCellValue) {
          text = value.value.text ?? '';
        } else if (value is IntCellValue) {
          text = value.value.toString();
        } else if (value is DoubleCellValue) {
          text = value.value.toString();
        } else if (value is DateCellValue) {
          text = '${value.year}-${value.month}-${value.day}';
        } else if (value != null) {
          text = value.toString();
        }
        cellText(r, c, text);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<ToolResult> _zip(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final name = options['name'] as String? ?? 'archive';
    onProgress?.call('Compressing ${inputs.length} files…', 0.4);
    final bytes = await runInIsolate(() async {
      final encoder = ZipEncoder();
      final archive = Archive();
      for (final p in inputs) {
        final f = File(p);
        final content = await f.readAsBytes();
        archive.addFile(ArchiveFile(f.uri.pathSegments.last, content.length, content));
      }
      return Uint8List.fromList(encoder.encode(archive) ?? const []);
    });
    onProgress?.call('Done', 1);
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, '$name.zip', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _unzip(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final input = inputs.first;
    final runDir = await newRunDir();
    final outDir = await Directory('$runDir/${baseNameWithoutExt(input)}').create(recursive: true);
    onProgress?.call('Extracting…', 0.3);
    final extracted = await runInIsolate(() async {
      final bytes = await File(input).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final paths = <String>[];
      for (final entry in archive.files) {
        if (entry.isFile) {
          final target = File('${outDir.path}/${entry.name}');
          await target.parent.create(recursive: true);
          await target.writeAsBytes(entry.content as List<int>);
          paths.add(target.path);
        }
      }
      return paths;
    });
    onProgress?.call('Done', 1);
    return ToolResult(outputPaths: extracted.take(50).toList());
  }
}
