import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nabu_explain/models/conversation.dart';
import 'package:nabu_explain/widgets/code/code_view.dart';
import 'package:nabu_explain/widgets/explanations/structured_explanation.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';

/// Bulle de conversation : texte de l'élève (avec images ou code) ou réponse
/// du professeur (Markdown, code coloré, explication structurée).
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isUser
              ? NabuColors.gradientViolet
              : null,
          color: isUser
              ? null
              : isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isDark ? Colors.white12 : NabuColors.violetLight.withValues(alpha: 0.4),
                ),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: NabuColors.violetElectric.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
        ),
        child: _buildContent(context, isUser),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isUser) {
    final text = message.content;

    if (isUser) {
      // Detect if it's code vs normal text
      final looksLikeCode = text.contains('\n') && (text.contains('{') || text.contains('=>') || text.contains('function') || text.contains('def '));
      if (looksLikeCode) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CodeView(code: text, fontSize: 12),
          ],
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.imagePaths.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final path in message.imagePaths)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _showImageZoom(context, path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(path),
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }

    return _buildAIContent(context, text);
  }

  Widget _buildAIContent(BuildContext context, String text) {
    final trimmed = text.trim();

    // If it's code explanation, use structured view
    final isCodeNear = text.contains('```');

    if (text.length > 40 && text.split('\n').length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCodeNear)
            _CodeRich(text: text)
          else
            _StructuredText(text: text),
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white38
                  : Colors.black38,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trimmed,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showImageZoom(BuildContext context, String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: InteractiveViewer(
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    ));
  }
}

class _CodeRich extends StatelessWidget {
  final String text;
  const _CodeRich({required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = _splitCodeBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in parts)
          if (part is _CodeBlock)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CodeView(code: part.code),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MarkdownBody(
                data: part as String,
                selectable: true,
              ),
            ),
      ],
    );
  }

  List<dynamic> _splitCodeBlocks(String text) {
    final result = <dynamic>[];
    final pattern = RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true);
    var lastIndex = 0;
    for (final m in pattern.allMatches(text)) {
      final before = text.substring(lastIndex, m.start).trim();
      if (before.isNotEmpty) result.add(before);
      result.add(_CodeBlock(code: m.group(2) ?? '', language: m.group(1) ?? ''));
      lastIndex = m.end;
    }
    final after = text.substring(lastIndex).trim();
    if (after.isNotEmpty) result.add(after);
    if (result.isEmpty) result.add(text);
    return result;
  }
}

class _CodeBlock {
  final String code;
  final String language;
  _CodeBlock({required this.code, this.language = ''});
}

class _StructuredText extends StatelessWidget {
  final String text;
  const _StructuredText({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.contains('🧠') || text.contains('📖') || text.contains('💡')) {
      return StructuredExplanation(text: text);
    }
    return MarkdownBody(
      data: text,
      selectable: true,
    );
  }
}
