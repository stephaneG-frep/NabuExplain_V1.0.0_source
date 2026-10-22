import 'package:flutter/material.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';

/// Trois points animés pendant que le professeur répond.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

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

/// Pastille de la barre d'actions (Pourquoi ?, Analogie, Quiz…).
class TeacherActionChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const TeacherActionChip({super.key, required this.icon, required this.label, required this.onTap});

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

/// Question d'exemple proposée quand la conversation est vide.
class TopicSuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const TopicSuggestionChip({super.key, required this.label, required this.onTap});

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
