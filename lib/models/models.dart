import 'package:uuid/uuid.dart';

class Flashcard {
  final String id;
  final String front;
  final String back;
  final String explanationId;
  final DateTime createdAt;
  final String? status; // 'unknown', 'review', 'known'

  Flashcard({
    String? id,
    required this.front,
    required this.back,
    this.explanationId = '',
    DateTime? createdAt,
    this.status = 'unknown',
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Flashcard copyWith({String? front, String? back, String? status}) {
    return Flashcard(
      id: id,
      front: front ?? this.front,
      back: back ?? this.back,
      explanationId: explanationId,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'front': front, 'back': back,
    'explanationId': explanationId,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
  };

  factory Flashcard.fromMap(Map<String, dynamic> map) => Flashcard(
    id: map['id'], front: map['front'], back: map['back'],
    explanationId: map['explanationId'] ?? '',
    createdAt: DateTime.parse(map['createdAt']),
    status: map['status'] ?? 'unknown',
  );
}

class MemoCard {
  final String id;
  final String title;
  final String content;
  final String explanationId;
  final DateTime createdAt;
  final String? category;

  MemoCard({
    String? id,
    required this.title,
    required this.content,
    this.explanationId = '',
    DateTime? createdAt,
    this.category,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'content': content,
    'explanationId': explanationId,
    'createdAt': createdAt.toIso8601String(),
    'category': category,
  };

  factory MemoCard.fromMap(Map<String, dynamic> map) => MemoCard(
    id: map['id'], title: map['title'], content: map['content'],
    explanationId: map['explanationId'] ?? '',
    createdAt: DateTime.parse(map['createdAt']),
    category: map['category'],
  );
}

class Quiz {
  final String id;
  final String topic;
  List<QuizQuestion> questions;
  int score;
  int get total => questions.length;
  final DateTime createdAt;
  final String level;

  Quiz({
    String? id,
    required this.topic,
    required this.questions,
    this.score = 0,
    DateTime? createdAt,
    this.level = 'beginner',
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'topic': topic,
    'questions': questions.map((q) => q.toMap()).toList(),
    'score': score, 'total': total,
    'createdAt': createdAt.toIso8601String(),
    'level': level,
  };

  factory Quiz.fromMap(Map<String, dynamic> map) => Quiz(
    id: map['id'], topic: map['topic'],
    questions: (map['questions'] as List?)
        ?.map((q) => QuizQuestion.fromMap(q)).toList() ?? [],
    score: map['score'] ?? 0,
    createdAt: DateTime.parse(map['createdAt']),
    level: map['level'] ?? 'beginner',
  );
}

class QuizQuestion {
  final String id;
  final String question;
  final String type; // 'qcm', 'true_false', 'short_answer', 'code_fill'
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String? userAnswer;
  final bool? isCorrect;

  QuizQuestion({
    String? id,
    required this.question,
    required this.type,
    this.options = const [],
    required this.correctAnswer,
    this.explanation = '',
    this.userAnswer,
    this.isCorrect,
  }) : id = id ?? const Uuid().v4();

  /// Copie sans réponse de l'élève (copyWith ne peut pas remettre à null).
  QuizQuestion reset() {
    return QuizQuestion(
      id: id, question: question, type: type,
      options: options, correctAnswer: correctAnswer,
      explanation: explanation,
    );
  }

  QuizQuestion copyWith({String? userAnswer, bool? isCorrect}) {
    return QuizQuestion(
      id: id, question: question, type: type,
      options: options, correctAnswer: correctAnswer,
      explanation: explanation,
      userAnswer: userAnswer ?? this.userAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'question': question, 'type': type,
    'options': options, 'correctAnswer': correctAnswer,
    'explanation': explanation,
    'userAnswer': userAnswer, 'isCorrect': isCorrect,
  };

  factory QuizQuestion.fromMap(Map<String, dynamic> map) => QuizQuestion(
    id: map['id'], question: map['question'], type: map['type'],
    options: List<String>.from(map['options'] ?? []),
    correctAnswer: map['correctAnswer'],
    explanation: map['explanation'] ?? '',
    userAnswer: map['userAnswer'],
    isCorrect: map['isCorrect'],
  );
}

class Exercise {
  final String id;
  final String topic;
  final String difficulty;
  final String content;
  final String? hint;
  final String? solution;
  final DateTime createdAt;
  final bool completed;

  Exercise({
    String? id,
    required this.topic,
    required this.difficulty,
    required this.content,
    this.hint,
    this.solution,
    DateTime? createdAt,
    this.completed = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'topic': topic, 'difficulty': difficulty,
    'content': content, 'hint': hint, 'solution': solution,
    'createdAt': createdAt.toIso8601String(),
    'completed': completed,
  };

  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
    id: map['id'], topic: map['topic'], difficulty: map['difficulty'],
    content: map['content'], hint: map['hint'], solution: map['solution'],
    createdAt: DateTime.parse(map['createdAt']),
    completed: map['completed'] ?? false,
  );
}

class ProgressData {
  int topicsStudied;
  int explanationsViewed;
  int quizzesTaken;
  int exercisesDone;
  int flashcardsReviewed;
  int quizCorrectAnswers;
  int quizTotalQuestions;
  List<String> topicsToReview;

  ProgressData({
    this.topicsStudied = 0,
    this.explanationsViewed = 0,
    this.quizzesTaken = 0,
    this.exercisesDone = 0,
    this.flashcardsReviewed = 0,
    this.quizCorrectAnswers = 0,
    this.quizTotalQuestions = 0,
    List<String>? topicsToReview,
  }) : topicsToReview = topicsToReview ?? [];

  /// Taux de réussite global aux quiz, en pourcentage.
  double get successRate =>
      quizTotalQuestions == 0 ? 0.0 : quizCorrectAnswers / quizTotalQuestions * 100;

  Map<String, dynamic> toMap() => {
    'topicsStudied': topicsStudied,
    'explanationsViewed': explanationsViewed,
    'quizzesTaken': quizzesTaken,
    'exercisesDone': exercisesDone,
    'flashcardsReviewed': flashcardsReviewed,
    'quizCorrectAnswers': quizCorrectAnswers,
    'quizTotalQuestions': quizTotalQuestions,
    'successRate': successRate,
    'topicsToReview': topicsToReview,
  };

  factory ProgressData.fromMap(Map<String, dynamic> map) => ProgressData(
    topicsStudied: map['topicsStudied'] ?? 0,
    explanationsViewed: map['explanationsViewed'] ?? 0,
    quizzesTaken: map['quizzesTaken'] ?? 0,
    exercisesDone: map['exercisesDone'] ?? 0,
    flashcardsReviewed: map['flashcardsReviewed'] ?? 0,
    quizCorrectAnswers: map['quizCorrectAnswers'] ?? 0,
    quizTotalQuestions: map['quizTotalQuestions'] ?? 0,
    topicsToReview: List<String>.from(map['topicsToReview'] ?? []),
  );
}
