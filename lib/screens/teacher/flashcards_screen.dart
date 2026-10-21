import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';

class FlashcardsScreen extends StatefulWidget {
  final List<Flashcard> cards;

  const FlashcardsScreen({super.key, required this.cards});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late List<Flashcard> _cards;
  int _index = 0;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _cards = List.of(widget.cards);
  }

  Future<void> _rate(String status) async {
    final card = _cards[_index].copyWith(status: status);
    _cards[_index] = card;
    await StorageService.instance.saveFlashcard(card);
    await StorageService.instance.incrementProgress('flashcardsReviewed');
    if (!mounted) return;
    if (_index < _cards.length - 1) {
      setState(() {
        _index++;
        _flipped = false;
      });
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🎉 Terminé !'),
            content: const Text('Toutes les flashcards sont revues.\nElles sont sauvegardées dans ta bibliothèque.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('🗂️ Flashcards')),
        body: const Center(child: Text('Aucune flashcard à réviser.')),
      );
    }
    final card = _cards[_index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗂️ Flashcards'),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : NabuColors.violetElectric,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [NabuColors.backgroundDark, const Color(0xFF1D244B)]
                : [NabuColors.backgroundLight, const Color(0xFFEAF8FF)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Carte ${_index + 1}/${_cards.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NabuColors.cyanSoft,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {
                      _cards.shuffle();
                      _index = 0;
                      _flipped = false;
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => setState(() => _flipped = !_flipped),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      final rotate = Tween(begin: 0.0, end: 1.0).animate(animation);
                      return AnimatedBuilder(
                        animation: rotate,
                        builder: (context, _) {
                          final angle = (1 - rotate.value) * 3.14159;
                          final showFront = angle < 1.57;
                          return Transform(
                            transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                            alignment: Alignment.center,
                            child: showFront
                                ? Transform(
                                    transform: Matrix4.identity()..rotateY(3.14159),
                                    alignment: Alignment.center,
                                    child: _FlashcardFace(
                                      key: ValueKey('front_${card.id}'),
                                      title: 'Verso',
                                      content: card.back,
                                      gradient: NabuColors.gradientCyan,
                                      icon: '✅',
                                    ),
                                  )
                                : _FlashcardFace(
                                    key: ValueKey('back_${card.id}'),
                                    title: 'Recto',
                                    content: card.front,
                                    gradient: NabuColors.gradientViolet,
                                    icon: '❓',
                                  ),
                          );
                        },
                      );
                    },
                    child: _flipped
                        ? _FlashcardFace(
                            key: ValueKey('flipped_${card.id}'),
                            title: 'Verso',
                            content: card.back,
                            gradient: NabuColors.gradientCyan,
                            icon: '✅',
                          )
                        : _FlashcardFace(
                            key: ValueKey('front_${card.id}'),
                            title: 'Recto',
                            content: card.front,
                            gradient: NabuColors.gradientViolet,
                            icon: '❓',
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Touchez la carte pour la retourner',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            if (_flipped)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rate('known'),
                        child: const Text('😊 Je savais'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rate('review'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: NabuColors.orange),
                        ),
                        child: const Text('🔄 À revoir'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rate('unknown'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: NabuColors.red),
                        ),
                        child: const Text('❓ Je ne savais pas'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardFace extends StatelessWidget {
  final String title;
  final String content;
  final Gradient gradient;
  final String icon;

  const _FlashcardFace({
    super.key,
    required this.title,
    required this.content,
    required this.gradient,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            child: MarkdownBody(
              data: content,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, fontSize: 20, height: 1.4, fontWeight: FontWeight.w800),
                listBullet: const TextStyle(color: Colors.white),
              ),
              selectable: true,
            ),
          ),
        ],
      ),
    );
  }
}