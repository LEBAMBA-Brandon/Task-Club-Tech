import 'department.dart';
import 'user.dart';

/// Accusé d'un destinataire : sent → delivered → seen → done (comme WhatsApp).
class Receipt {
  const Receipt({required this.state, this.user, this.deliveredAt, this.seenAt, this.doneAt});

  final AppUser? user;
  final String state;
  final DateTime? deliveredAt;
  final DateTime? seenAt;
  final DateTime? doneAt;

  bool get isDone => state == 'done';

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        user: json['user'] is Map<String, dynamic> ? AppUser.fromJson(json['user'] as Map<String, dynamic>) : null,
        state: json['state'] as String,
        deliveredAt: _date(json['delivered_at']),
        seenAt: _date(json['seen_at']),
        doneAt: _date(json['done_at']),
      );
}

/// Compteurs des accusés d'une tâche.
class ReceiptStats {
  const ReceiptStats({this.total = 0, this.delivered = 0, this.seen = 0, this.done = 0});
  final int total, delivered, seen, done;

  factory ReceiptStats.fromJson(Map<String, dynamic> json) => ReceiptStats(
        total: json['total'] as int? ?? 0,
        delivered: json['delivered'] as int? ?? 0,
        seen: json['seen'] as int? ?? 0,
        done: json['done'] as int? ?? 0,
      );
}

/// Tâche telle que vue par l'utilisateur connecté.
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.urgency,
    required this.urgencyLabel,
    required this.createdAt,
    required this.creator,
    required this.department,
    required this.isMine,
    required this.stats,
    this.description,
    this.dueAt,
    this.myState,
    this.recipients = const [],
    this.commentsCount = 0,
  });

  final int id;
  final String title;
  final String? description;

  /// green | blue | yellow | red
  final String urgency;
  final String urgencyLabel;
  final DateTime? dueAt;
  final DateTime createdAt;
  final AppUser creator;
  final Department department;
  final bool isMine;

  /// Mon accusé si je suis destinataire.
  final Receipt? myState;
  final ReceiptStats stats;

  /// Accusés de tous les destinataires (visible par l'auteur et la présidence).
  final List<Receipt> recipients;
  final int commentsCount;

  bool get isOverdue => dueAt != null && dueAt!.isBefore(DateTime.now()) && !(myState?.isDone ?? false);

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        urgency: json['urgency'] as String,
        urgencyLabel: json['urgency_label'] as String? ?? '',
        dueAt: _date(json['due_at']),
        createdAt: _date(json['created_at']) ?? DateTime.now(),
        creator: AppUser.fromJson(json['creator'] as Map<String, dynamic>),
        department: Department.fromJson(json['department'] as Map<String, dynamic>),
        isMine: json['is_mine'] as bool? ?? false,
        myState: json['my_state'] is Map<String, dynamic>
            ? Receipt.fromJson(json['my_state'] as Map<String, dynamic>)
            : null,
        stats: ReceiptStats.fromJson((json['stats'] as Map<String, dynamic>?) ?? const {}),
        recipients: ((json['recipients'] as List?) ?? const [])
            .map((e) => Receipt.fromJson(e as Map<String, dynamic>))
            .toList(),
        commentsCount: json['comments_count'] as int? ?? 0,
      );
}

/// Page de résultats + indicateur « données issues du cache ».
class TaskPage {
  const TaskPage({required this.tasks, this.fromCache = false});
  final List<Task> tasks;
  final bool fromCache;
}

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
