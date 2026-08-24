import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'json_store.dart';

class FileRecord {
  const FileRecord({
    required this.path,
    required this.name,
    required this.toolId,
    required this.toolName,
    required this.timestamp,
    this.sizeBytes,
  });

  final String path;
  final String name;
  final String toolId;
  final String toolName;
  final int timestamp;
  final int? sizeBytes;

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'toolId': toolId,
        'toolName': toolName,
        'timestamp': timestamp,
        'sizeBytes': sizeBytes,
      };

  factory FileRecord.fromJson(Map<String, dynamic> json) => FileRecord(
        path: json['path'] as String,
        name: json['name'] as String,
        toolId: (json['toolId'] as String?) ?? '',
        toolName: (json['toolName'] as String?) ?? '',
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      );
}

class RecentService {
  RecentService() : _store = JsonStore('recents.json');

  final JsonStore _store;

  Future<List<FileRecord>> getAll() async {
    final data = await _store.read();
    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => FileRecord.fromJson(e as Map<String, dynamic>))
        .where((r) => File(r.path).existsSync())
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> add(FileRecord record) async {
    final all = await getAll();
    all.removeWhere((r) => r.path == record.path);
    all.insert(0, record);
    if (all.length > 100) all.removeRange(100, all.length);
    await _store.write({
      'items': all.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> clear() => _store.clear();
}

class FavoritesService {
  FavoritesService() : _store = JsonStore('favorites.json');

  final JsonStore _store;

  Future<List<FileRecord>> getAll() async {
    final data = await _store.read();
    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => FileRecord.fromJson(e as Map<String, dynamic>))
        .where((r) => File(r.path).existsSync())
        .toList();
  }

  Future<bool> isFavorite(String path) async {
    final all = await getAll();
    return all.any((r) => r.path == path);
  }

  Future<void> toggle(FileRecord record) async {
    final all = await getAll();
    if (all.any((r) => r.path == record.path)) {
      all.removeWhere((r) => r.path == record.path);
    } else {
      all.insert(0, record);
    }
    await _store.write({
      'items': all.map((e) => e.toJson()).toList(),
    });
  }
}

final recentServiceProvider = Provider<RecentService>((ref) => RecentService());
final favoritesServiceProvider = Provider<FavoritesService>((ref) => FavoritesService());

class RecentsNotifier extends AsyncNotifier<List<FileRecord>> {
  @override
  Future<List<FileRecord>> build() => ref.watch(recentServiceProvider).getAll();

  Future<void> add(FileRecord record) async {
    final service = ref.read(recentServiceProvider);
    await service.add(record);
    state = AsyncData(await service.getAll());
  }

  Future<void> refresh() async {
    state = AsyncData(await ref.read(recentServiceProvider).getAll());
  }

  Future<void> clear() async {
    await ref.read(recentServiceProvider).clear();
    state = const AsyncData([]);
  }
}

final recentsProvider = AsyncNotifierProvider<RecentsNotifier, List<FileRecord>>(
  RecentsNotifier.new,
);

class FavoritesNotifier extends AsyncNotifier<List<FileRecord>> {
  @override
  Future<List<FileRecord>> build() => ref.watch(favoritesServiceProvider).getAll();

  Future<void> toggle(FileRecord record) async {
    final service = ref.read(favoritesServiceProvider);
    await service.toggle(record);
    state = AsyncData(await service.getAll());
  }

  Future<void> refresh() async {
    state = AsyncData(await ref.read(favoritesServiceProvider).getAll());
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, List<FileRecord>>(
  FavoritesNotifier.new,
);
