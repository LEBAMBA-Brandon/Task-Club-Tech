import 'user.dart';

/// Commentaire sur une tâche.
class Comment {
  const Comment({required this.id, required this.body, required this.author, required this.isMine, required this.createdAt});

  final int id;
  final String body;
  final AppUser author;
  final bool isMine;
  final DateTime createdAt;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as int,
        body: json['body'] as String,
        author: AppUser.fromJson(json['author'] as Map<String, dynamic>),
        isMine: json['is_mine'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
