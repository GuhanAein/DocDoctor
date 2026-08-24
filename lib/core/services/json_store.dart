import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class JsonStore {
  JsonStore(this.fileName);

  final String fileName;
  Map<String, dynamic>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<Map<String, dynamic>> read() async {
    if (_cache != null) return _cache!;
    try {
      final f = await _file();
      if (await f.exists()) {
        final raw = await f.readAsString();
        _cache = jsonDecode(raw) as Map<String, dynamic>;
        return _cache!;
      }
    } catch (_) {}
    _cache = <String, dynamic>{};
    return _cache!;
  }

  Future<void> write(Map<String, dynamic> data) async {
    _cache = data;
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(data), flush: true);
  }

  Future<void> clear() async {
    _cache = <String, dynamic>{};
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
