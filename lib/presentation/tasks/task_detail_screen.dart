import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/comment.dart';
import '../../data/models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../common/common_widgets.dart';

/// Détail d'une tâche.
///  - L'ouvrir envoie l'accusé « vu ».
///  - Le destinataire coche « effectuée » (ne concerne que lui).
///  - L'auteur et la présidence voient qui a reçu / vu / effectué.
///  - Tout le monde peut commenter.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taskDetailProvider(taskId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tâche'),
        actions: [
          if (async.asData?.value case final task? when task.isMine || (me?.isPresidency ?? false))
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, task),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => MessageView(
          icon: Icons.error_outline,
          title: 'Tâche indisponible',
          message: e.toString(),
          action: 'Réessayer',
          onAction: () => ref.invalidate(taskDetailProvider(taskId)),
        ),
        data: (task) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(commentsProvider(taskId));
            ref.invalidate(taskDetailProvider(taskId));
            await ref.read(taskDetailProvider(taskId).future);
          },
          child: _Body(task: task),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la tâche ?'),
        content: Text('« ${task.title} » sera retirée pour tous les destinataires.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(taskRepositoryProvider).delete(task.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = context.isDesktop;
    final main = <Widget>[
      _Header(task: task),
      if (task.myState != null) ...[const SizedBox(height: 16), _DoneButton(task: task)],
      if (task.recipients.isNotEmpty || task.isMine) ...[const SizedBox(height: 20), _Receipts(task: task)],
    ];
    final comments = _Comments(taskId: task.id);

    // Desktop : détail à gauche, commentaires à droite.
    if (wide) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: ListView(children: main)),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: comments))),
          ),
        ]),
      );
    }
    return MaxWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [...main, const SizedBox(height: 20), Card(child: Padding(padding: const EdgeInsets.all(16), child: comments))],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);
    final color = AppColors.urgencyColor(task.urgency);
    return Card(
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: color, width: 4))),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          UrgencyBadge(urgency: task.urgency, label: task.urgencyLabel),
          const SizedBox(height: 12),
          Text(task.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(task.description!, style: const TextStyle(height: 1.5)),
          ],
          const Divider(height: 28),
          _line(Icons.person_outline, 'Rédigée par', '${task.creator.fullName} · ${task.creator.positionLabel}', muted),
          _line(Icons.apartment_rounded, 'Département', task.department.name, muted),
          _line(Icons.schedule, 'Envoyée le', DateFormatter.full(task.createdAt), muted),
          if (task.dueAt != null)
            _line(Icons.event_outlined, 'Échéance', DateFormatter.full(task.dueAt!), task.isOverdue ? AppColors.error : muted),
        ]),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: color))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Bouton « Marquer comme effectuée » / « Effectuée — annuler ».
class _DoneButton extends ConsumerStatefulWidget {
  const _DoneButton({required this.task});
  final Task task;

  @override
  ConsumerState<_DoneButton> createState() => _DoneButtonState();
}

class _DoneButtonState extends ConsumerState<_DoneButton> {
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() => _loading = true);
    try {
      final done = !(widget.task.myState?.isDone ?? false);
      await ref.read(taskRepositoryProvider).setDone(widget.task.id, done);
      ref.invalidate(taskDetailProvider(widget.task.id));
      ref.invalidate(taskListProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.task.myState?.isDone ?? false;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: done
          ? OutlinedButton.icon(
              onPressed: _loading ? null : _toggle,
              icon: const Icon(Icons.check_circle_rounded, color: AppColors.done),
              label: Text('Effectuée le ${DateFormatter.full(widget.task.myState!.doneAt!)} — annuler'),
            )
          : FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.done),
              onPressed: _loading ? null : _toggle,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: const Text('Marquer comme effectuée'),
            ),
    );
  }
}

/// Liste des accusés par destinataire (vue de l'auteur / de la présidence).
class _Receipts extends StatelessWidget {
  const _Receipts({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final s = task.stats;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Suivi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 8, children: [
            _stat('delivered', 'Reçue', s.delivered, s.total),
            _stat('seen', 'Vue', s.seen, s.total),
            _stat('done', 'Effectuée', s.done, s.total),
          ]),
          if (task.recipients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Aucun membre actif dans ce département pour le moment.', style: TextStyle(color: muted)),
            ),
          const SizedBox(height: 8),
          for (final r in task.recipients)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: InitialsAvatar(r.user?.initials ?? '?'),
              title: Text(r.user?.fullName ?? 'Membre'),
              subtitle: Text(_subtitle(r), style: TextStyle(color: muted, fontSize: 12)),
              trailing: ReceiptTicks(r.state, size: 22),
            ),
        ]),
      ),
    );
  }

  String _subtitle(Receipt r) => switch (r.state) {
        'done' => 'Effectuée ${DateFormatter.relative(r.doneAt!)}',
        'seen' => 'Vue ${DateFormatter.relative(r.seenAt!)}',
        'delivered' => 'Reçue ${DateFormatter.relative(r.deliveredAt!)}',
        _ => 'Envoyée, pas encore reçue',
      };

  Widget _stat(String state, String label, int value, int total) => Row(mainAxisSize: MainAxisSize.min, children: [
        ReceiptTicks(state),
        const SizedBox(width: 6),
        Text('$label : $value/$total', style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}

/// Fil de commentaires + champ de saisie.
class _Comments extends ConsumerStatefulWidget {
  const _Comments({required this.taskId});
  final int taskId;

  @override
  ConsumerState<_Comments> createState() => _CommentsState();
}

class _CommentsState extends ConsumerState<_Comments> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(taskRepositoryProvider).addComment(widget.taskId, text);
      _controller.clear();
      ref.invalidate(commentsProvider(widget.taskId));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(commentsProvider(widget.taskId));
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('Commentaires', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      async.when(
        loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('Commentaires indisponibles hors ligne.', style: TextStyle(color: muted)),
        data: (comments) => comments.isEmpty
            ? Text('Aucun commentaire. Soyez le premier !', style: TextStyle(color: muted))
            : Column(children: [for (final c in comments) _bubble(context, c)]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(hintText: 'Écrire un commentaire…', counterText: '', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Envoyer',
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded),
        ),
      ]),
    ]);
  }

  Widget _bubble(BuildContext context, Comment c) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: c.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: c.isMine ? AppColors.violet.withValues(alpha: 0.18) : scheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!c.isMine)
            Text(c.author.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.violetLight)),
          Text(c.body),
          const SizedBox(height: 2),
          Text(DateFormatter.relative(c.createdAt),
              style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.5))),
        ]),
      ),
    );
  }
}
