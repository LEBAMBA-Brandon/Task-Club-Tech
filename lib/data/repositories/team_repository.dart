import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/counters.dart';
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
}
