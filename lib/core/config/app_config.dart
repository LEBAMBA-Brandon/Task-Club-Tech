/// Configuration globale de l'application.
///
/// L'URL de l'API se change sans toucher au code :
///   flutter run --dart-define=API_URL=http://192.168.1.20:8000/api/v1
///
/// Valeur par défaut : le serveur en ligne (Railway).
/// Pour tester avec le serveur local :
///   émulateur Android : --dart-define=API_URL=http://10.0.2.2:8000/api/v1
///   ordinateur        : --dart-define=API_URL=http://127.0.0.1:8000/api/v1
class AppConfig {
  AppConfig._();

  static const String appName = 'C-Tech Tasks';
  static const String clubName = 'Club-Tech (C-Tech)';

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://task-club-tech-production.up.railway.app/api/v1',
  );

  /// Texte envoyé par « Partager l'application » (ajoutez le lien de téléchargement dans [downloadUrl]).
  static const String downloadUrl = String.fromEnvironment('DOWNLOAD_URL', defaultValue: '');

  static String get shareText =>
      'Rejoins l\'espace des tâches du $clubName sur l\'application $appName : '
      'reçois les tâches de ton département, suis leur avancement et coche-les une fois faites.'
      '${downloadUrl.isEmpty ? '' : '\nTélécharger : $downloadUrl'}';

  /// Délais réseau.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Slug du département « Présidence » (postes président / vice-président).
  static const String presidencySlug = 'presidence';
}
