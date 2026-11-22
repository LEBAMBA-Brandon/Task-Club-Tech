import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase/firebase_setup.dart';

/// Erreur lisible par l'utilisateur (annulation, configuration manquante...).
class SocialAuthException implements Exception {
  SocialAuthException(this.message, {this.cancelled = false});
  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}

/// Connexion avec Google via Firebase Authentication.
///
/// Résultat : un « ID token » Firebase que l'on envoie à l'API (POST /auth/social),
/// qui vérifie sa signature puis connecte ou inscrit le membre.
///
/// Configuration Android (une fois) :
///  1. Firebase › Authentication › Méthodes de connexion › Google : activé ;
///  2. Firebase › Paramètres du projet › appli Android ga.ctech.tasks › « Ajouter une empreinte » :
///     coller le SHA-1 (commande : cd android puis gradlew signingReport) ;
///  3. retélécharger google-services.json dans android/app/ puis relancer l'appli.
/// Sans l'étape 2, Google refuse la connexion (le fichier ne contient alors pas de client « Android »).
class SocialAuthService {
  bool _googleReady = false;

  /// ID client « Web » de Google (facultatif sur Android : lu dans google-services.json).
  static const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Le bouton Google est affiché sur Android et sur le web.
  bool get isSupported => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  /// Renvoie l'ID token Firebase, ou lève une [SocialAuthException] avec un message clair.
  Future<String> signInWithGoogle() async {
    if (!FirebaseSetup.ready) {
      throw SocialAuthException(FirebaseSetup.error ?? 'Firebase n\'est pas configuré sur cet appareil.');
    }
    try {
      final credential = await _google();
      final token = await credential.user?.getIdToken();
      if (token == null) throw SocialAuthException('Connexion impossible, réessayez.');
      return token;
    } on SocialAuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw SocialAuthException(_firebaseMessage(e));
    } on GoogleSignInException catch (e) {
      throw _googleMessage(e);
    } on PlatformException catch (e) {
      throw SocialAuthException('Connexion Google impossible (${e.code}). Vérifiez l\'empreinte SHA-1 dans Firebase.');
    } catch (e) {
      // Aucune erreur ne doit passer inaperçue (c'était la cause du « rien ne se passe »).
      throw SocialAuthException('Connexion Google impossible : $e');
    }
  }

  /// Déconnecte aussi de Firebase / Google (pour pouvoir changer de compte).
  Future<void> signOut() async {
    if (!FirebaseSetup.ready) return;
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
    if (idToken == null) {
      throw SocialAuthException('Google n\'a pas renvoyé d\'identifiant. Vérifiez la configuration Firebase.');
    }
    return FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  /// Sur Android, une configuration incomplète (SHA-1 absente) se présente souvent
  /// comme une « annulation » : on le dit clairement plutôt que de ne rien afficher.
  SocialAuthException _googleMessage(GoogleSignInException e) => switch (e.code) {
        GoogleSignInExceptionCode.canceled => SocialAuthException(
            'Connexion Google annulée. Si vous n\'avez rien annulé, l\'empreinte SHA-1 de l\'application '
            'n\'est sans doute pas encore déclarée dans Firebase.',
            cancelled: true,
          ),
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          SocialAuthException('Google n\'est pas encore bien configuré (empreinte SHA-1 / google-services.json).'),
        GoogleSignInExceptionCode.uiUnavailable =>
          SocialAuthException('Aucun compte Google disponible sur ce téléphone. Ajoutez-en un dans les réglages.'),
        _ => SocialAuthException('Connexion Google impossible (${e.code.name}). ${e.description ?? ''}'.trim()),
      };

  String _firebaseMessage(FirebaseAuthException e) => switch (e.code) {
        'popup-closed-by-user' || 'cancelled-popup-request' => 'Connexion annulée.',
        'popup-blocked' => 'Le navigateur a bloqué la fenêtre Google : autorisez les fenêtres pour ce site.',
        'unauthorized-domain' => 'Ce site n\'est pas autorisé dans Firebase (Authentication › Paramètres › Domaines autorisés).',
        'operation-not-allowed' => 'La connexion Google n\'est pas activée dans Firebase.',
        'network-request-failed' => 'Pas de connexion internet.',
        'invalid-credential' => 'Identifiant Google refusé par Firebase. Vérifiez l\'empreinte SHA-1.',
        _ => 'Connexion impossible (${e.code}).',
      };
}
