import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'ssl_pinning_config.dart';

void configureDioSslPinning(Dio dio) {
  if (!SslPinningConfig.isActive) return;

  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;

  final pins = SslPinningConfig.allowedPins;
  if (kDebugMode) {
    // ignore: avoid_print
    print('[SslPinning] aktif — ${pins.length} fingerprint');
  }

  adapter.createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      final hash = _certSha256Hex(cert);
      final ok = pins.contains(hash);
      if (!ok && kDebugMode) {
        // ignore: avoid_print
        print(
          '[SslPinning] ditolak $host:$port — fingerprint $hash tidak cocok',
        );
      }
      return ok;
    };
    return client;
  };
}

String _certSha256Hex(X509Certificate cert) {
  return sha256
      .convert(cert.der)
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}
