import 'package:uuid/uuid.dart';

class Conversation {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final String? topic;

  Conversation({
    String? id,
    required this.title,
    this.messages = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
    this.topic,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Conversation copyWith({
    String? title,
    List<ChatMessage>? messages,
    bool? isFavorite,
    String? topic,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isFavorite: isFavorite ?? this.isFavorite,
      topic: topic ?? this.topic,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFavorite': isFavorite,
      'topic': topic,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      title: map['title'],
      messages: (map['messages'] as List?)
              ?.map((m) => ChatMessage.fromMap(m))
              .toList() ??
          [],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isFavorite: map['isFavorite'] ?? false,
      topic: map['topic'],
    );
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String> imagePaths;
  final String? type;

  ChatMessage({
    String? id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.imagePaths = const [],
    this.type,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'imagePaths': imagePaths,
      'type': type,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      content: map['content'],
      isUser: map['isUser'],
      timestamp: DateTime.parse(map['timestamp']),
      imagePaths: List<String>.from(map['imagePaths'] ?? []),
      type: map['type'],
    );
  }
}
