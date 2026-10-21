import 'package:flutter/material.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class ExplanationSection {
  final String title;
  final String content;
  final String icon;
  final Color color;

  ExplanationSection({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });
}

class StructuredExplanation extends StatelessWidget {
  final String text;

  const StructuredExplanation({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildWidgets(context, sections),
    );
  }

  List<ExplanationSection> _parseSections(String text) {
    final patterns = [
      (RegExp(r'🧠\s*En une phrase'), '🧠', 'En une phrase', NabuColors.violetElectric),
      (RegExp(r'📖\s*Explication'), '📖', 'Explication', NabuColors.blueDeep),
      (RegExp(r'💡\s*Exemple'), '💡', 'Exemple concret', NabuColors.cyanSoft),
      (RegExp(r'🔍\s*Plus précisément'), '🔍', 'Plus précisément', NabuColors.turquoise),
      (RegExp(r'⭐\s*À retenir'), '⭐', 'À retenir', NabuColors.green),
      (RegExp(r'⚠️\s*Erreur fréquente'), '⚠️', 'Erreur fréquente', NabuColors.orange),
      (RegExp(r'❓\s*Vérifions'), '❓', 'Vérifions si tu as compris', NabuColors.magenta),
    ];

    // Find all section markers
    final starts = patterns
        .expand((p) => p.$1.allMatches(text))
        .map((m) => m.start)
        .toList()
      ..sort();

    if (starts.isEmpty) {
      return [ExplanationSection(
        title: 'Explication',
        content: text.trim(),
        icon: '📖',
        color: NabuColors.blueDeep,
      )];
    }

    final sections = <ExplanationSection>[];
    final preamble = text.substring(0, starts.first).trim();
    if (preamble.isNotEmpty && preamble.length > 2 && !preamble.contains('🧠')) {
      sections.add(ExplanationSection(
        title: '',
        content: preamble,
        icon: '✨',
        color: NabuColors.violetElectric,
      ));
    }

    for (int i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = i + 1 < starts.length ? starts[i + 1] : text.length;
      var sectionText = text.substring(start, end).trim();
      if (sectionText.isEmpty) continue;

      // Determine which pattern matched
      String title = '';
      String icon = '';
      Color color = NabuColors.violetElectric;
      for (final (re, ic, ti, co) in patterns) {
        if (re.hasMatch(sectionText)) {
          title = ti;
          icon = ic;
          color = co;
          sectionText = sectionText.replaceAll(re, '').trim();
          break;
        }
      }

      sections.add(ExplanationSection(
        title: title,
        content: sectionText,
        icon: icon,
        color: color,
      ));
    }

    return sections;
  }

  List<Widget> _buildWidgets(BuildContext context, List<ExplanationSection> sections) {
    return [
      for (final section in sections)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SectionCard(section: section),
        ),
    ];
  }
}

class _SectionCard extends StatelessWidget {
  final ExplanationSection section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? section.color.withValues(alpha: 0.12)
            : section.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: section.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title.isNotEmpty)
            Row(
              children: [
                Text(section.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  section.title,
                  style: TextStyle(
                    color: section.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          if (section.title.isNotEmpty) const SizedBox(height: 8),
          Text(
            section.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionCardWidget extends StatelessWidget {
  final String title;
  final String content;
  final String icon;
  final Color color;

  const SectionCardWidget({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tintColor: color.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}