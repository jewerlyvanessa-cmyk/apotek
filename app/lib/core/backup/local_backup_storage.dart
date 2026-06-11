import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_backup_storage_io.dart' if (dart.library.html) 'local_backup_storage_stub.dart' as io;

const _prefsIndexKey = 'local_backup_index_v1';

class LocalBackupFile {
  const LocalBackupFile({
    required this.name,
    required this.path,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String name;
  final String path;
  final DateTime modifiedAt;
  final int sizeBytes;
}

class LocalBackupStorage {
  LocalBackupStorage(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalBackupStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalBackupStorage(prefs);
  }

  List<Map<String, dynamic>> _readIndex() {
    final raw = _prefs.getString(_prefsIndexKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeIndex(List<Map<String, dynamic>> items) async {
    await _prefs.setString(_prefsIndexKey, jsonEncode(items));
  }

  Future<String> save({
    required String filename,
    required String content,
  }) async {
    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final sizeBytes = utf8.encode(content).length;

    String path;
    if (kIsWeb) {
      final base = safeName.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
      await FileSaver.instance.saveFile(
        name: base,
        bytes: Uint8List.fromList(utf8.encode(content)),
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      path = safeName;
    } else {
      path = await io.saveBackupFile(filename: safeName, content: content);
    }

    final index = _readIndex();
    index.removeWhere((e) => e['name'] == safeName);
    index.insert(0, {
      'name': safeName,
      'path': path,
      'modified_at': DateTime.now().toIso8601String(),
      'size_bytes': sizeBytes,
    });
    await _writeIndex(index.take(50).toList());

    return path;
  }

  Future<List<LocalBackupFile>> list() async {
    if (!kIsWeb) {
      final disk = await io.listBackupFiles();
      if (disk.isNotEmpty) {
        await _writeIndex(
          disk
              .map(
                (f) => {
                  'name': f.name,
                  'path': f.path,
                  'modified_at': f.modifiedAt.toIso8601String(),
                  'size_bytes': f.sizeBytes,
                },
              )
              .toList(),
        );
      }
    }

    return _readIndex()
        .map(
          (e) => LocalBackupFile(
            name: e['name']?.toString() ?? '',
            path: e['path']?.toString() ?? '',
            modifiedAt: DateTime.tryParse(e['modified_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            sizeBytes: (e['size_bytes'] as num?)?.toInt() ?? 0,
          ),
        )
        .where((f) => f.name.isNotEmpty)
        .toList();
  }

  Future<String?> readContent(String path) {
    if (kIsWeb) return Future.value(null);
    return io.readBackupFile(path);
  }

  Future<void> delete(String path, String name) async {
    if (!kIsWeb) await io.deleteBackupFile(path);
    final index = _readIndex()
      ..removeWhere((e) => e['path'] == path || e['name'] == name);
    await _writeIndex(index);
  }

  Future<String> backupsDirectoryLabel() async {
    if (kIsWeb) return 'Folder Download (browser)';
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/apotikflow_backups';
  }
}
