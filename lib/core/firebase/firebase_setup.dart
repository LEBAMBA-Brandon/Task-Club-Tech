import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Démarrage de Firebase (notifications + connexion Google).
///
/// - Android : la configuration vient de android/app/google-services.json.
/// - Web (version navigateur) : Firebase a besoin de la configuration de « l'application Web »
///   déclarée dans la console Firebase (Paramètres du projet › Vos applications › Web).
///   On la passe au lancement, sans l'écrire dans le code :
///     flutter run -d chrome --dart-define=FIREBASE_WEB_API_KEY=... --dart-define=FIREBASE_WEB_APP_ID=...
///   Sans ces valeurs, la version web fonctionne sans Google ni notifications.
class FirebaseSetup {
  FirebaseSetup._();

  static const _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'tasks-ctech');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');

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
