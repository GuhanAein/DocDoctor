import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class OcrLine {
  const OcrLine({required this.text, required this.x, required this.y, required this.w, required this.h});
  final String text;
  final double x, y, w, h;
}

/// On-device OCR via Google ML Kit (models ship through Play Services and run
/// fully offline). Runs on the main isolate (native method channels).
class OcrService {
  Future<String> recognizeImage(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(path);
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  Future<String> recognizeBytes(Uint8List bytes, {String ext = 'png'}) async {
    final tmp = await getTemporaryDirectory();
    final f = File('${tmp.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.$ext');
    await f.writeAsBytes(bytes);
    try {
      return await recognizeImage(f.path);
    } finally {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  /// Runs OCR on a page image and returns word boxes scaled to PDF points
  /// for a [renderWidthPx]-wide source image.
  Future<List<OcrLine>> recognizeWords(
    Uint8List imageBytes,
    int renderWidthPx,
  ) async {
    final tmp = await getTemporaryDirectory();
    final f = File('${tmp.path}/ocr_words_${DateTime.now().microsecondsSinceEpoch}.png');
    await f.writeAsBytes(imageBytes);
    try {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final result = await recognizer.processImage(InputImage.fromFilePath(f.path));
        final scale = 72.0 / renderWidthPx;
        final lines = <OcrLine>[];
        for (final block in result.blocks) {
          for (final line in block.lines) {
            final b = line.boundingBox;
            final text = line.text.trim();
            if (text.isEmpty) continue;
            lines.add(OcrLine(
              text: text,
              x: b.left * scale,
              y: b.top * scale,
              w: b.width * scale,
              h: b.height * scale,
            ));
          }
        }
        return lines;
      } finally {
        await recognizer.close();
      }
    } finally {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}

final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());
