import 'package:flutter/material.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Quiz _quiz;
  int _currentIndex = 0;
  bool _answered = false;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _quiz = widget.quiz;
  }

  Future<void> _answer(String answer) async {
    if (_answered) return;
    setState(() {
      _selected = answer;
      _answered = true;
      final q = _quiz.questions[_currentIndex];
      final correct = answer.trim().toLowerCase() == q.correctAnswer.trim().toLowerCase();
      _quiz.questions[_currentIndex] = q.copyWith(
        userAnswer: answer,
        isCorrect: correct,
      );
      if (correct) {
        _quiz.score++;
      }
    });
  }

  Future<void> _next() async {
    if (_currentIndex < _quiz.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selected = null;
      });
    } else {
      // Save quiz result
      await StorageService.instance.saveQuiz(_quiz);
      final rate = (_quiz.score / _quiz.questions.length * 100).round();
      await StorageService.instance.incrementProgress('quizzesTaken');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => _QuizResultDialog(
          score: _quiz.score,
          total: _quiz.questions.length,
          rate: rate,
          onRetry: () {
            Navigator.pop(context);
            setState(() {
              _currentIndex = 0;
              _answered = false;
              _selected = null;
              _quiz.score = 0;
              _quiz.questions = [
                for (final q in _quiz.questions) q.copyWith(userAnswer: null, isCorrect: null),
              ];
            });
          },
          onReview: () {
            Navigator.pop(context);
            setState(() {
              _currentIndex = 0;
              _answered = true;
            });
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = _quiz.questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('🎯 Quiz : ${_quiz.topic}'),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : NabuColors.violetElectric,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [NabuColors.backgroundDark, const Color(0xFF4B1D3F)]
                : [NabuColors.backgroundLight, const Color(0xFFFDE8F2)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Question ${_currentIndex + 1}/${_quiz.questions.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NabuColors.magenta,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Score : $_quiz.score',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NabuColors.turquoise,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentIndex + 1) / _quiz.questions.length,
                    backgroundColor: Colors.white24,
                    color: NabuColors.magenta,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    child: Text(
                      question.question,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type : ${_typeLabel(question.type)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _buildOptions(question),
              ),
            ),
            if (_answered) _buildCorrection(question),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'qcm': return 'QCM';
      case 'true_false': return 'Vrai / Faux';
      case 'short_answer': return 'Réponse courte';
      case 'code_fill': return 'Compléter le code';
      default: return type;
    }
  }

  List<Widget> _buildOptions(dynamic q) {
    final options = q.options as List;
    if (options.isEmpty) {
      // Short answer or code_fill
      final controller = TextEditingController();
      WidgetsBinding.instance.addPostFrameCallback((_) {});
      return [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Tape ta réponse...',
            hintStyle: const TextStyle(fontSize: 14),
          ),
          enabled: !_answered,
          onSubmitted: (v) => _answer(v),
        ),
        const SizedBox(height: 12),
        if (!_answered)
          NabuButton(
            label: 'Valider',
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _answer(controller.text.trim());
              }
            },
          ),
      ];
    }

    return [
      for (final option in options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OptionTile(
            label: option,
            onTap: () => _answer(option),
            selected: _selected == option,
            revealed: _answered,
            isCorrect: option.trim().toLowerCase() == q.correctAnswer.trim().toLowerCase(),
          ),
        ),
    ];
  }

  Widget _buildCorrection(dynamic q) {
    final correct = _selected != null &&
        _selected!.trim().toLowerCase() == q.correctAnswer.trim().toLowerCase();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: correct
              ? [NabuColors.green.withValues(alpha: 0.9), NabuColors.turquoise.withValues(alpha: 0.8)]
              : [NabuColors.red.withValues(alpha: 0.9), NabuColors.orange.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? 'Bonne réponse !' : 'Mauvaise réponse',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (!correct) ...[
            const SizedBox(height: 8),
            Text(
              'Réponse correcte : ${q.correctAnswer}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
          if (q.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '💡 ${q.explanation}',
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          NabuButton(
            label: _currentIndex < _quiz.questions.length - 1 ? 'Question suivante ▶' : 'Voir le résultat 🏁',
            onPressed: _next,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool revealed;
  final bool isCorrect;

  const _OptionTile({
    required this.label,
    required this.onTap,
    required this.selected,
    required this.revealed,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color? bg;
    Color? border;
    IconData? trailing;

    if (revealed) {
      if (isCorrect) {
        bg = NabuColors.green.withValues(alpha: 0.2);
        border = NabuColors.green;
        trailing = Icons.check_circle;
      } else if (selected) {
        bg = NabuColors.red.withValues(alpha: 0.2);
        border = NabuColors.red;
        trailing = Icons.cancel;
      }
    } else if (selected) {
      bg = NabuColors.magenta.withValues(alpha: 0.2);
      border = NabuColors.magenta;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg ?? (isDark ? Colors.white10 : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: border ?? (isDark ? Colors.white24 : Colors.black12),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (trailing != null)
              Icon(trailing, color: isCorrect ? NabuColors.green : NabuColors.red),
          ],
        ),
      ),
    );
  }
}

class _QuizResultDialog extends StatelessWidget {
  final int score;
  final int total;
  final int rate;
  final VoidCallback onRetry;
  final VoidCallback onReview;

  const _QuizResultDialog({
    required this.score,
    required this.total,
    required this.rate,
    required this.onRetry,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final color = rate >= 70
        ? NabuColors.green
        : rate >= 40
            ? NabuColors.orange
            : NabuColors.red;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rate >= 70 ? '🎉' : rate >= 40 ? '💪' : '📚',
              style: const TextStyle(fontSize: 50),
            ),
            const SizedBox(height: 12),
            Text(
              rate >= 70
                  ? 'Excellent !'
                  : rate >= 40
                      ? 'Bien joué !'
                      : 'Continue à apprendre !',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$score / $total',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Taux de réussite : $rate%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rate >= 70
                  ? 'Le sujet est bien maîtrisé !'
                  : rate >= 40
                      ? 'Presque ! Relis les explications de tes erreurs.'
                      : 'Relis tes explications et réessaie, tu vas y arriver !',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Rejouer'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReview,
                    child: const Text('Correction'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}