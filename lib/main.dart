import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/core_providers.dart';

/// Point d'entrée.
///
/// Architecture en couches (voir le rapport PDF) :
///   core/          configuration, thème, réseau, stockage, notifications
///   data/          modèles + repositories (accès API et cache hors ligne)
///   providers/     état de l'application (Riverpod)
///   presentation/  écrans et widgets
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  final prefs = await SharedPreferences.getInstance();

  // Firebase (notifications + connexion Google/GitHub) : configuré pour Android
  // via android/app/google-services.json. Sans ce fichier, l'appli fonctionne sans.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase indisponible : $e');
    }
  }

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const CTechTasksApp(),
  ));
}
