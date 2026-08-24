import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/file_utils.dart';
import '../pdf/services/ocr_service.dart';
import '../tools/registrar.dart';
import '../tools/run_output.dart';
import '../tools/tool_handler.dart';
import 'services/image_service.dart';

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

/// Rasterizes watermark text to a transparent PNG using Flutter's text
/// engine (needs the main isolate).
Future<Uint8List> rasterizeTextPng(
  String text, {
  double fontSize = 64,
  int colorRgb = 0xFFFFFF,
}) async {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Color(0xFF000000 | colorRgb),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    painter.width.ceil().clamp(1, 4096),
    painter.height.ceil().clamp(1, 4096),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class ImageToolRegistrar {
  ImageToolRegistrar(this.read);

  final ToolRegistryReader read;

  void registerAll() {
    _reg('img_compress', _compress);
    _reg('img_resize', _resize);
    _reg('img_rotate', _rotate);
    _reg('img_convert', _convert);
    _reg('img_collage', _collage);
    _reg('img_adjust', _adjust);
    _reg('img_watermark', _watermark);
    _reg('img_border', _border);
    _reg('img_photo_layout', _photoLayout);
    _reg('img_ocr', _ocr);
    _reg('img_crop', _fromResult);
  }

  void _reg(String id, ToolProcessor processor) {
    ToolHandlerRegistry.register(id, ToolHandler(processor: processor));
  }

  static Future<ToolResult> _fromResult(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final path = options['resultPath'] as String?;
    if (path != null && path.isNotEmpty) {
      return ToolResult(outputPaths: [path]);
    }
    return ToolResult(error: 'No result produced');
  }

  Future<ToolResult> _single(
    List<String> inputs,
    Map<String, dynamic> options,
    String suffix,
    String ext,
    Future<Uint8List> Function(String path) op, {
    void Function(String, double)? onProgress,
  }) async {
    final runDir = await newRunDir();
    final outputs = <String>[];
    for (var i = 0; i < inputs.length; i++) {
      onProgress?.call('Processing ${i + 1} of ${inputs.length}', i / inputs.length);
      final bytes = await runInIsolate(() => op(inputs[i]));
      outputs.add(await writeRunFile(
        runDir,
        '${baseNameWithoutExt(inputs[i])}$suffix.$ext',
        bytes,
      ));
    }
    onProgress?.call('Done', 1);
    return ToolResult(outputPaths: outputs);
  }

  Future<ToolResult> _compress(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) {
    final quality = (options['quality'] as num?)?.toInt() ?? 70;
    final maxWidth = (options['maxWidth'] as num?)?.toInt();
    return _single(
      inputs,
      options,
      '_compressed',
      'jpg',
      (p) => ImageService().compress(p, quality: quality, maxWidth: maxWidth),
      onProgress: onProgress,
    );
  }

  Future<ToolResult> _resize(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) {
    final width = (options['width'] as num?)?.toInt();
    final height = (options['height'] as num?)?.toInt();
    return _single(
      inputs,
      options,
      '_resized',
      'jpg',
      (p) => ImageService().resize(p, width: width, height: height),
      onProgress: onProgress,
    );
  }

  Future<ToolResult> _rotate(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) {
    final mode = options['mode'] as String? ?? '90';
    return _single(
      inputs,
      options,
      '_rotated',
      'jpg',
      (p) => ImageService().rotate(p, mode: mode),
      onProgress: onProgress,
    );
  }

  Future<ToolResult> _convert(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final format = options['format'] as String? ?? 'png';
    final quality = (options['quality'] as num?)?.toInt() ?? 85;
    // WEBP needs the native encoder (no pure-Dart webp encoder available).
    if (format == 'webp') {
      final runDir = await newRunDir();
      final outputs = <String>[];
      for (var i = 0; i < inputs.length; i++) {
        onProgress?.call('Converting ${i + 1} of ${inputs.length}', i / inputs.length);
        final tmpPath = '$runDir/tmp_$i';
        final result = await FlutterImageCompress.compressAndGetFile(
          inputs[i],
          tmpPath,
          format: CompressFormat.webp,
          quality: quality,
        );
        final target = await uniquePath(
          runDir,
          '${baseNameWithoutExt(inputs[i])}.webp',
        );
        if (result != null && await File(result.path).exists()) {
          await File(result.path).copy(target);
          outputs.add(target);
        }
      }
      return ToolResult(outputPaths: outputs);
    }
    return _single(
      inputs,
      options,
      '',
      format,
      (p) => ImageService().convert(p, format, quality: quality),
      onProgress: onProgress,
    );
  }

  Future<ToolResult> _collage(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final cols = (options['cols'] as num?)?.toInt() ?? 2;
    final mode = options['mode'] as String? ?? 'grid';
    onProgress?.call('Building collage…', 0.5);
    final bytes = await runInIsolate(
      () => ImageService().collage(inputs, cols: cols, mode: mode),
    );
    final runDir = await newRunDir();
    final path = await writeRunFile(runDir, 'collage.jpg', bytes);
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _adjust(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) {
    final brightness = (options['brightness'] as num?)?.toDouble() ?? 0;
    final contrast = (options['contrast'] as num?)?.toDouble() ?? 1;
    final saturation = (options['saturation'] as num?)?.toDouble() ?? 1;
    final sharpen = (options['sharpen'] as num?)?.toDouble() ?? 0;
    return _single(
      inputs,
      options,
      '_adjusted',
      'jpg',
      (p) => ImageService().adjust(
        p,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
        sharpen: sharpen,
      ),
      onProgress: onProgress,
    );
  }

  Future<ToolResult> _watermark(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final text = options['text'] as String? ?? 'WATERMARK';
    final position = options['position'] as String? ?? 'center';
    final scale = (options['scale'] as num?)?.toDouble() ?? 0.4;
    final opacity = (options['opacity'] as num?)?.toDouble() ?? 0.5;
    final tiled = options['tiled'] as bool? ?? false;
    final markPng = await rasterizeTextPng(text, fontSize: 64);
    return _single(
      inputs,
      options,
      '_watermarked',
      'jpg',
      (p) => ImageService().watermarkWithPng(
        p,
        markPng,
        position: position,
        scale: scale,
        opacity: opacity,
        tiled: tiled,
      ),
      onProgress: onProgress,
    );
  }

  Future<ToolResult> _border(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) {
    final color = (options['color'] as num?)?.toInt() ?? 0xFFFFFF;
    final thickness = (options['thickness'] as num?)?.toInt() ?? 40;
    return _single(
      inputs,
      options,
      '_framed',
      'jpg',
      (p) => ImageService().border(p, colorRgb: color, thickness: thickness),
      onProgress: onProgress,
    );
  }

  Future<ToolResult> _photoLayout(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final layout = options['layout'] as String? ?? 'passport';
    final (pw, ph, cols, rows) = switch (layout) {
      'passport' => (826, 1063, 2, 3),
      'id35x45' => (827, 1063, 2, 3),
      'visa2x2' => (1200, 1200, 2, 2),
      _ => (1181, 1772, 2, 2),
    };
    onProgress?.call('Laying out photos…', 0.5);
    final bytes = await runInIsolate(
      () => ImageService().photoSheet(
        inputs.first,
        photoW: pw,
        photoH: ph,
        cols: cols,
        rows: rows,
      ),
    );
    final runDir = await newRunDir();
    final path = await writeRunFile(
      runDir,
      '${baseNameWithoutExt(inputs.first)}_sheet.jpg',
      bytes,
    );
    return ToolResult(outputPaths: [path]);
  }

  Future<ToolResult> _ocr(
    List<String> inputs,
    Map<String, dynamic> options, {
    void Function(String, double)? onProgress,
  }) async {
    final ocr = read(ocrServiceProvider);
    final runDir = await newRunDir();
    final outputs = <String>[];
    for (var i = 0; i < inputs.length; i++) {
      onProgress?.call('OCR ${i + 1} of ${inputs.length}', i / inputs.length);
      final text = await ocr.recognizeImage(inputs[i]);
      outputs.add(await writeRunFile(
        runDir,
        '${baseNameWithoutExt(inputs[i])}.txt',
        Uint8List.fromList(text.codeUnits),
      ));
    }
    return ToolResult(outputPaths: outputs);
  }
}
