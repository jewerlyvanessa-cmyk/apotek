/// Konfigurasi SSL pinning via `--dart-define` (build production mobile/desktop).
///
/// Contoh:
/// ```bash
/// flutter build apk --release -t lib/main_production.dart \
///   --dart-define=ENABLE_SSL_PINNING=true \
///   --dart-define=SSL_PIN_SHA256=ab12cd34...
/// ```
///
/// Dapatkan fingerprint sertifikat server:
/// ```bash
/// openssl s_client -connect api.example.com:443 </dev/null 2>/dev/null \
///   | openssl x509 -outform DER \
///   | openssl dgst -sha256 -hex
/// ```
class SslPinningConfig {
  SslPinningConfig._();

  static const bool enabled = bool.fromEnvironment(
    'ENABLE_SSL_PINNING',
    defaultValue: false,
  );

  /// Satu atau beberapa SHA-256 (hex, pisah koma). Contoh: `aa:bb:cc` atau `aabbcc`.
  static const String pinSha256 = String.fromEnvironment(
    'SSL_PIN_SHA256',
    defaultValue: '',
  );

  static List<String> get allowedPins {
    if (pinSha256.trim().isEmpty) return const [];
    return pinSha256
        .split(',')
        .map((p) => p.trim().replaceAll(':', '').toLowerCase())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  static bool get isActive => enabled && allowedPins.isNotEmpty;
}
