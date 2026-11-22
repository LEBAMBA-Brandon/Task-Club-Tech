import 'user.dart';

/// Membre + statistiques de suivi (page Équipe).
class Member {
  const Member({
    required this.user,
    this.tasksTotal = 0,
    this.tasksDone = 0,
    this.tasksUnseen = 0,
    this.lastActiveAt,
  });

  final AppUser user;
  final int tasksTotal;
  final int tasksDone;
  final int tasksUnseen;
  final DateTime? lastActiveAt;

  /// Taux de réalisation (0..1).
  double get completion => tasksTotal == 0 ? 0 : tasksDone / tasksTotal;

  factory Member.fromJson(Map<String, dynamic> json) {
    final stats = (json['stats'] as Map<String, dynamic>?) ?? const {};
    return Member(
      user: AppUser.fromJson(json),
      tasksTotal: (stats['tasks_total'] as num?)?.toInt() ?? 0,
      tasksDone: (stats['tasks_done'] as num?)?.toInt() ?? 0,
      tasksUnseen: (stats['tasks_unseen'] as num?)?.toInt() ?? 0,
      lastActiveAt: json['last_active_at'] is String ? DateTime.tryParse(json['last_active_at'] as String) : null,
    );
  }
}
