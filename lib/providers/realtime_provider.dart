import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/counters.dart';
import 'core_providers.dart';
import 'data_providers.dart';

/// Mises à jour « en direct » de l'application, sans bouton de rechargement.
///
/// Trois sources, de la plus rapide à la plus sûre :
///  1. Signal Firebase (type « sync ») envoyé par le serveur à chaque changement :
///     [onServerSignal] recharge discrètement l'écran concerné, en ~1 seconde.
///  2. Interrogation légère du serveur toutes les [interval] (GET /counters) :
///     si une pastille change, les listes correspondantes sont rechargées.
///     Indispensable sur ordinateur/web (pas de Firebase) ou si un signal se perd.
///  3. Retour dans l'application (téléphone déverrouillé...) : tout est rafraîchi.
///
/// Les rechargements sont silencieux : l'ancienne liste reste affichée
/// pendant que la nouvelle arrive (pas d'écran de chargement).
class CountersController extends Notifier<Counters> {
  static const interval = Duration(seconds: 15);
  Timer? _timer;
  bool _busy = false;

  @override
  Counters build() {
    ref.onDispose(() => _timer?.cancel());
    return const Counters();
  }

  /// Démarre l'interrogation régulière (appelé à l'ouverture de l'accueil).
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
    refresh();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Relit les pastilles ; si quelque chose a changé, recharge les écrans concernés.
  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final next = await ref.read(teamRepositoryProvider).counters();
      if (next == null) return; // hors ligne : on garde les dernières valeurs
      final previous = state;
      state = next;
      if (next.tasksUnread != previous.tasksUnread) ref.invalidate(taskListProvider);
      if (next.approvalsPending != previous.approvalsPending) {
        ref.invalidate(approvalsProvider);
        ref.invalidate(membersProvider);
      }
      if (next.messagesUnread != previous.messagesUnread) ref.invalidate(conversationsProvider);
    } catch (_) {
      // Erreur passagère : la prochaine interrogation réessaiera.
    } finally {
      _busy = false;
    }
  }

  /// Retour au premier plan : tout est rechargé.
  void refreshAll() {
    ref.invalidate(taskListProvider);
    ref.invalidate(approvalsProvider);
    ref.invalidate(conversationsProvider);
    ref.invalidate(membersProvider);
    refresh();
  }

  /// Signal reçu du serveur (notification Firebase, visible ou silencieuse).
  /// [scope] : tasks | comments | approvals | chat ; [data] : identifiants concernés.
  void onServerSignal(String scope, Map<String, dynamic> data) {
    final taskId = int.tryParse('${data['task_id'] ?? ''}');
    switch (scope) {
      case 'tasks':
        ref.invalidate(taskListProvider);
        if (taskId != null) ref.invalidate(taskDetailProvider(taskId));
      case 'comments':
        if (taskId != null) {
          ref.invalidate(commentsProvider(taskId));
          ref.invalidate(taskDetailProvider(taskId));
        }
        ref.invalidate(taskListProvider);
      case 'approvals':
        ref.invalidate(approvalsProvider);
        ref.invalidate(membersProvider);
      case 'chat':
        ref.invalidate(conversationsProvider);
    }
    refresh();
  }
}

final countersProvider = NotifierProvider<CountersController, Counters>(CountersController.new);
