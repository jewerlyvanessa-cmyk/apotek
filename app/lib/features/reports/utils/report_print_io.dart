import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> openAndPrintHtml(String htmlDocument) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/laporan-kasir-${DateTime.now().millisecondsSinceEpoch}.html';
  final file = File(path);
  await file.writeAsString(htmlDocument);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path)],
      subject: 'Laporan Kasir',
      text: 'Buka file HTML di browser lalu cetak (Ctrl/Cmd+P).',
    ),
  );
}
