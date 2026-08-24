import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../core/utils/file_utils.dart';
import '../tools/run_output.dart';
import 'services/pdf_service.dart';

enum DrawTool { pen, line, rect, ellipse, text }

class PdfAnnotatePage extends ConsumerStatefulWidget {
  const PdfAnnotatePage({super.key, required this.inputPath, required this.onDone});

  final String inputPath;
  final ValueChanged<String> onDone;

  @override
  ConsumerState<PdfAnnotatePage> createState() => _PdfAnnotatePageState();
}

class _PdfAnnotatePageState extends ConsumerState<PdfAnnotatePage> {
  late pdfx.PdfDocument _doc;
  int _pageNo = 1;
  int _pageCount = 1;
  Uint8List? _pageImage;
  double _scale = 1;
  double _aspect = 1.414;

  DrawTool _tool = DrawTool.pen;
  int _colorRgb = 0xD32F2F;
  double _widthPx = 4;

  final List<Map<String, dynamic>> _strokes = [];
  List<Offset> _currentStroke = [];
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
      _strokes.clear();
      _currentStroke = [];
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

  Future<void> _finish() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing drawn yet')));
      return;
    }
    setState(() => _busy = true);
    try {
      final ops = <Object>[];
      for (final s in _strokes) {
        final page = (s['p'] as int?) ?? 1;
        final c = (s['c'] as int?) ?? _colorRgb;
        final w = (s['w'] as double?) ?? _widthPx;
        final pts = (s['points'] as List<Offset>);
        switch (s['tool'] as DrawTool) {
          case DrawTool.pen:
            if (pts.length < 2) break;
            ops.add(DrawPathOp(
              page: page,
              points: [
                for (final pt in pts)
                  [(pt.dx * _scale).roundToDouble(), (pt.dy * _scale).roundToDouble()],
              ],
              width: w * _scale * 1.5,
              colorRgb: c,
            ));
            break;
          case DrawTool.line:
            ops.add(DrawLineOp(
              page: page,
              x1: pts[0].dx * _scale, y1: pts[0].dy * _scale,
              x2: pts[1].dx * _scale, y2: pts[1].dy * _scale,
              width: w * _scale * 1.5, colorRgb: c,
            ));
            break;
          case DrawTool.rect:
            final r = Rect.fromPoints(pts[0], pts[1]);
            ops.add(DrawRectOp(
              page: page,
              x: r.left * _scale, y: r.top * _scale,
              w: r.width * _scale, h: r.height * _scale,
              width: w * _scale * 1.5, colorRgb: c,
            ));
            break;
          case DrawTool.ellipse:
            final r = Rect.fromPoints(pts[0], pts[1]);
            ops.add(DrawEllipseOp(
              page: page,
              x: r.left * _scale, y: r.top * _scale,
              w: r.width * _scale, h: r.height * _scale,
              width: w * _scale * 1.5, colorRgb: c,
            ));
            break;
          case DrawTool.text:
            ops.add(DrawTextOp(
              page: page,
              text: (s['text'] as String?) ?? '',
              x: pts.first.dx * _scale,
              y: pts.first.dy * _scale,
              size: (s['size'] as double?) ?? 14,
              colorRgb: c,
            ));
            break;
        }
      }
      final bytes = await runInIsolate(() => PdfService().applyDrawOps(widget.inputPath, ops));
      final runDir = await newRunDir();
      final path = await writeRunFile(
        runDir,
        '${baseNameWithoutExt(widget.inputPath)}_annotated.pdf',
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
        title: Text('Annotate · page $_pageNo/$_pageCount'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: () => setState(() {
              if (_strokes.isNotEmpty) _strokes.removeLast();
            }),
            icon: const Icon(Icons.undo),
          ),
          if (_pageNo > 1)
            IconButton(onPressed: () => _loadPage(_pageNo - 1), icon: const Icon(Icons.chevron_left)),
          if (_pageNo < _pageCount)
            IconButton(onPressed: () => _loadPage(_pageNo + 1), icon: const Icon(Icons.chevron_right)),
          TextButton(
            onPressed: _busy ? null : _finish,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _pageImage == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: AspectRatio(
                      aspectRatio: _aspect,
                      child: GestureDetector(
                        onPanStart: (d) => setState(() {
                          _currentStroke = [d.localPosition];
                        }),
                        onPanUpdate: (d) => setState(() {
                          if (_tool == DrawTool.pen) {
                            _currentStroke.add(d.localPosition);
                          } else {
                            _currentStroke = [_currentStroke.first, d.localPosition];
                          }
                        }),
                        onPanEnd: (_) => setState(() {
                          if (_currentStroke.length >= 2 && _tool != DrawTool.pen) {
                            _strokes.add({
                              'tool': _tool,
                              'points': List.of(_currentStroke),
                              'w': _widthPx,
                              'c': _colorRgb,
                              'p': _pageNo,
                            });
                          } else if (_tool == DrawTool.pen && _currentStroke.length >= 2) {
                            _strokes.add({
                              'tool': DrawTool.pen,
                              'points': List.of(_currentStroke),
                              'w': _widthPx,
                              'c': _colorRgb,
                              'p': _pageNo,
                            });
                          }
                          _currentStroke = [];
                        }),
                        onTapUp: (d) async {
                          if (_tool != DrawTool.text) return;
                          final controller = TextEditingController();
                          final text = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Add text'),
                              content: TextField(controller: controller, autofocus: true),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, controller.text),
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                          );
                          if (text == null || text.isEmpty) return;
                          setState(() {
                            _strokes.add({
                              'tool': DrawTool.text,
                              'points': [d.localPosition],
                              'w': _widthPx,
                              'c': _colorRgb,
                              'size': _widthPx * 3.5,
                              'text': text,
                              'p': _pageNo,
                            });
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_pageImage!, fit: BoxFit.fill),
                            CustomPaint(
                              painter: _StrokesPainter(
                                strokes: _strokes,
                                current: _currentStroke,
                                color: _colorRgb,
                                width: _widthPx,
                                tool: _tool,
                              ),
                              size: Size.infinite,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          _ToolBar(
            tool: _tool,
            color: _colorRgb,
            width: _widthPx,
            onTool: (t) => setState(() => _tool = t),
            onColor: (c) => setState(() => _colorRgb = c),
            onWidth: (w) => setState(() => _widthPx = w),
          ),
        ],
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({
    required this.tool,
    required this.color,
    required this.width,
    required this.onTool,
    required this.onColor,
    required this.onWidth,
  });

  final DrawTool tool;
  final int color;
  final double width;
  final ValueChanged<DrawTool> onTool;
  final ValueChanged<int> onColor;
  final ValueChanged<double> onWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (final t in DrawTool.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Icon(_toolIcon(t), size: 20),
                        selected: tool == t,
                        onSelected: (_) => onTool(t),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final c in const [0xD32F2F, 0x1565C0, 0x1B5E20, 0x000000, 0xF57C00])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onColor(c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(0xFF000000 | c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == c
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => onWidth((width - 2).clamp(2, 24)),
                  ),
                  Text('${width.round()}px'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => onWidth((width + 2).clamp(2, 24)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _toolIcon(DrawTool t) => switch (t) {
        DrawTool.pen => Icons.edit,
        DrawTool.line => Icons.remove,
        DrawTool.rect => Icons.rectangle_outlined,
        DrawTool.ellipse => Icons.circle_outlined,
        DrawTool.text => Icons.title,
      };
}

class _StrokesPainter extends CustomPainter {
  const _StrokesPainter({
    required this.strokes,
    required this.current,
    required this.color,
    required this.width,
    required this.tool,
  });

  final List<Map<String, dynamic>> strokes;
  final List<Offset> current;
  final int color;
  final double width;
  final DrawTool tool;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final c = Color(0xFF000000 | (s['c'] as int? ?? color));
      final w = (s['w'] as double?) ?? width;
      final pts = (s['points'] as List<Offset>? ?? []);
      final t = s['tool'] as DrawTool? ?? DrawTool.pen;
      final p = Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      switch (t) {
        case DrawTool.pen:
          if (pts.length < 2) break;
          final path = Path()..moveTo(pts.first.dx, pts.first.dy);
          for (final pt in pts.skip(1)) {
            path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path, p);
          break;
        case DrawTool.line:
          if (pts.length == 2) canvas.drawLine(pts[0], pts[1], p);
          break;
        case DrawTool.rect:
          if (pts.length == 2) canvas.drawRect(Rect.fromPoints(pts[0], pts[1]), p);
          break;
        case DrawTool.ellipse:
          if (pts.length == 2) canvas.drawOval(Rect.fromPoints(pts[0], pts[1]), p);
          break;
        case DrawTool.text:
          final tp = TextPainter(
            text: TextSpan(
              text: s['text'] as String? ?? '',
              style: TextStyle(
                color: c,
                fontSize: (s['size'] as double?) ?? 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, pts.isEmpty ? Offset.zero : pts.first);
          break;
      }
    }

    if (current.length >= 2) {
      final p = Paint()
        ..color = Color(0xFF000000 | color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (tool == DrawTool.pen) {
        final path = Path()..moveTo(current.first.dx, current.first.dy);
        for (final pt in current.skip(1)) {
          path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path, p);
      } else if (tool == DrawTool.line) {
        canvas.drawLine(current.first, current.last, p);
      } else if (tool == DrawTool.rect) {
        canvas.drawRect(Rect.fromPoints(current.first, current.last), p);
      } else if (tool == DrawTool.ellipse) {
        canvas.drawOval(Rect.fromPoints(current.first, current.last), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter old) => true;
}
