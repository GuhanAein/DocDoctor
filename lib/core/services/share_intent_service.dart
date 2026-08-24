import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SharedFile {
  const SharedFile({required this.path, required this.name, this.mime = ''});

  final String path;
  final String name;
  final String mime;

  factory SharedFile.fromMap(Map<dynamic, dynamic> map) => SharedFile(
        path: (map['path'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        mime: (map['mime'] as String?) ?? '',
      );
}

class SharedIntentData {
  const SharedIntentData({this.files = const [], this.text = '', this.action = ''});

  final List<SharedFile> files;
  final String text;
  final String action;
}

class ShareIntentService {
  static const _channel = MethodChannel('doc_doctor/intents');
  final _controller = StreamController<SharedIntentData>.broadcast();
  bool _listening = false;

  Stream<SharedIntentData> get stream => _controller.stream;

  void startListening(BuildContext context) {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFiles') {
        final data = call.arguments as Map<dynamic, dynamic>? ?? {};
        final files = (data['files'] as List<dynamic>? ?? [])
            .map((e) => SharedFile.fromMap(e as Map<dynamic, dynamic>))
            .where((f) => f.path.isNotEmpty)
            .toList();
        _controller.add(SharedIntentData(
          files: files,
          text: (data['text'] as String?) ?? '',
          action: (data['action'] as String?) ?? '',
        ));
      }
    });
    _readInitial();
  }

  Future<void> _readInitial() async {
    try {
      final data = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInitialIntent');
      if (data == null) return;
      final files = (data['files'] as List<dynamic>? ?? [])
          .map((e) => SharedFile.fromMap(e as Map<dynamic, dynamic>))
          .where((f) => f.path.isNotEmpty)
          .toList();
      if (files.isEmpty && (data['text'] as String?)?.isEmpty != false) return;
      _controller.add(SharedIntentData(
        files: files,
        text: (data['text'] as String?) ?? '',
        action: (data['action'] as String?) ?? '',
      ));
    } on PlatformException {
      // Method channel not available (e.g. running on non-Android target).
    }
  }
}

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) => ShareIntentService());

final sharedFilesProvider = StreamProvider<SharedIntentData>((ref) {
  return ref.watch(shareIntentServiceProvider).stream;
});
