import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/department_overview.dart';
import '../../data/models/member.dart';
import '../../data/models/meta.dart';
import '../../core/network/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../approvals/approvals_screen.dart';
import '../chat/chat_screen.dart';
import '../common/common_widgets.dart';

/// Onglet « Équipe ».
///
/// Président et vice-président = ADMINISTRATEURS du système :
///  - Départements : tableau de bord de tous les départements ;
///  - Membres      : tous les membres du club, avec actions (changer de département / poste, suspendre) ;
///  - Demandes     : inscriptions à valider.
/// Responsable : Membres (son département seulement) + Demandes (membres de son département).
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key, this.initialTab = 'members'});

  /// departments | members | requests
  final String initialTab;

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> with TickerProviderStateMixin {
  TabController? _tabs;
  List<String> _ids = const [];

  /// (Re)crée le TabController quand la liste des onglets change (rôle de l'utilisateur).
  void _syncTabs(List<String> ids) {
    if (_tabs != null && _ids.join() == ids.join()) return;
    _tabs?.dispose();
    _ids = ids;
    final index = ids.indexOf(widget.initialTab);
    _tabs = TabController(length: ids.length, vsync: this, initialIndex: index < 0 ? 0 : index);
  }

  @override
  void didUpdateWidget(covariant TeamScreen old) {
    super.didUpdateWidget(old);
    final index = _ids.indexOf(widget.initialTab);
    if (old.initialTab != widget.initialTab && index >= 0) _tabs?.animateTo(index);
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(currentUserProvider)?.isPresidency ?? false;
    final pending = ref.watch(countersProvider).approvalsPending;
    _syncTabs(admin ? const ['departments', 'members', 'requests'] : const ['members', 'requests']);

    return Column(children: [
      TabBar(
        controller: _tabs,
        tabs: [
          if (admin) const Tab(text: 'Départements'),
          const Tab(text: 'Membres'),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Demandes'),
              if (pending > 0) ...[const SizedBox(width: 6), Badge(label: Text('$pending'))],
            ]),
          ),
        ],
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          if (admin)
            _DepartmentsTab(onOpen: (id) {
              // Toucher un département : liste de ses membres.
              ref.read(memberDepartmentFilterProvider.notifier).set(id);
              _tabs?.animateTo(_ids.indexOf('members'));
            }),
          const _MembersTab(),
          const ApprovalsScreen(),
        ]),
      ),
    ]);
  }
}

/// Tableau de bord des départements (administrateurs).
class _DepartmentsTab extends ConsumerWidget {
  const _DepartmentsTab({required this.onOpen});
  final void Function(int departmentId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(departmentsOverviewProvider);
    final columns = context.isDesktop ? 3 : (context.isPhone ? 1 : 2);

    return AutoRefresh(
      every: const Duration(seconds: 30),
      onTick: () => ref.invalidate(departmentsOverviewProvider),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(departmentsOverviewProvider);
          await ref.read(departmentsOverviewProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            MessageView(icon: Icons.error_outline, title: 'Tableau de bord indisponible', message: '$e',
                action: 'Réessayer', onAction: () => ref.invalidate(departmentsOverviewProvider)),
          ]),
          data: (items) {
            final totalMembers = items.fold<int>(0, (a, d) => a + d.membersActive);
            final totalPending = items.fold<int>(0, (a, d) => a + d.membersPending);
            final totalTasks = items.fold<int>(0, (a, d) => a + d.tasksCount);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _Kpi(icon: Icons.groups_rounded, value: '$totalMembers', label: 'membres actifs', color: AppColors.violet),
                  _Kpi(icon: Icons.how_to_reg, value: '$totalPending', label: 'demandes en attente', color: AppColors.urgencyColor('yellow')),
                  _Kpi(icon: Icons.task_alt_rounded, value: '$totalTasks', label: 'tâches envoyées', color: AppColors.blue),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Text('${items.length} départements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nouveau département'),
                    onPressed: () => _DepartmentAdmin.create(context, ref),
                  ),
                ]),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, c) {
                  final width = (c.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final d in items)
                      SizedBox(
                        width: width,
                        child: _DepartmentCard(
                          department: d,
                          onTap: () => onOpen(d.id),
                          onRename: () => _DepartmentAdmin.rename(context, ref, d),
                          onDelete: d.isPresidency ? null : () => _DepartmentAdmin.delete(context, ref, d),
                        ),
                      ),
                  ]);
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
        ]),
      );
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department, required this.onTap, required this.onRename, this.onDelete});
  final DepartmentOverview department;
  final VoidCallback onTap;
  final VoidCallback onRename;

  /// null pour la Présidence (non supprimable).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final d = department;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              if (d.membersPending > 0)
                Badge(label: Text('${d.membersPending} à valider'), backgroundColor: AppColors.urgencyColor('yellow')),
              // Menu d'administration du département.
              PopupMenuButton<String>(
                tooltip: 'Gérer le département',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) => action == 'rename' ? onRename() : onDelete?.call(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Renommer'))),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: AppColors.error),
                        title: Text('Supprimer', style: TextStyle(color: AppColors.error)),
                      ),
                    ),
                ],
              ),
            ]),
            const SizedBox(height: 4),
            Text(d.responsable == null ? 'Pas de responsable' : 'Responsable : ${d.responsable}',
                style: TextStyle(color: d.responsable == null ? AppColors.error : muted, fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.person_outline, size: 16, color: muted),
              const SizedBox(width: 4),
              Text('${d.membersActive} membre${d.membersActive > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 14),
              Icon(Icons.task_alt_rounded, size: 16, color: muted),
              const SizedBox(width: 4),
              Text('${d.tasksCount} tâche${d.tasksCount > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12)),
              if (d.membersSuspended > 0) ...[
                const SizedBox(width: 14),
                Text('${d.membersSuspended} suspendu${d.membersSuspended > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error)),
              ],
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: d.completion,
                minHeight: 6,
                backgroundColor: AppColors.violet.withValues(alpha: 0.12),
                color: AppColors.done,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              d.receiptsTotal == 0
                  ? 'Aucune tâche reçue'
                  : '${(d.completion * 100).round()} % effectué · ${d.receiptsUnseen} non ouverte${d.receiptsUnseen > 1 ? 's' : ''}',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MembersTab extends ConsumerStatefulWidget {
  const _MembersTab();

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final departmentId = ref.watch(memberDepartmentFilterProvider);
    final query = (departmentId: departmentId, search: _search.isEmpty ? null : _search);
    final async = ref.watch(membersProvider(query));
    final meta = ref.watch(metaProvider).asData?.value;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 260,
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher', isDense: true),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          // Filtre par département : seulement pour la présidence (le responsable ne voit que le sien).
          if ((me?.isPresidency ?? false) && meta != null)
            DropdownButton<int?>(
              value: departmentId,
              hint: const Text('Tous les départements'),
              borderRadius: BorderRadius.circular(12),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Tous les départements')),
                for (final d in meta.departments) DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) => ref.read(memberDepartmentFilterProvider.notifier).set(v),
            )
          else if (me?.department != null)
            Chip(avatar: const Icon(Icons.apartment, size: 16), label: Text(me!.department!.name)),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(membersProvider(query));
            await ref.read(membersProvider(query).future);
          },
          child: async.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              MessageView(icon: Icons.error_outline, title: 'Membres indisponibles', message: '$e',
                  action: 'Réessayer', onAction: () => ref.invalidate(membersProvider(query))),
            ]),
            data: (members) => members.isEmpty
                ? ListView(children: const [MessageView(icon: Icons.groups_outlined, title: 'Aucun membre')])
                : _MemberGrid(members: members),
          ),
        ),
      ),
    ]);
  }
}

class _MemberGrid extends StatelessWidget {
  const _MemberGrid({required this.members});
  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    final columns = context.isDesktop ? 3 : (context.isPhone ? 1 : 2);
    final active = members.where((m) => m.user.status == 'active').length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text('$active membre${active > 1 ? 's' : ''} actif${active > 1 ? 's' : ''} sur ${members.length}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final width = (c.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final m in members) SizedBox(width: width, child: _MemberCard(member: m)),
          ]);
        }),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) {
    final u = member.user;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final (statusLabel, statusColor) = switch (u.status) {
      'active' => ('Actif', AppColors.done),
      'pending_approval' => ('À valider', AppColors.urgencyColor('yellow')),
      'pending_verification' => ('E-mail non confirmé', AppColors.tickGrey),
      'suspended' => ('Suspendu', AppColors.error),
      _ => (u.status, AppColors.tickGrey),
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              InitialsAvatar(u.initials, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  Text('${u.positionLabel} · ${u.department?.name ?? ''}',
                      style: TextStyle(color: muted, fontSize: 12), overflow: TextOverflow.ellipsis),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            // Barre de progression : tâches effectuées / reçues.
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: member.completion,
                minHeight: 6,
                backgroundColor: AppColors.violet.withValues(alpha: 0.12),
                color: AppColors.done,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('${member.tasksDone}/${member.tasksTotal} effectuées', style: const TextStyle(fontSize: 12)),
              const Spacer(),
              if (member.tasksUnseen > 0)
                Text('${member.tasksUnseen} non ouverte${member.tasksUnseen > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text(
              member.lastActiveAt == null ? 'Jamais connecté' : 'Actif ${DateFormatter.relative(member.lastActiveAt!)}',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ]),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _MemberSheet(member: member),
      );
}

/// Détail d'un membre + bouton « Envoyer un message ».
class _MemberSheet extends ConsumerWidget {
  const _MemberSheet({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = member.user;
    final me = ref.watch(currentUserProvider);
    Widget stat(String value, String label, Color color) => Expanded(
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ]),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InitialsAvatar(u.initials, radius: 32),
          const SizedBox(height: 10),
          Text(u.fullName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text('${u.positionLabel} · ${u.department?.name ?? ''}', style: const TextStyle(color: AppColors.violetLight)),
          Text(u.email),
          const SizedBox(height: 18),
          Row(children: [
            stat('${member.tasksTotal}', 'reçues', AppColors.blue),
            stat('${member.tasksDone}', 'effectuées', AppColors.done),
            stat('${member.tasksTotal - member.tasksDone}', 'à faire', AppColors.urgencyColor('yellow')),
            stat('${member.tasksUnseen}', 'non ouvertes', AppColors.error),
          ]),
          const SizedBox(height: 18),
          if (u.status == 'active' && u.id != me?.id)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Envoyer un message'),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  try {
                    final c = await ref.read(chatRepositoryProvider).openDirect(u.id);
                    navigator.pop();
                    await navigator.push(MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(conversationId: c.id, title: c.title, subtitle: c.subtitle),
                    ));
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ),
          // ----- Actions d'administration (président / vice-président)
          if ((me?.isPresidency ?? false) && u.status != 'pending_approval' && u.status != 'pending_verification') ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Département / poste'),
                  onPressed: () => _edit(context, ref),
                ),
              ),
              if (u.id != me?.id) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: u.status == 'suspended' ? AppColors.done : AppColors.error,
                    ),
                    icon: Icon(u.status == 'suspended' ? Icons.lock_open_rounded : Icons.block_rounded),
                    label: Text(u.status == 'suspended' ? 'Réactiver' : 'Suspendre'),
                    onPressed: () => _toggleSuspension(context, ref),
                  ),
                ),
              ],
            ]),
            // Suppression définitive (pas sur soi-même ; le VP ne supprime pas le président).
            if (u.id != me?.id && !(u.position == 'president' && me?.position != 'president'))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Supprimer le compte'),
                  onPressed: () => _deleteMember(context, ref),
                ),
              ),
          ],
        ]),
      ),
    );
  }

  /// Après une modification : listes et tableau de bord à jour, fiche fermée, message.
  void _done(BuildContext context, WidgetRef ref, String message) {
    ref.invalidate(membersProvider);
    ref.invalidate(departmentsOverviewProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Suppression définitive : ses tâches, commentaires et messages restent, signés « Ancien membre ».
  Future<void> _deleteMember(BuildContext context, WidgetRef ref) async {
    final u = member.user;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer le compte de ${u.fullName} ?'),
        content: const Text(
          'Cette action est définitive : la personne ne pourra plus se connecter et devra se réinscrire. '
          'Les tâches, commentaires et messages qu\'elle a écrits restent visibles, signés « Ancien membre ». '
          'Pour un départ temporaire, préférez « Suspendre ».',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(teamRepositoryProvider).deleteMember(u.id);
      if (context.mounted) _done(context, ref, 'Compte de ${u.fullName} supprimé.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  /// Suspendre (déconnecte le membre de tous ses appareils) ou réactiver un compte.
  Future<void> _toggleSuspension(BuildContext context, WidgetRef ref) async {
    final u = member.user;
    final suspend = u.status != 'suspended';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(suspend ? 'Suspendre ${u.fullName} ?' : 'Réactiver ${u.fullName} ?'),
        content: Text(suspend
            ? 'Il sera déconnecté immédiatement et ne pourra plus se connecter tant que vous ne l\'aurez pas réactivé.'
            : 'Il pourra de nouveau se connecter et recevoir des tâches.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: suspend ? AppColors.error : AppColors.done),
            onPressed: () => Navigator.pop(context, true),
            child: Text(suspend ? 'Suspendre' : 'Réactiver'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(teamRepositoryProvider).updateMember(u.id, status: suspend ? 'suspended' : 'active');
      if (context.mounted) _done(context, ref, suspend ? 'Compte suspendu.' : 'Compte réactivé.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  /// Changer le département et/ou le poste d'un membre.
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final meta = await ref.read(metaProvider.future);
    if (!context.mounted) return;
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _EditMemberDialog(member: member, meta: meta),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(teamRepositoryProvider).updateMember(member.user.id, departmentId: result.$1, position: result.$2);
      if (context.mounted) _done(context, ref, 'Membre mis à jour.');
    } on ApiException catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

/// Boîte de dialogue « Département / poste » (administrateurs).
class _EditMemberDialog extends StatefulWidget {
  const _EditMemberDialog({required this.member, required this.meta});
  final Member member;
  final Meta meta;

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late int? _departmentId = widget.member.user.department?.id;
  late String? _position = widget.member.user.position;

  @override
  Widget build(BuildContext context) {
    final positions = _departmentId == null ? const <Option>[] : (widget.meta.positions[_departmentId] ?? const <Option>[]);
    // Le poste actuel n'existe peut-être pas dans le nouveau département.
    final positionValue = positions.any((p) => p.value == _position) ? _position : null;

    return AlertDialog(
      title: Text(widget.member.user.fullName),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(
          initialValue: _departmentId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Département'),
          items: [for (final d in widget.meta.departments) DropdownMenuItem(value: d.id, child: Text(d.name))],
          onChanged: (v) => setState(() => _departmentId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('position-$_departmentId'),
          initialValue: positionValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Poste'),
          items: [for (final p in positions) DropdownMenuItem(value: p.value, child: Text(p.label))],
          onChanged: (v) => setState(() => _position = v),
        ),
        const SizedBox(height: 10),
        const Text(
          'Un seul président, un seul vice-président et un seul responsable par département.',
          style: TextStyle(fontSize: 12),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _departmentId == null || positionValue == null
              ? null
              : () => Navigator.pop(context, (_departmentId!, positionValue)),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Actions d'administration sur les départements (président / vice-président).
class _DepartmentAdmin {
  _DepartmentAdmin._();

  /// Après un changement : tableau de bord, listes déroulantes et membres à jour.
  static void _refresh(WidgetRef ref) {
    ref.invalidate(departmentsOverviewProvider);
    ref.invalidate(metaProvider);
    ref.invalidate(membersProvider);
    ref.invalidate(conversationsProvider);
  }

  /// Petite boîte de saisie du nom.
  static Future<String?> _askName(BuildContext context, {required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nom du département'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
  }

  static Future<void> create(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context, title: 'Nouveau département');
    if (name == null || name.length < 2 || !context.mounted) return;
    try {
      await ref.read(teamRepositoryProvider).createDepartment(name);
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Département « $name » créé.')));
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  static Future<void> rename(BuildContext context, WidgetRef ref, DepartmentOverview d) async {
    final name = await _askName(context, title: 'Renommer « ${d.name} »', initial: d.name);
    if (name == null || name.length < 2 || name == d.name || !context.mounted) return;
    try {
      await ref.read(teamRepositoryProvider).renameDepartment(d.id, name);
      _refresh(ref);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  static Future<void> delete(BuildContext context, WidgetRef ref, DepartmentOverview d) async {
    final members = d.membersActive + d.membersPending + d.membersSuspended;
    if (members > 0) {
      // Le serveur refuserait : on explique tout de suite quoi faire.
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Impossible de supprimer « ${d.name} »'),
          content: Text('Ce département compte encore $members membre${members > 1 ? 's' : ''}. '
              'Déplacez-les vers un autre département (ou supprimez leur compte) depuis l\'onglet Membres, puis réessayez.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Compris'))],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer « ${d.name} » ?'),
        content: Text(d.tasksCount == 0
            ? 'Le département et son groupe de discussion seront supprimés.'
            : 'Le département, son groupe de discussion et ses ${d.tasksCount} tâche${d.tasksCount > 1 ? 's' : ''} '
                'seront supprimés définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(teamRepositoryProvider).deleteDepartment(d.id);
      if (ref.read(memberDepartmentFilterProvider) == d.id) {
        ref.read(memberDepartmentFilterProvider.notifier).set(null);
      }
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Département « ${d.name} » supprimé.')));
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
