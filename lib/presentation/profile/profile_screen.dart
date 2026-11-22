import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../account/change_password_screen.dart';
import '../common/common_widgets.dart';
import '../help/help_screen.dart';
import '../help/legal_screen.dart';
import '../help/tutorial_screen.dart';
import '../tasks/create_task_screen.dart';

/// Profil organisé en catégories :
///  - Mon contenu  : accès rapide aux différentes pages ;
///  - Compte       : notifications, thème, mot de passe ;
///  - Informations : aide, tutoriel, conditions, confidentialité, partage ;
///  - Se déconnecter.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late bool _push = ref.read(devicePrefsProvider).pushEnabled;
  bool _pushBusy = false;

  void _open(Widget screen, {bool fullscreen = false}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: fullscreen, builder: (_) => screen));

  void _goTo(String section) => ref.read(homeSectionProvider.notifier).go(section);

  Future<void> _togglePush(bool value) async {
    setState(() {
      _push = value;
      _pushBusy = true;
    });
    await ref.read(devicePrefsProvider).setPushEnabled(value);
    final push = ref.read(pushNotificationServiceProvider);
    try {
      value ? await push.registerDevice() : await push.unregisterDevice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value ? 'Notifications activées.' : 'Notifications désactivées.'),
        ));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez saisir à nouveau votre e-mail et votre mot de passe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final unread = ref.watch(unreadCountProvider).asData?.value ?? 0;
    if (user == null) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return MaxWidth(
      maxWidth: 640,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        // ----- En-tête
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              InitialsAvatar(user.initials, radius: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${user.positionLabel} · ${user.department?.name ?? ''}',
                      style: const TextStyle(color: AppColors.violetLight, fontWeight: FontWeight.w600)),
                  Text(user.email, style: TextStyle(color: muted, fontSize: 13)),
                ]),
              ),
            ]),
          ),
        ),

        // ----- Mon contenu
        const _Category('Mon contenu'),
        _Group(children: [
          _Item(
            icon: Icons.inbox_rounded,
            label: 'Tâches reçues',
            trailing: unread > 0 ? Badge(label: Text('$unread')) : null,
            onTap: () => _goTo('received'),
          ),
          _Item(icon: Icons.outbox_rounded, label: 'Tâches envoyées', onTap: () => _goTo('sent')),
          if (user.isPresidency)
            _Item(icon: Icons.groups_rounded, label: 'Toutes les tâches du club', onTap: () => _goTo('all')),
          if (user.canApprove)
            _Item(icon: Icons.how_to_reg, label: 'Comptes à valider', onTap: () => _goTo('approvals')),
          _Item(icon: Icons.add_task_rounded, label: 'Nouvelle tâche', onTap: () => _open(const CreateTaskScreen())),
        ]),

        // ----- Compte
        const _Category('Compte'),
        _Group(children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined, color: AppColors.violet),
            title: const Text('Notifications'),
            subtitle: Text(_push ? 'Être prévenu des nouvelles tâches' : 'Désactivées sur cet appareil',
                style: TextStyle(color: muted, fontSize: 12)),
            value: _push,
            onChanged: _pushBusy ? null : _togglePush,
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined, color: AppColors.violet),
            title: const Text('Thème'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('Système')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Clair')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre')),
              ],
              onChanged: (m) => ref.read(themeModeProvider.notifier).set(m ?? ThemeMode.system),
            ),
          ),
          _Item(
            icon: Icons.lock_reset_rounded,
            label: 'Changer le mot de passe',
            onTap: () => _open(const ChangePasswordScreen()),
          ),
        ]),

        // ----- Informations
        const _Category('Informations'),
        _Group(children: [
          _Item(icon: Icons.help_outline_rounded, label: 'Aide', onTap: () => _open(const HelpScreen())),
          _Item(
            icon: Icons.play_lesson_outlined,
            label: 'Tutoriel',
            onTap: () => _open(const TutorialScreen(), fullscreen: true),
          ),
          _Item(icon: Icons.gavel_rounded, label: 'Conditions d\'utilisation', onTap: () => _open(LegalScreen.terms())),
          _Item(
            icon: Icons.privacy_tip_outlined,
            label: 'Politique de confidentialité',
            onTap: () => _open(LegalScreen.privacy()),
          ),
          _Item(
            icon: Icons.share_rounded,
            label: 'Partager l\'application',
            onTap: () => SharePlus.instance.share(ShareParams(text: AppConfig.shareText, subject: AppConfig.appName)),
          ),
        ]),

        // ----- Déconnexion
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, minimumSize: const Size(0, 50)),
          onPressed: _confirmLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text('${AppConfig.appName} · ${AppConfig.clubName}', style: TextStyle(color: muted, fontSize: 12)),
        ),
      ]),
    );
  }
}

/// Titre de catégorie.
class _Category extends StatelessWidget {
  const _Category(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.violetLight, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
      );
}

/// Carte regroupant les lignes d'une catégorie, séparées par un trait.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ]),
      );
}

/// Ligne cliquable avec icône et flèche.
class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.onTap, this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.violet),
        title: Text(label),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          const Icon(Icons.chevron_right),
        ]),
        onTap: onTap,
      );
}
