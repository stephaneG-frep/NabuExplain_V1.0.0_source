import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class ExerciseScreen extends StatefulWidget {
  final String topic;
  final AIController aiController;

  const ExerciseScreen({
    super.key,
    required this.topic,
    required this.aiController,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  Exercise? _exercise;
  bool _isLoading = true;
  bool _hintShown = false;
  bool _solutionShown = false;
  String _difficulty = 'Normal';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final ex = await widget.aiController.generateExercise(
        widget.topic,
        _difficulty,
        StorageService.instance.cachedSettings['selectedLevel'] as String? ?? 'beginner',
      );
      if (!mounted) return;
      setState(() {
        _exercise = ex;
        _isLoading = false;
        _hintShown = false;
        _solutionShown = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('😕 $e')));
    }
  }

  Future<void> _markDone() async {
    // Un exercice ne compte qu'une fois dans la progression.
    if (_exercise == null || _exercise!.completed) return;
    final updated = Exercise(
      id: _exercise!.id,
      topic: _exercise!.topic,
      difficulty: _exercise!.difficulty,
      content: _exercise!.content,
      hint: _exercise!.hint,
      solution: _exercise!.solution,
      createdAt: _exercise!.createdAt,
      completed: true,
    );
    await StorageService.instance.updateExercise(updated);
    await StorageService.instance.incrementProgress('exercisesDone');
    if (!mounted) return;
    setState(() => _exercise = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Exercice terminé ! Ta progression est mise à jour.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('🏋️ Exercice : ${widget.topic}'),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : NabuColors.violetElectric,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [NabuColors.backgroundDark, const Color(0xFF122042)]
                : [NabuColors.backgroundLight, const Color(0xFFE8F0FF)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _exercise == null
                ? const Center(child: Text('Impossible de générer l\'exercice.'))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final ex = _exercise!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Difficulté : ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            DropdownButton<String>(
              value: _difficulty,
              items: ['Facile', 'Normal', 'Difficile', 'Challenge']
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                setState(() => _difficulty = v ?? 'Normal');
                _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📝 Énoncé',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NabuColors.blueDeep),
              ),
              const SizedBox(height: 10),
              MarkdownBody(data: ex.content, selectable: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_hintShown)
          NabuButton(
            label: '💡 INDICE',
            icon: Icons.lightbulb_outline,
            onPressed: () => setState(() => _hintShown = true),
          )
        else if (ex.hint != null && ex.hint!.isNotEmpty) ...[
          GlassCard(
            tintColor: NabuColors.orange.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 Indice',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: NabuColors.orange),
                ),
                const SizedBox(height: 8),
                Text(ex.hint!),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!_solutionShown && _hintShown)
          NabuButton(
            label: '🔍 AUTRE INDICE',
            icon: Icons.lightbulb,
            gradient: NabuColors.gradientCyan,
            onPressed: () => setState(() => _hintShown = false),
          ),
        if (_hintShown && !_solutionShown) ...[
          const SizedBox(height: 12),
          NabuButton(
            label: '👀 VOIR LA SOLUTION',
            icon: Icons.remove_red_eye,
            gradient: NabuColors.gradientMagenda,
            onPressed: () => setState(() => _solutionShown = true),
          ),
        ],
        if (_solutionShown) ...[
          const SizedBox(height: 16),
          GlassCard(
            tintColor: NabuColors.green.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Solution',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: NabuColors.green),
                ),
                const SizedBox(height: 8),
                MarkdownBody(data: ex.solution ?? '', selectable: true),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Plus tard'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NabuButton(
                label: ex.completed ? '✅ Terminé' : '🏁 J\'ai terminé',
                gradient: NabuColors.gradientCyan,
                onPressed: ex.completed ? null : _markDone,
              ),
            ),
          ],
        ),
      ],
    );
  }
}