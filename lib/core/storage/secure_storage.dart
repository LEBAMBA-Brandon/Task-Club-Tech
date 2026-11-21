import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage chiffré (Android Keystore) du jeton d'authentification.
/// Le jeton n'est JAMAIS mis dans shared_preferences (non chiffré).
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _expiresKey = 'auth_token_expires_at';

  Future<void> saveToken(String token, DateTime expiresAt) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _expiresKey, value: expiresAt.toIso8601String());
  }

  /// Retourne le jeton s'il existe et n'a pas expiré (7 semaines).
  Future<String?> readValidToken() async {
    final token = await _storage.read(key: _tokenKey);
    final expires = DateTime.tryParse(await _storage.read(key: _expiresKey) ?? '');
    if (token == null || expires == null || expires.isBefore(DateTime.now())) return null;
    return token;
  }

  Future<void> clear() => _storage.deleteAll();
}
