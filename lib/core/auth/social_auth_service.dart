import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Fournisseurs de connexion proposés sur l'écran d'accueil.
enum SocialProvider { google, github }

/// Erreur lisible par l'utilisateur (annulation, configuration manquante...).
class SocialAuthException implements Exception {
  SocialAuthException(this.message, {this.cancelled = false});
  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}

/// Connexion avec Google ou GitHub via Firebase Authentication.
///
/// Résultat : un « ID token » Firebase que l'on envoie à l'API (POST /auth/social),
/// qui vérifie sa signature puis connecte ou inscrit le membre.
///
/// Configuration (une fois, console Firebase › Authentication › Méthodes de connexion) :
///  - Google : activer, puis ajouter l'empreinte SHA-1 de l'appli Android
///    (Paramètres du projet) et retélécharger google-services.json ;
///  - GitHub : activer avec l'ID client et le secret d'une « OAuth App » GitHub.
class SocialAuthService {
  bool _googleReady = false;

  /// ID client « Web » de Google (facultatif sur Android si google-services.json le contient).
  static const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  bool get isSupported => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  Future<String> signIn(SocialProvider provider) async {
    if (!isSupported) {
      throw SocialAuthException('La connexion avec Google ou GitHub est disponible sur Android.');
    }
    try {
      final credential = switch (provider) {
        SocialProvider.google => await _google(),
        SocialProvider.github => await _github(),
      };
      final token = await credential.user?.getIdToken();
      if (token == null) throw SocialAuthException('Connexion impossible, réessayez.');
      return token;
    } on FirebaseAuthException catch (e) {
      throw SocialAuthException(_message(e));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw SocialAuthException('Connexion annulée.', cancelled: true);
      }
      throw SocialAuthException('Connexion Google impossible (${e.code.name}). Vérifiez la configuration Firebase.');
    }
  }

  /// Déconnecte aussi de Firebase / Google (pour pouvoir changer de compte).
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  Future<UserCredential> _google() async {
    if (kIsWeb) return FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());

    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
      );
      _googleReady = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    return FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  Future<UserCredential> _github() {
    final provider = GithubAuthProvider()..addScope('read:user')..addScope('user:email');
    return kIsWeb ? FirebaseAuth.instance.signInWithPopup(provider) : FirebaseAuth.instance.signInWithProvider(provider);
  }

  String _message(FirebaseAuthException e) => switch (e.code) {
        'web-context-canceled' || 'popup-closed-by-user' || 'canceled' => 'Connexion annulée.',
        'account-exists-with-different-credential' =>
          'Cette adresse est déjà liée à un autre moyen de connexion. Utilisez celui-ci.',
        'operation-not-allowed' => 'Ce mode de connexion n\'est pas encore activé dans Firebase.',
        'network-request-failed' => 'Pas de connexion internet.',
        _ => 'Connexion impossible (${e.code}).',
      };
}
