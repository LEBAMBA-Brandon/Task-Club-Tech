import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';
import '../../providers/data_providers.dart';
import '../common/common_widgets.dart';
import 'task_detail_screen.dart';
import 'widgets/task_card.dart';

/// Liste de tâches : « received » (reçues), « sent » (envoyées) ou « all » (présidence).
/// Filtres : urgence + (pour les reçues) à faire / effectuées.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, required this.box});
  final String box;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  String? _urgency;
  String? _state;

  TaskQuery get _query => (box: widget.box, urgency: _urgency, state: _state);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taskListProvider(_query));

    return Column(children: [
      _Filters(
        urgency: _urgency,
        state: _state,
        showState: widget.box == 'received',
        onUrgency: (v) => setState(() => _urgency = v),
        onState: (v) => setState(() => _state = v),
      ),
      Expanded(
        child: AutoRefresh(
          // Liste à jour toutes les 20 s (en plus des signaux Firebase instantanés).
          every: const Duration(seconds: 20),
          onTick: () => ref.invalidate(taskListProvider(_query)),
          child: RefreshIndicator(
          onRefresh: () async {
            ref.read(countersProvider.notifier).refresh();
            ref.invalidate(taskListProvider(_query));
            await ref.read(taskListProvider(_query).future);
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              MessageView(
                icon: Icons.wifi_off_rounded,
                title: 'Chargement impossible',
                message: e.toString(),
                action: 'Réessayer',
                onAction: () => ref.invalidate(taskListProvider(_query)),
              ),
            ]),
            data: (page) => _list(page),
          ),
        ),
        ),
      ),
    ]);
  }

  Widget _list(TaskPage page) {
    if (page.tasks.isEmpty) {
      return ListView(children: [
        if (page.fromCache) const OfflineBanner(),
        MessageView(
          icon: widget.box == 'sent' ? Icons.outbox_rounded : Icons.inbox_rounded,
          title: widget.box == 'sent' ? 'Aucune tâche envoyée' : 'Aucune tâche pour le moment',
          message: widget.box == 'sent' ? 'Créez une tâche avec le bouton « Nouvelle tâche ».' : 'Vous serez notifié dès qu\'une tâche arrive.',
        ),
      ]);
    }

    return LayoutBuilder(builder: (context, constraints) {
      // 1 colonne sur smartphone / tablette, 2 sur grand écran.
      final columns = constraints.maxWidth >= 1000 ? 2 : 1;
      final rows = <List<Task>>[];
      for (var i = 0; i < page.tasks.length; i += columns) {
        rows.add(page.tasks.sublist(i, (i + columns).clamp(0, page.tasks.length)));
      }
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: rows.length + (page.fromCache ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (page.fromCache && index == 0) return const OfflineBanner();
          final row = rows[index - (page.fromCache ? 1 : 0)];
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var j = 0; j < columns; j++) ...[
              if (j > 0) const SizedBox(width: 12),
              Expanded(
                child: j < row.length
                    ? TaskCard(task: row[j], onTap: () => _open(row[j].id))
                    : const SizedBox.shrink(),
              ),
            ],
          ]);
        },
      );
    });
  }

  Future<void> _open(int id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(taskId: id)));
    if (mounted) refreshTaskLists(ref);
  }
}

/// Puces de filtre.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.urgency,
    required this.state,
    required this.showState,
    required this.onUrgency,
    required this.onState,
  });

  final String? urgency;
  final String? state;
  final bool showState;
  final ValueChanged<String?> onUrgency;
  final ValueChanged<String?> onState;

  static const _urgencies = {'green': 'Flexible', 'blue': 'Normale', 'yellow': 'Importante', 'red': 'Urgente'};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(children: [
        if (showState) ...[
          _chip(context, 'Toutes', state == null, () => onState(null)),
          _chip(context, 'À faire', state == 'todo', () => onState('todo')),
          _chip(context, 'Effectuées', state == 'done', () => onState('done')),
          const SizedBox(height: 24, child: VerticalDivider(width: 20)),
        ],
        for (final e in _urgencies.entries)
          _chip(
            context,
            e.value,
            urgency == e.key,
            () => onUrgency(urgency == e.key ? null : e.key),
            color: AppColors.urgencyColor(e.key),
          ),
      ]),
    );
  }

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback onTap, {Color? color}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          avatar: color == null ? null : CircleAvatar(backgroundColor: color, radius: 5),
          showCheckmark: color == null,
          selectedColor: (color ?? AppColors.violet).withValues(alpha: 0.2),
        ),
      );
}
