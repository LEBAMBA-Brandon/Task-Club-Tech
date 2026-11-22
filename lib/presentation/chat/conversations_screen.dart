import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/chat.dart';
import '../../data/models/user.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../common/common_widgets.dart';
import 'chat_screen.dart';

/// Onglet « Messages ».
///  - smartphone / tablette : la liste, et la conversation s'ouvre par-dessus ;
///  - grand écran : liste à gauche, conversation à droite.
class ChatSection extends ConsumerStatefulWidget {
  const ChatSection({super.key});

  @override
  ConsumerState<ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends ConsumerState<ChatSection> {
  Conversation? _selected;

  Future<void> _open(Conversation c) async {
    if (context.isDesktop) {
      setState(() => _selected = c);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatScreen(conversationId: c.id, title: c.title, subtitle: c.subtitle),
    ));
  }

  /// Choisir un membre dans l'annuaire puis ouvrir la conversation privée.
  Future<void> _newConversation() async {
    final user = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DirectoryPicker(),
    );
    if (user == null || !mounted) return;
    try {
      final conversation = await ref.read(chatRepositoryProvider).openDirect(user.id);
      ref.invalidate(conversationsProvider);
      if (mounted) await _open(conversation);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _ConversationList(onOpen: _open, onNew: _newConversation, selectedId: _selected?.id);
    if (!context.isDesktop) return list;

    return Row(children: [
      SizedBox(width: 360, child: list),
      const VerticalDivider(width: 1),
      Expanded(
        child: _selected == null
            ? const MessageView(
                icon: Icons.forum_outlined,
                title: 'Choisissez une conversation',
                message: 'ou démarrez-en une nouvelle avec le bouton « Nouveau message ».',
              )
            : ChatScreen(
                key: ValueKey(_selected!.id),
                conversationId: _selected!.id,
                title: _selected!.title,
                subtitle: _selected!.subtitle,
                embedded: true,
              ),
      ),
    ]);
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList({required this.onOpen, required this.onNew, this.selectedId});
  final void Function(Conversation) onOpen;
  final VoidCallback onNew;
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider);

    return Stack(children: [
      RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conversationsProvider);
          await ref.read(conversationsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            MessageView(
              icon: Icons.wifi_off_rounded,
              title: 'Messagerie indisponible',
              message: '$e',
              action: 'Réessayer',
              onAction: () => ref.invalidate(conversationsProvider),
            ),
          ]),
          data: (items) => items.isEmpty
              ? ListView(children: const [
                  MessageView(icon: Icons.forum_outlined, title: 'Aucune conversation', message: 'Écrivez à un membre du club.'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
                  itemBuilder: (_, i) => _ConversationTile(
                    conversation: items[i],
                    selected: items[i].id == selectedId,
                    onTap: () => onOpen(items[i]),
                  ),
                ),
        ),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton.extended(
          heroTag: 'new-message',
          onPressed: onNew,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Nouveau message'),
        ),
      ),
    ]);
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap, this.selected = false});
  final Conversation conversation;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unreadCount > 0;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final last = c.lastMessage;
    final preview = last == null
        ? (c.isGroup ? 'Groupe du département' : 'Nouvelle conversation')
        : '${last.isMine ? 'Vous : ' : (c.isGroup ? '${last.author?.firstName ?? ''} : ' : '')}${last.body}';

    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.violet.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: c.isGroup
          ? const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.blue,
              child: Icon(Icons.groups_rounded, color: Colors.white),
            )
          : InitialsAvatar(c.otherUser?.initials ?? '?', radius: 22),
      title: Text(c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
      subtitle: Text(preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: unread ? null : muted, fontWeight: unread ? FontWeight.w600 : null)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(DateFormatter.relative(c.updatedAt),
            style: TextStyle(fontSize: 11, color: unread ? AppColors.violet : muted)),
        const SizedBox(height: 4),
        if (unread)
          Badge(label: Text('${c.unreadCount}'), backgroundColor: AppColors.violet)
        else
          const SizedBox(height: 16),
      ]),
      onTap: onTap,
    );
  }
}

/// Annuaire : recherche d'un membre pour lui écrire.
class _DirectoryPicker extends ConsumerStatefulWidget {
  const _DirectoryPicker();

  @override
  ConsumerState<_DirectoryPicker> createState() => _DirectoryPickerState();
}

class _DirectoryPickerState extends ConsumerState<_DirectoryPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(directoryProvider(_search));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(children: [
        const SizedBox(height: 12),
        Text('Nouveau message', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher un membre'),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
        ),
        Expanded(
          child: async.when(
            // Pendant la frappe, on garde l'affichage précédent (pas de clignotement).
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => MessageView(icon: Icons.error_outline, title: 'Annuaire indisponible', message: '$e'),
            data: (users) => users.isEmpty
                ? const MessageView(icon: Icons.person_search_outlined, title: 'Aucun membre trouvé')
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, i) {
                      final u = users[i];
                      return ListTile(
                        leading: InitialsAvatar(u.initials),
                        title: Text(u.fullName),
                        subtitle: Text('${u.positionLabel} · ${u.department?.name ?? ''}'),
                        onTap: () => Navigator.pop(context, u),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}
