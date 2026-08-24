import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../core/utils/file_utils.dart';
import '../tools/run_output.dart';
import 'services/pdf_service.dart';

/// Select regions (or search text) to black out, then write the redacted PDF.
class PdfRedactPage extends ConsumerStatefulWidget {
  const PdfRedactPage({super.key, required this.inputPath, required this.onDone});

  final String inputPath;
  final ValueChanged<String> onDone;

  @override
  ConsumerState<PdfRedactPage> createState() => _PdfRedactPageState();
}

class _PdfRedactPageState extends ConsumerState<PdfRedactPage> {
  late pdfx.PdfDocument _doc;
  int _pageNo = 1;
  int _pageCount = 1;
  Uint8List? _pageImage;
  double _scale = 1;
  double _aspect = 1.414;
  final List<Map<String, dynamic>> _rects = []; // {page, rect(pixels)}
  Offset? _dragStart;
  Offset? _dragEnd;
  bool _dragging = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _doc = await pdfx.PdfDocument.openFile(widget.inputPath);
    _pageCount = _doc.pagesCount;
    await _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    setState(() {
      _pageNo = page;
      _pageImage = null;
    });
    final p = await _doc.getPage(page);
    final width = 1400.0;
    final height = width * (p.height / p.width);
    final img = await p.render(
      width: width,
      height: height,
      format: pdfx.PdfPageImageFormat.png,
      backgroundColor: '#FFFFFF',
    );
    await p.close();
    if (mounted) {
      setState(() {
        _pageImage = img?.bytes;
        _scale = p.width / width;
        _aspect = width / height;
      });
    }
  }

  Future<void> _searchText() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find & redact text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. John Doe'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Redact'),
          ),
        ],
      ),
    );
    if (query == null || query.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await runInIsolate(() => PdfService().redactText(widget.inputPath, query));
      final runDir = await newRunDir();
      final path = await writeRunFile(
        runDir,
        '${baseNameWithoutExt(widget.inputPath)}_redacted.pdf',
        bytes,
      );
      if (!mounted) return;
      await _doc.close();
      widget.onDone(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _finish() async {
    if (_rects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drag over the areas to redact')));
      return;
    }
    setState(() => _busy = true);
    try {
      final ops = [
        for (final r in _rects)
          RedactRectOp(
            page: r['page'] as int,
            x: (r['rect'] as Rect).left * _scale,
            y: (r['rect'] as Rect).top * _scale,
            w: (r['rect'] as Rect).width * _scale,
            h: (r['rect'] as Rect).height * _scale,
          ),
      ];
      final bytes = await runInIsolate(() => PdfService().redactRects(widget.inputPath, ops));
      final runDir = await newRunDir();
      final path = await writeRunFile(
        runDir,
        '${baseNameWithoutExt(widget.inputPath)}_redacted.pdf',
        bytes,
      );
      if (!mounted) return;
      await _doc.close();
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
        title: Text('Redact · page $_pageNo/$_pageCount'),
        actions: [
          IconButton(
            tooltip: 'Undo last',
            onPressed: () => setState(() {
              if (_rects.isNotEmpty) _rects.removeLast();
            }),
            icon: const Icon(Icons.undo),
          ),
          if (_pageNo > 1)
            IconButton(onPressed: () => _loadPage(_pageNo - 1), icon: const Icon(Icons.chevron_left)),
          if (_pageNo < _pageCount)
            IconButton(onPressed: () => _loadPage(_pageNo + 1), icon: const Icon(Icons.chevron_right)),
          IconButton(tooltip: 'Redact text occurrences', onPressed: _searchText, icon: const Icon(Icons.manage_search)),
          TextButton(
            onPressed: _busy ? null : _finish,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Apply'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Drag over content to black it out',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: _pageImage == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: AspectRatio(
                      aspectRatio: _aspect,
                      child: GestureDetector(
                        onPanStart: (d) => setState(() {
                          _dragging = true;
                          _dragStart = d.localPosition;
                          _dragEnd = d.localPosition;
                        }),
                        onPanUpdate: (d) => setState(() => _dragEnd = d.localPosition),
                        onPanEnd: (_) => setState(() {
                          _dragging = false;
                          final start = _dragStart;
                          final end = _dragEnd;
                          if (start != null && end != null) {
                            final r = Rect.fromPoints(start, end);
                            if (r.width > 10 && r.height > 10) {
                              _rects.add({'page': _pageNo, 'rect': r});
                            }
                          }
                          _dragStart = null;
                          _dragEnd = null;
                        }),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_pageImage!, fit: BoxFit.fill),
                            CustomPaint(
                              painter: _RedactPainter(
                                rects: _rects,
                                page: _pageNo,
                                dragRect: _dragging && _dragStart != null && _dragEnd != null
                                    ? Rect.fromPoints(_dragStart!, _dragEnd!)
                                    : null,
                              ),
                              size: Size.infinite,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RedactPainter extends CustomPainter {
  const _RedactPainter({required this.rects, required this.page, this.dragRect});

  final List<Map<String, dynamic>> rects;
  final int page;
  final Rect? dragRect;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    for (final r in rects) {
      if (r['page'] != page) continue;
      canvas.drawRect(r['rect'] as Rect, paint);
    }
    if (dragRect != null) {
      canvas.drawRect(dragRect!, Paint()..color = Colors.red.withValues(alpha: 0.4));
    }
  }

  @override
  bool shouldRepaint(covariant _RedactPainter old) => true;
}
