import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> openAndPrintHtml(String htmlDocument) async {
  final win = web.window.open('', '_blank');
  if (win == null) {
    throw Exception('Popup diblokir. Izinkan popup untuk cetak laporan.');
  }
  win.document.open();
  win.document.write(htmlDocument.toJS);
  win.document.close();
  win.focus();
  win.print();
}
