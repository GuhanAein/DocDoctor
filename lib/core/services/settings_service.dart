import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'json_store.dart';

class SettingsService {
  SettingsService() : _store = JsonStore('settings.json');

  final JsonStore _store;
  String? _outputDir;

  static const String docDoctorFolder = 'docdoctor';

  Future<String> getDefaultOutputDir() async {
    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    return p.join(base.path, docDoctorFolder);
  }

  Future<String> getOutputDir() async {
    if (_outputDir != null) return _outputDir!;
    final data = await _store.read();
    final stored = data['outputDir'] as String?;
    if (stored != null && await Directory(stored).exists()) {
      _outputDir = stored;
      return stored;
    }
    final def = await getDefaultOutputDir();
    await Directory(def).create(recursive: true);
    _outputDir = def;
    await _store.write({...data, 'outputDir': def});
    return def;
  }

  Future<void> setOutputDir(String dir) async {
    await Directory(dir).create(recursive: true);
    _outputDir = dir;
    final data = await _store.read();
    await _store.write({...data, 'outputDir': dir});
  }

  Future<void> resetOutputDir() async {
    _outputDir = null;
    final data = await _store.read();
    data.remove('outputDir');
    await _store.write(data);
  }

  Future<ThemeMode> getThemeMode() async {
    final data = await _store.read();
    switch (data['themeMode'] as String?) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final data = await _store.read();
    await _store.write({
      ...data,
      'themeMode': mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system',
    });
  }

  Future<Map<String, dynamic>> exportConfig() async => _store.read();

  Future<bool> isOnboarded() async {
    final data = await _store.read();
    return data['onboarded'] == true;
  }

  Future<void> setOnboarded(bool value) async {
    final data = await _store.read();
    await _store.write({...data, 'onboarded': value});
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());

final outputDirProvider = FutureProvider<String>((ref) async {
  return ref.watch(settingsServiceProvider).getOutputDir();
});

class OutputDirNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.read(settingsServiceProvider).getOutputDir().then((d) => state = d);
    return null;
  }

  Future<void> setDir(String dir) async {
    await ref.read(settingsServiceProvider).setOutputDir(dir);
    state = dir;
  }

  Future<void> setParent(String parent) async {
    final dir = p.join(parent, SettingsService.docDoctorFolder);
    await ref.read(settingsServiceProvider).setOutputDir(dir);
    state = dir;
  }

  Future<void> reset() async {
    await ref.read(settingsServiceProvider).resetOutputDir();
    state = await ref.read(settingsServiceProvider).getOutputDir();
  }
}

final outputDirNotifierProvider = NotifierProvider<OutputDirNotifier, String?>(
  OutputDirNotifier.new,
);
