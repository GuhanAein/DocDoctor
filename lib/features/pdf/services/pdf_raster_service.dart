import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'dart:ui' show Rect, Size;


/// Raster operations on PDFs. Uses pdfx (native Pdfium) so these methods
/// must run on the main isolate.
class PdfRasterService {
  Future<List<Uint8List>> pdfToImages(
    String path, {
    int dpi = 150,
    pdfx.PdfPageImageFormat format = pdfx.PdfPageImageFormat.png,
    List<int>? pages,
    void Function(String, double)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(path);
    try {
      final count = doc.pagesCount;
      final selected = pages?.where((p) => p >= 1 && p <= count).toList() ??
          List.generate(count, (i) => i + 1);
      final results = <Uint8List>[];
      var done = 0;
      for (final p in selected) {
        onProgress?.call('Rendering page $p of ${selected.length}', done / selected.length);
        final page = await doc.getPage(p);
        final width = (page.width / 72 * dpi).round();
        final imgPage = await page.render(
          width: width.toDouble(),
          height: (width * (page.height / page.width)).toDouble(),
          format: format,
          backgroundColor: '#FFFFFF',
        );
        await page.close();
        if (imgPage?.bytes != null) results.add(imgPage!.bytes);
        done++;
      }
      onProgress?.call('Done', 1);
      return results;
    } finally {
      await doc.close();
    }
  }

  Future<Uint8List> cropPdf(
    String path, {
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
    int dpi = 200,
    void Function(String, double)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(path);
    try {
      final out = sf.PdfDocument();
      final count = doc.pagesCount;
      for (var p = 1; p <= count; p++) {
        onProgress?.call('Cropping page $p of $count', p / count);
        final page = await doc.getPage(p);
        final width = (page.width / 72 * dpi).round();
        final full = await page.render(
          width: width.toDouble(),
          height: (width * (page.height / page.width)).toDouble(),
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        await page.close();
        if (full?.bytes == null) continue;
        final decoded = img.decodeImage(full!.bytes);
        if (decoded == null) continue;
        final cropW = (decoded.width * (1 - left - right)).round().clamp(1, decoded.width);
        final cropH = (decoded.height * (1 - top - bottom)).round().clamp(1, decoded.height);
        final cropX = (decoded.width * left).round().clamp(0, decoded.width - cropW);
        final cropY = (decoded.height * top).round().clamp(0, decoded.height - cropH);
        final cropped = img.copyCrop(decoded,
            x: cropX, y: cropY, width: cropW, height: cropH);
        final jpeg = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
        final bitmap = sf.PdfBitmap(jpeg);
        final newPage = out.pages.add();
        out.pageSettings.size = Size(
          page.width * (1 - left - right),
          page.height * (1 - top - bottom),
        );
        newPage.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(0, 0, page.width * (1 - left - right), page.height * (1 - top - bottom)),
        );
      }
      final bytes = await out.save();
      out.dispose();
      return Uint8List.fromList(bytes);
    } finally {
      await doc.close();
    }
  }

  Future<Uint8List> grayscalePdf(
    String path, {
    int dpi = 180,
    void Function(String, double)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(path);
    try {
      final out = sf.PdfDocument();
      final count = doc.pagesCount;
      for (var p = 1; p <= count; p++) {
        onProgress?.call('Converting page $p of $count', p / count);
        final page = await doc.getPage(p);
        final width = (page.width / 72 * dpi).round();
        final full = await page.render(
          width: width.toDouble(),
          height: (width * (page.height / page.width)).toDouble(),
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        await page.close();
        if (full?.bytes == null) continue;
        final decoded = img.decodeImage(full!.bytes);
        if (decoded == null) continue;
        final gray = img.grayscale(decoded);
        final jpeg = Uint8List.fromList(img.encodeJpg(gray, quality: 88));
        final bitmap = sf.PdfBitmap(jpeg);
        final newPage = out.pages.add();
        out.pageSettings.size = Size(page.width, page.height);
        newPage.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(0, 0, page.width, page.height),
        );
      }
      final bytes = await out.save();
      out.dispose();
      return Uint8List.fromList(bytes);
    } finally {
      await doc.close();
    }
  }

  Future<Uint8List> compressLossy(
    String path, {
    int dpi = 130,
    int quality = 60,
    void Function(String, double)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(path);
    try {
      final out = sf.PdfDocument();
      final count = doc.pagesCount;
      for (var p = 1; p <= count; p++) {
        onProgress?.call('Compressing page $p of $count', p / count);
        final page = await doc.getPage(p);
        final width = (page.width / 72 * dpi).round();
        final full = await page.render(
          width: width.toDouble(),
          height: (width * (page.height / page.width)).toDouble(),
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: quality,
        );
        await page.close();
        if (full?.bytes == null) continue;
        final bitmap = sf.PdfBitmap(full!.bytes);
        final newPage = out.pages.add();
        out.pageSettings.size = Size(page.width, page.height);
        newPage.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(0, 0, page.width, page.height),
        );
      }
      final bytes = await out.save();
      out.dispose();
      return Uint8List.fromList(bytes);
    } finally {
      await doc.close();
    }
  }

  Future<Uint8List> pdfFromImages(
    List<String> imagePaths, {
    String pageSizeId = 'auto',
    int quality = 85,
    void Function(String, double)? onProgress,
  }) async {
    final out = sf.PdfDocument();
    var done = 0;
    for (final p in imagePaths) {
      onProgress?.call('Adding image ${done + 1} of ${imagePaths.length}', done / imagePaths.length);
      final fileBytes = await File(p).readAsBytes();
      var decoded = img.decodeImage(fileBytes);
      if (decoded == null) continue;
      decoded = img.bakeOrientation(decoded);
      Uint8List jpeg;
      if (quality < 95) {
        jpeg = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
      } else {
        jpeg = Uint8List.fromList(img.encodePng(decoded));
      }
      final bitmap = sf.PdfBitmap(jpeg);
      final newPage = out.pages.add();
      final pw = pageWidthPoints(pageSizeId, decoded.width, decoded.height);
      final ph = pageHeightPoints(pageSizeId, decoded.width, decoded.height);
      out.pageSettings.size = Size(pw, ph);
      newPage.graphics.drawImage(bitmap, Rect.fromLTWH(0, 0, pw, ph));
      done++;
    }
    final bytes = await out.save();
    out.dispose();
    return Uint8List.fromList(bytes);
  }

  double pageWidthPoints(String sizeId, int imgW, int imgH) {
    final s = _pageSizePoints(sizeId);
    if (s != null) return s.width;
    // auto: A4 portrait/landscape based on image aspect
    final aspect = imgW / imgH;
    return aspect >= 1 ? 842.0 : 595.0;
  }

  double pageHeightPoints(String sizeId, int imgW, int imgH) {
    final s = _pageSizePoints(sizeId);
    if (s != null) return s.height;
    final aspect = imgW / imgH;
    return aspect >= 1 ? 595.0 : 842.0;
  }

  Size? _pageSizePoints(String id) => switch (id) {
        'a4' => const Size(595, 842),
        'a5' => const Size(421, 595),
        'a3' => const Size(842, 1190),
        'letter' => const Size(612, 792),
        'legal' => const Size(612, 1008),
        _ => null,
      };
}

final pdfRasterServiceProvider = Provider<PdfRasterService>((ref) => PdfRasterService());
