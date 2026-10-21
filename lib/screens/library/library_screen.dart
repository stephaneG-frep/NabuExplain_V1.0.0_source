import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nabu_explain/core/constants/app_constants.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/models/conversation.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/providers/app_provider.dart';
import 'package:nabu_explain/services/pdf/pdf_service.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/common/cards.dart';
import 'package:nabu_explain/screens/teacher/flashcards_screen.dart';
import 'package:nabu_explain/screens/teacher/teacher_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _tab = 0;
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'Tous';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                ? [NabuColors.backgroundDark, const Color(0xFF311520)]
                : [NabuColors.backgroundLight, const Color(0xFFFDEAF3)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Text('📚', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Text(
                      'Ma bibliothèque',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : NabuColors.blueDeep,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        ref.invalidate(explanationsProvider);
                        ref.invalidate(memosProvider);
                        ref.invalidate(flashcardsProvider);
                        ref.invalidate(conversationsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: '🔍 Rechercher dans ta bibliothèque...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TabChip(label: 'Explications', icon: '💬', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                      _TabChip(label: 'Fiches mémo', icon: '📝', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                      _TabChip(label: 'Flashcards', icon: '🗂️', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
                      _TabChip(label: 'Historique', icon: '🕐', selected: _tab == 3, onTap: () => setState(() => _tab = 3)),
                    ],
                  ),
                ),
              ),
              // Category filter
              if (_tab == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Filtre : ', style: TextStyle(fontSize: 12)),
                        for (final cat in ['Tous', ...AppConstants.categories])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: CategoryChip(
                              label: cat,
                              icon: Icons.label,
                              color: NabuColors.violetElectric,
                              selected: _selectedCategory == cat,
                              onTap: () => setState(() => _selectedCategory = cat),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return ref.watch(explanationsProvider).when(
          data: (data) {
            final list = data.cast<Explanation>().where((e) {
              final matchesQuery = e.query.toLowerCase().contains(_query.toLowerCase()) ||
                  (e.response.toLowerCase().contains(_query.toLowerCase()));
              final matchesCat = _selectedCategory == 'Tous' || e.category == _selectedCategory;
              return matchesQuery && matchesCat;
            }).toList();
            if (list.isEmpty) {
              return const _EmptyLibrary(message: 'Aucune explication sauvegardée.\n💡 Demande « Sauvegarder » pendant une conversation.');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) => _ExplanationCard(exp: list[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('Erreur de chargement')),
        );
      case 1:
        return ref.watch(memosProvider).when(
          data: (data) {
            final list = data.cast<MemoCard>().where((m) =>
                m.title.toLowerCase().contains(_query.toLowerCase()) ||
                m.content.toLowerCase().contains(_query.toLowerCase())).toList();
            if (list.isEmpty) {
              return const _EmptyLibrary(message: 'Aucune fiche mémo.\n💡 Utilise « Fiche mémo » pendant une conversation.');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) => _MemoCardWidget(memo: list[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('Erreur de chargement')),
        );
      case 2:
        return ref.watch(flashcardsProvider).when(
          data: (data) {
            final list = data.cast<Flashcard>();
            if (list.isEmpty) {
              return const _EmptyLibrary(message: 'Aucune flashcard.\n💡 Utilise « Flashcards » pendant une conversation.');
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NabuButton(
                    label: '▶ Réviser toutes les cartes',
                    height: 48,
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => FlashcardsScreen(cards: list),
                      ));
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final card = list[i];
                        return GlassCard(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Text('🗂️'),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(card.front,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(card.back,
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () async {
                                  await StorageService.instance.deleteFlashcard(card.id);
                                  ref.invalidate(flashcardsProvider);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('Erreur de chargement')),
        );
      case 3:
        return ref.watch(conversationsProvider).when(
          data: (data) {
            final q = _query.toLowerCase();
            final list = data.where((c) =>
                c.title.toLowerCase().contains(q) ||
                c.messages.any((m) => m.content.toLowerCase().contains(q))).toList();
            if (list.isEmpty) {
              return const _EmptyLibrary(message: 'Aucun historique.\n💡 Tes conversations apparaîtront ici.');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) => _HistoryItem(conversation: list[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('Erreur de chargement')),
        );
      default:
        return const SizedBox();
    }
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? NabuColors.gradientViolet : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? Colors.transparent : NabuColors.violetLight.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final Explanation exp;

  const _ExplanationCard({required this.exp});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = NabuColors.forType(exp.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        tintColor: color.withValues(alpha: 0.08),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _ExplanationDetail(exp: exp),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('💡', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.title ?? exp.query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : NabuColors.blueDeep,
                        ),
                      ),
                      Text(
                        '${exp.category ?? 'Non classé'} • ${_formatDate(exp.createdAt)}',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    exp.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: exp.isFavorite ? NabuColors.magenta : null,
                    size: 20,
                  ),
                  onPressed: () async {
                    final updated = exp.copyWith(isFavorite: !exp.isFavorite);
                    await StorageService.instance.saveExplanation(updated);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              exp.response,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin', 'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _ExplanationDetail extends StatelessWidget {
  final Explanation exp;

  const _ExplanationDetail({required this.exp});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? NabuColors.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    exp.title ?? exp.query,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (exp.imagePaths.isNotEmpty) ...[
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: exp.imagePaths.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Image.file(File(exp.imagePaths[i]), width: 140, height: 140, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                MarkdownBody(data: exp.response, selectable: true),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Exporter PDF'),
                        onPressed: () => PdfExportService().exportAndShare(
                          context,
                          () => PdfExportService().exportExplanation(exp),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await StorageService.instance.deleteExplanation(exp.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoCardWidget extends StatelessWidget {
  final MemoCard memo;

  const _MemoCardWidget({required this.memo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      tintColor: NabuColors.turquoise.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  memo.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : NabuColors.blueDeep,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                onPressed: () => PdfExportService().exportAndShare(
                  context,
                  () => PdfExportService().exportMemo(memo),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () async {
                  await StorageService.instance.deleteMemo(memo.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          MarkdownBody(
            data: memo.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final String message;
  const _EmptyLibrary({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Conversation conversation;
  const _HistoryItem({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lastMessage = conversation.messages.isEmpty ? '' : conversation.messages.last.content;
    final dt = conversation.updatedAt;
    final date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TeacherScreen(conversation: conversation),
      )),
      child: Row(
        children: [
          const Text('🕐', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title.isEmpty ? 'Conversation' : conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : NabuColors.blueDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date • ${conversation.messages.length} messages',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  lastMessage.replaceAll('\n', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => StorageService.instance.deleteConversation(conversation.id),
          ),
        ],
      ),
    );
  }
}
