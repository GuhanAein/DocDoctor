import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges to native Android intents to open files/folders via the system.
class OpenService {
  static const MethodChannel _channel = MethodChannel('doc_doctor/intents');

  /// Opens [path] with the Android "Open with" chooser (ACTION_VIEW).
  Future<bool> openFile(String path) async {
    try {
      final res = await _channel.invokeMethod<bool>('openFile', {'path': path});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens [path] (a directory) in the native Android Files / file manager
  /// app (best-effort across OEMs).
  Future<bool> openFolder(String path) async {
    try {
      final res = await _channel.invokeMethod<bool>('openFolder', {'path': path});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}

final openServiceProvider = Provider<OpenService>((ref) => OpenService());
