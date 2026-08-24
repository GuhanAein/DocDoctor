import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

class WatermarkSpec {
  const WatermarkSpec({
    required this.text,
    this.fontSize = 48,
    this.opacity = 0.25,
    this.colorRgb = 0x000000,
    this.angle = -45,
    this.tiled = false,
    this.pages = const [],
  });

  final String text;
  final double fontSize;
  final double opacity;
  final int colorRgb;
  final double angle;
  final bool tiled;
  final List<int> pages;
}

class PageNumberSpec {
  const PageNumberSpec({
    required this.format,
    this.fontSize = 10,
    this.alignment = 'bottom-center',
    this.startAt = 1,
    this.skipFirst = false,
  });

  final String format; // e.g. 'Page {0} of {1}'
  final double fontSize;
  final String alignment; // bottom-left|bottom-center|bottom-right|top-left|top-center|top-right
  final int startAt;
  final bool skipFirst;
}

class StampSpec {
  const StampSpec({
    required this.text,
    this.colorRgb = 0xD32F2F,
    this.fontSize = 18,
    this.position = 'top-right',
    this.pages = const [],
  });

  final String text;
  final int colorRgb;
  final double fontSize;
  final String position; // top-left|top-right|center|bottom-left|bottom-right
  final List<int> pages;
}

class DrawTextOp {
  const DrawTextOp({required this.text, required this.x, required this.y, required this.size, required this.colorRgb, this.page = 1});
  final String text;
  final double x, y, size;
  final int colorRgb;
  final int page;
}

class DrawPathOp {
  const DrawPathOp({required this.points, required this.width, required this.colorRgb, this.page = 1});
  final List<List<double>> points; // [x,y] in PDF points
  final double width;
  final int colorRgb;
  final int page;
}

class DrawRectOp {
  const DrawRectOp({required this.x, required this.y, required this.w, required this.h, required this.width, required this.colorRgb, this.page = 1});
  final double x, y, w, h, width;
  final int colorRgb;
  final int page;
}

class DrawEllipseOp {
  const DrawEllipseOp({required this.x, required this.y, required this.w, required this.h, required this.width, required this.colorRgb, this.page = 1});
  final double x, y, w, h, width;
  final int colorRgb;
  final int page;
}

class DrawLineOp {
  const DrawLineOp({required this.x1, required this.y1, required this.x2, required this.y2, required this.width, required this.colorRgb, this.page = 1});
  final double x1, y1, x2, y2, width;
  final int colorRgb;
  final int page;
}

class RedactRectOp {
  const RedactRectOp({required this.x, required this.y, required this.w, required this.h, this.page = 1});
  final double x, y, w, h;
  final int page;
}

class FormFieldInfo {
  const FormFieldInfo({required this.name, required this.type, this.value = '', this.page = 0});
  final String name;
  final String type;
  final String value;
  final int page;

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'value': value, 'page': page};
}

class PageOcrWord {
  const PageOcrWord({required this.text, required this.x, required this.y, required this.w, required this.h});
  final String text;
  final double x, y, w, h;
}

class PageOcrData {
  const PageOcrData({required this.page, required this.words});
  final int page;
  final List<PageOcrWord> words;
}

class SignaturePlacement {
  const SignaturePlacement({required this.pngBytes, required this.page, required this.x, required this.y, required this.w});
  final Uint8List pngBytes;
  final int page;
  final double x, y, w;
}

/// Pure-Dart PDF engine (Syncfusion). Every method here runs fine inside
/// a background isolate; callers should wrap with [runInIsolate].
class PdfService {
  PdfDocument _open(String path, {String? password}) {
    final bytes = File(path).readAsBytesSync();
    return PdfDocument(inputBytes: bytes, password: password);
  }

  // ── Organize ────────────────────────────────────────────────────
  Future<Uint8List> merge(List<String> paths) async {
    final out = PdfDocument();
    for (final path in paths) {
      final src = _open(path);
      try {
        for (var i = 0; i < src.pages.count; i++) {
          final page = src.pages[i];
          final template = page.createTemplate();
          final newPage = out.pages.add();
          newPage.graphics.drawPdfTemplate(
            template,
            Offset.zero,
            newPage.getClientSize(),
          );
        }
      } finally {
        src.dispose();
      }
    }
    final bytes = await out.save();
    out.dispose();
    return Uint8List.fromList(bytes);
  }

  Future<List<Uint8List>> splitEveryPage(String path) async {
    final src = _open(path);
    final results = <Uint8List>[];
    try {
      for (var i = 0; i < src.pages.count; i++) {
        final doc = PdfDocument();
        final page = src.pages[i];
        final newPage = doc.pages.add();
        newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero, newPage.getClientSize());
        results.add(Uint8List.fromList(await doc.save()));
        doc.dispose();
      }
    } finally {
      src.dispose();
    }
    return results;
  }

  Future<Uint8List> extractPages(String path, List<int> pages) async {
    final src = _open(path);
    final out = PdfDocument();
    try {
      for (final p in pages) {
        if (p < 1 || p > src.pages.count) continue;
        final page = src.pages[p - 1];
        final newPage = out.pages.add();
        newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero, newPage.getClientSize());
      }
      final bytes = await out.save();
      return Uint8List.fromList(bytes);
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  Future<Uint8List> removePages(String path, List<int> pages) async {
    final src = _open(path);
    final out = PdfDocument();
    final remove = pages.toSet();
    try {
      for (var i = 0; i < src.pages.count; i++) {
        if (remove.contains(i + 1)) continue;
        final page = src.pages[i];
        final newPage = out.pages.add();
        newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero, newPage.getClientSize());
      }
      final bytes = await out.save();
      return Uint8List.fromList(bytes);
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  Future<Uint8List> reorder(String path, List<int> newOrder) async {
    final src = _open(path);
    final out = PdfDocument();
    try {
      for (final p in newOrder) {
        if (p < 1 || p > src.pages.count) continue;
        final page = src.pages[p - 1];
        final newPage = out.pages.add();
        newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero, newPage.getClientSize());
      }
      final bytes = await out.save();
      return Uint8List.fromList(bytes);
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  /// [inserts] = list of (sourcePath, pageIndex1based, position) where
  /// position is the page number AFTER which the source is inserted
  /// (0 = at the beginning).
  Future<Uint8List> insertPages(
    String basePath,
    List<(String, int, int)> inserts,
  ) async {
    final base = _open(basePath);
    final out = PdfDocument();
    try {
      final insertMap = <int, List<PdfTemplate>>{};
      for (final (srcPath, pageNo, position) in inserts) {
        final src = _open(srcPath);
        try {
          final templates = <PdfTemplate>[];
          if (pageNo == 0) {
            for (var i = 0; i < src.pages.count; i++) {
              templates.add(src.pages[i].createTemplate());
            }
          } else if (pageNo <= src.pages.count) {
            templates.add(src.pages[pageNo - 1].createTemplate());
          }
          insertMap.putIfAbsent(position, () => []).addAll(templates);
        } finally {
          src.dispose();
        }
      }
      for (var i = 0; i < base.pages.count; i++) {
        final toInsert = insertMap[i + 1] ?? const <PdfTemplate>[];
        for (final t in toInsert) {
          final np = out.pages.add();
          np.graphics.drawPdfTemplate(t, Offset.zero, np.getClientSize());
        }
        final page = base.pages[i];
        final newPage = out.pages.add();
        newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero, newPage.getClientSize());
      }
      for (final t in insertMap[base.pages.count + 1] ?? const <PdfTemplate>[]) {
        final np = out.pages.add();
        np.graphics.drawPdfTemplate(t, Offset.zero, np.getClientSize());
      }
      final bytes = await out.save();
      return Uint8List.fromList(bytes);
    } finally {
      base.dispose();
      out.dispose();
    }
  }

  // ── Optimize ────────────────────────────────────────────────────
  Future<Uint8List> recompress(String path) async {
    final doc = _open(path);
    try {
      doc.compressionLevel = PdfCompressionLevel.best;
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> repair(String path) async {
    final bytes = File(path).readAsBytesSync();
    // Strip trailing garbage after last %%EOF (common corruption).
    var cleaned = bytes;
    final lastEof = _lastIndexOf(bytes, asciiCodes('%%EOF'));
    if (lastEof >= 0) {
      final eofEnd = lastEof + 5;
      if (eofEnd < bytes.length) {
        cleaned = bytes.sublist(0, eofEnd);
      }
    }
    try {
      final doc = PdfDocument(inputBytes: cleaned);
      try {
        doc.compressionLevel = PdfCompressionLevel.best;
        final fixed = await doc.save();
        return Uint8List.fromList(fixed);
      } finally {
        doc.dispose();
      }
    } catch (_) {
      // Fall back: re-save the raw file unchanged.
      return cleaned;
    }
  }

  static int _lastIndexOf(Uint8List haystack, List<int> needle) {
    outer:
    for (var i = haystack.length - needle.length; i >= 0; i--) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  Future<Uint8List> toPdfA(String path) async {
    final src = _open(path);
    final out = PdfDocument(conformanceLevel: PdfConformanceLevel.a1b);
    try {
      out.documentInformation.title = src.documentInformation.title;
      out.documentInformation.author = src.documentInformation.author;
      for (var i = 0; i < src.pages.count; i++) {
        final page = src.pages[i];
        final newPage = out.pages.add();
        newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero, newPage.getClientSize());
      }
      final bytes = await out.save();
      return Uint8List.fromList(bytes);
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  // ── Annotations / markup ────────────────────────────────────────
  Future<Uint8List> applyDrawOps(String path, List<Object> ops) async {
    final doc = _open(path);
    try {
      for (final op in ops) {
        final PdfColor color;
        final int pageNo;
        if (op is DrawTextOp) {
          color = _color(op.colorRgb);
          pageNo = op.page;
          final page = _pageSafe(doc, pageNo);
          final g = page.graphics;
          g.save();
          g.drawString(
            op.text,
            PdfStandardFont(PdfFontFamily.helvetica, op.size),
            brush: PdfSolidBrush(color),
            bounds: Rect.fromLTWH(op.x, op.y, 500, 100),
          );
          g.restore();
        } else if (op is DrawPathOp) {
          color = _color(op.colorRgb);
          pageNo = op.page;
          final page = _pageSafe(doc, pageNo);
          final g = page.graphics;
          final pen = PdfPen(color, width: op.width);
          pen.lineCap = PdfLineCap.round;
          pen.lineJoin = PdfLineJoin.round;
          final points = op.points;
          if (points.length < 2) continue;
          for (var i = 1; i < points.length; i++) {
            g.drawLine(
              pen,
              Offset(points[i - 1][0], points[i - 1][1]),
              Offset(points[i][0], points[i][1]),
            );
          }
        } else if (op is DrawRectOp) {
          color = _color(op.colorRgb);
          pageNo = op.page;
          final page = _pageSafe(doc, pageNo);
          page.graphics.drawRectangle(
            pen: PdfPen(color, width: op.width),
            bounds: Rect.fromLTWH(op.x, op.y, op.w, op.h),
          );
        } else if (op is DrawEllipseOp) {
          color = _color(op.colorRgb);
          pageNo = op.page;
          final page = _pageSafe(doc, pageNo);
          page.graphics.drawEllipse(
            Rect.fromLTWH(op.x, op.y, op.w, op.h),
            pen: PdfPen(color, width: op.width),
          );
        } else if (op is DrawLineOp) {
          color = _color(op.colorRgb);
          pageNo = op.page;
          final page = _pageSafe(doc, pageNo);
          page.graphics.drawLine(
            PdfPen(color, width: op.width),
            Offset(op.x1, op.y1),
            Offset(op.x2, op.y2),
          );
        } else {
          continue;
        }
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> addWatermark(String path, WatermarkSpec spec) async {
    final doc = _open(path);
    try {
      final color = _color(spec.colorRgb, alpha: (spec.opacity * 255).round());
      final font = PdfStandardFont(PdfFontFamily.helvetica, spec.fontSize);
      for (var i = 0; i < doc.pages.count; i++) {
        if (spec.pages.isNotEmpty && !spec.pages.contains(i + 1)) continue;
        final page = doc.pages[i];
        final size = page.getClientSize();
        final g = page.graphics;
        g.save();
        g.setTransparency(spec.opacity);
        if (spec.tiled) {
          final stepX = 300.0;
          final stepY = 240.0;
          for (var x = -size.height; x < size.width + 100; x += stepX) {
            for (var y = -100.0; y < size.height + 100; y += stepY) {
              g.drawString(
                spec.text,
                font,
                brush: PdfSolidBrush(color),
                bounds: Rect.fromLTWH(x, y, 300, 60),
              );
            }
          }
        } else {
          final cx = size.width / 2;
          final cy = size.height / 2;
          g.translateTransform(cx, cy);
          g.rotateTransform(spec.angle);
          g.drawString(
            spec.text,
            font,
            brush: PdfSolidBrush(color),
            bounds: Rect.fromLTWH(-size.width / 2, -spec.fontSize / 2, size.width, spec.fontSize * 2),
            format: PdfStringFormat(alignment: PdfTextAlignment.center),
          );
          g.rotateTransform(-spec.angle);
          g.translateTransform(-cx, -cy);
        }
        g.restore();
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> addPageNumbers(String path, PageNumberSpec spec) async {
    final doc = _open(path);
    try {
      final font = PdfStandardFont(PdfFontFamily.helvetica, spec.fontSize);
      for (var i = 0; i < doc.pages.count; i++) {
        if (spec.skipFirst && i == 0) continue;
        final page = doc.pages[i];
        final size = page.getClientSize();
        final pageNumber = PdfPageNumberField(font: font, brush: PdfBrushes.black)
          ..numberStyle = PdfNumberStyle.numeric;
        final pageCount = PdfPageCountField(font: font, brush: PdfBrushes.black);
        final composite = PdfCompositeField(
          font: font,
          brush: PdfBrushes.black,
          text: spec.format,
          fields: [pageNumber, pageCount],
        );
        final Offset pos = _alignmentPosition(spec.alignment, size, 60, 24);
        composite.draw(page.graphics, pos);
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> addStamp(String path, StampSpec spec) async {
    final doc = _open(path);
    try {
      final font = PdfStandardFont(PdfFontFamily.helvetica, spec.fontSize);
      final color = _color(spec.colorRgb);
      for (var i = 0; i < doc.pages.count; i++) {
        if (spec.pages.isNotEmpty && !spec.pages.contains(i + 1)) continue;
        final page = doc.pages[i];
        final size = page.getClientSize();
        final g = page.graphics;
        final textWidth = _textWidth(spec.text, font);
        final w = textWidth + 36;
        final h = spec.fontSize * 2.2;
        final Offset pos = _stampPosition(spec.position, size, w, h);
        final rect = Rect.fromLTWH(pos.dx, pos.dy, w, h);
        final transparentColor = PdfColor(120, color.r, color.g, color.b);
        g.setTransparency(0.55);
        g.drawRectangle(
          bounds: rect,
          brush: PdfSolidBrush(transparentColor),
          pen: PdfPen(color, width: 2),
        );
        g.drawString(
          spec.text,
          font,
          brush: PdfSolidBrush(color),
          bounds: rect.deflate(12),
          format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
        );
        g.setTransparency(1);
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> addSignatureImage(String path, SignaturePlacement placement) async {
    final doc = _open(path);
    try {
      final page = _pageSafe(doc, placement.page);
      final bitmap = PdfBitmap(placement.pngBytes);
      final aspect = bitmap.height / bitmap.width;
      final h = placement.w * aspect;
      page.graphics.drawImage(bitmap, Rect.fromLTWH(placement.x, placement.y, placement.w, h));
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> redactRects(String path, List<RedactRectOp> rects) async {
    final doc = _open(path);
    try {
      for (final r in rects) {
        final page = _pageSafe(doc, r.page);
        page.graphics.drawRectangle(
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(r.x, r.y, r.w, r.h),
        );
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> redactText(String path, String search) async {
    final doc = _open(path);
    try {
      final extractor = PdfTextExtractor(doc);
      final lower = search.toLowerCase();
      for (var i = 0; i < doc.pages.count; i++) {
        final lines = extractor.extractTextLines(startPageIndex: i, endPageIndex: i);
        for (final line in lines) {
          if (!line.text.toLowerCase().contains(lower)) continue;
          doc.pages[i].graphics.drawRectangle(
            brush: PdfBrushes.black,
            bounds: line.bounds.inflate(1),
          );
        }
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  // ── Metadata / pages ────────────────────────────────────────────
  Future<Map<String, String>> getMetadata(String path) async {
    final doc = _open(path);
    try {
      final info = doc.documentInformation;
      return {
        'title': info.title,
        'author': info.author,
        'subject': info.subject,
        'keywords': info.keywords,
        'creator': info.creator,
        'producer': info.producer,
      };
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> setMetadata(String path, Map<String, String> values) async {
    final doc = _open(path);
    try {
      final info = doc.documentInformation;
      info.title = values['title'] ?? '';
      info.author = values['author'] ?? '';
      info.subject = values['subject'] ?? '';
      info.keywords = values['keywords'] ?? '';
      info.creator = values['creator'] ?? '';
      info.producer = values['producer'] ?? '';
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> resizePages(String path, Size size) async {
    final src = _open(path);
    final out = PdfDocument();
    try {
      final targetW = size.width;
      final targetH = size.height;
      for (var i = 0; i < src.pages.count; i++) {
        final page = src.pages[i];
        final srcW = page.size.width;
        final srcH = page.size.height;
        out.pageSettings.size = size;
        final newPage = out.pages.add();
        final scale = math.min(targetW / srcW, targetH / srcH);
        final w = srcW * scale;
        final h = srcH * scale;
        newPage.graphics.drawPdfTemplate(
          page.createTemplate(),
          Offset((targetW - w) / 2, (targetH - h) / 2),
          Size(w, h),
        );
      }
      final bytes = await out.save();
      return Uint8List.fromList(bytes);
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  Future<Uint8List> flatten(String path) async {
    final doc = _open(path);
    try {
      final form = doc.form;
      form.flattenAllFields();
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  // ── Security ────────────────────────────────────────────────────
  Future<Uint8List> passwordProtect(
    String path, {
    required String userPassword,
    String? ownerPassword,
    String algorithm = 'aes256',
  }) async {
    final doc = _open(path);
    try {
      final security = doc.security;
      security.userPassword = userPassword;
      security.ownerPassword = ownerPassword ?? userPassword;
      security.algorithm = switch (algorithm) {
        'aes128' => PdfEncryptionAlgorithm.aesx128Bit,
        'rc4' => PdfEncryptionAlgorithm.rc4x128Bit,
        _ => PdfEncryptionAlgorithm.aesx256Bit,
      };
      security.permissions.addAll([
        PdfPermissionsFlags.print,
        PdfPermissionsFlags.fullQualityPrint,
        PdfPermissionsFlags.copyContent,
        PdfPermissionsFlags.accessibilityCopyContent,
      ]);
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> unlock(String path, String password) async {
    final src = _open(path, password: password);
    final out = PdfDocument();
    try {
      for (var i = 0; i < src.pages.count; i++) {
        final page = src.pages[i];
        final newPage = out.pages.add();
        newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero, newPage.getClientSize());
      }
      final bytes = await out.save();
      return Uint8List.fromList(bytes);
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  // ── Text / forms ────────────────────────────────────────────────
  Future<String> extractText(String path, {String? password}) async {
    final doc = _open(path, password: password);
    try {
      return PdfTextExtractor(doc).extractText();
    } finally {
      doc.dispose();
    }
  }

  Future<List<FormFieldInfo>> getFormFields(String path) async {
    final doc = _open(path);
    try {
      final form = doc.form;
      final result = <FormFieldInfo>[];
      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        result.add(FormFieldInfo(
          name: field.name ?? '',
          type: _fieldType(field),
          value: _fieldValue(field),
          page: _fieldPage(field),
        ));
      }
      return result;
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> fillFormFields(String path, Map<String, String> values, {bool flatten = false}) async {
    final doc = _open(path);
    try {
      final form = doc.form;
      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        if (!values.containsKey(field.name)) continue;
        final v = values[field.name] ?? '';
        if (field is PdfTextBoxField) {
          field.text = v;
        } else if (field is PdfCheckBoxField) {
          field.isChecked = v.toLowerCase() == 'true' || v == '1' || v.toLowerCase() == 'on';
        } else if (field is PdfComboBoxField) {
          if (_itemContains(field, v)) field.selectedValue = v;
        } else if (field is PdfListBoxField) {
          final sel = v.split(',').where((x) => _itemContains(field, x)).toList();
          if (sel.isNotEmpty) field.selectedValues = sel;
        }
      }
      if (flatten) form.flattenAllFields();
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> createTextFields(
    String path,
    List<({String name, int page, double x, double y, double w, double h, String value})> fields,
  ) async {
    final doc = _open(path);
    try {
      for (final f in fields) {
        final page = _pageSafe(doc, f.page);
        final field = PdfTextBoxField(
          page,
          f.name,
          Rect.fromLTWH(f.x, f.y, f.w, f.h),
          text: f.value,
        );
        doc.form.fields.add(field);
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  // ── OCR text layer ──────────────────────────────────────────────
  Future<Uint8List> addOcrTextLayer(String path, List<PageOcrData> pages) async {
    final doc = _open(path);
    try {
      final invisible = PdfSolidBrush(PdfColor(0, 0, 0, 0));
      for (final data in pages) {
        if (data.page < 1 || data.page > doc.pages.count) continue;
        final page = doc.pages[data.page - 1];
        for (final word in data.words) {
          final size = word.h.clamp(4.0, 200.0);
          final wfont = PdfStandardFont(PdfFontFamily.helvetica, size);
          page.graphics.drawString(
            word.text,
            wfont,
            brush: invisible,
            bounds: Rect.fromLTWH(word.x, word.y, word.w + 4, size + 2),
            format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.top),
          );
        }
      }
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  // ── helpers ─────────────────────────────────────────────────────
  PdfPage _pageSafe(PdfDocument doc, int pageNo) {
    final idx = pageNo.clamp(1, doc.pages.count) - 1;
    return doc.pages[idx];
  }

  PdfColor _color(int rgb, {int alpha = 255}) {
    return PdfColor(alpha, (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
  }

  double _textWidth(String text, PdfFont font) {
    // Helvetica average char width ≈ 0.55 * size.
    return text.length * font.size * 0.55;
  }

  Offset _alignmentPosition(String alignment, Size page, double w, double h) {
    final pad = 36.0;
    final dx = switch (alignment) {
      'bottom-right' || 'top-right' => page.width - w - pad,
      'bottom-left' || 'top-left' => pad,
      _ => (page.width - w) / 2,
    };
    final dy = alignment.startsWith('top') ? pad : page.height - h - pad;
    return Offset(dx, dy);
  }

  Offset _stampPosition(String position, Size page, double w, double h) {
    final pad = 40.0;
    final dx = switch (position) {
      'top-right' || 'bottom-right' => page.width - w - pad,
      'center' => (page.width - w) / 2,
      'bottom-left' || 'top-left' => pad,
      'top-center' || 'bottom-center' => (page.width - w) / 2,
      _ => page.width - w - pad,
    };
    final dy = switch (position) {
      'top-left' || 'top-right' || 'top-center' => pad,
      'center' => page.height / 2 - h / 2,
      'bottom-left' || 'bottom-right' || 'bottom-center' => page.height - h - pad,
      _ => pad,
    };
    return Offset(dx, dy);
  }

  String _fieldType(PdfField field) {
    if (field is PdfTextBoxField) return 'text';
    if (field is PdfCheckBoxField) return 'checkbox';
    if (field is PdfComboBoxField) return 'combobox';
    if (field is PdfListBoxField) return 'listbox';
    if (field is PdfButtonField) return 'button';
    return 'other';
  }

  String _fieldValue(PdfField field) {
    if (field is PdfTextBoxField) return field.text;
    if (field is PdfCheckBoxField) return field.isChecked ? 'true' : 'false';
    if (field is PdfComboBoxField) return field.selectedValue;
    if (field is PdfListBoxField) return field.selectedValues.join(', ');
    return '';
  }

  bool _itemContains(dynamic field, String v) {
    if (field is PdfComboBoxField || field is PdfListBoxField) {
      final items = (field as dynamic).items as PdfListFieldItemCollection;
      for (var i = 0; i < items.count; i++) {
        if (items[i].text == v) return true;
      }
    }
    return false;
  }

  int _fieldPage(PdfField field) {
    try {
      return field.page != null ? 1 : 0;
    } catch (_) {
      return 0;
    }
  }
}

// Local helper for the repair method.
List<int> asciiCodes(String s) => s.codeUnits;
