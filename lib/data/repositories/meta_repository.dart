import '../../core/network/api_client.dart';
import '../../core/storage/cache_storage.dart';
import '../models/meta.dart';

/// Référentiel (départements, postes, urgences), mis en cache pour le hors ligne.
class MetaRepository {
  MetaRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheStorage _cache;

  Future<Meta> fetch() async {
    try {
      final data = await _api.get('/meta');
      await _cache.write('meta', data);
      return Meta.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      final cached = _cache.read('meta');
      if (cached is Map<String, dynamic>) return Meta.fromJson(cached);
      rethrow;
    }
  }
}
