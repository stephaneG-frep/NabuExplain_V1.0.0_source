import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class LearnScreen extends StatefulWidget {
  final String topic;
  final AIController aiController;

  const LearnScreen({
    super.key,
    required this.topic,
    required this.aiController,
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<_Chapter>? _chapters;
  int _currentChapter = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await widget.aiController.generateLearn(widget.topic, 'beginner');
      setState(() {
        _chapters = _parseChapters(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _chapters = [_Chapter(number: 1, title: 'Erreur', content: '😕 $e')];
    }
  }

  List<_Chapter> _parseChapters(String raw) {
    final chapters = <_Chapter>[];
    final pattern = RegExp(r'(\d+)\s*[.)]\s*([^\n]+)\n([\s\S]*?)(?=\n\s*\d+\s*[.)]\s|$)');
    for (final m in pattern.allMatches(raw)) {
      chapters.add(_Chapter(
        number: int.tryParse(m.group(1) ?? '') ?? chapters.length + 1,
        title: m.group(2)!.trim(),
        content: m.group(3)!.trim(),
      ));
    }
    if (chapters.isEmpty) {
      chapters.add(_Chapter(number: 1, title: 'Parcours', content: raw.trim()));
    }
    return chapters;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('🎓 Apprends-moi : ${widget.topic}'),
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
            : Column(
                children: [
                  // Chapter navigator
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _chapters!.length,
                      itemBuilder: (context, i) {
                        final selected = i == _currentChapter;
                        return GestureDetector(
                          onTap: () => setState(() => _currentChapter = i),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: selected ? NabuColors.gradientViolet : null,
                              color: selected
                                  ? null
                                  : Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white10
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: selected ? Colors.white : NabuColors.violetElectric,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _chapters![_currentChapter].title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : NabuColors.blueDeep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chapitre ${_currentChapter + 1} / ${_chapters!.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: GlassCard(
                        child: MarkdownBody(
                          data: _chapters![_currentChapter].content,
                          selectable: true,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _currentChapter > 0
                                ? () => setState(() => _currentChapter--)
                                : null,
                            child: const Text('◀ Chapitre préc.'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: NabuButton(
                            label: _currentChapter < _chapters!.length - 1
                                ? 'Chapitre suiv. ▶'
                                : '🎉 Terminer',
                            onPressed: _currentChapter < _chapters!.length - 1
                                ? () => setState(() => _currentChapter++)
                                : () => Navigator.pop(context),
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

class _Chapter {
  final int number;
  final String title;
  final String content;
  _Chapter({required this.number, required this.title, required this.content});
}