import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Logo de l'application, adapté au thème :
///  - thème clair  -> assets/images/logo_light.png (fond blanc)
///  - thème sombre -> assets/images/logo_dark.png  (fond noir)
/// Le thème est celui choisi dans le profil (Système / Clair / Sombre).
/// [brightness] permet de forcer une version (ex. écrans toujours sombres).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 36, this.brightness});
  final double size;
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Image.asset(
        isDark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
        key: ValueKey(isDark),
        width: size,
        height: size,
        semanticLabel: 'Logo C-Tech Tasks',
      ),
    );
  }
}

/// Avatar rond avec les initiales.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials, {super.key, this.radius = 18});
  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
      child: Text(initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.72)),
    );
  }
}

/// Pastille d'urgence colorée (vert, bleu, jaune, rouge).
class UrgencyBadge extends StatelessWidget {
  const UrgencyBadge({super.key, required this.urgency, required this.label});
  final String urgency;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.urgencyColor(urgency);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

/// Coches façon WhatsApp :
///  sent ✓ gris · delivered ✓✓ gris · seen ✓✓ bleu · done ✔ vert (cercle)
class ReceiptTicks extends StatelessWidget {
  const ReceiptTicks(this.state, {super.key, this.size = 18});
  final String state;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      'done' => Icon(Icons.check_circle_rounded, size: size, color: AppColors.done),
      'seen' => Icon(Icons.done_all_rounded, size: size, color: AppColors.tickSeen),
      'delivered' => Icon(Icons.done_all_rounded, size: size, color: AppColors.tickGrey),
      _ => Icon(Icons.check_rounded, size: size, color: AppColors.tickGrey),
    };
  }

  static String label(String state) => switch (state) {
        'done' => 'Effectuée',
        'seen' => 'Vue',
        'delivered' => 'Reçue',
        _ => 'Envoyée',
      };
}

/// État vide / erreur avec action.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 52, color: AppColors.violetLight),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: muted)),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      ),
    );
  }
}

/// Bandeau « hors ligne ».
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: AppColors.blue.withValues(alpha: 0.12),
        child: const Row(children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Hors ligne : affichage des dernières données enregistrées.', style: TextStyle(fontSize: 12))),
        ]),
      );
}

/// Affiche un message d'erreur rouge en bas de l'écran.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(backgroundColor: AppColors.error, content: Text(error.toString())),
  );
}

/// Rafraîchit automatiquement un écran à intervalle régulier tant qu'il est affiché
/// (filet de sécurité du « temps réel » quand aucun signal Firebase n'arrive,
/// par exemple sur ordinateur). Le rechargement est silencieux.
class AutoRefresh extends StatefulWidget {
  const AutoRefresh({super.key, required this.every, required this.onTick, required this.child});

  final Duration every;
  final VoidCallback onTick;
  final Widget child;

  @override
  State<AutoRefresh> createState() => _AutoRefreshState();
}

class _AutoRefreshState extends State<AutoRefresh> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) => widget.onTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
