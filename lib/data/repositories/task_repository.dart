import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/cache_storage.dart';
import '../models/comment.dart';
import '../models/task.dart';
import '../models/user.dart';

/// Filtres d'une liste de tâches. Un « record » Dart : égalité par valeur,
/// donc utilisable comme paramètre de provider Riverpod.
typedef TaskQuery = ({String box, String? urgency, String? state});

/// Accès à l'API des tâches, commentaires et validations de comptes.
class TaskRepository {
  TaskRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheStorage _cache;

  /// Liste ; si le serveur est injoignable, renvoie la dernière liste en cache.
  Future<TaskPage> list(TaskQuery query) async {
    final cacheKey = 'tasks_${query.box}_${query.urgency ?? ''}_${query.state ?? ''}';
    try {
      final data = await _api.get('/tasks', query: {
        'box': query.box,
        'urgency': query.urgency,
        'state': query.state,
        'per_page': 50,
      });
      await _cache.write(cacheKey, data['data']);
      return TaskPage(tasks: _tasks(data['data']));
    } on ApiException catch (e) {
      final cached = _cache.read(cacheKey);
      if (e.isOffline && cached is List) return TaskPage(tasks: _tasks(cached), fromCache: true);
      rethrow;
    }
  }

  Future<Task> show(int id) async {
    try {
      final data = await _api.get('/tasks/$id');
      await _cache.write('task_$id', data['data']);
      return Task.fromJson(data['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      final cached = _cache.read('task_$id');
      if (e.isOffline && cached is Map<String, dynamic>) return Task.fromJson(cached);
      rethrow;
    }
  }

  Future<Task> create({
    required String title,
    String? description,
    required int departmentId,
    required String urgency,
    DateTime? dueAt,
  }) async {
    final data = await _api.post('/tasks', {
      'title': title.trim(),
      'description': (description?.trim().isEmpty ?? true) ? null : description!.trim(),
      'department_id': departmentId,
      'urgency': urgency,
      'due_at': dueAt?.toUtc().toIso8601String(),
    });
    return Task.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Task> setDone(int id, bool done) async {
    final data = done ? await _api.post('/tasks/$id/done') : await _api.delete('/tasks/$id/done');
    return Task.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/tasks/$id');

  /// Accusé « reçu » (appelé à l'arrivée d'une notification push).
  Future<void> markDelivered(List<int> ids) => _api.post('/tasks/delivered', {'task_ids': ids});

  Future<List<Comment>> comments(int taskId) async {
    final data = await _api.get('/tasks/$taskId/comments');
    return (data['data'] as List).map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Comment> addComment(int taskId, String body) async {
    final data = await _api.post('/tasks/$taskId/comments', {'body': body.trim()});
    return Comment.fromJson(data['data'] as Map<String, dynamic>);
  }

  // ----- Validation des inscriptions

  Future<List<AppUser>> pendingApprovals() async {
    final data = await _api.get('/approvals');
    return (data['data'] as List).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> approve(int userId) => _api.post('/approvals/$userId/approve');

  Future<void> reject(int userId) => _api.post('/approvals/$userId/reject');

  List<Task> _tasks(dynamic list) =>
      (list as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
}
