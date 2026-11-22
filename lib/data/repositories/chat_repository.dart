import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/cache_storage.dart';
import '../models/chat.dart';

/// Accès à la messagerie (conversations + messages), avec cache hors ligne de la liste.
class ChatRepository {
  ChatRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheStorage _cache;

  Future<List<Conversation>> conversations() async {
    try {
      final data = await _api.get('/conversations');
      await _cache.write('conversations', data['data']);
      return _conversations(data['data']);
    } on ApiException catch (e) {
      final cached = _cache.read('conversations');
      if (e.isOffline && cached is List) return _conversations(cached);
      rethrow;
    }
  }

  /// Ouvre (ou crée) la conversation privée avec un membre.
  Future<Conversation> openDirect(int userId) async {
    final data = await _api.post('/conversations', {'user_id': userId});
    return Conversation.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Derniers messages (ou seulement ceux après [afterId] pour la mise à jour en direct).
  Future<List<ChatMessage>> messages(int conversationId, {int? afterId, int? beforeId}) async {
    final data = await _api.get('/conversations/$conversationId/messages', query: {
      'after_id': afterId,
      'before_id': beforeId,
    });
    return (data['data'] as List).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> send(int conversationId, String body) async {
    final data = await _api.post('/conversations/$conversationId/messages', {'body': body.trim()});
    return ChatMessage.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> markRead(int conversationId) => _api.post('/conversations/$conversationId/read');

  List<Conversation> _conversations(dynamic list) =>
      (list as List).map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
}
