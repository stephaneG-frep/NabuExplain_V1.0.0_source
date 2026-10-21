import 'dart:convert';
import 'package:nabu_explain/core/constants/app_constants.dart';
import 'package:nabu_explain/core/utils/prompt_builder.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/services/ai/ai_service.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';

class _AIConfig {
  final AIService service;
  final String apiKey;
  final String model;
  const _AIConfig(this.service, this.apiKey, this.model);
}

class AIController {
  final StorageService _storage = StorageService.instance;

  Future<_AIConfig> _config() async {
    final settings = await _storage.loadSettings();
    final provider = settings['provider'] as String? ?? 'OpenAI';
    final service = AIServiceFactory.create(provider, baseUrl: settings['ollamaUrl'] as String?);
    if (service == null) {
      throw AIException('Fournisseur IA inconnu : $provider');
    }
    final key = await _storage.getApiKey(provider) ?? '';
    if (key.isEmpty && AIServiceFactory.requiresApiKey(provider)) {
      throw AIException('Aucune clé API configurée pour $provider. Va dans Profil → Paramètres → IA.');
    }
    final model = settings['model'] as String? ?? 'gpt-4o-mini';
    return _AIConfig(service, key, model);
  }

  Future<String> _generate(
    String userPrompt, {
    String systemPrompt = AppConstants.systemPrompt,
    List<String>? imagePaths,
    double temperature = 0.7,
    List<AIMessage> history = const [],
  }) async {
    final c = await _config();
    return c.service.generate(
      userPrompt: userPrompt,
      systemPrompt: systemPrompt,
      model: c.model,
      apiKey: c.apiKey,
      imagePaths: imagePaths,
      temperature: temperature,
      history: history,
    );
  }

  Future<Explanation> explain({
    required String query,
    required String level,
    required int complexity,
    List<String>? imagePaths,
    String type = 'notion',
    List<AIMessage> history = const [],
  }) async {
    final prompt = PromptBuilder.buildExplainPrompt(
      query: query,
      level: level,
      complexity: complexity,
    );

    final response = await _generate(prompt, imagePaths: imagePaths, history: history);

    await _storage.incrementProgress('explanationsViewed');

    return Explanation(
      query: query,
      response: response,
      level: level,
      complexity: complexity,
      type: type,
      imagePaths: imagePaths ?? [],
    );
  }

  Future<String> explainCode({
    required String code,
    required String language,
    required String level,
    required int complexity,
    String? action,
    List<AIMessage> history = const [],
  }) async {
    final prompt = PromptBuilder.buildCodeExplainPrompt(
      code: code,
      language: language,
      level: level,
      complexity: complexity,
      action: action,
    );
    final response = await _generate(prompt, history: history);
    await _storage.incrementProgress('explanationsViewed');
    return response;
  }

  Future<String> explainError({
    required String error,
    required String context,
    required String level,
    List<AIMessage> history = const [],
  }) async {
    final prompt = PromptBuilder.buildErrorExplainPrompt(
      error: error,
      context: context,
      level: level,
    );
    final response = await _generate(prompt, history: history);
    await _storage.incrementProgress('explanationsViewed');
    return response;
  }

  Future<Quiz> generateQuiz(String topic, String level) async {
    final response = await _generate(
      PromptBuilder.buildQuizPrompt(topic, level),
      systemPrompt: 'Tu génères des quiz pédagogiques en JSON.',
      temperature: 0.5,
    );

    final quiz = parseQuiz(response, topic, level);
    await _storage.saveQuiz(quiz);
    return quiz;
  }

  static Quiz parseQuiz(String raw, String topic, String level) {
    List<QuizQuestion> questions;
    try {
      final data = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      final questionsRaw = data['questions'] as List? ?? [];
      questions = questionsRaw
          .whereType<Map<String, dynamic>>()
          .map(_parseQuestion)
          .whereType<QuizQuestion>()
          .toList();
    } catch (_) {
      throw AIException('Impossible de générer le quiz. Réessaie.');
    }
    if (questions.isEmpty) {
      throw AIException('Le quiz généré ne contient aucune question exploitable. Réessaie.');
    }
    return Quiz(topic: topic, questions: questions, level: level);
  }

  static QuizQuestion? _parseQuestion(Map<String, dynamic> m) {
    final question = (m['question'] as String? ?? '').trim();
    var correct = '${m['correctAnswer'] ?? ''}'.trim();
    if (question.isEmpty || correct.isEmpty) return null;
    final type = m['type'] as String? ?? 'qcm';
    var options = List<String>.from((m['options'] as List? ?? []).map((o) => '$o'));

    if (type == 'true_false') {
      options = ['Vrai', 'Faux'];
      final c = correct.toLowerCase();
      correct = (c == 'true' || c == 'vrai' || c == 'v') ? 'Vrai' : 'Faux';
    } else if (options.isNotEmpty && !options.any((o) => o.trim().toLowerCase() == correct.toLowerCase())) {
      // L'IA répond parfois par la lettre de l'option (« B ») au lieu du texte.
      final letter = RegExp(r'^([A-Da-d])[).:]?$').firstMatch(correct)?.group(1);
      final index = letter == null ? -1 : letter.toUpperCase().codeUnitAt(0) - 65;
      if (index >= 0 && index < options.length) {
        correct = options[index];
      } else {
        final match = options.where((o) => o.toLowerCase().contains(correct.toLowerCase()));
        if (match.length != 1) return null;
        correct = match.first;
      }
    }

    return QuizQuestion(
      question: question,
      type: type,
      options: options,
      correctAnswer: correct,
      explanation: m['explanation'] as String? ?? '',
    );
  }

  static String _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return raw.substring(start, end + 1);
    }
    return raw;
  }

  Future<Exercise> generateExercise(String topic, String difficulty, String level) async {
    final prompt = PromptBuilder.buildExercisePrompt(topic, difficulty, level);
    final response = await _generate(prompt, temperature: 0.6);

    final exercise = parseExercise(response, topic, difficulty);
    await _storage.saveExercise(exercise);
    return exercise;
  }

  static const _exerciseLabels = [
    'EXERCICE',
    'INDICE',
    'DEUXIEME_INDICE',
    'SOLUTION',
    'EXPLICATION_SOLUTION',
  ];

  static Exercise parseExercise(String raw, String topic, String difficulty) {
    final sections = _sections(raw);
    final content = sections['EXERCICE'] ?? '';
    final hint = sections['INDICE'] ?? '';
    final secondHint = sections['DEUXIEME_INDICE'] ?? '';
    final solution = sections['SOLUTION'] ?? '';
    final solutionExplanation = sections['EXPLICATION_SOLUTION'] ?? '';

    final hints = [hint, secondHint].where((h) => h.isNotEmpty).join('\n\n');
    return Exercise(
      topic: topic,
      difficulty: difficulty,
      content: content.isEmpty ? raw : content,
      hint: hints,
      solution: [solution, solutionExplanation].where((s) => s.isNotEmpty).join('\n\n'),
    );
  }

  /// Découpe la réponse sur les étiquettes en début de ligne (même entourées
  /// de ** ou #) : chaque section va jusqu'à l'étiquette suivante, donc les
  /// sections de plusieurs paragraphes ne sont plus tronquées.
  static Map<String, String> _sections(String raw) {
    final pattern = RegExp(
      '^[ \\t#*]*(${_exerciseLabels.join('|')})[ \\t*]*:[ \\t*]*',
      multiLine: true,
    );
    final matches = pattern.allMatches(raw).toList();
    final result = <String, String>{};
    for (var i = 0; i < matches.length; i++) {
      final end = i + 1 < matches.length ? matches[i + 1].start : raw.length;
      result.putIfAbsent(matches[i].group(1)!, () => raw.substring(matches[i].end, end).trim());
    }
    return result;
  }

  Future<List<Flashcard>> generateFlashcards(String explanation, String topic) async {
    final prompt = PromptBuilder.buildFlashcardsPrompt(explanation, topic);
    final response = await _generate(
      prompt,
      systemPrompt: 'Tu génères des flashcards en JSON.',
      temperature: 0.4,
    );

    final cards = parseFlashcards(response);
    await _storage.saveFlashcards(cards);
    return cards;
  }

  static List<Flashcard> parseFlashcards(String raw) {
    List<Flashcard> cards;
    try {
      final data = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      final cardsRaw = data['cards'] as List? ?? [];
      cards = cardsRaw
          .whereType<Map<String, dynamic>>()
          .map((m) => Flashcard(
                front: '${m['front'] ?? ''}'.trim(),
                back: '${m['back'] ?? ''}'.trim(),
              ))
          .where((c) => c.front.isNotEmpty && c.back.isNotEmpty)
          .toList();
    } catch (_) {
      throw AIException('Impossible de générer les flashcards.');
    }
    if (cards.isEmpty) {
      throw AIException('Aucune flashcard exploitable n\'a été générée. Réessaie.');
    }
    return cards;
  }

  Future<String> generateMemo(String explanation, String topic) {
    return _generate(PromptBuilder.buildMemoPrompt(explanation, topic), temperature: 0.4);
  }

  Future<String> generateAnalogy(String explanation, String topic, {List<AIMessage> history = const []}) {
    return _generate(PromptBuilder.buildAnalogiePrompt(explanation, topic), history: history);
  }

  Future<String> generateSteps(String topic, String level) {
    return _generate(PromptBuilder.buildStepPrompt(topic, level));
  }

  Future<String> generateSocratic(String topic, String level) {
    return _generate(PromptBuilder.buildSocraticPrompt(topic, level));
  }

  Future<String> generateWhy(String topic, int depth, {List<AIMessage> history = const []}) {
    return _generate(PromptBuilder.buildWhyPrompt(topic, depth), history: history);
  }

  Future<String> generateNotUnderstood(String topic, int attempts, {List<AIMessage> history = const []}) {
    return _generate(PromptBuilder.buildNotUnderstoodPrompt(topic, attempts), history: history);
  }

  Future<String> generateLearn(String topic, String level) {
    return _generate(PromptBuilder.buildLearnPrompt(topic, level));
  }

  Future<String> simpleChat(String message, String level, {List<AIMessage> history = const []}) {
    return _generate(
      'Réponds à cet élève :\n"$message"\n${PromptBuilder.levelInstruction(level)}',
      history: history,
    );
  }

  /// Renvoie null si la connexion fonctionne, sinon la cause de l'échec.
  Future<String?> testConnection({
    required String provider,
    required String apiKey,
    required String model,
    String? baseUrl,
  }) async {
    final service = AIServiceFactory.create(provider, baseUrl: baseUrl);
    if (service == null) return 'Fournisseur inconnu : $provider';
    if (apiKey.isEmpty && AIServiceFactory.requiresApiKey(provider)) {
      return 'Entre d\'abord ta clé API.';
    }
    if (model.trim().isEmpty) return 'Choisis un modèle.';
    return service.testConnection(model: model.trim(), apiKey: apiKey);
  }
}
