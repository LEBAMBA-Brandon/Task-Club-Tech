/// Ligne du tableau de bord des départements (président / vice-président).
class DepartmentOverview {
  const DepartmentOverview({
    required this.id,
    required this.name,
    this.responsable,
    this.membersActive = 0,
    this.membersPending = 0,
    this.membersSuspended = 0,
    this.tasksCount = 0,
    this.receiptsTotal = 0,
    this.receiptsDone = 0,
    this.receiptsUnseen = 0,
  });

  final int id;
  final String name;

  /// Nom du responsable actif (null si le poste est vacant).
  final String? responsable;
  final int membersActive;
  final int membersPending;
  final int membersSuspended;

  /// Nombre de tâches envoyées au département.
  final int tasksCount;

  /// Accusés des membres : total, effectués, pas encore ouverts.
  final int receiptsTotal;
  final int receiptsDone;
  final int receiptsUnseen;

  double get completion => receiptsTotal == 0 ? 0 : receiptsDone / receiptsTotal;

  factory DepartmentOverview.fromJson(Map<String, dynamic> j) => DepartmentOverview(
        id: j['id'] as int,
        name: j['name'] as String,
        responsable: j['responsable'] as String?,
        membersActive: (j['members_active'] as num?)?.toInt() ?? 0,
        membersPending: (j['members_pending'] as num?)?.toInt() ?? 0,
        membersSuspended: (j['members_suspended'] as num?)?.toInt() ?? 0,
        tasksCount: (j['tasks_count'] as num?)?.toInt() ?? 0,
        receiptsTotal: (j['receipts_total'] as num?)?.toInt() ?? 0,
        receiptsDone: (j['receipts_done'] as num?)?.toInt() ?? 0,
        receiptsUnseen: (j['receipts_unseen'] as num?)?.toInt() ?? 0,
      );
}
