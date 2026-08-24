import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:signature/signature.dart';

import '../../core/utils/file_utils.dart';
import '../tools/run_output.dart';
import 'services/pdf_service.dart';

class PdfSignPage extends ConsumerStatefulWidget {
  const PdfSignPage({super.key, required this.inputPath, required this.onDone});

  final String inputPath;
  final ValueChanged<String> onDone;

  @override
  ConsumerState<PdfSignPage> createState() => _PdfSignPageState();
}

class _PdfSignPageState extends ConsumerState<PdfSignPage> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  late pdfx.PdfDocument _doc;
  int _pageCount = 1;
  int _pageNo = 1;
  Uint8List? _pageImage;
  double _aspect = 1.414;
  double _scale = 1;

  double _sigW = 150; // signature width in PDF points
  Offset? _sigPos; // center position in screen px

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
      _sigPos = null;
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

  Future<void> _apply() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draw your signature first')));
      return;
    }
    if (_sigPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tap the page to place the signature')));
      return;
    }
    setState(() => _busy = true);
    try {
      final png = await _controller.toPngBytes();
      final pos = _sigPos!;
      final bytes = await runInIsolate(
        () => PdfService().addSignatureImage(
          widget.inputPath,
          SignaturePlacement(
            pngBytes: png!,
            page: _pageNo,
            x: pos.dx * _scale - _sigW / 2,
            y: pos.dy * _scale - _sigW / 4,
            w: _sigW,
          ),
        ),
      );
      final runDir = await newRunDir();
      final path = await writeRunFile(
        runDir,
        '${baseNameWithoutExt(widget.inputPath)}_signed.pdf',
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
    final sigWpx = _sigW / _scale;
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign PDF · page $_pageNo/$_pageCount'),
        actions: [
          if (_pageNo > 1)
            IconButton(onPressed: () => _loadPage(_pageNo - 1), icon: const Icon(Icons.chevron_left)),
          if (_pageNo < _pageCount)
            IconButton(onPressed: () => _loadPage(_pageNo + 1), icon: const Icon(Icons.chevron_right)),
          TextButton(
            onPressed: _busy ? null : _apply,
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
              '1. Draw below  2. Tap the page to place',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 5,
            child: _pageImage == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: AspectRatio(
                      aspectRatio: _aspect,
                      child: GestureDetector(
                        onTapDown: (d) => setState(() => _sigPos = d.localPosition),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_pageImage!, fit: BoxFit.fill),
                            if (_sigPos != null && _sigPos != null)
                              Positioned(
                                left: _sigPos!.dx - sigWpx / 2,
                                top: _sigPos!.dy - sigWpx / 4,
                                width: sigWpx,
                                height: sigWpx / 2,
                                child: const Icon(Icons.draw, color: Colors.red),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Signature(
                          controller: _controller,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => _controller.clear(),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                      ),
                      TextButton.icon(
                        onPressed: () => _controller.undo(),
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
