import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../common/common_widgets.dart';

/// Une page du tutoriel : une illustration + un titre + une explication.
class _Slide {
  const _Slide(this.title, this.text, this.illustration);
  final String title;
  final String text;
  final Widget illustration;
}

/// Tutoriel de prise en main, affiché au premier lancement
/// et accessible ensuite depuis Profil › Informations › Aide.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _pager = PageController();
  int _page = 0;

  static final _slides = <_Slide>[
    const _Slide(
      'Bienvenue sur C-Tech Tasks',
      'Toutes les tâches du Club-Tech au même endroit : qui doit faire quoi, pour quand, et qui l\'a déjà fait.',
      AppLogo(size: 140),
    ),
    const _Slide(
      'Vos tâches reçues',
      'L\'onglet « Reçues » rassemble les tâches envoyées à votre département. La pastille rouge indique '
          'combien vous n\'en avez pas encore ouvert. Une notification vous prévient à chaque nouvelle tâche.',
      _InboxIllustration(),
    ),
    const _Slide(
      'Quatre couleurs d\'urgence',
      'Chaque tâche a une couleur, de la plus flexible à la plus pressante. Commencez par le rouge !',
      _UrgencyIllustration(),
    ),
    const _Slide(
      'Les coches, comme sur WhatsApp',
      'L\'auteur d\'une tâche voit, pour chaque membre, si elle a été reçue, vue puis effectuée.',
      _TicksIllustration(),
    ),
    const _Slide(
      'Marquez-la comme effectuée',
      'Ouvrez la tâche, puis touchez le bouton vert quand vous avez terminé. Cela ne concerne que vous. '
          'Une question ? Laissez un commentaire en bas de la tâche.',
      _DoneIllustration(),
    ),
    const _Slide(
      'Envoyez une tâche',
      'Touchez « Nouvelle tâche », écrivez un titre, choisissez le département et la couleur d\'urgence. '
          'Tous ses membres la reçoivent aussitôt.',
      _CreateIllustration(),
    ),
    const _Slide(
      'Discutez entre membres',
      'L\'onglet « Messages » contient le groupe de votre département et vos conversations privées. '
          'Touchez « Nouveau message » pour écrire à n\'importe quel membre du club.',
      _ChatIllustration(),
    ),
    const _Slide(
      'Votre profil',
      'Changez votre mot de passe, gérez les notifications et le thème clair ou sombre, retrouvez l\'aide '
          'et ce tutoriel dans l\'onglet « Profil ».',
      _ProfileIllustration(),
    ),
  ];

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(devicePrefsProvider).setTutorialSeen();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: last ? null : TextButton(onPressed: _finish, child: const Text('Passer')),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final slide = _slides[i];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(children: [
                        const SizedBox(height: 12),
                        SizedBox(height: 240, child: Center(child: slide.illustration)),
                        const SizedBox(height: 28),
                        Text(slide.title, textAlign: TextAlign.center, style: AppTheme.display(28)),
                        const SizedBox(height: 12),
                        Text(slide.text, textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.5, fontSize: 15)),
                      ]),
                    );
                  },
                ),
              ),
              // Points de progression
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.violet : AppColors.violet.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Row(children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _pager.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                      child: const Text('Précédent'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: last
                        ? _finish
                        : () => _pager.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(last ? 'Commencer' : 'Suivant'),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Illustrations

/// Cadre arrondi commun aux illustrations.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: 0.15), blurRadius: 30)],
        ),
        child: child,
      );
}

class _MiniTask extends StatelessWidget {
  const _MiniTask(this.title, this.urgency, {this.state});
  final String title;
  final String urgency;
  final String? state;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: AppColors.urgencyColor(urgency), width: 5)),
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (state != null) ReceiptTicks(state!, size: 16),
        ]),
      );
}

class _InboxIllustration extends StatelessWidget {
  const _InboxIllustration();

  @override
  Widget build(BuildContext context) => _Frame(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Badge(label: Text('2'), child: Icon(Icons.inbox_rounded, color: AppColors.violet)),
            const SizedBox(width: 12),
            const Text('Reçues', style: TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Icon(Icons.notifications_active_rounded, color: AppColors.blue.withValues(alpha: 0.9)),
          ]),
          const SizedBox(height: 14),
          const _MiniTask('Préparer l\'affiche', 'red'),
          const _MiniTask('Réserver la salle', 'yellow'),
          const _MiniTask('Compte rendu', 'green', state: 'done'),
        ]),
      );
}

class _UrgencyIllustration extends StatelessWidget {
  const _UrgencyIllustration();

  @override
  Widget build(BuildContext context) => const _Frame(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          UrgencyBadge(urgency: 'green', label: 'Flexible'),
          SizedBox(height: 10),
          UrgencyBadge(urgency: 'blue', label: 'Normale'),
          SizedBox(height: 10),
          UrgencyBadge(urgency: 'yellow', label: 'Importante'),
          SizedBox(height: 10),
          UrgencyBadge(urgency: 'red', label: 'Urgente'),
        ]),
      );
}

class _TicksIllustration extends StatelessWidget {
  const _TicksIllustration();

  @override
  Widget build(BuildContext context) => _Frame(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (state, label) in const [
            ('sent', 'Envoyée'),
            ('delivered', 'Reçue'),
            ('seen', 'Vue'),
            ('done', 'Effectuée'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                ReceiptTicks(state, size: 24),
                const SizedBox(width: 14),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ]),
            ),
        ]),
      );
}

class _DoneIllustration extends StatelessWidget {
  const _DoneIllustration();

  @override
  Widget build(BuildContext context) => _Frame(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _MiniTask('Préparer l\'affiche', 'red', state: 'seen'),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.done),
              onPressed: () {},
              icon: const Icon(Icons.check_rounded),
              label: const Text('Marquer comme effectuée'),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('C\'est fait, je l\'envoie au groupe 👍'),
            ),
          ),
        ]),
      );
}

class _CreateIllustration extends StatelessWidget {
  const _CreateIllustration();

  @override
  Widget build(BuildContext context) => _Frame(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _field(context, Icons.title, 'Titre de la tâche'),
          _field(context, Icons.apartment, 'Département : Communication'),
          const Wrap(spacing: 6, children: [
            UrgencyBadge(urgency: 'blue', label: 'Normale'),
            UrgencyBadge(urgency: 'red', label: 'Urgente'),
          ]),
          const SizedBox(height: 12),
          Center(
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: () {},
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Nouvelle tâche'),
            ),
          ),
        ]),
      );

  Widget _field(BuildContext context, IconData icon, String text) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(text)]),
      );
}

class _ChatIllustration extends StatelessWidget {
  const _ChatIllustration();

  @override
  Widget build(BuildContext context) => _Frame(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Qui s\'occupe des badges ?'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.violet, AppColors.blue]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Moi, c\'est prêt demain 👍', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          const Row(children: [
            Badge(label: Text('3'), child: Icon(Icons.chat_bubble_rounded, color: AppColors.violet)),
            SizedBox(width: 12),
            Text('Messages', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ]),
      );
}

class _ProfileIllustration extends StatelessWidget {
  const _ProfileIllustration();

  @override
  Widget build(BuildContext context) => _Frame(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (icon, label) in const [
            (Icons.notifications_outlined, 'Notifications'),
            (Icons.lock_reset_rounded, 'Changer le mot de passe'),
            (Icons.dark_mode_outlined, 'Thème'),
            (Icons.help_outline, 'Aide'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Icon(icon, color: AppColors.violet),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right),
              ]),
            ),
        ]),
      );
}
