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

  const TeacherScreen({
    super.key,
    this.initialPrompt,
    this.initialType = 'notion',
    this.initialImages,
  });

  @override
  ConsumerState<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends ConsumerState<TeacherScreen> {
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

  @override
  void initState() {
    super.initState();
    _level = 'beginner';
    _currentType = widget.initialType;
    _pendingImages = widget.initialImages ?? [];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prompt = widget.initialPrompt;
      if (prompt != null && prompt.trim().isNotEmpty && !_isTyping(prompt)) {
        _handleInitialPrompt(prompt.trim());
      }
    });
  }

  bool _isTyping(String prompt) {
    for (final type in ['💻 Ex', '🐞 C', '📚 C', '📄 A', '➗ E', '💬 D']) {
      if (prompt.startsWith(type)) return false;
    }
    return false;
  }

  Future<void> _handleInitialPrompt(String prompt) async {
    _messages.add(ChatMessage(content: prompt, isUser: true));
    setState(() {});
    await _process(prompt);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _process(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && _pendingImages.isEmpty) return;

    setState(() {
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      String response;
      _currentTopic ??= trimmed.isEmpty ? 'Image' : trimmed;

      switch (_currentType) {
        case 'code':
          response = await _aiController.explainCode(
            code: trimmed,
            language: CodeView.detectLanguage(trimmed),
            level: _level,
            complexity: _complexity,
          );
          _saveExplanation(trimmed, response);
          break;
        case 'error':
          response = await _aiController.explainError(
            error: trimmed,
            context: 'Contexte : application mobile/développement',
            level: _level,
          );
          _saveExplanation(trimmed, response);
          break;
        case 'photo':
        case 'gallery':
          final images = List<String>.from(_pendingImages);
          final exp = await _aiController.explain(
            query: trimmed.isEmpty ? 'Explique ce que tu vois sur cette image.' : trimmed,
            level: _level,
            complexity: _complexity,
            imagePaths: images,
            type: _currentType,
          );
          response = exp.response;
          _saveExplanation(trimmed.isEmpty ? 'Image' : trimmed, response);
          break;
        default:
          final exp = await _aiController.explain(
            query: trimmed,
            level: _level,
            complexity: _complexity,
            type: _currentType,
          );
          response = exp.response;
          _saveExplanation(trimmed, response);
      }

      _addAIResponse(response);
      _lastExplanation = response;
      _understandAttempts = 0;
      _whyDepth = 0;
    } on AIException catch (e) {
      _addAIResponse('😕 ${e.message}\n\nVa dans **Profil → Paramètres → IA** pour configurer ta clé API, ou vérifie ta connexion Internet.');
    } catch (e) {
      _addAIResponse('😕 Une erreur est survenue. Vérifie ta connexion Internet et réessaie.\n\nDétail : $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _pendingImages = [];
      }
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
      imagePaths: _pendingImages,
      title: _currentTopic,
    );
    await StorageService.instance.saveExplanation(exp);
    _savedExplanation = exp;
  }

  void _addAIResponse(String content) {
    _messages.add(ChatMessage(content: content, isUser: false));
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _reLevel() async {
    setState(() => _isLoading = true);
    _addUserBubble('Changer de niveau : ${_levelLabel(_level)}');
    try {
      final exp = await _aiController.explain(
        query: _currentTopic!,
        level: _level,
        complexity: _complexity,
        type: _currentType,
      );
      final response = exp.response;
      _addAIResponse(response);
      _lastExplanation = response;
      _understandAttempts = 0;
      _whyDepth = 0;
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _levelLabel(String key) {
    for (final l in AppConstants.levels) {
      if (l['key'] == key) return l['label']!;
    }
    return key;
  }

  void _addUserBubble(String text) {
    _messages.add(ChatMessage(content: text, isUser: true));
    setState(() {});
  }

  Future<void> _askWhy() async {
    final topic = _currentTopic ?? 'ce sujet';
    _whyDepth++;
    _addUserBubble('❓ Pourquoi ?');
    setState(() => _isLoading = true);
    try {
      final response = await _aiController.generateWhy(topic, _whyDepth);
      _addAIResponse(response);
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _notUnderstood() async {
    _understandAttempts++;
    _addUserBubble('😕 Je n\'ai toujours pas compris');
    setState(() => _isLoading = true);
    try {
      final response = await _aiController.generateNotUnderstood(
        _currentTopic ?? 'ce sujet',
        _understandAttempts,
      );
      _addAIResponse(response);
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _analogy() async {
    _addUserBubble('🎭 Explique avec une analogie');
    setState(() => _isLoading = true);
    try {
      final response = await _aiController.generateAnalogy(
        _currentTopic ?? 'ce sujet',
        _currentTopic ?? 'ce sujet',
      );
      _addAIResponse(response);
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
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
    final topic = _currentTopic ?? 'ce sujet';
    _addUserBubble('🎯 Teste-moi sur "$topic"');
    setState(() => _isLoading = true);
    try {
      final quiz = await _aiController.generateQuiz(topic, _level);
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizScreen(quiz: quiz),
      ));
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
      setState(() => _isLoading = false);
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
    _addUserBubble('📝 Crée une fiche mémo');
    setState(() => _isLoading = true);
    try {
      final memoContent = await _aiController.generateMemo(explanation, topic);
      final memo = MemoCard(
        title: topic,
        content: memoContent,
        explanationId: _savedExplanation?.id ?? '',
        category: _guessCategory(topic),
      );
      await StorageService.instance.saveMemo(memo);
      _addAIResponse('✅ **Fiche mémo créée et sauvegardée !**\n\nTu la retrouveras dans **Bibliothèque → Fiches mémo**.\n\n$memoContent');
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createFlashcards() async {
    final topic = _currentTopic ?? 'ce sujet';
    final explanation = _lastExplanation ?? '';
    _addUserBubble('🗂️ Crée des flashcards');
    setState(() => _isLoading = true);
    try {
      final cards = await _aiController.generateFlashcards(explanation, topic);
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FlashcardsScreen(cards: cards),
      ));
    } catch (e) {
      _addAIResponse('😕 ${e.toString()}');
      setState(() => _isLoading = false);
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
    _addAIResponse('✅ **Expliquation sauvegardée** dans ta bibliothèque.\n\nTu peux la retrouver dans l\'onglet **Bibliothèque**.');
  }

  String _guessCategory(String topic) {
    final t = topic.toLowerCase();
    if (t.contains('git') || t.contains('code') || t.contains('flutter') || t.contains('api') ||
        t.contains('python') || t.contains('program') || t.contains('sql')) {
      return 'Informatique';
    }
    if (t.contains('math') || t.contains('équation') || t.contains('formule')) return 'Mathématiques';
    if (t.contains('bio') || t.contains('phys') || t.contains('chim') || t.contains('atom')) return 'Sciences';
    if (t.contains('histoire') || t.contains('roi') || t.contains('guerre')) return 'Histoire';
    if (t.contains('anglais') || t.contains('français') || t.contains('espagnol')) return 'Langues';
    return 'Autres';
  }

  void _goBackToTopic() {
    if (_currentTopic != null) {
      _addUserBubble('← Revenir à : $_currentTopic');
      setState(() => _isLoading = true);
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
    if (_lastExplanation == null || _currentTopic == null) return;
    final exp = Explanation(
      query: _currentTopic!,
      response: _lastExplanation!,
      level: _level,
      complexity: _complexity,
      type: _currentType,
    );
    final file = await PdfExportService().exportExplanation(exp);
    if (file != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📄 PDF exporté : ${file.path}')),
      );
    }
  }

  Future<void> _pickImageForChat() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        final paths = <String>[];
        for (final img in images) {
          final file = await StorageService.instance.saveImage(File(img.path));
          paths.add(file);
        }
        _pendingImages = paths;
        _currentType = 'photo';
        _messages.add(ChatMessage(
          content: '📷 ${_currentTopic ?? 'Image importée'}',
          isUser: true,
          imagePaths: paths,
        ));
        setState(() {});
        await _process(_controller.text.isEmpty ? 'Explique ce que tu vois sur cette image.' : _controller.text);
      }
    } catch (_) {}
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
                onSubmitted: (v) => _process(v),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_isLoading) return;
                final text = _controller.text.trim();
                _messages.add(ChatMessage(content: text, isUser: true));
                _process(text);
              },
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