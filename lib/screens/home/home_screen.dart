import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nabu_explain/core/constants/app_constants.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/screens/teacher/teacher_screen.dart';
import 'package:nabu_explain/screens/settings/settings_screen.dart';
import 'package:nabu_explain/screens/manual/manual_screen.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<String> _pendingImages = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages(BuildContext context) async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
      if (images.isNotEmpty) {
        final paths = <String>[];
        for (final img in images) {
          final file = await StorageService.instance.saveImage(File(img.path));
          paths.add(file);
        }
        setState(() => _pendingImages.addAll(paths));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'importer l\'image')),
        );
      }
    }
  }

  Future<void> _takePhoto(BuildContext context) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (photo != null) {
        final file = await StorageService.instance.saveImage(File(photo.path));
        setState(() => _pendingImages.add(file));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La caméra est indisponible')),
        );
      }
    }
  }

  void _launch(BuildContext context, String type) {
    final text = _controller.text.trim();
    _showPrivacyNotice(context);
    final prefills = {
      'code': '💻 Expliquer du code',
      'error': '🐞 Comprendre une erreur',
      'notion': '📚 Comprendre une notion',
      'document': '📄 Analyser un document',
      'formula': '➗ Expliquer une formule',
      'chat': '💬 Discuter avec le professeur',
    };
    final effectiveText = text.isNotEmpty && (prefills.containsKey(type))
        ? (text.length < 3 ? text : text)
        : text;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TeacherScreen(
        initialPrompt: effectiveText.isEmpty ? prefills[type] ?? '' : effectiveText,
        initialType: type,
        initialImages: _pendingImages.isNotEmpty ? List.of(_pendingImages) : null,
      ),
    ));

    _pendingImages.clear();
    _controller.clear();
  }

  void _showPrivacyNotice(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '🔒 Votre contenu sera envoyé à un·e fournisseur·se IA externe. Consultez les paramètres pour le configurer.',
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Compris',
          onPressed: () {},
        ),
      ),
    );
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
                ? [NabuColors.backgroundDark, const Color(0xFF241650)]
                : [NabuColors.backgroundLight, const Color(0xFFEDE7FB)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🦉', style: TextStyle(fontSize: 28)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'NabuExplain',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        foreground: Paint()
                                          ..shader = const LinearGradient(
                                            colors: [NabuColors.violetElectric, NabuColors.cyanSoft],
                                          ).createShader(const Rect.fromLTWH(0, 0, 250, 40)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppConstants.tagline,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          )),
                          icon: const Icon(Icons.settings, color: NabuColors.violetElectric),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const ManualScreen(),
                          )),
                            icon: const Icon(Icons.help_outline, color: NabuColors.violetElectric),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Central input area
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text('🧠', style: TextStyle(fontSize: 22)),
                                SizedBox(width: 8),
                                Text(
                                  'Que veux-tu comprendre ?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _controller,
                              maxLines: 4,
                              minLines: 2,
                              decoration: const InputDecoration(
                                hintText: 'Écris, colle ou photographie quelque chose...',
                              ),
                            ),
                            if (_pendingImages.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _pendingImages.length,
                                  itemBuilder: (context, i) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(
                                            File(_pendingImages[i]),
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => setState(() =>
                                              _pendingImages.removeAt(i)),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close,
                                                size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            NabuButton(
                              label: '✨ EXPLIQUE-MOI',
                              icon: Icons.auto_awesome,
                              gradient: NabuColors.gradientMulti,
                              onPressed: () => _launch(context, 'notion'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Quick actions grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    for (final action in AppConstants.quickActions)
                      _QuickActionCard(
                        icon: action['icon']!,
                        label: action['label']!,
                        onTap: () => _handleQuickAction(action['type']!),
                      ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleQuickAction(String type) async {
    switch (type) {
      case 'photo':
        await _takePhoto(context);
        if (!mounted) return;
        if (_pendingImages.isNotEmpty) {
          _launch(context, 'photo');
        }
        break;
      case 'gallery':
        await _pickImages(context);
        if (!mounted) return;
        if (_pendingImages.isNotEmpty) {
          _launch(context, 'gallery');
        }
        break;
      case 'code':
        _showCodeDialog();
        break;
      case 'error':
        _showErrorDialog();
        break;
      default:
        _launch(context, type);
    }
  }

  void _showCodeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💻 Colle ton code'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Colle ton code ici...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TeacherScreen(
                    initialPrompt: controller.text.trim(),
                    initialType: 'code',
                  ),
                ));
              }
            },
            child: const Text('Expliquer'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🐞 Colle ton erreur'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Colle ton message d\'erreur, stack trace...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TeacherScreen(
                    initialPrompt: controller.text.trim(),
                    initialType: 'error',
                  ),
                ));
              }
            },
            child: const Text('Expliquer'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      [NabuColors.violetElectric.withValues(alpha: 0.15), NabuColors.blueDeep.withValues(alpha: 0.1)],
      [NabuColors.cyanSoft.withValues(alpha: 0.15), NabuColors.turquoise.withValues(alpha: 0.1)],
      [NabuColors.orange.withValues(alpha: 0.15), NabuColors.magenta.withValues(alpha: 0.1)],
      [NabuColors.turquoise.withValues(alpha: 0.15), NabuColors.cyanSoft.withValues(alpha: 0.1)],
    ];
    final index = label.hashCode % colors.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors[index],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : Colors.white,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}