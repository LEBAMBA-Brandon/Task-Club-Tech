import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/counters.dart';
import '../models/department_overview.dart';
import '../models/member.dart';
import '../models/user.dart';

/// Suivi des membres, annuaire et pastilles.
class TeamRepository {
  TeamRepository(this._api);

  final ApiClient _api;

  /// Pastilles (tâches non lues, demandes, messages). Hors ligne : on garde les dernières.
  Future<Counters?> counters() async {
    try {
      final data = await _api.get('/counters');
      return Counters.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isOffline) return null;
      rethrow;
    }
  }

  /// Suivi : président/VP = tout le club ; responsable = son département (filtré par l'API).
  Future<List<Member>> members({int? departmentId, String? search}) async {
    final data = await _api.get('/members', query: {'department_id': departmentId, 'search': search});
    return (data['data'] as List).map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Annuaire des membres actifs (pour écrire à quelqu'un).
  Future<List<AppUser>> directory({String? search}) async {
    final data = await _api.get('/directory', query: {'search': search});
    return (data['data'] as List).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ----- Administration (président / vice-président)

  /// Tableau de bord de tous les départements.
  Future<List<DepartmentOverview>> departmentsOverview() async {
    final data = await _api.get('/admin/departments');
    return (data['data'] as List).map((e) => DepartmentOverview.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Modifie un membre : département, poste, statut (active | suspended).
  Future<Member> updateMember(int userId, {int? departmentId, String? position, String? status}) async {
    final data = await _api.patch('/members/$userId', {
      'department_id': ?departmentId,
      'position': ?position,
      'status': ?status,
    });
    return Member.fromJson(data['data'] as Map<String, dynamic>);
  }
}
