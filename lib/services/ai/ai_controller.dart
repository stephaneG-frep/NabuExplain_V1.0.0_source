import 'dart:convert';
import 'package:nabu_explain/core/constants/app_constants.dart';
import 'package:nabu_explain/core/utils/prompt_builder.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/services/ai/ai_service.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';

class AIController {
  final StorageService _storage = StorageService.instance;

  Future<AIService> _getService() async {
    final settings = await _storage.loadSettings();
    final provider = settings['provider'] as String? ?? 'OpenAI';
    final service = AIServiceFactory.create(provider);
    if (service == null) {
      throw AIException('Fournisseur IA inconnu : $provider');
    }
    return service;
  }

  Future<String> _getApiKey() async {
    final settings = await _storage.loadSettings();
    final provider = settings['provider'] as String? ?? 'OpenAI';
    final key = await _storage.getApiKey(provider);
    if (key == null || key.isEmpty) {
      throw AIException('Aucune clé API configurée pour $provider. Va dans Profil → Paramètres → IA.');
    }
    return key;
  }

  Future<String> _getModel() async {
    final settings = await _storage.loadSettings();
    return settings['model'] as String? ?? 'gpt-4o-mini';
  }

  Future<Explanation> explain({
    required String query,
    required String level,
    required int complexity,
    List<String>? imagePaths,
    String type = 'notion',
  }) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildExplainPrompt(
      query: query,
      level: level,
      complexity: complexity,
    );

    final response = await service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
      imagePaths: imagePaths,
    );

    await _storage.incrementProgress('explanationsViewed');
    await _storage.incrementProgress('topicsStudied');

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
  }) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildCodeExplainPrompt(
      code: code,
      language: language,
      level: level,
      complexity: complexity,
      action: action,
    );

    return service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<String> explainError({
    required String error,
    required String context,
    required String level,
  }) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildErrorExplainPrompt(
      error: error,
      context: context,
      level: level,
    );

    return service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<bool> isError(String text) async {
    try {
      final service = await _getService();
      final apiKey = await _getApiKey();
      final model = await _getModel();
      final response = await service.generate(
        userPrompt: PromptBuilder.buildErrorDetectPrompt(text),
        systemPrompt: 'Tu es un détecteur d\'erreurs technique.',
        model: model,
        apiKey: apiKey,
      );
      return response.toUpperCase().contains('OUI');
    } catch (_) {
      return false;
    }
  }

  Future<Quiz> generateQuiz(String topic, String level) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final response = await service.generate(
      userPrompt: PromptBuilder.buildQuizPrompt(topic, level),
      systemPrompt: 'Tu génères des quiz pédagogiques en JSON.',
      model: model,
      apiKey: apiKey,
      temperature: 0.5,
    );

    final quiz = _parseQuiz(response, topic, level);
    await _storage.saveQuiz(quiz);
    return quiz;
  }

  Quiz _parseQuiz(String raw, String topic, String level) {
    try {
      final cleaned = _extractJson(raw);
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      final questionsRaw = data['questions'] as List? ?? [];
      final questions = questionsRaw.map<QuizQuestion>((q) {
        final m = q as Map<String, dynamic>;
        return QuizQuestion(
          question: m['question'] as String? ?? '',
          type: m['type'] as String? ?? 'qcm',
          options: List<String>.from(m['options'] ?? []),
          correctAnswer: m['correctAnswer'] as String? ?? '',
          explanation: m['explanation'] as String? ?? '',
        );
      }).toList();
      return Quiz(topic: topic, questions: questions, level: level);
    } catch (_) {
      throw AIException('Impossible de générer le quiz. Réessaie.');
    }
  }

  String _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return raw.substring(start, end + 1);
    }
    return raw;
  }

  Future<Exercise> generateExercise(String topic, String difficulty, String level) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildExercisePrompt(topic, difficulty, level);
    final response = await service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
      temperature: 0.6,
    );

    final exercise = _parseExercise(response, topic, difficulty);
    await _storage.saveExercise(exercise);
    return exercise;
  }

  Exercise _parseExercise(String raw, String topic, String difficulty) {
    final content = _section(raw, 'EXERCICE');
    final hint = _section(raw, 'INDICE');
    final secondHint = _section(raw, 'DEUXIEME_INDICE');
    final solution = _section(raw, 'SOLUTION');
    final solutionExplanation = _section(raw, 'EXPLICATION_SOLUTION');

    return Exercise(
      topic: topic,
      difficulty: difficulty,
      content: content.isEmpty ? raw : content,
      hint: hint.isEmpty ? secondHint : hint,
      solution: '${solution.isEmpty ? '' : '$solution\n\n'}$solutionExplanation',
    );
  }

  String _section(String raw, String label) {
    final index = raw.indexOf('$label:');
    if (index < 0) return '';
    var end = raw.indexOf('\n\n', index + label.length + 1);
    if (end < 0) end = raw.length;
    return raw.substring(index + label.length + 1, end).trim();
  }

  Future<List<Flashcard>> generateFlashcards(String explanation, String topic) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildFlashcardsPrompt(explanation, topic);
    final response = await service.generate(
      userPrompt: prompt,
      systemPrompt: 'Tu génères des flashcards en JSON.',
      model: model,
      apiKey: apiKey,
      temperature: 0.4,
    );

    final cards = _parseFlashcards(response);
    await _storage.saveFlashcards(cards);
    return cards;
  }

  List<Flashcard> _parseFlashcards(String raw) {
    try {
      final cleaned = _extractJson(raw);
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      final cardsRaw = data['cards'] as List? ?? [];
      return cardsRaw.map<Flashcard>((c) {
        final m = c as Map<String, dynamic>;
        return Flashcard(
          front: m['front'] as String? ?? '',
          back: m['back'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      throw AIException('Impossible de générer les flashcards.');
    }
  }

  Future<String> generateMemo(String explanation, String topic) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildMemoPrompt(explanation, topic);
    return service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
      temperature: 0.4,
    );
  }

  Future<String> generateAnalogy(String explanation, String topic) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildAnalogiePrompt(explanation, topic);
    return service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<String> generateSteps(String topic, String level) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildStepPrompt(topic, level);
    return service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<String> generateSocratic(String topic, String level) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildSocraticPrompt(topic, level);
    return service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<String> generateWhy(String topic, int depth) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildWhyPrompt(topic, depth);
    return service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<String> generateNotUnderstood(String topic, int attempts) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildNotUnderstoodPrompt(topic, attempts);
    return service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<String> generateLearn(String topic, String level) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    final prompt = PromptBuilder.buildLearnPrompt(topic, level);
    return service.generate(
      userPrompt: prompt,
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<String> simpleChat(String message, String level) async {
    final service = await _getService();
    final apiKey = await _getApiKey();
    final model = await _getModel();

    return service.generate(
      userPrompt: 'Réponds à cet élève :\n"$message"\n${PromptBuilder.levelInstruction(level)}',
      systemPrompt: AppConstants.systemPrompt,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<bool> testConnection({required String provider, required String apiKey, required String model}) async {
    try {
      final service = AIServiceFactory.create(provider);
      if (service == null) return false;
      return await service.testConnection(model: model, apiKey: apiKey);
    } catch (_) {
      return false;
    }
  }
}