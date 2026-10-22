import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/core/constants/app_constants.dart';
import 'package:nabu_explain/models/conversation.dart';
import 'package:nabu_explain/providers/app_provider.dart';
import 'package:nabu_explain/services/pdf/pdf_service.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/common/cards.dart';
import 'package:nabu_explain/widgets/inputs/level_selector.dart';
import 'package:nabu_explain/screens/teacher/quiz_screen.dart';
import 'package:nabu_explain/screens/teacher/exercise_screen.dart';
import 'package:nabu_explain/screens/teacher/flashcards_screen.dart';
import 'package:nabu_explain/screens/teacher/step_by_step_screen.dart';
import 'package:nabu_explain/screens/teacher/socratic_screen.dart';
import 'package:nabu_explain/screens/teacher/learn_screen.dart';
import 'package:nabu_explain/screens/teacher/teacher_session.dart';
import 'package:nabu_explain/screens/teacher/widgets/message_bubble.dart';
import 'package:nabu_explain/screens/teacher/widgets/teacher_chips.dart';

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
  // Textes pré-remplis par l'accueil : ce sont des intitulés, pas des questions.
  static const _prefills = ['💻 Ex', '🐞 C', '📚 C', '📄 A', '➗ E', '💬 D'];

  static const _suggestions = [
    'Pourquoi le ciel est bleu ?',
    'Qu\'est-ce qu\'une API ?',
    'Explique-moi Git',
    'Comment fonctionne Internet ?',
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final TeacherSession _session;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _session = TeacherSession(
      initialType: widget.initialType,
      initialImages: widget.initialImages,
      conversation: widget.conversation,
      level: settings['selectedLevel'] as String? ?? 'beginner',
      complexity: settings['complexity'] as int? ?? 50,
    )..addListener(_onSessionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prompt = widget.initialPrompt?.trim();
      if (prompt != null &&
          prompt.isNotEmpty &&
          !_prefills.any(prompt.startsWith)) {
        _session.send(prompt);
      }
    });
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Actions ────────────────────────────────────────────────
  void _send() {
    if (_session.send(_controller.text)) _controller.clear();
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _startQuiz() async {
    final quiz = await _session.generateQuiz();
    if (quiz != null && mounted) _push(QuizScreen(quiz: quiz));
  }

  Future<void> _createFlashcards() async {
    final cards = await _session.generateFlashcards();
    if (cards != null && mounted) _push(FlashcardsScreen(cards: cards));
  }

  Future<void> _saveToLibrary() async {
    final saved = await _session.saveToLibrary();
    _showSnack(
      saved
          ? '✅ Explication sauvegardée dans ta bibliothèque.'
          : 'Aucune explication à sauvegarder pour l\'instant.',
    );
  }

  Future<void> _exportPdf() async {
    final exp = _session.explanationForExport();
    if (exp == null) {
      _showSnack('Aucune explication à exporter pour l\'instant.');
      return;
    }
    await PdfExportService().exportAndShare(
      context,
      () => PdfExportService().exportExplanation(exp),
    );
  }

  Future<void> _pickImageForChat() async {
    if (_session.isLoading) return;
    try {
      final images = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (images.isEmpty) return;
      final paths = <String>[];
      for (final img in images) {
        paths.add(await StorageService.instance.saveImage(File(img.path)));
      }
      final text = _controller.text;
      _controller.clear();
      await _session.sendImages(paths, text);
    } catch (_) {
      _showSnack('Impossible d\'importer l\'image');
    }
  }

  // ── Interface ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = _session.messages;

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
            onPressed: _pickImageForChat,
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
              child: messages.isEmpty && !_session.isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, i) =>
                          MessageBubble(message: messages[i]),
                    ),
            ),
            if (_session.isLoading) const TypingIndicator(),
            _buildActionBar(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Map<String, String> _levelInfo(String key) {
    return AppConstants.levels.firstWhere(
      (l) => l['key'] == key,
      orElse: () => {'key': key, 'label': key, 'emoji': '🎓'},
    );
  }

  Widget _buildLevelPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = _levelInfo(_session.level);
    final complexity = _session.complexity;
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
                '${level['emoji']} ${level['label']}',
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
                complexity < 30
                    ? 'Simple'
                    : complexity > 70
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
        String localLevel = _session.level;
        int localComplexity = _session.complexity;
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
                    label: _session.hasExplanation
                        ? '🔄 Reformuler maintenant'
                        : '✅ Valider',
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(settingsProvider.notifier).updateAll({
                        'selectedLevel': localLevel,
                        'complexity': localComplexity,
                      });
                      _session.updateLevel(
                        localLevel,
                        localComplexity,
                        levelLabel: _levelInfo(localLevel)['label']!,
                      );
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
    // Défilant pour les petits écrans (ou le clavier ouvert), centré sinon.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 64).clamp(0, double.infinity),
          ),
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
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in _suggestions)
                    TopicSuggestionChip(
                      label: s,
                      onTap: () => _session.send(s),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final s = _session;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            TeacherActionChip(icon: '❓', label: 'Pourquoi ?', onTap: s.askWhy),
            TeacherActionChip(
              icon: '😕',
              label: 'Pas compris',
              onTap: s.notUnderstood,
            ),
            TeacherActionChip(icon: '🎭', label: 'Analogie', onTap: s.analogy),
            TeacherActionChip(
              icon: '🪜',
              label: 'Pas à pas',
              onTap: () =>
                  _push(StepByStepScreen(topic: s.topic, aiController: s.ai)),
            ),
            TeacherActionChip(
              icon: '🧠',
              label: 'Fais-moi réfléchir',
              onTap: () =>
                  _push(SocraticScreen(topic: s.topic, aiController: s.ai)),
            ),
            TeacherActionChip(
              icon: '🎯',
              label: 'Teste-moi',
              onTap: _startQuiz,
            ),
            TeacherActionChip(
              icon: '🏋️',
              label: 'Exercice',
              onTap: () =>
                  _push(ExerciseScreen(topic: s.topic, aiController: s.ai)),
            ),
            TeacherActionChip(
              icon: '📝',
              label: 'Fiche mémo',
              onTap: s.createMemo,
            ),
            TeacherActionChip(
              icon: '🗂️',
              label: 'Flashcards',
              onTap: _createFlashcards,
            ),
            TeacherActionChip(
              icon: '🎓',
              label: 'Apprends-moi',
              onTap: () =>
                  _push(LearnScreen(topic: s.topic, aiController: s.ai)),
            ),
            if (s.currentTopic != null)
              TeacherActionChip(
                icon: '↩️',
                label: 'Revenir au sujet',
                onTap: s.goBackToTopic,
              ),
            TeacherActionChip(
              icon: '💾',
              label: 'Sauvegarder',
              onTap: _saveToLibrary,
            ),
            TeacherActionChip(
              icon: '📤',
              label: 'Exporter PDF',
              onTap: _exportPdf,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final type = _session.currentType;
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
                  hintText: type == 'code'
                      ? 'Colle ton code...'
                      : type == 'error'
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
                child: _session.isLoading
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
