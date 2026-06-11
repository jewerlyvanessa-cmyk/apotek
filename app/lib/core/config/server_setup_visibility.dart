import 'package:shared_preferences/shared_preferences.dart';
import '../../app/config/app_config.dart';
import '../../features/license/domain/entities/license_status.dart';
import '../storage/server_url_storage.dart';

/// Kapan menampilkan tautan «Atur alamat server» di halaman login (pre-login).
///
/// Ketentuan (`referensi/10. checklist beli putus.md` §D1, `referensi/9. audit` §3.3):
/// - **Dev / staging:** sembunyikan — URL API sudah tetap dari flavor build.
/// - **SaaS (cloud):** sembunyikan — endpoint cloud bawaan sudah benar.
/// - **On-prem / belum terhubung:** tampilkan jika belum ada alamat server kustom
///   tersimpan (wajib saat instalasi pertama beli putus).
/// - **Sudah dikonfigurasi:** sembunyikan — Super Admin dapat ubah lewat Platform Admin.
bool showServerSetupOnLogin({
  required AppFlavor flavor,
  required SharedPreferences prefs,
  LicenseStatus? license,
  bool licenseLoading = false,
}) {
  if (flavor == AppFlavor.dev || flavor == AppFlavor.staging) {
    return false;
  }

  final saved = ServerUrlStorage(prefs).savedApiBaseUrl;
  if (saved != null && saved.isNotEmpty) {
    return false;
  }

  if (licenseLoading) {
    return false;
  }

  if (license?.isSaas == true) {
    return false;
  }

  return true;
}
