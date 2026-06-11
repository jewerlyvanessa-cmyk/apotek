import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'local_backup_storage.dart';

const _subdir = 'apotikflow_backups';

Future<String> saveBackupFile({
  required String filename,
  required String content,
}) async {
  final dir = await _backupDir();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, encoding: utf8);
  return file.path;
}

Future<Directory> _backupDir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/$_subdir');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<List<LocalBackupFile>> listBackupFiles() async {
  final dir = await _backupDir();
  if (!await dir.exists()) return [];

  final files = await dir
      .list()
      .where((e) => e is File && e.path.endsWith('.json'))
      .cast<File>()
      .toList();

  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

  return files
      .map(
        (f) => LocalBackupFile(
          name: f.uri.pathSegments.last,
          path: f.path,
          modifiedAt: f.lastModifiedSync(),
          sizeBytes: f.lengthSync(),
        ),
      )
      .toList();
}

Future<String?> readBackupFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsString(encoding: utf8);
}

Future<void> deleteBackupFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
