import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/theme_map.dart';

class CodeView extends StatelessWidget {
  final String code;
  final String? language;
  final double fontSize;

  const CodeView({
    super.key,
    required this.code,
    this.language,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detectedLang = language ?? detectLanguage(code);
    final languageId = _languageIds[detectedLang] ?? 'dart';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            width: double.infinity,
            child: Row(
              children: [
                Text(
                  detectedLang,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black45,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copié !'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: Icon(
                    Icons.copy,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              code,
              language: languageId,
              theme: isDark ? themeMap['monokai-sublime']! : themeMap['atom-one-light']!,
              padding: EdgeInsets.zero,
              textStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String detectLanguage(String code) {
    final trimmed = code.trimLeft();
    if (trimmed.startsWith('import ')) {
      if (trimmed.contains('package:flutter')) return 'Dart';
      if (trimmed.contains('from ') && trimmed.contains(';')) return 'JavaScript';
    }
    if (trimmed.startsWith('void main') || trimmed.startsWith('int ')) return 'Dart';
    if (trimmed.contains('public static void main') || trimmed.contains('System.out')) return 'Java';
    if (trimmed.startsWith('func ') || trimmed.contains('package main')) return 'Go';
    if (trimmed.startsWith('def ') || trimmed.contains('print(') && !trimmed.contains('{')) return 'Python';
    if (trimmed.startsWith('#include')) return 'C++';
    if (trimmed.contains('console.log') && !trimmed.contains(';') == false) return 'JavaScript';
    if (trimmed.startsWith('SELECT ') || (trimmed.contains('FROM ') && trimmed.contains('WHERE'))) return 'SQL';
    if (trimmed.startsWith('<!DOCTYPE')) return 'HTML';
    if (trimmed.startsWith('<style') || trimmed.contains('{') && trimmed.contains('color:')) return 'CSS';
    if (trimmed.startsWith('let ') || trimmed.startsWith('const ')) return 'JavaScript';
    if (trimmed.startsWith('fn ')) return 'Rust';
    if (trimmed.contains('<?php')) return 'PHP';
    if (trimmed.contains('echo ') && trimmed.contains('"')) return 'Bash';
    return 'Dart';
  }

  static const Map<String, String> _languageIds = {
    'Dart': 'dart',
    'Python': 'python',
    'JavaScript': 'javascript',
    'TypeScript': 'typescript',
    'Java': 'java',
    'Kotlin': 'kotlin',
    'Swift': 'swift',
    'PHP': 'php',
    'C': 'c',
    'C++': 'cpp',
    'C#': 'csharp',
    'Rust': 'rust',
    'Go': 'go',
    'SQL': 'sql',
    'Bash': 'bash',
    'Shell': 'bash',
    'PowerShell': 'powershell',
    'HTML': 'xml',
    'CSS': 'css',
    'Flutter': 'dart',
  };
}