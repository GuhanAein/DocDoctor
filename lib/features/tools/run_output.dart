import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../core/utils/file_utils.dart';

Future<String> newRunDir() async {
  final tmp = await getTemporaryDirectory();
  final dir = Directory('${tmp.path}/run_${DateTime.now().millisecondsSinceEpoch}');
  await dir.create(recursive: true);
  return dir.path;
}

Future<String> writeRunFile(String runDir, String name, List<int> bytes) async {
  final path = await uniquePath(runDir, sanitizeFileName(name));
  await File(path).writeAsBytes(Uint8List.fromList(bytes), flush: true);
  return path;
}

Future<String> copyToRunDir(String runDir, String sourcePath, String name) async {
  final path = await uniquePath(runDir, sanitizeFileName(name));
  await File(sourcePath).copy(path);
  return path;
}
