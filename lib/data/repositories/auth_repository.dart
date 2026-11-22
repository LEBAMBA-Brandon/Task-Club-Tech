import '../../core/network/api_client.dart';
import '../../core/storage/cache_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../models/user.dart';

/// Résultat d'une action qui envoie un code par e-mail.
/// [debugCode] n'est rempli qu'en développement (serveur local sans SMTP).
class CodeSent {
  const CodeSent(this.message, {this.debugCode});
  final String message;
  final String? debugCode;
}

/// Session ouverte après connexion.
class AuthSession {
  const AuthSession({required this.token, required this.expiresAt, required this.user});
  final String token;
  final DateTime expiresAt;
  final AppUser user;
}

/// Accès à l'API d'authentification + persistance de la session.
class AuthRepository {
  AuthRepository(this._api, this._secure, this._cache);

  final ApiClient _api;
  final SecureStorage _secure;
  final CacheStorage _cache;

  static const _userCacheKey = 'me';

  Future<CodeSent> register({
    required String firstName,
    required String lastName,
    required String email,
    required int departmentId,
    required String position,
    required String password,
    required String passwordConfirmation,
    required bool acceptTerms,
  }) async {
    final data = await _api.post('/auth/register', {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'department_id': departmentId,
      'position': position,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'accept_terms': acceptTerms,
    });
    return _codeSent(data);
  }

  Future<String> verifyEmail(String email, String code) async {
    final data = await _api.post('/auth/verify-email', {'email': email.trim(), 'code': code});
    return data['message'] as String;
  }

  Future<CodeSent> resendCode(String email) async => _codeSent(await _api.post('/auth/resend-code', {'email': email.trim()}));

  Future<CodeSent> forgotPassword(String email) async =>
      _codeSent(await _api.post('/auth/forgot-password', {'email': email.trim()}));

  Future<String> resetPassword(String email, String code, String password, String confirmation) async {
    final data = await _api.post('/auth/reset-password', {
      'email': email.trim(),
      'code': code,
      'password': password,
      'password_confirmation': confirmation,
    });
    return data['message'] as String;
  }

  /// Connexion. Si [remember] est faux, le jeton reste en mémoire (session fermée à la sortie de l'appli).
  Future<AuthSession> login(String email, String password, {required bool remember}) async {
    final data = await _api.post('/auth/login', {
      'email': email.trim(),
      'password': password,
      'device_name': 'android',
    });
    final session = AuthSession(
      token: data['token'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String),
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
    if (remember) {
      await _secure.saveToken(session.token, session.expiresAt);
    }
    await _cache.write(_userCacheKey, session.user.toJson());
    return session;
  }

  /// Connexion avec Google : [idToken] vient de Firebase Authentication.
  /// Pour un nouveau compte, l'API répond PROFILE_REQUIRED (ApiException) : on rappelle
  /// alors cette méthode avec le département, le poste et l'acceptation des conditions.
  Future<AuthSession> social(
    String idToken, {
    String? firstName,
    String? lastName,
    int? departmentId,
    String? position,
    bool? acceptTerms,
  }) async {
    final data = await _api.post('/auth/social', {
      'id_token': idToken,
      'device_name': 'android',
      'first_name': ?firstName?.trim(),
      'last_name': ?lastName?.trim(),
      'department_id': ?departmentId,
      'position': ?position,
      'accept_terms': ?acceptTerms,
    });
    final session = AuthSession(
      token: data['token'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String),
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
    // La connexion sociale garde toujours la session (comme « Se souvenir de moi »).
    await _secure.saveToken(session.token, session.expiresAt);
    await _cache.write(_userCacheKey, session.user.toJson());
    return session;
  }

  Future<String?> readStoredToken() => _secure.readValidToken();

  /// Profil à jour ; en cas d'absence de réseau, renvoie le profil en cache.
  Future<AppUser> me() async {
    try {
      final data = await _api.get('/auth/me');
      final user = AppUser.fromJson(data['data'] as Map<String, dynamic>);
      await _cache.write(_userCacheKey, user.toJson());
      return user;
    } catch (e) {
      final cached = _cache.read(_userCacheKey);
      if (cached is Map<String, dynamic>) return AppUser.fromJson(cached);
      rethrow;
    }
  }

  /// Changement de mot de passe depuis le profil.
  Future<String> changePassword(String current, String password, String confirmation) async {
    final data = await _api.put('/auth/password', {
      'current_password': current,
      'password': password,
      'password_confirmation': confirmation,
    });
    return data['message'] as String;
  }

  Future<void> updateFcmToken(String? token) => _api.put('/auth/fcm-token', {'fcm_token': token});

  /// Déconnexion : révoque le jeton côté serveur (si possible) et efface tout localement.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Hors ligne : on efface quand même localement.
    }
    await clearLocal();
  }

  Future<void> clearLocal() async {
    await _secure.clear();
    await _cache.clear();
  }

  CodeSent _codeSent(dynamic data) =>
      CodeSent(data['message'] as String, debugCode: data['debug_code']?.toString());
}
