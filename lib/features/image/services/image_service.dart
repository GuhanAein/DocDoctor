import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Pure-Dart image engine (package:image). Isolate-safe.
class ImageService {
  Future<Uint8List> compress(
    String path, {
    int quality = 70,
    int? maxWidth,
    String format = 'jpg',
  }) async {
    final bytes = await File(path).readAsBytes();
    var decoded = _decode(bytes);
    if (decoded == null) throw Exception('Unsupported image');
    decoded = img.bakeOrientation(decoded);
    if (maxWidth != null && decoded.width > maxWidth) {
      decoded = img.copyResize(decoded, width: maxWidth);
    }
    return switch (format) {
      'png' => Uint8List.fromList(img.encodePng(decoded, level: 6)),
      'bmp' => Uint8List.fromList(img.encodeBmp(decoded)),
      _ => Uint8List.fromList(img.encodeJpg(decoded, quality: quality)),
    };
  }

  Future<Uint8List> resize(String path, {int? width, int? height}) async {
    final bytes = await File(path).readAsBytes();
    final raw = _decode(bytes);
    if (raw == null) throw Exception('Unsupported image');
    final img.Image decoded = img.bakeOrientation(raw);
    if (width == null && height == null) return bytes;
    final w = width ?? (decoded.width * (height! / decoded.height)).round();
    final h = height ?? (decoded.height * (w / decoded.width)).round();
    final resized = img.copyResize(decoded, width: w, height: h);
    return _encodeLike(bytes, resized);
  }

  Future<Uint8List> crop(String path, int x, int y, int w, int h) async {
    final bytes = await File(path).readAsBytes();
    var decoded = _decode(bytes);
    if (decoded == null) throw Exception('Unsupported image');
    decoded = img.bakeOrientation(decoded);
    final cropped = img.copyCrop(
      decoded,
      x: x.clamp(0, decoded.width - 1),
      y: y.clamp(0, decoded.height - 1),
      width: w.clamp(1, decoded.width),
      height: h.clamp(1, decoded.height),
    );
    return _encodeLike(bytes, cropped);
  }

  Future<Uint8List> rotate(String path, {required String mode}) async {
    final bytes = await File(path).readAsBytes();
    var decoded = _decode(bytes);
    if (decoded == null) throw Exception('Unsupported image');
    decoded = img.bakeOrientation(decoded);
    final rotated = switch (mode) {
      '90' => img.copyRotate(decoded, angle: 90),
      '180' => img.copyRotate(decoded, angle: 180),
      '270' => img.copyRotate(decoded, angle: 270),
      'flipH' => img.flipHorizontal(decoded),
      'flipV' => img.flipVertical(decoded),
      _ => decoded,
    };
    return _encodeLike(bytes, rotated);
  }

  Future<Uint8List> convert(String path, String format, {int quality = 85}) async {
    final bytes = await File(path).readAsBytes();
    var decoded = _decode(bytes);
    if (decoded == null) throw Exception('Unsupported image');
    decoded = img.bakeOrientation(decoded);
    return switch (format) {
      'jpg' => Uint8List.fromList(img.encodeJpg(decoded, quality: quality)),
      'png' => Uint8List.fromList(img.encodePng(decoded)),
      'bmp' => Uint8List.fromList(img.encodeBmp(decoded)),
      'gif' => Uint8List.fromList(img.encodeGif(decoded)),
      _ => throw Exception('Unsupported format'),
    };
  }

  Future<Uint8List> adjust(
    String path, {
    double brightness = 0,
    double contrast = 1,
    double saturation = 1,
    double sharpen = 0,
  }) async {
    final bytes = await File(path).readAsBytes();
    var decoded = _decode(bytes);
    if (decoded == null) throw Exception('Unsupported image');
    decoded = img.bakeOrientation(decoded);
    var out = img.adjustColor(
      decoded,
      brightness: brightness,
      saturation: saturation,
    );
    out = img.contrast(out, contrast: contrast * 100);
    if (sharpen > 0) {
      // Unsharp-mask style 3x3 convolution.
      final strength = 1 + sharpen * 4;
      final center = 5 * strength - 4 * strength / 5;
      out = img.convolution(out, filter: [
        0, -strength, 0,
        -strength, center, -strength,
        0, -strength, 0,
      ]);
    }
    return _encodeLike(bytes, out);
  }

  Future<Uint8List> grayscale(String path) async {
    final bytes = await File(path).readAsBytes();
    var decoded = _decode(bytes);
    if (decoded == null) throw Exception('Unsupported image');
    decoded = img.bakeOrientation(decoded);
    return _encodeLike(bytes, img.grayscale(decoded));
  }

  /// Composites a pre-rasterized watermark PNG (RGBA) onto the image.
  Future<Uint8List> watermarkWithPng(
    String path,
    Uint8List watermarkPng, {
    String position = 'center',
    double scale = 0.4,
    double opacity = 0.5,
    bool tiled = false,
  }) async {
    final bytes = await File(path).readAsBytes();
    final raw = _decode(bytes);
    if (raw == null) throw Exception('Unsupported image');
    final img.Image decoded = img.bakeOrientation(raw);
    final decodedMark = img.decodePng(watermarkPng);
    if (decodedMark == null) return bytes;
    final img.Image baseMark = img.bakeOrientation(decodedMark);
    final targetW = (decoded.width * scale).round().clamp(24, decoded.width);
    final markH = (targetW * (baseMark.height / baseMark.width)).round();
    final img.Image mark = img.copyResize(baseMark, width: targetW, height: markH);

    void drawAt(int x, int y) {
      for (var my = 0; my < mark.height; my++) {
        for (var mx = 0; mx < mark.width; mx++) {
          final dx = x + mx;
          final dy = y + my;
          if (dx < 0 || dy < 0 || dx >= decoded.width || dy >= decoded.height) continue;
          final mp = mark.getPixel(mx, my);
          if (mp.a == 0) continue;
          final dp = decoded.getPixel(dx, dy);
          final a = (mp.a / 255.0) * opacity;
          final r = (dp.r * (1 - a) + mp.r * a).round();
          final g = (dp.g * (1 - a) + mp.g * a).round();
          final b = (dp.b * (1 - a) + mp.b * a).round();
          decoded.setPixelRgba(dx, dy, r, g, b, 255);
        }
      }
    }

    if (tiled) {
      for (var y = 0; y < decoded.height; y += markH * 2) {
        for (var x = 0; x < decoded.width; x += mark.width * 2) {
          drawAt(x, y);
        }
      }
    } else {
      final x = switch (position) {
        'top-left' => 20,
        'top-right' => decoded.width - mark.width - 20,
        'bottom-left' => 20,
        'bottom-right' => decoded.width - mark.width - 20,
        _ => (decoded.width - mark.width) ~/ 2,
      };
      final y = switch (position) {
        'top-left' || 'top-right' => 20,
        'bottom-left' || 'bottom-right' => decoded.height - markH - 20,
        _ => (decoded.height - markH) ~/ 2,
      };
      drawAt(x, y);
    }
    return _encodeLike(bytes, decoded);
  }

  Future<Uint8List> collage(
    List<String> paths, {
    int cols = 2,
    String mode = 'grid',
  }) async {
    final images = <img.Image>[];
    for (final p in paths) {
      final bytes = await File(p).readAsBytes();
      final d = _decode(bytes);
      if (d == null) continue;
      images.add(img.bakeOrientation(d));
    }
    if (images.isEmpty) throw Exception('No valid images');
    final thumbW = 800;
    final thumbs = images.map((im) => img.copyResize(im, width: thumbW)).toList();
    if (mode == 'horizontal') {
      final h = thumbs.map((t) => t.height).reduce(math.max);
      final totalW = thumbs.map((t) => t.width).reduce((a, b) => a + b);
      final canvas = img.Image(width: totalW, height: h);
      var x = 0;
      for (final t in thumbs) {
        img.compositeImage(canvas, t, dstX: x, dstY: (h - t.height) ~/ 2);
        x += t.width;
      }
      return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
    }
    final rows = (thumbs.length / cols).ceil();
    final cellW = thumbW;
    final cellH = thumbs
        .map((t) => (t.height * (thumbW / t.width)).round())
        .reduce(math.max);
    final canvas = img.Image(width: cols * cellW, height: rows * cellH, numChannels: 3);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    for (var i = 0; i < thumbs.length; i++) {
      final t = thumbs[i];
      final r = i ~/ cols;
      final c = i % cols;
      final scaled = img.copyResize(
        t,
        width: cellW,
        height: cellH,
        interpolation: img.Interpolation.linear,
      );
      img.compositeImage(canvas, scaled, dstX: c * cellW, dstY: r * cellH);
    }
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
  }

  Future<Uint8List> border(
    String path, {
    int colorRgb = 0xFFFFFF,
    int thickness = 40,
  }) async {
    final bytes = await File(path).readAsBytes();
    var decoded = _decode(bytes);
    if (decoded == null) throw Exception('Unsupported image');
    decoded = img.bakeOrientation(decoded);
    final canvas = img.Image(
      width: decoded.width + thickness * 2,
      height: decoded.height + thickness * 2,
      numChannels: 3,
    );
    img.fill(canvas, color: _rgb8(colorRgb));
    img.compositeImage(canvas, decoded, dstX: thickness, dstY: thickness);
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
  }

  /// Photo layout sheets: grid of the same photo at exact print sizes,
  /// 300 dpi (10x15 cm photo = 1181x1772 px).
  Future<Uint8List> photoSheet(
    String path, {
    int sheetW = 2480,
    int sheetH = 3508, // A4 at 300dpi
    int photoW = 1181,
    int photoH = 1772,
    int cols = 2,
    int rows = 2,
  }) async {
    final bytes = await File(path).readAsBytes();
    var decoded = _decode(bytes);
    if (decoded == null) throw Exception('Unsupported image');
    decoded = img.bakeOrientation(decoded);
    final canvas = img.Image(width: sheetW, height: sheetH, numChannels: 3);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    final fit = img.copyResize(decoded, width: photoW, height: photoH);
    final gapX = math.max(0, (sheetW - cols * photoW) ~/ (cols + 1));
    final gapY = math.max(0, (sheetH - rows * photoH) ~/ (rows + 1));
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        img.compositeImage(
          canvas,
          fit,
          dstX: gapX + c * (photoW + gapX),
          dstY: gapY + r * (photoH + gapY),
        );
      }
    }
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
  }

  img.Image? _decode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  img.ColorRgb8 _rgb8(int rgb) =>
      img.ColorRgb8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);

  /// Encodes in the same family as the source format (detected by magic bytes).
  Uint8List _encodeLike(Uint8List sourceBytes, img.Image image) {
    final fmt = _fileFormat(sourceBytes);
    return switch (fmt) {
      'png' => Uint8List.fromList(img.encodePng(image)),
      'bmp' => Uint8List.fromList(img.encodeBmp(image)),
      'gif' => Uint8List.fromList(img.encodeGif(image)),
      _ => Uint8List.fromList(img.encodeJpg(image, quality: 92)),
    };
  }

  String _fileFormat(Uint8List b) {
    if (b.length < 12) return 'jpg';
    if (b[0] == 0x89 && b[1] == 0x50) return 'png';
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return 'gif';
    if (b[0] == 0x42 && b[1] == 0x4D) return 'bmp';
    if (b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'webp';
    }
    return 'jpg';
  }
}
