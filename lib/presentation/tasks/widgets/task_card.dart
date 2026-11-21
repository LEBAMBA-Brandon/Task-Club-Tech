import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/task.dart';
import '../../common/common_widgets.dart';

/// Carte d'une tâche dans une liste.
/// Bande colorée à gauche = urgence. En bas : accusés (mes coches ou les statistiques).
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.urgencyColor(task.urgency);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final done = task.myState?.isDone ?? false;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    UrgencyBadge(urgency: task.urgency, label: task.urgencyLabel),
                    const Spacer(),
                    Text(DateFormatter.relative(task.createdAt), style: TextStyle(color: muted, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(task.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    _Meta(icon: Icons.apartment_rounded, text: task.department.name),
                    _Meta(icon: Icons.person_outline, text: task.isMine ? 'Moi' : task.creator.fullName),
                    if (task.dueAt != null)
                      _Meta(
                        icon: Icons.event_outlined,
                        text: DateFormatter.full(task.dueAt!),
                        color: task.isOverdue ? AppColors.error : null,
                      ),
                    if (task.commentsCount > 0) _Meta(icon: Icons.chat_bubble_outline, text: '${task.commentsCount}'),
                  ]),
                  const SizedBox(height: 10),
                  _receipts(context, muted),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Destinataire : mes coches. Auteur : « vue par 3/5 · 1 effectuée ».
  Widget _receipts(BuildContext context, Color muted) {
    if (task.myState != null) {
      return Row(children: [
        ReceiptTicks(task.myState!.state, size: 16),
        const SizedBox(width: 6),
        Text(ReceiptTicks.label(task.myState!.state), style: TextStyle(color: muted, fontSize: 12)),
      ]);
    }
    final s = task.stats;
    return Row(children: [
      const ReceiptTicks('seen', size: 16),
      const SizedBox(width: 4),
      Text('${s.seen}/${s.total} vue${s.seen > 1 ? 's' : ''}', style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(width: 12),
      const ReceiptTicks('done', size: 16),
      const SizedBox(width: 4),
      Text('${s.done}/${s.total} effectuée${s.done > 1 ? 's' : ''}', style: TextStyle(color: muted, fontSize: 12)),
    ]);
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: c),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: c, fontSize: 12)),
    ]);
  }
}
