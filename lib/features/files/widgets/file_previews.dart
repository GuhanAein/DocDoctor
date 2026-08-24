import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/utils/file_utils.dart';

final Map<String, Future<Uint8List?>> _pdfThumbCache = {};
final Map<String, Future<int?>> _pdfPageCountCache = {};

Future<int?> pdfPageCount(String path) {
  return _pdfPageCountCache.putIfAbsent(path, () async {
    try {
      final doc = await PdfDocument.openFile(path);
      final count = doc.pagesCount;
      await doc.close();
      return count;
    } catch (_) {
      return null;
    }
  });
}

Future<Uint8List?> pdfThumbnail(String path, {int page = 1, int width = 400}) {
  final key = '$path#$page#$width';
  return _pdfThumbCache.putIfAbsent(key, () async {
    try {
      final doc = await PdfDocument.openFile(path);
      final p = await doc.getPage(page);
      final img = await p.render(
        width: width.toDouble(),
        height: (width * (p.height / p.width)).toDouble(),
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
      );
      await p.close();
      await doc.close();
      return img?.bytes;
    } catch (_) {
      return null;
    }
  });
}

Future<Uint8List?> pdfPageImage(String path, int page,
    {int width = 1400, PdfPageImageFormat format = PdfPageImageFormat.png}) async {
  try {
    final doc = await PdfDocument.openFile(path);
    final p = await doc.getPage(page);
    final img = await p.render(
      width: width.toDouble(),
      height: (width * (p.height / p.width)).toDouble(),
      format: format,
      backgroundColor: '#FFFFFF',
    );
    await p.close();
    await doc.close();
    return img?.bytes;
  } catch (_) {
    return null;
  }
}

void clearPdfCaches() {
  _pdfThumbCache.clear();
  _pdfPageCountCache.clear();
}

class PdfThumbnail extends StatelessWidget {
  const PdfThumbnail({super.key, required this.path, this.page = 1, this.width = 400});

  final String path;
  final int page;
  final int width;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: pdfThumbnail(path, page: page, width: width),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Center(
          child: Icon(Icons.picture_as_pdf, size: 48, color: Theme.of(context).colorScheme.error),
        );
      },
    );
  }
}

class FileThumbnail extends StatelessWidget {
  const FileThumbnail({super.key, required this.path, this.width = 400});

  final String path;
  final int width;

  @override
  Widget build(BuildContext context) {
    final ext = fileExtension(path);
    if (['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic'].contains(ext)) {
      return FutureBuilder<ui.Image?>(
        future: _decodeImage(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final img = snapshot.data!;
            return FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: img.width.toDouble(),
                height: img.height.toDouble(),
                child: RawImage(image: img, fit: BoxFit.contain),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return _fallback(context);
        },
      );
    }
    if (ext == 'pdf') return PdfThumbnail(path: path, width: width);
    if (ext == 'txt' || ext == 'csv' || ext == 'md' || ext == 'html' || ext == 'json') {
      return FutureBuilder<String?>(
        future: _readText(),
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text != null) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                text,
                maxLines: 40,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return _fallback(context);
        },
      );
    }
    return _fallback(context);
  }

  Future<ui.Image?> _decodeImage() async {
    try {
      final bytes = await File(path).readAsBytes();
      return await decodeImageFromList(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readText() async {
    try {
      final content = await File(path).readAsString();
      if (content.length > 8000) return content.substring(0, 8000);
      return content;
    } catch (_) {
      return null;
    }
  }

  Widget _fallback(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_iconFor(fileExtension(path)), size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text('No preview', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

IconData _iconFor(String ext) {
  switch (ext) {
    case 'pdf': return Icons.picture_as_pdf;
    case 'xlsx': case 'xls': case 'ods': return Icons.table_chart;
    case 'csv': return Icons.grid_on;
    case 'docx': case 'doc': case 'odt': return Icons.description;
    case 'pptx': case 'ppt': case 'odp': return Icons.slideshow;
    case 'zip': return Icons.folder_zip;
    case 'txt': case 'md': return Icons.notes;
    case 'html': case 'htm': return Icons.code;
    default: return Icons.insert_drive_file;
  }
}
