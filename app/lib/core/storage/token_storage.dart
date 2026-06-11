import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accessTokenKey = 'access_token';
const _refreshTokenKey = 'refresh_token';
const _userJsonKey = 'user_json';

class TokenStorage {
  TokenStorage(this._secure, this._prefs);

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secure.write(key: _accessTokenKey, value: accessToken);
    await _secure.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _secure.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _secure.read(key: _refreshTokenKey);

  Future<void> saveUserJson(String json) async {
    await _prefs.setString(_userJsonKey, json);
  }

  String? getUserJson() => _prefs.getString(_userJsonKey);

  Future<void> clear() async {
    await _secure.delete(key: _accessTokenKey);
    await _secure.delete(key: _refreshTokenKey);
    await _prefs.remove(_userJsonKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  throw UnimplementedError('tokenStorageProvider must be overridden');
});
