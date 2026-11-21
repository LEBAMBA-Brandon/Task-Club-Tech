import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/push_notification_service.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../approvals/approvals_screen.dart';
import '../common/common_widgets.dart';
import '../profile/profile_screen.dart';
import '../tasks/create_task_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_list_screen.dart';

/// Une section de la navigation principale.
class _Section {
  const _Section(this.label, this.icon, this.selectedIcon, this.builder, {this.title});
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
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Notifications : clic -> ouvre la tâche ; réception -> rafraîchit les listes.
    final push = ref.read(pushNotificationServiceProvider);
    push.onOpenTask = (id) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(taskId: id)));
    };
    push.onMessage = () {
      if (mounted) refreshTaskLists(ref);
    };
  }

  List<_Section> _sections(bool presidency, bool canApprove) => [
        _Section('Reçues', Icons.inbox_outlined, Icons.inbox_rounded,
            (_) => const TaskListScreen(key: ValueKey('received'), box: 'received'), title: 'Tâches reçues'),
        _Section('Envoyées', Icons.outbox_outlined, Icons.outbox_rounded,
            (_) => const TaskListScreen(key: ValueKey('sent'), box: 'sent'), title: 'Tâches envoyées'),
        if (presidency)
          _Section('Club', Icons.groups_outlined, Icons.groups_rounded,
              (_) => const TaskListScreen(key: ValueKey('all'), box: 'all'), title: 'Toutes les tâches du club'),
        if (canApprove)
          _Section('Validations', Icons.how_to_reg_outlined, Icons.how_to_reg,
              (_) => const ApprovalsScreen(), title: 'Comptes à valider'),
        _Section('Profil', Icons.person_outline, Icons.person, (_) => const ProfileScreen(), title: 'Mon profil'),
      ];

  void _newTask() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateTaskScreen()));

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final sections = _sections(user?.isPresidency ?? false, user?.canApprove ?? false);
    final index = _index.clamp(0, sections.length - 1);
    final section = sections[index];
    final size = context.screenSize;

    final fab = FloatingActionButton.extended(
      onPressed: _newTask,
      icon: const Icon(Icons.add_task_rounded),
      label: const Text('Nouvelle tâche'),
    );

    final page = Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (size == ScreenSize.phone) ...[const AppLogo(size: 30), const SizedBox(width: 10)],
          Flexible(child: Text(section.title ?? section.label, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: section.builder(context),
      floatingActionButton: fab,
      bottomNavigationBar: size == ScreenSize.phone
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final s in sections)
                  NavigationDestination(icon: Icon(s.icon), selectedIcon: Icon(s.selectedIcon), label: s.label),
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
          onDestinationSelected: (i) => setState(() => _index = i),
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
              NavigationRailDestination(icon: Icon(s.icon), selectedIcon: Icon(s.selectedIcon), label: Text(s.label)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: page),
      ]),
    );
  }
}
