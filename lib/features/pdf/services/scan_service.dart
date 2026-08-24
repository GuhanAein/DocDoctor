import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

class ScanQuad {
  const ScanQuad({required this.topLeft, required this.topRight, required this.bottomLeft, required this.bottomRight});

  final img.Point topLeft;
  final img.Point topRight;
  final img.Point bottomLeft;
  final img.Point bottomRight;
}

/// Pure-Dart document edge detection + perspective correction. Isolate-safe.
class ScanService {
  /// Detects the largest roughly-quadrilateral region (assumed to be the
  /// document) and returns its corners in full-image coordinates.
  ScanQuad? detectDocument(Uint8List jpegBytes) {
    final full = img.decodeJpg(jpegBytes);
    if (full == null) return null;
    final small = img.copyResize(full, width: 320, interpolation: img.Interpolation.linear);
    final gray = img.grayscale(small);
    final edges = img.sobel(gray);

    // Collect edge points above a high threshold.
    final points = <img.Point>[];
    var maxMag = 1;
    for (var y = 0; y < edges.height; y++) {
      for (var x = 0; x < edges.width; x++) {
        final p = edges.getPixel(x, y);
        final mag = (p.r + p.g + p.b) ~/ 3;
        if (mag > maxMag) maxMag = mag;
        points.add(img.Point(x, y));
      }
    }
    final threshold = (maxMag * 0.55).clamp(30, 200);
    final edgePts = <img.Point>[];
    for (var y = 0; y < edges.height; y++) {
      for (var x = 0; x < edges.width; x++) {
        final p = edges.getPixel(x, y);
        final mag = (p.r + p.g + p.b) ~/ 3;
        if (mag >= threshold) edgePts.add(img.Point(x, y));
      }
    }
    if (edgePts.length < 40) return null;

    final w = small.width;
    final h = small.height;
    final diag = math.sqrt(w * w + h * h);

    // Hough transform.
    const nTheta = 180;
    final nRho = (diag * 2).ceil();
    final accumulator = List<int>.filled(nTheta * nRho, 0);
    final cosTable = List<double>.generate(nTheta, (t) => math.cos(t * math.pi / 180));
    final sinTable = List<double>.generate(nTheta, (t) => math.sin(t * math.pi / 180));
    for (final pt in edgePts) {
      for (var t = 0; t < nTheta; t++) {
        final rho = pt.x * cosTable[t] + pt.y * sinTable[t];
        final r = (rho + diag).round().clamp(0, nRho - 1);
        accumulator[t * nRho + r]++;
      }
    }

    // Find dominant line in each angular bucket.
    final bestLine = List<({double theta, double rho, int votes})?>.generate(nTheta, (_) => null);
    for (var t = 0; t < nTheta; t++) {
      var bestVotes = 0;
      var bestR = 0;
      for (var r = 0; r < nRho; r++) {
        final v = accumulator[t * nRho + r];
        if (v > bestVotes) {
          bestVotes = v;
          bestR = r;
        }
      }
      if (bestVotes > 0) {
        bestLine[t] = (theta: t.toDouble(), rho: bestR - diag, votes: bestVotes);
      }
    }

    ({double theta, double rho, int votes})? topLine;
    ({double theta, double rho, int votes})? bottomLine;
    ({double theta, double rho, int votes})? leftLine;
    ({double theta, double rho, int votes})? rightLine;

    for (var t = 0; t < nTheta; t++) {
      final line = bestLine[t];
      if (line == null) continue;
      final theta = t * math.pi / 180;
      final isHorizontalish = (math.sin(theta).abs() < 0.35); // near 0/180
      final isVerticalish = (math.cos(theta).abs() < 0.35);   // near 90
      if (isHorizontalish) {
        final rho = line.rho;
        final tL = topLine;
        final bL = bottomLine;
        if (tL == null || rho < tL.rho - 10) topLine = line;
        if (bL == null || rho > bL.rho + 10) bottomLine = line;
      } else if (isVerticalish) {
        final rho = line.rho;
        final lL = leftLine;
        final rL = rightLine;
        if (lL == null || rho < lL.rho - 10) leftLine = line;
        if (rL == null || rho > rL.rho + 10) rightLine = line;
      }
    }

        final tL = topLine;
    final bL = bottomLine;
    final lL = leftLine;
    final rL = rightLine;
    if (tL == null || bL == null || lL == null || rL == null) {
      return null;
    }

    // Intersections.
    final tl = _intersect(tL, lL);
    final tr = _intersect(tL, rL);
    final bl = _intersect(bL, lL);
    final br = _intersect(bL, rL);
    if (tl == null || tr == null || bl == null || br == null) return null;

    // Validate.
    double area(List<img.Point> q) {
      var a = 0.0;
      for (var i = 0; i < 4; i++) {
        final p1 = q[i];
        final p2 = q[(i + 1) % 4];
        a += p1.x * p2.y - p2.x * p1.y;
      }
      return a.abs() / 2;
    }

    final quad = [tl, tr, br, bl];
    final areaFrac = area(quad) / (w * h);
    if (areaFrac < 0.15 || areaFrac > 0.98) return null;

    final sx = full.width / w;
    final sy = full.height / h;
    img.Point scalePt(img.Point p) => img.Point((p.x * sx).round(), (p.y * sy).round());

    // Normalize corner order.
    var a = scalePt(tl);
    var b = scalePt(tr);
    var c = scalePt(br);
    var d = scalePt(bl);
    // Sort by y, then x to be safe.
    final pts = [a, b, c, d];
    pts.sort((p1, p2) => p1.y == p2.y ? p1.x.compareTo(p2.x) : p1.y.compareTo(p2.y));
    final topLeft = pts[0].x < pts[1].x ? pts[0] : pts[1];
    final topRight = pts[0].x < pts[1].x ? pts[1] : pts[0];
    final bottomLeft = pts[2].x < pts[3].x ? pts[2] : pts[3];
    final bottomRight = pts[2].x < pts[3].x ? pts[3] : pts[2];

    return ScanQuad(
      topLeft: topLeft,
      topRight: topRight,
      bottomLeft: bottomLeft,
      bottomRight: bottomRight,
    );
  }

  img.Point? _intersect(
    ({double theta, double rho, int votes}) l1,
    ({double theta, double rho, int votes}) l2,
  ) {
    final a1 = math.cos(l1.theta);
    final b1 = math.sin(l1.theta);
    final a2 = math.cos(l2.theta);
    final b2 = math.sin(l2.theta);
    final det = a1 * b2 - a2 * b1;
    if (det.abs() < 1e-6) return null;
    final x = (l1.rho * b2 - l2.rho * b1) / det;
    final y = (a1 * l2.rho - a2 * l1.rho) / det;
    return img.Point(x.round(), y.round());
  }

  /// Warps the document region to a flat rectangle and enhances contrast.
  Uint8List rectify(Uint8List jpegBytes, ScanQuad quad, {bool enhance = true}) {
    final full = img.decodeJpg(jpegBytes);
    if (full == null) return jpegBytes;

    img.Point clampPt(img.Point p) => img.Point(
          p.x.clamp(0, full.width - 1),
          p.y.clamp(0, full.height - 1),
        );

    final w1 = (quad.topRight.x - quad.topLeft.x).abs();
    final w2 = (quad.bottomRight.x - quad.bottomLeft.x).abs();
    final h1 = (quad.bottomLeft.y - quad.topLeft.y).abs();
    final h2 = (quad.bottomRight.y - quad.topRight.y).abs();
    final outW = ((w1 + w2) / 2).round().clamp(100, 2400);
    final outH = ((h1 + h2) / 2).round().clamp(100, 3200);

    var warped = img.copyRectify(
      full,
      topLeft: clampPt(quad.topLeft),
      topRight: clampPt(quad.topRight),
      bottomLeft: clampPt(quad.bottomLeft),
      bottomRight: clampPt(quad.bottomRight),
      interpolation: img.Interpolation.linear,
    );
    if (warped.width != outW || warped.height != outH) {
      warped = img.copyResize(warped, width: outW, height: outH, interpolation: img.Interpolation.linear);
    }

    if (enhance) {
      final gray = img.grayscale(warped);
      warped = img.adjustColor(gray, contrast: 1.25, saturation: 0, brightness: 0.02);
    }
    return Uint8List.fromList(img.encodeJpg(warped, quality: 88));
  }

  Uint8List enhancePhoto(Uint8List jpegBytes) {
    final full = img.decodeJpg(jpegBytes);
    if (full == null) return jpegBytes;
    final gray = img.grayscale(full);
    final enhanced = img.adjustColor(gray, contrast: 1.3, brightness: 0.03);
    return Uint8List.fromList(img.encodeJpg(enhanced, quality: 88));
  }
}

final scanServiceProvider = Provider<ScanService>((ref) => ScanService());
