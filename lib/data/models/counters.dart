/// Pastilles de l'application (GET /counters).
class Counters {
  const Counters({this.tasksUnread = 0, this.approvalsPending = 0, this.messagesUnread = 0});

  /// Tâches reçues pas encore ouvertes (onglet Reçues).
  final int tasksUnread;

  /// Demandes d'inscription à valider (onglet Équipe).
  final int approvalsPending;

  /// Messages non lus (onglet Messages).
  final int messagesUnread;

  factory Counters.fromJson(Map<String, dynamic> json) => Counters(
        tasksUnread: (json['tasks_unread'] as num?)?.toInt() ?? 0,
        approvalsPending: (json['approvals_pending'] as num?)?.toInt() ?? 0,
        messagesUnread: (json['messages_unread'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is Counters &&
      other.tasksUnread == tasksUnread &&
      other.approvalsPending == approvalsPending &&
      other.messagesUnread == messagesUnread;

  @override
  int get hashCode => Object.hash(tasksUnread, approvalsPending, messagesUnread);
}
