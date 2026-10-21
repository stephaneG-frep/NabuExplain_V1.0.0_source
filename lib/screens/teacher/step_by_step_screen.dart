import 'package:flutter/material.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/common/cards.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class StepByStepScreen extends StatefulWidget {
  final String topic;
  final AIController aiController;

  const StepByStepScreen({
    super.key,
    required this.topic,
    required this.aiController,
  });

  @override
  State<StepByStepScreen> createState() => _StepByStepScreenState();
}

class _StepByStepScreenState extends State<StepByStepScreen> {
  List<_Step>? _steps;
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _showVerification = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await widget.aiController.generateSteps(
        widget.topic,
        StorageService.instance.cachedSettings['selectedLevel'] as String? ?? 'beginner',
      );
      if (!mounted) return;
      setState(() {
        _steps = _parseSteps(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('😕 $e'),
      ));
    }
  }

  List<_Step> _parseSteps(String raw) {
    final steps = <_Step>[];
    final pattern = RegExp(r'ÉTAPE\s*(\d+):\s*\n([\s\S]*?)(?=ÉTAPE\s*\d+:|$)');
    for (final m in pattern.allMatches(raw)) {
      final num = int.tryParse(m.group(1)!) ?? steps.length;
      final content = m.group(2)!.trim();
      steps.add(_Step(number: num, content: content));
    }
    if (steps.isEmpty) {
      // Fallback: split by double newlines
      final parts = raw.split(RegExp(r'\n\s*\n'));
      for (int i = 0; i < parts.length; i++) {
        final content = parts[i].trim();
        if (content.isNotEmpty) steps.add(_Step(number: steps.length + 1, content: content));
      }
    }
    return steps;
  }


  Future<void> _notUnderstood() async {
    final current = _steps![_currentIndex];
    setState(() => _isLoading = true);
    try {
      final rephrased = await widget.aiController.generateNotUnderstood(
        '${widget.topic} — étape ${current.number}',
        1,
      );
      if (!mounted) return;
      setState(() {
        _steps![_currentIndex] = _Step(
          number: current.number,
          content: '**Reformulation de l\'étape :**\n\n$rephrased',
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('😕 $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🪜 Mode pas à pas'),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : NabuColors.violetElectric,
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _steps == null || _steps!.isEmpty
                ? const Center(child: Text('Impossible de générer les étapes.'))
                : _buildSteps(isDark),
      ),
    );
  }

  Widget _buildSteps(bool isDark) {
    final total = _steps!.length;
    final current = _steps![_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              for (int i = 0; i < total; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _currentIndex
                          ? NabuColors.violetElectric
                          : isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Étape ${current.number} / $total',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: NabuColors.cyanSoft,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: GlassCard(
                child: MarkdownBody(
                  data: current.content,
                  selectable: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: _currentIndex > 0
                    ? () => setState(() => _currentIndex--)
                    : null,
                child: const Text('◀ PRÉCÉDENT'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _notUnderstood,
                  child: const Text('😕 JE N\'AI PAS COMPRIS'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NabuButton(
                  label: _currentIndex < total - 1 ? 'SUIVANT ▶' : 'J\'AI COMPRIS ✓',
                  onPressed: _currentIndex < total - 1
                      ? () => setState(() => _currentIndex++)
                      : () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _showVerification = !_showVerification),
            child: const Text('❓ Vérifier ma compréhension'),
          ),
        ],
      ),
    );
  }
}

class _Step {
  final int number;
  final String content;
  _Step({required this.number, required this.content});
}