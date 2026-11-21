import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/user.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../common/common_widgets.dart';

/// Validation des nouveaux comptes.
/// Président / vice-président : tous les comptes. Responsable : les membres de son département.
class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvalsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(approvalsProvider.future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          MessageView(icon: Icons.error_outline, title: 'Chargement impossible', message: '$e',
              action: 'Réessayer', onAction: () => ref.invalidate(approvalsProvider)),
        ]),
        data: (users) => users.isEmpty
            ? ListView(children: const [
                MessageView(
                  icon: Icons.how_to_reg_rounded,
                  title: 'Aucune demande en attente',
                  message: 'Les nouvelles inscriptions à valider apparaîtront ici.',
                ),
              ])
            : MaxWidth(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ApprovalTile(user: users[i]),
                ),
              ),
      ),
    );
  }
}

class _ApprovalTile extends ConsumerStatefulWidget {
  const _ApprovalTile({required this.user});
  final AppUser user;

  @override
  ConsumerState<_ApprovalTile> createState() => _ApprovalTileState();
}

class _ApprovalTileState extends ConsumerState<_ApprovalTile> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(taskRepositoryProvider);
      approve ? await repo.approve(widget.user.id) : await repo.reject(widget.user.id);
      ref.invalidate(approvalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? '${widget.user.fullName} peut maintenant se connecter.' : 'Demande refusée.'),
        ));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              InitialsAvatar(u.initials, radius: 22),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(u.email, style: const TextStyle(fontSize: 12)),
                Text('${u.positionLabel} · ${u.department?.name ?? ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.violetLight)),
              ]),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: _busy ? null : () => _decide(false),
                child: const Text('Refuser'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _busy ? null : () => _decide(true), child: const Text('Valider')),
            ]),
          ],
        ),
      ),
    );
  }
}
