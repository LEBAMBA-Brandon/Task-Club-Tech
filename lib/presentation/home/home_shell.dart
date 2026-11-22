import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/push_notification_service.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../chat/chat_screen.dart';
import '../chat/conversations_screen.dart';
import '../common/common_widgets.dart';
import '../help/tutorial_screen.dart';
import '../profile/profile_screen.dart';
import '../tasks/create_task_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_list_screen.dart';
import '../team/team_screen.dart';

/// Une section de la navigation principale.
class _Section {
  const _Section(this.id, this.label, this.icon, this.selectedIcon, this.builder, {this.title, this.badge = 0});
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
  final String? title;

  /// Nombre affiché en pastille rouge (0 = pas de pastille).
  final int badge;
}

/// Coquille principale, responsive :
///  - smartphone : barre de navigation en bas ;
///  - tablette   : rail de navigation compact à gauche ;
///  - desktop    : rail étendu avec libellés.
///
/// Elle démarre aussi les mises à jour en direct (pastilles + listes), voir CountersController,
/// et branche les notifications Firebase (toucher une notification ouvre le bon écran).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  late final CountersController _counters = ref.read(countersProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _counters.start();

    final push = ref.read(pushNotificationServiceProvider);
    push.onSignal = (scope, data) {
      if (mounted) _counters.onServerSignal(scope, data);
    };
    push.onOpenTask = (id) async {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(taskId: id)));
      if (mounted) refreshTaskLists(ref);
    };
    push.onOpenConversation = (id) {
      if (!mounted) return;
      final known = ref.read(conversationsProvider).asData?.value.where((c) => c.id == id).firstOrNull;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChatScreen(conversationId: id, title: known?.title, subtitle: known?.subtitle),
      ));
    };
    push.onOpenApprovals = () {
      if (!mounted) return;
      ref.read(teamTabProvider.notifier).show('requests');
      ref.read(homeSectionProvider.notifier).go('team');
    };

    // Premier lancement : tutoriel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(devicePrefsProvider).tutorialSeen) return;
      Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const TutorialScreen()));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _counters.stop();
    super.dispose();
  }

  /// Retour dans l'application : tout est rafraîchi ; en arrière-plan : on arrête d'interroger le serveur.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _counters.start();
      _counters.refreshAll();
    } else if (state == AppLifecycleState.paused) {
      _counters.stop();
    }
  }

  List<_Section> _sections(bool canFollowTeam) {
    final counters = ref.watch(countersProvider);
    final user = ref.watch(currentUserProvider);
    return [
      _Section('received', 'Reçues', Icons.inbox_outlined, Icons.inbox_rounded,
          (_) => const TaskListScreen(key: ValueKey('received'), box: 'received'),
          title: 'Tâches reçues', badge: counters.tasksUnread),
      _Section('sent', 'Envoyées', Icons.outbox_outlined, Icons.outbox_rounded, (_) => const SentTasksSection(),
          title: 'Tâches envoyées'),
      _Section('chat', 'Messages', Icons.chat_bubble_outline, Icons.chat_bubble_rounded, (_) => const ChatSection(),
          badge: counters.messagesUnread),
      if (canFollowTeam)
        _Section('team', 'Équipe', Icons.groups_outlined, Icons.groups_rounded,
            (_) => TeamScreen(initialTab: ref.watch(teamTabProvider)),
            title: (user?.isPresidency ?? false) ? 'Administration du club' : 'Suivi de l\'équipe',
            badge: counters.approvalsPending),
      _Section('profile', 'Profil', Icons.person_outline, Icons.person, (_) => const ProfileScreen(), title: 'Mon profil'),
    ];
  }

  void _newTask() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateTaskScreen()));

  /// Icône avec pastille rouge si [badge] > 0.
  Widget _icon(IconData icon, int badge) {
    final child = Icon(icon);
    if (badge == 0) return child;
    return Badge(label: Text(badge > 99 ? '99+' : '$badge'), child: child);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final sections = _sections(user?.canApprove ?? false);
    final currentId = ref.watch(homeSectionProvider);
    final index = sections.indexWhere((s) => s.id == currentId).clamp(0, sections.length - 1);
    final section = sections[index];
    final size = context.screenSize;
    final showFab = section.id == 'received' || section.id == 'sent';

    void select(int i) {
      ref.read(homeSectionProvider.notifier).go(sections[i].id);
      if (sections[i].id == 'team' && sections[i].badge > 0) ref.read(teamTabProvider.notifier).show('requests');
      _counters.refresh();
    }

    final page = Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (size == ScreenSize.phone) ...[const AppLogo(size: 30), const SizedBox(width: 10)],
          Flexible(child: Text(section.title ?? section.label, overflow: TextOverflow.ellipsis)),
          if (section.id == 'received' && section.badge > 0) ...[
            const SizedBox(width: 8),
            _UnreadPill(count: section.badge, noun: 'non lue'),
          ],
        ]),
      ),
      body: section.builder(context),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _newTask,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Nouvelle tâche'),
            )
          : null,
      bottomNavigationBar: size == ScreenSize.phone
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: select,
              destinations: [
                for (final s in sections)
                  NavigationDestination(
                    icon: _icon(s.icon, s.badge),
                    selectedIcon: _icon(s.selectedIcon, s.badge),
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
                icon: _icon(s.icon, s.badge),
                selectedIcon: _icon(s.selectedIcon, s.badge),
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

/// Onglet « Envoyées » : la présidence peut basculer sur toutes les tâches du club.
class SentTasksSection extends ConsumerStatefulWidget {
  const SentTasksSection({super.key});

  @override
  ConsumerState<SentTasksSection> createState() => _SentTasksSectionState();
}

class _SentTasksSectionState extends ConsumerState<SentTasksSection> {
  bool _club = false;

  @override
  Widget build(BuildContext context) {
    final presidency = ref.watch(currentUserProvider)?.isPresidency ?? false;
    final list = TaskListScreen(key: ValueKey(_club ? 'all' : 'sent'), box: _club ? 'all' : 'sent');
    if (!presidency) return list;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Mes tâches'), icon: Icon(Icons.outbox_rounded)),
            ButtonSegment(value: true, label: Text('Tout le club'), icon: Icon(Icons.groups_rounded)),
          ],
          selected: {_club},
          onSelectionChanged: (s) => setState(() => _club = s.first),
        ),
      ),
      Expanded(child: list),
    ]);
  }
}

/// « 3 non lues » à côté du titre de la page.
class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count, required this.noun});
  final int count;
  final String noun;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count $noun${count > 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}
