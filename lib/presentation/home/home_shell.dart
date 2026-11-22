import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/push_notification_service.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../approvals/approvals_screen.dart';
import '../common/common_widgets.dart';
import '../help/tutorial_screen.dart';
import '../profile/profile_screen.dart';
import '../tasks/create_task_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_list_screen.dart';

/// Une section de la navigation principale.
class _Section {
  const _Section(this.id, this.label, this.icon, this.selectedIcon, this.builder, {this.title});
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
  final String? title;
}

/// Coquille principale, responsive :
///  - smartphone : barre de navigation en bas ;
///  - tablette   : rail de navigation compact à gauche ;
///  - desktop    : rail étendu avec libellés.
/// La section affichée est dans [homeSectionProvider] (le profil peut aussi y naviguer).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    // Notifications : clic -> ouvre la tâche ; réception -> rafraîchit listes et badge.
    final push = ref.read(pushNotificationServiceProvider);
    push.onOpenTask = (id) async {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(taskId: id)));
      if (mounted) refreshTaskLists(ref);
    };
    push.onMessage = () {
      if (mounted) refreshTaskLists(ref);
    };

    // Premier lancement : tutoriel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(devicePrefsProvider).tutorialSeen) return;
      Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const TutorialScreen()));
    });
  }

  List<_Section> _sections(bool presidency, bool canApprove) => [
        _Section('received', 'Reçues', Icons.inbox_outlined, Icons.inbox_rounded,
            (_) => const TaskListScreen(key: ValueKey('received'), box: 'received'), title: 'Tâches reçues'),
        _Section('sent', 'Envoyées', Icons.outbox_outlined, Icons.outbox_rounded,
            (_) => const TaskListScreen(key: ValueKey('sent'), box: 'sent'), title: 'Tâches envoyées'),
        if (presidency)
          _Section('all', 'Club', Icons.groups_outlined, Icons.groups_rounded,
              (_) => const TaskListScreen(key: ValueKey('all'), box: 'all'), title: 'Toutes les tâches du club'),
        if (canApprove)
          _Section('approvals', 'Validations', Icons.how_to_reg_outlined, Icons.how_to_reg,
              (_) => const ApprovalsScreen(), title: 'Comptes à valider'),
        _Section('profile', 'Profil', Icons.person_outline, Icons.person, (_) => const ProfileScreen(), title: 'Mon profil'),
      ];

  void _newTask() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateTaskScreen()));

  /// Icône avec pastille du nombre de tâches non lues (onglet « Reçues »).
  Widget _icon(_Section s, IconData icon, int unread) {
    final child = Icon(icon);
    if (s.id != 'received' || unread == 0) return child;
    return Badge(label: Text(unread > 99 ? '99+' : '$unread'), child: child);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final sections = _sections(user?.isPresidency ?? false, user?.canApprove ?? false);
    final currentId = ref.watch(homeSectionProvider);
    final index = sections.indexWhere((s) => s.id == currentId).clamp(0, sections.length - 1);
    final section = sections[index];
    final unread = ref.watch(unreadCountProvider).asData?.value ?? 0;
    final size = context.screenSize;

    void select(int i) {
      ref.read(homeSectionProvider.notifier).go(sections[i].id);
      ref.invalidate(unreadCountProvider);
    }

    final page = Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (size == ScreenSize.phone) ...[const AppLogo(size: 30), const SizedBox(width: 10)],
          Flexible(child: Text(section.title ?? section.label, overflow: TextOverflow.ellipsis)),
          if (section.id == 'received' && unread > 0) ...[
            const SizedBox(width: 8),
            _UnreadPill(count: unread),
          ],
        ]),
      ),
      body: section.builder(context),
      floatingActionButton: section.id == 'profile'
          ? null
          : FloatingActionButton.extended(
              onPressed: _newTask,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Nouvelle tâche'),
            ),
      bottomNavigationBar: size == ScreenSize.phone
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: select,
              destinations: [
                for (final s in sections)
                  NavigationDestination(
                    icon: _icon(s, s.icon, unread),
                    selectedIcon: _icon(s, s.selectedIcon, unread),
                    label: s.label,
                  ),
              ],
            )
          : null,
    );

    if (size == ScreenSize.phone) return page;

    final extended = size == ScreenSize.desktop;
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: extended,
          selectedIndex: index,
          onDestinationSelected: select,
          labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              AppLogo(size: extended ? 48 : 36),
              if (extended) ...[
                const SizedBox(height: 6),
                const Text('C-Tech Tasks', style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ]),
          ),
          destinations: [
            for (final s in sections)
              NavigationRailDestination(
                icon: _icon(s, s.icon, unread),
                selectedIcon: _icon(s, s.selectedIcon, unread),
                label: Text(s.label),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: page),
      ]),
    );
  }
}

/// « 3 non lues » à côté du titre de la page Reçues.
class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count non lue${count > 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}
