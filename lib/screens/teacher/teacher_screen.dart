import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/core/constants/app_constants.dart';
import 'package:nabu_explain/models/conversation.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/providers/app_provider.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';
import 'package:nabu_explain/services/ai/ai_service.dart';
import 'package:nabu_explain/services/pdf/pdf_service.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/code/code_view.dart';
import 'package:nabu_explain/widgets/common/cards.dart';
import 'package:nabu_explain/widgets/explanations/structured_explanation.dart';
import 'package:nabu_explain/widgets/inputs/level_selector.dart';
import 'package:nabu_explain/screens/teacher/quiz_screen.dart';
import 'package:nabu_explain/screens/teacher/exercise_screen.dart';
import 'package:nabu_explain/screens/teacher/flashcards_screen.dart';
import 'package:nabu_explain/screens/teacher/step_by_step_screen.dart';
import 'package:nabu_explain/screens/teacher/socratic_screen.dart';
import 'package:nabu_explain/screens/teacher/learn_screen.dart';

class TeacherScreen extends ConsumerStatefulWidget {
  final String? initialPrompt;
  final String initialType;
  final List<String>? initialImages;

  /// Conversation de l'historique à reprendre.
  final Conversation? conversation;

  const TeacherScreen({
    super.key,
    this.initialPrompt,
    this.initialType = 'notion',
    this.initialImages,
    this.conversation,
  });

  @override
  ConsumerState<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends ConsumerState<TeacherScreen> {
  // Nombre de messages précédents envoyés à l'IA comme contexte.
  static const _historyLength = 10;

  // Textes pré-remplis par l'accueil : ce sont des intitulés, pas des questions.
  static const _prefills = ['💻 Ex', '🐞 C', '📚 C', '📄 A', '➗ E', '💬 D'];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _aiController = AIController();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _level = 'beginner';
  int _complexity = 50;
  String? _currentTopic;
  String _currentType = 'notion';
  int _whyDepth = 0;
  int _understandAttempts = 0;
  String? _lastExplanation;
  Explanation? _savedExplanation;
  List<String> _pendingImages = [];
  List<String> _lastImages = [];
  late String _conversationId;
  late DateTime _conversationCreatedAt;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _level = settings['selectedLevel'] as String? ?? 'beginner';
    _complexity = settings['complexity'] as int? ?? 50;
    _currentType = widget.initialType;
    _pendingImages = widget.initialImages ?? [];

    final conversation = widget.conversation ?? Conversation(title: '');
    _conversationId = conversation.id;
    _conversationCreatedAt = conversation.createdAt;
    if (widget.conversation != null) {
      _messages.addAll(conversation.messages);
      _currentTopic = conversation.topic;
      final lastAI = conversation.messages.lastWhere(
        (m) => !m.isUser && !m.content.startsWith('😕'),
        orElse: () => ChatMessage(content: '', isUser: false),
      );
      if (lastAI.content.isNotEmpty) _lastExplanation = lastAI.content;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prompt = widget.initialPrompt;
      if (prompt != null && prompt.trim().isNotEmpty && !_isPrefill(prompt)) {
        _handleInitialPrompt(prompt.trim());
      }
    });
  }

  bool _isPrefill(String prompt) {
    return _prefills.any(prompt.startsWith);
  }

  Future<void> _handleInitialPrompt(String prompt) async {
    _messages.add(ChatMessage(content: prompt, isUser: true, imagePaths: List.of(_pendingImages)));
    setState(() {});
    await _process(prompt);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Messages précédents (hors erreurs et hors dernier message de l'élève,
  /// déjà contenu dans le prompt) envoyés comme contexte à l'IA.
  List<AIMessage> _history() {
    final messages = List.of(_messages);
    if (messages.isNotEmpty && messages.last.isUser) messages.removeLast();
    final relevant = messages.where((m) => m.isUser || !m.content.startsWith('😕')).toList();
    final recent = relevant.length > _historyLength
        ? relevant.sublist(relevant.length - _historyLength)
        : relevant;
    return [
      for (final m in recent) AIMessage(role: m.isUser ? 'user' : 'assistant', content: m.content),
    ];
  }

  void _send() {
    if (_isLoading) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) return;
    _messages.add(ChatMessage(content: text, isUser: true, imagePaths: List.of(_pendingImages)));
    _process(text);
  }

  Future<void> _process(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && _pendingImages.isEmpty) return;

    setState(() {
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    final images = List<String>.from(_pendingImages);
    final history = _history();
    try {
      String response;
      if (_currentTopic == null) {
        _currentTopic = trimmed.isEmpty ? 'Image' : trimmed;
        StorageService.instance.incrementProgress('topicsStudied');
      }

      switch (_currentType) {
        case 'code':
          response = await _aiController.explainCode(
            code: trimmed,
            language: CodeView.detectLanguage(trimmed),
            level: _level,
            complexity: _complexity,
            history: history,
          );
          break;
        case 'error':
          response = await _aiController.explainError(
            error: trimmed,
            context: 'Contexte : application mobile/développement',
            level: _level,
            history: history,
          );
          break;
        default:
          final exp = await _aiController.explain(
            query: trimmed.isEmpty ? 'Explique ce que tu vois sur cette image.' : trimmed,
            level: _level,
            complexity: _complexity,
            imagePaths: images,
            type: _currentType,
            history: history,
          );
          response = exp.response;
      }

      _lastExplanation = response;
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
      _safeSetState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _saveExplanation(String topic, String response) async {
    final exp = Explanation(
      query: topic,
      response: response,
      level: _level,
      complexity: _complexity,
      type: _currentType,
      imagePaths: _lastImages,
      title: _currentTopic,
      category: _guessCategory(topic),
    );
    await StorageService.instance.saveExplanation(exp);
    _savedExplanation = exp;
  }

  /// Ajoute la réponse et enregistre la conversation dans l'historique, même
  /// si l'élève a quitté l'écran entre-temps.
  void _addAIResponse(String content) {
    _messages.add(ChatMessage(content: content, isUser: false));
    _persistConversation();
    _safeSetState(() {});
    _scrollToBottom();
  }

  Future<void> _persistConversation() async {
    if (_messages.isEmpty) return;
    final title = _currentTopic ?? _messages.first.content;
    await StorageService.instance.saveConversation(Conversation(
      id: _conversationId,
      title: title.length > 80 ? '${title.substring(0, 80)}…' : title,
      messages: List.of(_messages),
      createdAt: _conversationCreatedAt,
      topic: _currentTopic,
    ));
  }

  /// Lance une action IA en gérant le chargement, les erreurs et le cas où
  /// l'écran est fermé avant la réponse.
  Future<void> _runAction(String userLabel, Future<String> Function(List<AIMessage> history) action) async {
    if (_isLoading) return;
    final history = _history();
    _addUserBubble(userLabel);
    _safeSetState(() => _isLoading = true);
    try {
      _addAIResponse(await action(history));
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _reLevel() async {
    final topic = _currentTopic;
    if (topic == null) return;
    await _runAction('Changer de niveau : ${_levelLabel(_level)}', (history) async {
      final exp = await _aiController.explain(
        query: topic,
        level: _level,
        complexity: _complexity,
        type: _currentType,
        history: history,
      );
      _lastExplanation = exp.response;
      _savedExplanation = null;
      _understandAttempts = 0;
      _whyDepth = 0;
      return exp.response;
    });
  }

  String _levelLabel(String key) {
    for (final l in AppConstants.levels) {
      if (l['key'] == key) return l['label']!;
    }
    return key;
  }

  void _addUserBubble(String text) {
    _messages.add(ChatMessage(content: text, isUser: true));
    _safeSetState(() {});
  }

  Future<void> _askWhy() async {
    final topic = _currentTopic ?? 'ce sujet';
    _whyDepth++;
    await _runAction('❓ Pourquoi ?', (history) => _aiController.generateWhy(topic, _whyDepth, history: history));
  }

  Future<void> _notUnderstood() async {
    _understandAttempts++;
    await _runAction('😕 Je n\'ai toujours pas compris', (history) => _aiController.generateNotUnderstood(
          _currentTopic ?? 'ce sujet',
          _understandAttempts,
          history: history,
        ));
  }

  Future<void> _analogy() async {
    final topic = _currentTopic ?? 'ce sujet';
    await _runAction('🎭 Explique avec une analogie', (history) => _aiController.generateAnalogy(
          _lastExplanation ?? '',
          topic,
          history: history,
        ));
  }

  void _showStepByStep() {
    final topic = _currentTopic ?? 'ce sujet';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StepByStepScreen(topic: topic, aiController: _aiController),
    ));
  }

  void _showSocratic() {
    final topic = _currentTopic ?? 'ce sujet';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SocraticScreen(topic: topic, aiController: _aiController),
    ));
  }

  void _showLearn() {
    final topic = _currentTopic ?? 'ce sujet';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LearnScreen(topic: topic, aiController: _aiController),
    ));
  }

  Future<void> _startQuiz() async {
    if (_isLoading) return;
    final topic = _currentTopic ?? 'ce sujet';
    _addUserBubble('🎯 Teste-moi sur "$topic"');
    _safeSetState(() => _isLoading = true);
    try {
      final quiz = await _aiController.generateQuiz(topic, _level);
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizScreen(quiz: quiz),
      ));
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
      _safeSetState(() => _isLoading = false);
    }
  }

  void _showExercise() {
    final topic = _currentTopic ?? 'ce sujet';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExerciseScreen(topic: topic, aiController: _aiController),
    ));
  }

  Future<void> _createMemos() async {
    final topic = _currentTopic ?? 'ce sujet';
    final explanation = _lastExplanation ?? '';
    await _runAction('📝 Crée une fiche mémo', (_) async {
      final memoContent = await _aiController.generateMemo(explanation, topic);
      final memo = MemoCard(
        title: topic,
        content: memoContent,
        explanationId: _savedExplanation?.id ?? '',
        category: _guessCategory(topic),
      );
      await StorageService.instance.saveMemo(memo);
      return '✅ **Fiche mémo créée et sauvegardée !**\n\nTu la retrouveras dans **Bibliothèque → Fiches mémo**.\n\n$memoContent';
    });
  }

  Future<void> _createFlashcards() async {
    if (_isLoading) return;
    final topic = _currentTopic ?? 'ce sujet';
    final explanation = _lastExplanation ?? '';
    _addUserBubble('🗂️ Crée des flashcards');
    _safeSetState(() => _isLoading = true);
    try {
      final cards = await _aiController.generateFlashcards(explanation, topic);
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FlashcardsScreen(cards: cards),
      ));
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveToLibrary() async {
    if (_savedExplanation == null) {
      if (_lastExplanation != null && _currentTopic != null) {
        await _saveExplanation(_currentTopic!, _lastExplanation!);
      } else {
        _addAIResponse('Aucune explication à sauvegarder.');
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Explication sauvegardée dans ta bibliothèque.')),
    );
  }

  String _guessCategory(String topic) {
    final t = topic.toLowerCase();
    if (_currentType == 'code' || _currentType == 'error') return 'Informatique';
    if (_currentType == 'formula') return 'Mathématiques';
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

  void _goBackToTopic() {
    if (_currentTopic != null && !_isLoading) {
      _addUserBubble('← Revenir à : $_currentTopic');
      _process(_currentTopic!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🦉', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Le Professeur',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : NabuColors.violetElectric,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            onPressed: () => _pickImageForChat(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [NabuColors.backgroundDark, const Color(0xFF241650)]
                : [NabuColors.backgroundLight, const Color(0xFFEDE7FB)],
          ),
        ),
        child: Column(
          children: [
            _buildLevelPanel(),
            Expanded(
              child: _messages.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        return _MessageBubble(message: msg);
                      },
                    ),
            ),
            if (_isLoading) const _TypingIndicator(),
            _buildActionBar(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _showLevelSheet,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.7),
          border: Border(
            bottom: BorderSide(
              color: NabuColors.violetElectric.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: NabuColors.gradientViolet,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_levelEmoji(_level)} ${_levelLabel(_level)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _complexity < 30
                    ? 'Simple'
                    : _complexity > 70
                        ? 'Technique'
                        : 'Équilibré',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
            const Icon(Icons.tune, size: 18, color: NabuColors.violetElectric),
          ],
        ),
      ),
    );
  }

  String _levelEmoji(String key) {
    for (final l in AppConstants.levels) {
      if (l['key'] == key) return l['emoji']!;
    }
    return '🎓';
  }

  void _showLevelSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? NabuColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        String localLevel = _level;
        int localComplexity = _complexity;
        final hadExplanation = _currentTopic != null && _lastExplanation != null;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚙️ Adapter l\'explication',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  LevelSelector(
                    selected: localLevel,
                    onChanged: (v) => setSheetState(() => localLevel = v),
                  ),
                  const SizedBox(height: 16),
                  ComplexitySlider(
                    value: localComplexity,
                    onChanged: (v) => setSheetState(() => localComplexity = v),
                  ),
                  const SizedBox(height: 16),
                  NabuButton(
                    label: hadExplanation ? '🔄 Reformuler maintenant' : '✅ Valider',
                    onPressed: () {
                      Navigator.pop(context);
                      final levelChanged = localLevel != _level;
                      final complexityChanged = localComplexity != _complexity;
                      setState(() {
                        _level = localLevel;
                        _complexity = localComplexity;
                      });
                      ref.read(settingsProvider.notifier).updateAll({
                        'selectedLevel': localLevel,
                        'complexity': localComplexity,
                      });
                      if (hadExplanation && (levelChanged || complexityChanged)) {
                        _reLevel();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🦉', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            Text(
              'Comment puis-je t\'aider aujourd\'hui ?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : NabuColors.blueDeep,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.initialType == 'code'
                  ? 'Colle ton code ci-dessous pour que je te l\'explique.'
                  : widget.initialType == 'error'
                      ? 'Colle ton message d\'erreur ci-dessous.'
                      : 'Pose une question, colle un texte ou une image.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(label: 'Pourquoi le ciel est bleu ?', onTap: () => _sendSuggestion('Pourquoi le ciel est bleu ?')),
                _SuggestionChip(label: 'Qu\'est-ce qu\'une API ?', onTap: () => _sendSuggestion('Qu\'est-ce qu\'une API ?')),
                _SuggestionChip(label: 'Explique-moi Git', onTap: () => _sendSuggestion('Explique-moi Git')),
                _SuggestionChip(label: 'Comment fonctionne Internet ?', onTap: () => _sendSuggestion('Comment fonctionne Internet ?')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendSuggestion(String s) {
    if (_isLoading) return;
    _messages.add(ChatMessage(content: s, isUser: true));
    _process(s);
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ActionChip(icon: '❓', label: 'Pourquoi ?', onTap: _askWhy),
            _ActionChip(icon: '😕', label: 'Pas compris', onTap: _notUnderstood),
            _ActionChip(icon: '🎭', label: 'Analogie', onTap: _analogy),
            _ActionChip(icon: '🪜', label: 'Pas à pas', onTap: _showStepByStep),
            _ActionChip(icon: '🧠', label: 'Fais-moi réfléchir', onTap: _showSocratic),
            _ActionChip(icon: '🎯', label: 'Teste-moi', onTap: _startQuiz),
            _ActionChip(icon: '🏋️', label: 'Exercice', onTap: _showExercise),
            _ActionChip(icon: '📝', label: 'Fiche mémo', onTap: _createMemos),
            _ActionChip(icon: '🗂️', label: 'Flashcards', onTap: _createFlashcards),
            _ActionChip(icon: '🎓', label: 'Apprends-moi', onTap: _showLearn),
            if (_currentTopic != null)
              _ActionChip(icon: '↩️', label: 'Revenir au sujet', onTap: _goBackToTopic),
            _ActionChip(icon: '💾', label: 'Sauvegarder', onTap: _saveToLibrary),
            _ActionChip(icon: '📤', label: 'Exporter PDF', onTap: _exportPdf),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_lastExplanation == null || _currentTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune explication à exporter pour l\'instant.')),
      );
      return;
    }
    final exp = Explanation(
      query: _currentTopic!,
      response: _lastExplanation!,
      level: _level,
      complexity: _complexity,
      type: _currentType,
    );
    await PdfExportService().exportAndShare(context, () => PdfExportService().exportExplanation(exp));
  }

  Future<void> _pickImageForChat() async {
    if (_isLoading) return;
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
      if (images.isNotEmpty) {
        final paths = <String>[];
        for (final img in images) {
          final file = await StorageService.instance.saveImage(File(img.path));
          paths.add(file);
        }
        final text = _controller.text.trim();
        _pendingImages = paths;
        _currentType = 'photo';
        _messages.add(ChatMessage(
          content: text.isEmpty ? '📷 Image importée' : text,
          isUser: true,
          imagePaths: paths,
        ));
        _safeSetState(() {});
        await _process(text.isEmpty ? 'Explique ce que tu vois sur cette image.' : text);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'importer l\'image')),
        );
      }
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? NabuColors.surfaceDark
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _currentType == 'code'
                      ? 'Colle ton code...'
                      : _currentType == 'error'
                          ? 'Colle ton erreur...'
                          : 'Pose ta question au professeur...',
                  suffixIcon: widget.initialType == 'code'
                      ? null
                      : IconButton(
                          onPressed: _pickImageForChat,
                          icon: const Icon(Icons.image_outlined),
                        ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: NabuColors.gradientViolet,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: NabuColors.violetElectric.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isUser
              ? NabuColors.gradientViolet
              : null,
          color: isUser
              ? null
              : isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isDark ? Colors.white12 : NabuColors.violetLight.withValues(alpha: 0.4),
                ),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: NabuColors.violetElectric.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
        ),
        child: _buildContent(context, isUser),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isUser) {
    final text = message.content;

    if (isUser) {
      // Detect if it's code vs normal text
      final looksLikeCode = text.contains('\n') && (text.contains('{') || text.contains('=>') || text.contains('function') || text.contains('def '));
      if (looksLikeCode) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CodeView(code: text, fontSize: 12),
          ],
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.imagePaths.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final path in message.imagePaths)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _showImageZoom(context, path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(path),
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }

    return _buildAIContent(context, text);
  }

  Widget _buildAIContent(BuildContext context, String text) {
    final trimmed = text.trim();

    // If it's code explanation, use structured view
    final isCodeNear = text.contains('```');

    if (text.length > 40 && text.split('\n').length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCodeNear)
            _CodeRich(text: text)
          else
            _StructuredText(text: text),
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white38
                  : Colors.black38,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trimmed,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showImageZoom(BuildContext context, String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: InteractiveViewer(
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    ));
  }
}

class _CodeRich extends StatelessWidget {
  final String text;
  const _CodeRich({required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = _splitCodeBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in parts)
          if (part is _CodeBlock)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CodeView(code: part.code),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MarkdownBody(
                data: part as String,
                selectable: true,
              ),
            ),
      ],
    );
  }

  List<dynamic> _splitCodeBlocks(String text) {
    final result = <dynamic>[];
    final pattern = RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true);
    var lastIndex = 0;
    for (final m in pattern.allMatches(text)) {
      final before = text.substring(lastIndex, m.start).trim();
      if (before.isNotEmpty) result.add(before);
      result.add(_CodeBlock(code: m.group(2) ?? '', language: m.group(1) ?? ''));
      lastIndex = m.end;
    }
    final after = text.substring(lastIndex).trim();
    if (after.isNotEmpty) result.add(after);
    if (result.isEmpty) result.add(text);
    return result;
  }
}

class _CodeBlock {
  final String code;
  final String language;
  _CodeBlock({required this.code, this.language = ''});
}

class _StructuredText extends StatelessWidget {
  final String text;
  const _StructuredText({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.contains('🧠') || text.contains('📖') || text.contains('💡')) {
      return StructuredExplanation(text: text);
    }
    return MarkdownBody(
      data: text,
      selectable: true,
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NabuColors.violetElectric.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _Dot(delay: Duration(milliseconds: 200 * i)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Duration delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Interval(
          widget.delay.inMilliseconds / 600,
          widget.delay.inMilliseconds / 600 + 0.5,
        )),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: NabuColors.violetElectric,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NabuColors.cyanSoft.withValues(alpha: 0.15),
                NabuColors.violetElectric.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: NabuColors.violetElectric.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : NabuColors.blueDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NabuColors.cyanSoft.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : NabuColors.blueDeep,
          ),
        ),
      ),
    );
  }
}