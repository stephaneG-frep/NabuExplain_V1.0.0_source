import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';

class SocraticScreen extends StatefulWidget {
  final String topic;
  final AIController aiController;

  const SocraticScreen({
    super.key,
    required this.topic,
    required this.aiController,
  });

  @override
  State<SocraticScreen> createState() => _SocraticScreenState();
}

class _SocraticScreenState extends State<SocraticScreen> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = true;
  int _step = 1;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _isLoading = true);
    try {
      final response = await widget.aiController.generateSocratic(
        widget.topic,
        'beginner',
      );
      setState(() {
        _messages.add({'sender': 'ai', 'text': response});
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _messages.add({'sender': 'ai', 'text': '😕 $e'});
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });
    try {
      _step++;
      final followUp = await widget.aiController.simpleChat(
        'Méthode socratique sur "${widget.topic}". L\'élève a répondu : "$text". '
        'Adapte ta prochaine question en fonction. Sois progressif, à l\'étape $_step.',
        'beginner',
      );
      setState(() {
        _messages.add({'sender': 'ai', 'text': followUp});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'ai', 'text': '😕 $e'});
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Fais-moi réfléchir'),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : NabuColors.violetElectric,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [NabuColors.backgroundDark, const Color(0xFF3B1D4F)]
                : [NabuColors.backgroundLight, const Color(0xFFFBEAFF)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final isUser = m['sender'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.88,
                      ),
                      decoration: BoxDecoration(
                        gradient: isUser ? NabuColors.gradientMagenda : null,
                        color: isUser
                            ? null
                            : isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: isUser
                          ? Text(
                              m['text'] ?? '',
                              style: const TextStyle(color: Colors.white),
                            )
                          : MarkdownBody(data: m['text'] ?? '', selectable: true),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading) const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ta réponse au professeur...',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: NabuColors.magenta),
                    onPressed: _send,
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