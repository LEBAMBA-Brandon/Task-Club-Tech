import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache hors ligne basé sur shared_preferences :
/// on garde la dernière réponse de l'API (listes de tâches, profil, référentiel)
/// pour pouvoir consulter l'application sans connexion.
class CacheStorage {
  CacheStorage(this._prefs);

  final SharedPreferences _prefs;
  static const _prefix = 'cache_';

  Future<void> write(String key, Object? json) => _prefs.setString('$_prefix$key', jsonEncode(json));

  dynamic read(String key) {
    final raw = _prefs.getString('$_prefix$key');
    return raw == null ? null : jsonDecode(raw);
  }

  /// Vide tout le cache (déconnexion).
  Future<void> clear() async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await _prefs.remove(key);
    }
  }

  // Préférences simples (thème...)
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
}
