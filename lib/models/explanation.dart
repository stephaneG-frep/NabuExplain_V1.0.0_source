import 'package:uuid/uuid.dart';

class Explanation {
  final String id;
  final String query;
  final String response;
  final String level;
  final int complexity;
  final String type;
  final List<String> imagePaths;
  final DateTime createdAt;
  final bool isFavorite;
  final String? category;
  final String? title;

  Explanation({
    String? id,
    required this.query,
    required this.response,
    required this.level,
    this.complexity = 50,
    this.type = 'notion',
    this.imagePaths = const [],
    DateTime? createdAt,
    this.isFavorite = false,
    this.category,
    this.title,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Explanation copyWith({
    String? query,
    String? response,
    String? level,
    int? complexity,
    String? type,
    List<String>? imagePaths,
    bool? isFavorite,
    String? category,
    String? title,
  }) {
    return Explanation(
      id: id,
      query: query ?? this.query,
      response: response ?? this.response,
      level: level ?? this.level,
      complexity: complexity ?? this.complexity,
      type: type ?? this.type,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
      title: title ?? this.title,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'query': query,
      'response': response,
      'level': level,
      'complexity': complexity,
      'type': type,
      'imagePaths': imagePaths,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'category': category,
      'title': title,
    };
  }

  factory Explanation.fromMap(Map<String, dynamic> map) {
    return Explanation(
      id: map['id'],
      query: map['query'],
      response: map['response'],
      level: map['level'],
      complexity: map['complexity'] ?? 50,
      type: map['type'] ?? 'notion',
      imagePaths: List<String>.from(map['imagePaths'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
      isFavorite: map['isFavorite'] ?? false,
      category: map['category'],
      title: map['title'],
    );
  }
}
