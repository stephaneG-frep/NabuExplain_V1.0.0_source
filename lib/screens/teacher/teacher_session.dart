import 'package:flutter/foundation.dart';
import 'package:nabu_explain/models/conversation.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';
import 'package:nabu_explain/services/ai/ai_service.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/code/code_view.dart';

/// État et logique d'une conversation avec le professeur, sans aucun widget :
/// l'écran ne fait qu'afficher [messages] et appeler les actions.
///
/// La session peut survivre à l'écran : une réponse qui arrive après sa
/// fermeture est quand même enregistrée dans l'historique.
class TeacherSession extends ChangeNotifier {
  /// Nombre de messages précédents envoyés à l'IA comme contexte.
  static const historyLength = 10;

  TeacherSession({
    required String initialType,
    List<String>? initialImages,
    Conversation? conversation,
    this.level = 'beginner',
    this.complexity = 50,
    AIController? aiController,
  })  : ai = aiController ?? AIController(),
        currentType = initialType,
        _pendingImages = List.of(initialImages ?? const []) {
    final conv = conversation ?? Conversation(title: '');
    _conversationId = conv.id;
    _conversationCreatedAt = conv.createdAt;
    if (conversation != null) {
      messages.addAll(conversation.messages);
      currentTopic = conversation.topic;
      final lastAI = conversation.messages.lastWhere(
        (m) => !m.isUser && !_isError(m.content),
        orElse: () => ChatMessage(content: '', isUser: false),
      );
      if (lastAI.content.isNotEmpty) lastExplanation = lastAI.content;
    }
  }

  final AIController ai;
  final List<ChatMessage> messages = [];
  bool isLoading = false;
  String level;
  int complexity;
  String? currentTopic;
  String currentType;
  String? lastExplanation;

  int _whyDepth = 0;
  int _understandAttempts = 0;
  Explanation? _savedExplanation;
  List<String> _pendingImages;
  List<String> _lastImages = [];
  late final String _conversationId;
  late final DateTime _conversationCreatedAt;
  bool _disposed = false;

  String get topic => currentTopic ?? 'ce sujet';
  bool get hasExplanation => currentTopic != null && lastExplanation != null;
  List<String> get pendingImages => List.unmodifiable(_pendingImages);

  static bool _isError(String content) => content.startsWith('😕');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Messages ───────────────────────────────────────────────
  void addUserMessage(String text, {List<String> images = const []}) {
    messages.add(ChatMessage(content: text, isUser: true, imagePaths: images));
    _notify();
  }

  /// Ajoute la réponse et enregistre la conversation dans l'historique.
  void _addAIResponse(String content) {
    messages.add(ChatMessage(content: content, isUser: false));
    _persistConversation();
    _notify();
  }

  Future<void> _persistConversation() async {
    if (messages.isEmpty) return;
    final title = currentTopic ?? messages.first.content;
    await StorageService.instance.saveConversation(Conversation(
      id: _conversationId,
      title: title.length > 80 ? '${title.substring(0, 80)}…' : title,
      messages: List.of(messages),
      createdAt: _conversationCreatedAt,
      topic: currentTopic,
    ));
  }

  /// Messages précédents (hors erreurs et hors dernier message de l'élève,
  /// déjà contenu dans le prompt) envoyés comme contexte à l'IA.
  List<AIMessage> history() {
    final previous = List.of(messages);
    if (previous.isNotEmpty && previous.last.isUser) previous.removeLast();
    final relevant = previous.where((m) => m.isUser || !_isError(m.content)).toList();
    final recent = relevant.length > historyLength
        ? relevant.sublist(relevant.length - historyLength)
        : relevant;
    return [
      for (final m in recent) AIMessage(role: m.isUser ? 'user' : 'assistant', content: m.content),
    ];
  }

  // ── Questions ──────────────────────────────────────────────
  /// Envoie le texte saisi (et les images en attente). Renvoie false si rien
  /// n'a été envoyé.
  bool send(String text) {
    if (isLoading) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty && _pendingImages.isEmpty) return false;
    addUserMessage(trimmed, images: List.of(_pendingImages));
    process(trimmed);
    return true;
  }

  /// Joint des images à la question et lance l'explication.
  Future<void> sendImages(List<String> paths, String text) async {
    if (isLoading || paths.isEmpty) return;
    final trimmed = text.trim();
    _pendingImages = List.of(paths);
    currentType = 'photo';
    addUserMessage(trimmed.isEmpty ? '📷 Image importée' : trimmed, images: paths);
    await process(trimmed.isEmpty ? 'Explique ce que tu vois sur cette image.' : trimmed);
  }

  Future<void> process(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && _pendingImages.isEmpty) return;

    isLoading = true;
    _notify();

    final images = List<String>.from(_pendingImages);
    final context = history();
    try {
      String response;
      if (currentTopic == null) {
        currentTopic = trimmed.isEmpty ? 'Image' : trimmed;
        StorageService.instance.incrementProgress('topicsStudied');
      }

      switch (currentType) {
        case 'code':
          response = await ai.explainCode(
            code: trimmed,
            language: CodeView.detectLanguage(trimmed),
            level: level,
            complexity: complexity,
            history: context,
          );
          break;
        case 'error':
          response = await ai.explainError(
            error: trimmed,
            context: 'Contexte : application mobile/développement',
            level: level,
            history: context,
          );
          break;
        default:
          final exp = await ai.explain(
            query: trimmed.isEmpty ? 'Explique ce que tu vois sur cette image.' : trimmed,
            level: level,
            complexity: complexity,
            imagePaths: images,
            type: currentType,
            history: context,
          );
          response = exp.response;
      }

      lastExplanation = response;
      _lastImages = images;
      _savedExplanation = null;
      _understandAttempts = 0;
      _whyDepth = 0;
      _addAIResponse(response);
    } on AIException catch (e) {
      _addAIResponse('😕 ${e.message}\n\nVa dans **Profil → Paramètres → IA** pour configurer ta clé API, ou vérifie ta connexion Internet.');
    } catch (e) {
      _addAIResponse('😕 Une erreur est survenue. Vérifie ta connexion Internet et réessaie.\n\nDétail : $e');
    } finally {
      _pendingImages = [];
      isLoading = false;
      _notify();
    }
  }

  void goBackToTopic() {
    final topic = currentTopic;
    if (topic == null || isLoading) return;
    addUserMessage('← Revenir à : $topic');
    process(topic);
  }

  // ── Actions pédagogiques ───────────────────────────────────
  /// Lance une action IA en gérant le chargement et les erreurs.
  Future<void> _runAction(String userLabel, Future<String> Function(List<AIMessage> history) action) async {
    if (isLoading) return;
    final context = history();
    addUserMessage(userLabel);
    isLoading = true;
    _notify();
    try {
      _addAIResponse(await action(context));
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
    } finally {
      isLoading = false;
      _notify();
    }
  }

  /// Change le niveau ; reformule la dernière explication si besoin.
  void updateLevel(String newLevel, int newComplexity, {required String levelLabel}) {
    final changed = newLevel != level || newComplexity != complexity;
    final reformulate = hasExplanation && changed;
    level = newLevel;
    complexity = newComplexity;
    _notify();
    if (reformulate) _reLevel(levelLabel);
  }

  Future<void> _reLevel(String levelLabel) async {
    final topic = currentTopic;
    if (topic == null) return;
    await _runAction('Changer de niveau : $levelLabel', (context) async {
      final exp = await ai.explain(
        query: topic,
        level: level,
        complexity: complexity,
        type: currentType,
        history: context,
      );
      lastExplanation = exp.response;
      _savedExplanation = null;
      _understandAttempts = 0;
      _whyDepth = 0;
      return exp.response;
    });
  }

  Future<void> askWhy() async {
    _whyDepth++;
    await _runAction('❓ Pourquoi ?', (context) => ai.generateWhy(topic, _whyDepth, history: context));
  }

  Future<void> notUnderstood() async {
    _understandAttempts++;
    await _runAction('😕 Je n\'ai toujours pas compris', (context) => ai.generateNotUnderstood(
          topic,
          _understandAttempts,
          history: context,
        ));
  }

  Future<void> analogy() async {
    await _runAction('🎭 Explique avec une analogie', (context) => ai.generateAnalogy(
          lastExplanation ?? '',
          topic,
          history: context,
        ));
  }

  Future<void> createMemo() async {
    final memoTopic = topic;
    final explanation = lastExplanation ?? '';
    await _runAction('📝 Crée une fiche mémo', (_) async {
      final memoContent = await ai.generateMemo(explanation, memoTopic);
      await StorageService.instance.saveMemo(MemoCard(
        title: memoTopic,
        content: memoContent,
        explanationId: _savedExplanation?.id ?? '',
        category: guessCategory(memoTopic),
      ));
      return '✅ **Fiche mémo créée et sauvegardée !**\n\nTu la retrouveras dans **Bibliothèque → Fiches mémo**.\n\n$memoContent';
    });
  }

  /// Génère un quiz ; renvoie null (et affiche l'erreur) en cas d'échec.
  Future<Quiz?> generateQuiz() {
    return _generateForScreen('🎯 Teste-moi sur "$topic"', () => ai.generateQuiz(topic, level));
  }

  /// Génère des flashcards ; renvoie null (et affiche l'erreur) en cas d'échec.
  Future<List<Flashcard>?> generateFlashcards() {
    final explanation = lastExplanation ?? '';
    return _generateForScreen('🗂️ Crée des flashcards', () => ai.generateFlashcards(explanation, topic));
  }

  Future<T?> _generateForScreen<T>(String userLabel, Future<T> Function() generate) async {
    if (isLoading) return null;
    addUserMessage(userLabel);
    isLoading = true;
    _notify();
    try {
      return await generate();
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
      return null;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  // ── Bibliothèque / export ──────────────────────────────────
  /// Sauvegarde la dernière explication ; renvoie false s'il n'y en a pas.
  Future<bool> saveToLibrary() async {
    if (_savedExplanation != null) return true;
    final topic = currentTopic;
    final response = lastExplanation;
    if (topic == null || response == null) return false;
    final exp = Explanation(
      query: topic,
      response: response,
      level: level,
      complexity: complexity,
      type: currentType,
      imagePaths: _lastImages,
      title: topic,
      category: guessCategory(topic),
    );
    await StorageService.instance.saveExplanation(exp);
    _savedExplanation = exp;
    return true;
  }

  /// La dernière explication, prête pour l'export PDF (null s'il n'y en a pas).
  Explanation? explanationForExport() {
    if (!hasExplanation) return null;
    return Explanation(
      query: currentTopic!,
      response: lastExplanation!,
      level: level,
      complexity: complexity,
      type: currentType,
    );
  }

  String guessCategory(String topic) {
    final t = topic.toLowerCase();
    if (currentType == 'code' || currentType == 'error') return 'Informatique';
    if (currentType == 'formula') return 'Mathématiques';
    if (t.contains('git') || t.contains('code') || t.contains('flutter') || t.contains('api') ||
        t.contains('python') || t.contains('program') || t.contains('sql') ||
        t.contains('informatique') || t.contains('ordinateur') || t.contains('internet')) {
      return 'Informatique';
    }
    if (t.contains('math') || t.contains('équation') || t.contains('formule')) return 'Mathématiques';
    if (t.contains('bio') || t.contains('phys') || t.contains('chim') || t.contains('atom')) return 'Sciences';
    if (t.contains('histoire') || t.contains('roi') || t.contains('guerre')) return 'Histoire';
    if (t.contains('anglais') || t.contains('français') || t.contains('espagnol')) return 'Langues';
    return 'Autres';
  }
}
