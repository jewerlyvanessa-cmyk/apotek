import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../printing/printer_providers.dart';

const _enabledKey = 'biometric_login_enabled';
const _emailKey = 'biometric_login_email';
const _passwordKey = 'biometric_login_password';

class BiometricCredentialStorage {
  BiometricCredentialStorage(this._secure, this._prefs);

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  bool get isEnabled => _prefs.getBool(_enabledKey) ?? false;

  Future<void> enable({
    required String email,
    required String password,
  }) async {
    await _secure.write(key: _emailKey, value: email);
    await _secure.write(key: _passwordKey, value: password);
    await _prefs.setBool(_enabledKey, true);
  }

  Future<void> disable() async {
    await _secure.delete(key: _emailKey);
    await _secure.delete(key: _passwordKey);
    await _prefs.setBool(_enabledKey, false);
  }

  Future<({String email, String password})?> readCredentials() async {
    if (!isEnabled) return null;
    final email = await _secure.read(key: _emailKey);
    final password = await _secure.read(key: _passwordKey);
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return (email: email, password: password);
  }
}

final biometricCredentialStorageProvider =
    Provider<BiometricCredentialStorage>((ref) {
  return BiometricCredentialStorage(
    const FlutterSecureStorage(),
    ref.watch(prefsProvider),
  );
});
