import 'package:flutter/material.dart';
import 'package:nabu_explain/core/constants/app_constants.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';

class LevelSelector extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const LevelSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<LevelSelector> createState() => _LevelSelectorState();
}

class _LevelSelectorState extends State<LevelSelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Niveau d\'explication',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SizedBox(
          // Marges et bordure fixes + contenu (émoji, titre, 2 lignes de
          // description) qui suit la taille de police du système.
          height: 40 + 92 * MediaQuery.textScalerOf(context).scale(14) / 14,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: AppConstants.levels.length,
            itemBuilder: (context, i) {
              final level = AppConstants.levels[i];
              final key = level['key']!;
              final selected = widget.selected == key;
              final label = level['label']!;
              final emoji = level['emoji']!;
              final description = AppConstants.levelDescriptions[key] ?? '';

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => widget.onChanged(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 140,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? LinearGradient(
                              colors: _gradientFor(i),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: selected ? null : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : NabuColors.violetLight.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _gradientFor(i).first.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected ? Colors.white.withValues(alpha: 0.85) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Color> _gradientFor(int i) {
    switch (i) {
      case 0: return [NabuColors.green, NabuColors.turquoise];
      case 1: return [NabuColors.cyanSoft, NabuColors.blueDeep];
      case 2: return [NabuColors.blueDeep, NabuColors.violetElectric];
      case 3: return [NabuColors.violetElectric, NabuColors.magenta];
      default: return [NabuColors.magenta, NabuColors.orange];
    }
  }
}

class ComplexitySlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const ComplexitySlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Simple',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text(
              'Complexité',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: themeColor(context),
              ),
            ),
            const Text(
              'Technique',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: NabuColors.violetElectric,
            inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : NabuColors.violetLight,
            thumbColor: NabuColors.cyanSoft,
            overlayColor: NabuColors.cyanSoft.withValues(alpha: 0.2),
            trackHeight: 5,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: value < 30
                ? 'Plus simple'
                : value > 70
                    ? 'Plus technique'
                    : 'Équilibré',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  Color themeColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
}