import 'dart:io';

import 'package:flutter/foundation.dart';

/// Host backend dev untuk emulator/simulator (bukan `localhost` di Android).
String devApiHost() {
  if (kIsWeb) return 'localhost';
  if (Platform.isAndroid) return '10.0.2.2';
  return '127.0.0.1';
}

String devApiBaseUrl() => 'http://${devApiHost()}:3000/api/v1';

String devWsBaseUrl() => 'http://${devApiHost()}:3000';
