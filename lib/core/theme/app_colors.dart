import 'package:flutter/material.dart';

/// Palette C-Tech : bleu et violet (logo), rouge pour les erreurs,
/// blanc / noir pour les thèmes clair et sombre.
class AppColors {
  AppColors._();

  // Couleurs de marque (dégradé du logo)
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetLight = Color(0xFF8B5CF6);
  static const Color blue = Color(0xFF3B82F6);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color error = Color(0xFFEF4444);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [violet, blue, cyan],
  );

  // Fonds
  static const Color black = Color(0xFF0B0B12);
  static const Color darkSurface = Color(0xFF15151F);
  static const Color darkCard = Color(0xFF1C1C28);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5FA);

  // Accusés façon WhatsApp
  static const Color tickGrey = Color(0xFF9CA3AF);
  static const Color tickSeen = Color(0xFF38BDF8);
  static const Color done = Color(0xFF22C55E);

  /// Couleurs d'urgence, du plus flexible au plus pressant : vert, bleu, jaune, rouge.
  static const Map<String, Color> urgency = {
    'green': Color(0xFF22C55E),
    'blue': Color(0xFF3B82F6),
    'yellow': Color(0xFFEAB308),
    'red': Color(0xFFEF4444),
  };

  static Color urgencyColor(String value) => urgency[value] ?? blue;

  /// Couleurs de la lampe de l'écran de connexion (un clic sur la lampe change de couleur).
  static const List<Color> lampColors = [violetLight, blue, cyan, Color(0xFFA78BFA)];
}
