import 'local_backup_storage.dart';

Future<String> saveBackupFile({
  required String filename,
  required String content,
}) async =>
    throw UnsupportedError('Use file_saver on web');

Future<List<LocalBackupFile>> listBackupFiles() async => [];

Future<String?> readBackupFile(String path) async => null;

Future<void> deleteBackupFile(String path) async {}
