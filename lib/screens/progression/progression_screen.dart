import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/providers/app_provider.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [NabuColors.backgroundDark, const Color(0xFF10251B)]
                : [NabuColors.backgroundLight, const Color(0xFFE8FBF1)],
          ),
        ),
        child: SafeArea(
          child: ref.watch(progressProvider).when(
            data: (data) => _buildContent(context, data as ProgressData),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(child: Text('Erreur de chargement')),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProgressData p) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(progressProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(
                'Ma progression',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : NabuColors.blueDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Success rate ring
          _SuccessRateCard(rate: p.successRate, quizzes: p.quizzesTaken),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _StatCard(
                icon: '📚',
                label: 'Sujets étudiés',
                value: '${p.topicsStudied}',
                gradient: [NabuColors.violetElectric, NabuColors.blueDeep],
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: '💬',
                label: 'Explications',
                value: '${p.explanationsViewed}',
                gradient: [NabuColors.cyanSoft, NabuColors.turquoise],
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: '🎯',
                label: 'Quiz réalisés',
                value: '${p.quizzesTaken}',
                gradient: [NabuColors.magenta, NabuColors.violetElectric],
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: '🏋️',
                label: 'Exercices',
                value: '${p.exercisesDone}',
                gradient: [NabuColors.orange, NabuColors.magenta],
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: '🗂️',
                label: 'Flashcards',
                value: '${p.flashcardsReviewed}',
                gradient: [NabuColors.turquoise, NabuColors.cyanSoft],
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: '⭐',
                label: 'Réussite',
                value: '${p.successRate.round()}%',
                gradient: [NabuColors.green, NabuColors.turquoise],
              )),
            ],
          ),
          const SizedBox(height: 24),

          // Notions à revoir
          GlassCard(
            tintColor: NabuColors.orange.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📌 Notions à revoir',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NabuColors.orange),
                ),
                const SizedBox(height: 10),
                if (p.topicsToReview.isEmpty)
                  const Text(
                    'Rien à revoir pour l\'instant. Continue comme ça ! 🌟',
                    style: TextStyle(fontSize: 13),
                  )
                else
                  for (final topic in p.topicsToReview)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.replay, size: 16, color: NabuColors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(topic, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          GlassCard(
            tintColor: NabuColors.cyanSoft.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔥 Série d\'apprentissage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: p.quizzesTaken > 0 ? (p.successRate / 100).clamp(0, 1) : 0.0,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                  color: NabuColors.turquoise,
                  backgroundColor: Colors.white24,
                ),
                const SizedBox(height: 8),
                Text(
                  p.quizzesTaken == 0
                      ? 'Fais ton premier quiz pour lancer ta série !'
                      : 'Continue tes quiz pour progresser !',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SuccessRateCard extends StatelessWidget {
  final double rate;
  final int quizzes;

  const _SuccessRateCard({required this.rate, required this.quizzes});

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      gradient: NabuColors.gradientMulti,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: quizzes > 0 ? (rate / 100).clamp(0.0, 1.0) : 0.0,
                    strokeWidth: 8,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ),
                Text(
                  quizzes > 0 ? '${rate.round()}%' : '--',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Taux de réussite',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  quizzes == 0
                      ? 'Fais un quiz pour mesurer ta progression !'
                      : 'Tu progresses à ton rythme. Continue comme ça !',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final List<Color> gradient;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}