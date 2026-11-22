import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Démarrage de Firebase (notifications + connexion Google).
///
/// - Android : la configuration vient de android/app/google-services.json.
/// - Web (version navigateur) : configuration de l'application Web « C-Tech Tasks Web »
///   déclarée dans la console Firebase (Paramètres du projet › Vos applications › Web).
///   Ces valeurs sont publiques par conception (elles identifient le projet, ce ne sont pas
///   des mots de passe) ; la sécurité repose sur les « domaines autorisés » de Firebase
///   Authentication et sur la vérification du jeton par l'API.
///   Elles peuvent être remplacées au lancement avec --dart-define=FIREBASE_WEB_API_KEY=... etc.
class FirebaseSetup {
  FirebaseSetup._();

  static const _webApiKey =
      String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: 'AIzaSyBTpWjnWAcA48zyn7jgWvJbqeUS4DqT1OY');
  static const _webAppId =
      String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '1:755413969568:web:53bebe56025735f096f7c5');
  static const _measurementId = 'G-0GVP79KY9Q';
  static const _storageBucket = 'task-ctech.firebasestorage.app';
  // Identifiants publics du projet Firebase « task-ctech » (lus dans google-services.json).
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'task-ctech');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '755413969568');

  /// Vrai si Firebase a pu démarrer sur cette plateforme.
  static bool ready = false;

  /// Dernière erreur de démarrage (affichée si l'utilisateur touche « Google »).
  static String? error;

  static Future<void> init() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        ready = true;
      } else if (kIsWeb) {
        if (_webApiKey.isEmpty || _webAppId.isEmpty) {
          error = 'Configuration Firebase « Web » absente (voir le guide, section 16).';
          return;
        }
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: _webApiKey,
            appId: _webAppId,
            messagingSenderId: _senderId,
            projectId: _projectId,
            authDomain: '$_projectId.firebaseapp.com',
            storageBucket: _storageBucket,
            measurementId: _measurementId,
          ),
        );
        ready = true;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        await Firebase.initializeApp();
        ready = true;
      } else {
        error = 'La connexion Google est disponible sur Android et sur la version web.';
      }
    } catch (e) {
      error = 'Firebase n\'a pas pu démarrer : $e';
      debugPrint(error);
    }
  }
}
