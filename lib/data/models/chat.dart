import 'user.dart';

/// Message d'une conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.isMine,
    required this.createdAt,
    this.author,
    this.pending = false,
  });

  final int id;
  final int conversationId;
  final String body;
  final AppUser? author;
  final bool isMine;
  final DateTime createdAt;

  /// Vrai tant que le message est en cours d'envoi (affichage immédiat, sans attendre le serveur).
  final bool pending;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        conversationId: json['conversation_id'] as int,
        body: json['body'] as String,
        author: json['author'] is Map<String, dynamic> ? AppUser.fromJson(json['author'] as Map<String, dynamic>) : null,
        isMine: json['is_mine'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Conversation : privée (deux membres) ou groupe du département.
class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    required this.updatedAt,
    this.subtitle,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final int id;

  /// direct | department
  final String type;
  final String title;
  final String? subtitle;
  final AppUser? otherUser;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  bool get isGroup => type == 'department';

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as int,
        type: json['type'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        otherUser: json['other_user'] is Map<String, dynamic>
            ? AppUser.fromJson(json['other_user'] as Map<String, dynamic>)
            : null,
        lastMessage: json['last_message'] is Map<String, dynamic>
            ? ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>)
            : null,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
