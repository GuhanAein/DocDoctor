import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

Future<R> runInIsolate<R>(FutureOr<R> Function() fn) {
  if (!kIsWeb) {
    return Isolate.run(fn);
  }
  return Future.sync(fn);
}

String formatBytes(num bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String sanitizeFileName(String name) {
  var n = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (n.isEmpty) n = 'file';
  return n;
}

String baseNameWithoutExt(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final idx = name.lastIndexOf('.');
  return idx > 0 ? name.substring(0, idx) : name;
}

String fileExtension(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final idx = name.lastIndexOf('.');
  return idx >= 0 ? name.substring(idx + 1).toLowerCase() : '';
}

Future<String> uniquePath(String dir, String name) async {
  var candidate = '$dir${Platform.pathSeparator}$name';
  var counter = 1;
  while (await File(candidate).exists()) {
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    candidate = '$dir${Platform.pathSeparator}$stem ($counter)$ext';
    counter++;
  }
  return candidate;
}

Future<DateTime?> fileModified(String path) async {
  try {
    return (await File(path).stat()).modified;
  } catch (_) {
    return null;
  }
}

Future<int> fileSize(String path) async {
  try {
    return (await File(path).length());
  } catch (_) {
    return 0;
  }
}
