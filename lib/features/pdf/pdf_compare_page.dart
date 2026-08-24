import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'dart:ui' show Rect;

import '../../core/utils/file_utils.dart';
import '../tools/run_output.dart';

class PdfComparePage extends ConsumerStatefulWidget {
  const PdfComparePage({super.key, required this.inputs, required this.onDone});

  final List<String> inputs;
  final ValueChanged<String> onDone;

  @override
  ConsumerState<PdfComparePage> createState() => _PdfComparePageState();
}

class _PdfComparePageState extends ConsumerState<PdfComparePage> {
  List<({int page, double diff, Uint8List? image})> _diffs = [];
  bool _busy = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _compare();
  }

  Future<void> _compare() async {
    setState(() {
      _busy = true;
      _status = 'Rendering…';
    });
    try {
      final a = widget.inputs[0];
      final b = widget.inputs[1];
      final docA = await pdfx.PdfDocument.openFile(a);
      final docB = await pdfx.PdfDocument.openFile(b);
      final countA = docA.pagesCount;
      final countB = docB.pagesCount;
      final maxPages = math.max(countA, countB);
      final results = <({int page, double diff, Uint8List? image})>[];

      for (var p = 1; p <= maxPages; p++) {
        setState(() => _status = 'Comparing page $p/$maxPages…');
        if (p > countA || p > countB) {
          results.add((page: p, diff: 1.0, image: null));
          continue;
        }
        final pageA = await docA.getPage(p);
        final width = 1000.0;
        final heightA = width * (pageA.height / pageA.width);
        final imgA = await pageA.render(
          width: width,
          height: heightA,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        await pageA.close();
        final pageB = await docB.getPage(p);
        final heightB = width * (pageB.height / pageB.width);
        final imgB = await pageB.render(
          width: width,
          height: heightB,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        await pageB.close();
        if (imgA?.bytes == null || imgB?.bytes == null) {
          results.add((page: p, diff: 1.0, image: null));
          continue;
        }
        final decodedA = img.decodePng(imgA!.bytes);
        final decodedB = img.decodePng(imgB!.bytes);
        if (decodedA == null || decodedB == null) {
          results.add((page: p, diff: 1.0, image: null));
          continue;
        }
        final diffMap = await runInIsolate(() => _diff(decodedA, decodedB));
        results.add((page: p, diff: diffMap.$1, image: diffMap.$2));
      }
      await docA.close();
      await docB.close();
      if (mounted) {
        setState(() {
          _diffs = results;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Compare failed: $e';
        });
      }
    }
  }

  static (double, Uint8List) _diff(img.Image a, img.Image b) {
    final w = math.min(a.width, b.width);
    final h = math.min(a.height, b.height);
    final out = img.Image(width: w, height: h);
    var changed = 0;
    var total = 0;
    for (var y = 0; y < h; y += 1) {
      for (var x = 0; x < w; x += 1) {
        final pa = a.getPixel(x, y);
        final pb = b.getPixel(x, y);
        final d = ((pa.r - pb.r).abs() + (pa.g - pb.g).abs() + (pa.b - pb.b).abs()) / 3;
        total++;
        if (d > 24) {
          changed++;
          out.setPixelRgba(x, y, 255, 64, 64, 255);
        } else {
          final lum = ((pa.r + pa.g + pa.b) ~/ 3) ~/ 3;
          out.setPixelRgba(x, y, lum, lum, lum, 255);
        }
      }
    }
    final pct = total == 0 ? 0.0 : changed / total;
    final png = img.encodePng(out);
    return (pct, Uint8List.fromList(png));
  }

  Future<void> _buildReport() async {
    setState(() => _busy = true);
    try {
      final doc = sf.PdfDocument();
      final page = doc.pages.add();
      final g = page.graphics;
      const margin = 40.0;
      var y = margin;
      final titleFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 16);
      final bodyFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 11);
      final redFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 11);
      g.drawString(
        'PDF Comparison Report',
        titleFont,
        brush: sf.PdfBrushes.black,
        bounds: Rect.fromLTWH(margin, y, 500, 24),
      );
      y += 30;
      g.drawString(
        'A: ${widget.inputs[0].split('/').last}',
        bodyFont,
        brush: sf.PdfBrushes.black,
        bounds: Rect.fromLTWH(margin, y, 500, 16),
      );
      y += 18;
      g.drawString(
        'B: ${widget.inputs[1].split('/').last}',
        bodyFont,
        brush: sf.PdfBrushes.black,
        bounds: Rect.fromLTWH(margin, y, 500, 16),
      );
      y += 30;
      for (final d in _diffs) {
        g.drawString(
          'Page ${d.page}: ${(d.diff * 100).toStringAsFixed(1)}% changed',
          d.diff > 0.01 ? redFont : bodyFont,
          brush: d.diff > 0.01 ? sf.PdfSolidBrush(sf.PdfColor(255, 210, 40, 40)) : sf.PdfBrushes.black,
          bounds: Rect.fromLTWH(margin, y, 500, 16),
        );
        y += 18;
        if (y > 790) {
          doc.pages.add();
          y = margin;
        }
      }
      final bytes = await doc.save();
      doc.dispose();
      final runDir = await newRunDir();
      final path = await writeRunFile(runDir, 'compare_report.pdf', Uint8List.fromList(bytes));
      if (!mounted) return;
      widget.onDone(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare PDFs'),
        actions: [
          TextButton(
            onPressed: _busy || _diffs.isEmpty ? null : _buildReport,
            child: const Text('Save report'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _busy
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_status),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _diffs.length,
              itemBuilder: (context, i) {
                final d = _diffs[i];
                final pct = d.diff * 100;
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Icon(
                          pct < 1 ? Icons.check_circle_outline : Icons.warning_amber,
                          color: pct < 1 ? Colors.green : Colors.orange,
                        ),
                        title: Text('Page ${d.page}'),
                        subtitle: Text('${pct.toStringAsFixed(1)}% pixels differ'),
                      ),
                      if (d.image != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              d.image!,
                              height: 180,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
