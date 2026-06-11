import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

Future<void> saveReportBytes({
  required Uint8List bytes,
  required String fileName,
  required MimeType mimeType,
}) async {
  final dot = fileName.lastIndexOf('.');
  final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot + 1) : '';

  await FileSaver.instance.saveFile(
    name: baseName,
    bytes: bytes,
    fileExtension: ext,
    mimeType: mimeType,
  );
}

MimeType reportMimeXlsx() => MimeType.microsoftExcel;

MimeType reportMimePdf() => MimeType.pdf;
