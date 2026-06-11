import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/config/app_config.dart';
import '../network/dio_client.dart';
import '../storage/server_url_storage.dart';

/// Simpan & terapkan alamat server baru tanpa menutup aplikasi.
Future<AppConfig> applyServerApiBaseUrl(
  WidgetRef ref,
  SharedPreferences prefs,
  String rawUrl,
) async {
  final apiBase = normalizeApiBaseUrl(rawUrl);
  await ServerUrlStorage(prefs).saveApiBaseUrl(apiBase);
  final current = ref.read(appConfigProvider);
  final updated = AppConfig(
    flavor: current.flavor,
    apiBaseUrl: apiBase,
    wsBaseUrl: wsBaseUrlFromApi(apiBase),
    appName: current.appName,
  );
  ref.read(appConfigProvider.notifier).state = updated;
  return updated;
}
