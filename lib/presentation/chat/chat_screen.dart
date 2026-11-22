import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/push_notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../data/models/chat.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../common/common_widgets.dart';

/// Conversation (privée ou groupe de département).
///
/// Temps réel : les nouveaux messages sont récupérés toutes les 3 secondes
/// (seulement ceux après le dernier reçu, donc très léger) et dès qu'une
/// notification Firebase arrive. Un message envoyé s'affiche immédiatement,
/// avant même la réponse du serveur.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.title, this.subtitle, this.embedded = false});

  final int conversationId;
  final String? title;
  final String? subtitle;

  /// Vrai quand l'écran est affiché à droite de la liste (grand écran) : pas de bouton retour.
  final bool embedded;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _pollEvery = Duration(seconds: 3);

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  Timer? _poll;
  bool _loading = true;
  bool _hasOlder = false;
  bool _loadingOlder = false;
  String? _error;
  late final PushNotificationService _push = ref.read(pushNotificationServiceProvider);

  int? get _lastId {
    for (final m in _messages.reversed) {
      if (!m.pending) return m.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _push.activeConversationId = widget.conversationId;
    _loadInitial();
    _poll = Timer.periodic(_pollEvery, (_) => _fetchNew());
  }

  @override
  void didUpdateWidget(covariant ChatScreen old) {
    super.didUpdateWidget(old);
    if (old.conversationId != widget.conversationId) {
      _push.activeConversationId = widget.conversationId;
      _messages.clear();
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    if (_push.activeConversationId == widget.conversationId) _push.activeConversationId = null;
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(chatRepositoryProvider).messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _hasOlder = list.length >= 50;
        _loading = false;
      });
      _afterRead();
      _scrollToBottom(jump: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Récupère uniquement les messages arrivés depuis le dernier affiché.
  Future<void> _fetchNew() async {
    if (_loading || !mounted) return;
    try {
      final fresh = await ref.read(chatRepositoryProvider).messages(widget.conversationId, afterId: _lastId);
      if (!mounted || fresh.isEmpty) return;
      final known = _messages.map((m) => m.id).toSet();
      final added = fresh.where((m) => !known.contains(m.id)).toList();
      if (added.isEmpty) return;
      final nearBottom = !_scroll.hasClients || _scroll.position.extentAfter < 120;
      setState(() => _messages.addAll(added));
      _afterRead();
      if (nearBottom) _scrollToBottom();
    } catch (_) {
      // Réseau passager : le prochain passage réessaiera.
    }
  }

  Future<void> _loadOlder() async {
    final firstId = _messages.where((m) => !m.pending).firstOrNull?.id;
    if (firstId == null) return;
    setState(() => _loadingOlder = true);
    try {
      final older = await ref.read(chatRepositoryProvider).messages(widget.conversationId, beforeId: firstId);
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, older);
        _hasOlder = older.length >= 50;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  /// Envoi « optimiste » : la bulle apparaît tout de suite, puis est confirmée par le serveur.
  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final temp = ChatMessage(
      id: -DateTime.now().microsecondsSinceEpoch,
      conversationId: widget.conversationId,
      body: text,
      isMine: true,
      createdAt: DateTime.now(),
      pending: true,
    );
    setState(() => _messages.add(temp));
    _scrollToBottom();

    try {
      final saved = await ref.read(chatRepositoryProvider).send(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        _messages.remove(temp);
        if (!_messages.any((m) => m.id == saved.id)) _messages.add(saved);
      });
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.remove(temp));
      _input.text = text; // on rend le texte pour pouvoir réessayer
      showError(context, e);
    }
  }

  /// Après lecture : pastilles et liste de conversations à jour.
  void _afterRead() {
    ref.invalidate(conversationsProvider);
    ref.read(countersProvider.notifier).refresh();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      jump
          ? _scroll.jumpTo(target)
          : _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Un signal Firebase « chat » arrive : on va chercher les nouveaux messages sans attendre.
    ref.listen(conversationsProvider, (_, _) => _fetchNew());

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title ?? 'Conversation', overflow: TextOverflow.ellipsis),
          if (widget.subtitle != null)
            Text(widget.subtitle!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
      ),
      body: Column(children: [
        Expanded(child: _body()),
        _Composer(controller: _input, onSend: _send),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return MessageView(
        icon: Icons.wifi_off_rounded,
        title: 'Messages indisponibles',
        message: _error,
        action: 'Réessayer',
        onAction: _loadInitial,
      );
    }
    if (_messages.isEmpty) {
      return const MessageView(
        icon: Icons.waving_hand_rounded,
        title: 'Aucun message',
        message: 'Écrivez le premier message !',
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _messages.length + (_hasOlder ? 1 : 0),
      itemBuilder: (context, i) {
        if (_hasOlder && i == 0) {
          return Center(
            child: TextButton(
              onPressed: _loadingOlder ? null : _loadOlder,
              child: Text(_loadingOlder ? 'Chargement…' : 'Messages plus anciens'),
            ),
          );
        }
        final index = i - (_hasOlder ? 1 : 0);
        final message = _messages[index];
        final previous = index > 0 ? _messages[index - 1] : null;
        // Le nom de l'auteur n'est affiché qu'au début d'une série de messages.
        final showAuthor = !message.isMine && previous?.author?.id != message.author?.id;
        return _Bubble(message: message, showAuthor: showAuthor);
      },
    );
  }
}

/// Bulle de message.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showAuthor});
  final ChatMessage message;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75 > 460 ? 460 : MediaQuery.sizeOf(context).width * 0.75),
        margin: EdgeInsets.only(top: showAuthor ? 10 : 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          gradient: mine
              ? const LinearGradient(colors: [AppColors.violet, AppColors.blue])
              : null,
          color: mine ? null : scheme.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showAuthor && message.author != null)
            Text(message.author!.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.violetLight)),
          Text(message.body, style: TextStyle(color: mine ? Colors.white : null, height: 1.35)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(DateFormatter.relative(message.createdAt),
                style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : scheme.onSurface.withValues(alpha: 0.5))),
            if (mine) ...[
              const SizedBox(width: 4),
              Icon(message.pending ? Icons.schedule_rounded : Icons.check_rounded, size: 13, color: Colors.white70),
            ],
          ]),
        ]),
      ),
    );
  }
}

/// Zone de saisie.
class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'Votre message…', counterText: '', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(tooltip: 'Envoyer', onPressed: onSend, icon: const Icon(Icons.send_rounded)),
          ]),
        ),
      );
}
