import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/comment.dart';
import '../data/models/meta.dart';
import '../data/models/task.dart';
import '../data/models/user.dart';
import '../data/repositories/task_repository.dart';
import 'core_providers.dart';

/// Référentiel (départements, postes, urgences).
final metaProvider = FutureProvider<Meta>((ref) => ref.watch(metaRepositoryProvider).fetch());

/// Liste de tâches pour un filtre donné (reçues / envoyées / toutes).
final taskListProvider = FutureProvider.autoDispose.family<TaskPage, TaskQuery>(
  (ref, query) => ref.watch(taskRepositoryProvider).list(query),
);

/// Détail d'une tâche (l'ouvrir la marque « vue »).
final taskDetailProvider = FutureProvider.autoDispose.family<Task, int>(
  (ref, id) => ref.watch(taskRepositoryProvider).show(id),
);

/// Commentaires d'une tâche.
final commentsProvider = FutureProvider.autoDispose.family<List<Comment>, int>(
  (ref, id) => ref.watch(taskRepositoryProvider).comments(id),
);

/// Nombre de tâches reçues non lues (badge).
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(taskRepositoryProvider).unreadCount());

/// Comptes en attente de validation.
final approvalsProvider = FutureProvider.autoDispose<List<AppUser>>(
  (ref) => ref.watch(taskRepositoryProvider).pendingApprovals(),
);

/// Rafraîchit toutes les listes de tâches (après création, notification...).
void refreshTaskLists(WidgetRef ref) {
  ref.invalidate(taskListProvider);
  ref.invalidate(unreadCountProvider);
}

/// Section affichée dans la navigation principale :
/// received | sent | all | approvals | profile
class HomeSectionController extends Notifier<String> {
  @override
  String build() => 'received';

  void go(String section) => state = section;
}

final homeSectionProvider = NotifierProvider<HomeSectionController, String>(HomeSectionController.new);

/// Préférences simples enregistrées sur l'appareil (notifications, tutoriel déjà vu).
class DevicePrefs {
  DevicePrefs(this._ref);
  final Ref _ref;

  static const _push = 'push_enabled';
  static const _tutorial = 'tutorial_seen';

  bool get pushEnabled => _ref.read(cacheStorageProvider).getString(_push) != 'false';
  Future<void> setPushEnabled(bool value) => _ref.read(cacheStorageProvider).setString(_push, '$value');

  bool get tutorialSeen => _ref.read(cacheStorageProvider).getString(_tutorial) == 'true';
  Future<void> setTutorialSeen() => _ref.read(cacheStorageProvider).setString(_tutorial, 'true');
}

final devicePrefsProvider = Provider<DevicePrefs>((ref) => DevicePrefs(ref));

/// Thème choisi par l'utilisateur (système / clair / sombre), mémorisé.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.read(cacheStorageProvider).getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(cacheStorageProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
