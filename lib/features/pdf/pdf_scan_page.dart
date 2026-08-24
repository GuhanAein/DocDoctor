import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/permission_service.dart';
import '../../core/utils/file_utils.dart';
import '../tools/run_output.dart';
import 'services/pdf_raster_service.dart';
import 'services/scan_service.dart';

class PdfScanPage extends ConsumerStatefulWidget {
  const PdfScanPage({super.key, required this.onDone});

  final ValueChanged<String> onDone;

  @override
  ConsumerState<PdfScanPage> createState() => _PdfScanPageState();
}

class _PdfScanPageState extends ConsumerState<PdfScanPage> {
  CameraController? _camera;
  bool _initFailed = false;
  final List<Uint8List> _pages = [];
  Uint8List? _pending;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    final granted = await ref.read(permissionServiceProvider).ensureCamera();
    if (!granted) {
      setState(() => _initFailed = true);
      return;
    }
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (mounted) setState(() => _camera = controller);
    } catch (e) {
      if (mounted) {
        setState(() => _initFailed = true);
      }
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await camera.takePicture();
      final jpeg = await shot.readAsBytes();
      // Edge detection + perspective correction in an isolate.
      final quad = await runInIsolate(() => ScanService().detectDocument(jpeg));
      final Uint8List processed;
      if (quad != null) {
        processed = await runInIsolate(() => ScanService().rectify(jpeg, quad));
      } else {
        processed = await runInIsolate(() => ScanService().enhancePhoto(jpeg));
      }
      if (mounted) setState(() => _pending = processed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_pages.isEmpty) return;
    setState(() => _busy = true);
    try {
      final tmp = await newRunDir();
      final jpegs = <String>[];
      for (var i = 0; i < _pages.length; i++) {
        final f = await writeRunFile(tmp, 'scan_${i + 1}.jpg', _pages[i]);
        jpegs.add(f);
      }
      final bytes = await ref.read(pdfRasterServiceProvider).pdfFromImages(jpegs, pageSizeId: 'a4', quality: 88);
      final runDir = await newRunDir();
      final path = await writeRunFile(runDir, 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf', bytes);
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
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan to PDF (${_pages.length} page${_pages.length == 1 ? '' : 's'})'),
        actions: [
          if (_pages.isNotEmpty)
            TextButton(
              onPressed: _busy ? null : _finish,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Done'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _initFailed
          ? const Center(child: Text('Camera unavailable. Grant camera permission to scan.'))
          : camera == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(camera),
                          // Frame guide
                          Center(
                            child: FractionallySizedBox(
                              widthFactor: 0.82,
                              heightFactor: 0.7,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white70, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_pending != null)
                      Container(
                        height: 130,
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                              child: Image.memory(_pending!, height: 130, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Scanned page preview'),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => setState(() => _pending = null),
                                        child: const Text('Retake'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: () => setState(() {
                                          _pages.add(_pending!);
                                          _pending = null;
                                        }),
                                        child: const Text('Add page'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            if (_pages.isNotEmpty)
                              SizedBox(
                                height: 64,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: _pages.length,
                                  itemBuilder: (context, i) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.memory(_pages[i], height: 64, fit: BoxFit.cover),
                                        ),
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: InkWell(
                                            onTap: () => setState(() => _pages.removeAt(i)),
                                            child: const CircleAvatar(
                                              radius: 10,
                                              backgroundColor: Colors.black54,
                                              child: Icon(Icons.close, size: 12, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _busy ? null : _capture,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 4),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _busy
                                        ? Theme.of(context).colorScheme.outline
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
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
