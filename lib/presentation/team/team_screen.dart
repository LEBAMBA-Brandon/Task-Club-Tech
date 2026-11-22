import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../approvals/approvals_screen.dart';
import '../chat/chat_screen.dart';
import '../common/common_widgets.dart';

/// Onglet « Équipe » (président, vice-président, responsables) :
///  - Membres  : suivi de chaque membre (tâches reçues, faites, pas ouvertes, dernière activité) ;
///    le président et le vice-président voient tout le club, un responsable son département ;
///  - Demandes : inscriptions à valider (mise à jour automatique, pastille du nombre en attente).
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

  @override
  void didUpdateWidget(covariant TeamScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) _tabs.animateTo(widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(countersProvider).approvalsPending;
    return Column(children: [
      TabBar(
        controller: _tabs,
        tabs: [
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
        child: TabBarView(controller: _tabs, children: const [_MembersTab(), ApprovalsScreen()]),
      ),
    ]);
  }
}

class _MembersTab extends ConsumerStatefulWidget {
  const _MembersTab();

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  int? _departmentId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final query = (departmentId: _departmentId, search: _search.isEmpty ? null : _search);
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
              value: _departmentId,
              hint: const Text('Tous les départements'),
              borderRadius: BorderRadius.circular(12),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Tous les départements')),
                for (final d in meta.departments) DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) => setState(() => _departmentId = v),
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
        ]),
      ),
    );
  }
}
