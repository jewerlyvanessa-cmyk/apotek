import 'package:shared_preferences/shared_preferences.dart';

const kOnPremApiBaseUrlKey = 'on_prem_api_base_url';

class ServerUrlStorage {
  ServerUrlStorage(this._prefs);

  final SharedPreferences _prefs;

  String? get savedApiBaseUrl => _prefs.getString(kOnPremApiBaseUrlKey)?.trim();

  Future<void> saveApiBaseUrl(String url) async {
    await _prefs.setString(kOnPremApiBaseUrlKey, url.trim());
  }

  Future<void> clear() async {
    await _prefs.remove(kOnPremApiBaseUrlKey);
  }
}

String normalizeApiBaseUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return url;
  if (url.endsWith('/')) url = url.substring(0, url.length - 1);
  if (!url.contains('/api/v1')) url = '$url/api/v1';
  return url;
}

String wsBaseUrlFromApi(String apiBaseUrl) {
  return apiBaseUrl.replaceAll('/api/v1', '');
}
