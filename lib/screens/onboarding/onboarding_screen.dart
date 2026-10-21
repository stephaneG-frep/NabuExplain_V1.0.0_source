import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/providers/app_provider.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingData(
      title: 'Tu ne comprends pas quelque chose ?',
      subtitle: 'Montre-le à NabuExplain.\nUn professeur particulier dans ta poche.',
      icon: '🤔',
      gradient: NabuColors.gradientViolet,
    ),
    _OnboardingData(
      title: 'Texte, photo, code ou erreur',
      subtitle: 'Plusieurs façons de poser une question.\nÉcris, colle ou photographie.',
      icon: '📸',
      gradient: NabuColors.gradientCyan,
    ),
    _OnboardingData(
      title: 'À ton niveau',
      subtitle: 'De très simple à expert.\nNabuExplain s\'adapte à toi.',
      icon: '🎯',
      gradient: NabuColors.gradientOrange,
    ),
    _OnboardingData(
      title: 'Comprendre, pas mémoriser',
      subtitle: 'Exemples, analogies, exercices et quiz.\nPour comprendre pour de vrai.',
      icon: '🧠',
      gradient: NabuColors.gradientMagenda,
    ),
    _OnboardingData(
      title: 'Ton professeur IA est prêt',
      subtitle: 'Prêt à tout t\'expliquer,\nquoi que tu veuilles comprendre.',
      icon: '🚀',
      gradient: NabuColors.gradientMulti,
    ),
  ];

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
                ? [NabuColors.backgroundDark, const Color(0xFF221544)]
                : [NabuColors.backgroundLight, const Color(0xFFEDE7FB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1.0),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) =>
                                Transform.scale(scale: value, child: child),
                            child: Text(
                              page.icon,
                              style: const TextStyle(fontSize: 90),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : NabuColors.blueDeep,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentPage ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? NabuColors.violetElectric
                            : NabuColors.violetElectric.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _currentPage < _pages.length - 1
                    ? Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => _skip(context),
                              child: const Text('Passer'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: NabuButton(
                              label: 'SUIVANT',
                              gradient: _pages[_currentPage].gradient,
                              onPressed: () => _controller.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                              ),
                            ),
                          ),
                        ],
                      )
                    : NabuButton(
                        label: 'COMMENCER',
                        gradient: NabuColors.gradientMulti,
                        onPressed: () => _complete(context),
                      ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _complete(BuildContext context) async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    }
  }

  void _skip(BuildContext context) {
    _controller.jumpToPage(_pages.length - 1);
  }
}

class _OnboardingData {
  final String title;
  final String subtitle;
  final String icon;
  final Gradient gradient;

  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}