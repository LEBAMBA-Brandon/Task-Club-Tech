/// Configuration globale de l'application.
///
/// L'URL de l'API se change sans toucher au code :
///   flutter run --dart-define=API_URL=http://192.168.1.20:8000/api/v1
///
/// Valeur par défaut : 10.0.2.2 = « localhost du PC » vu depuis l'émulateur Android.
class AppConfig {
  AppConfig._();

  static const String appName = 'C-Tech Tasks';
  static const String clubName = 'Club-Tech (C-Tech)';

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Délais réseau.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Slug du département « Présidence » (postes président / vice-président).
  static const String presidencySlug = 'presidence';
}
