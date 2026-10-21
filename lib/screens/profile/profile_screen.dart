import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/providers/app_provider.dart';
import 'package:nabu_explain/screens/settings/settings_screen.dart';
import 'package:nabu_explain/screens/manual/manual_screen.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [NabuColors.backgroundDark, const Color(0xFF1D244B)]
                : [NabuColors.backgroundLight, const Color(0xFFEAF0FF)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Text('👤', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Text(
                    'Mon profil',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : NabuColors.blueDeep,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Profile card
              GradientCard(
                gradient: NabuColors.gradientMulti,
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Text('🦉', style: TextStyle(fontSize: 32)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Élève NabuExplain',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Niveau : ${settings['selectedLevel'] == 'very_simple' ? '🌱 Très simple' : settings['selectedLevel'] == 'beginner' ? '🎓 Débutant' : settings['selectedLevel'] == 'intermediate' ? '📘 Intermédiaire' : settings['selectedLevel'] == 'advanced' ? '🧠 Avancé' : '🚀 Expert'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fournisseur IA : ${settings['provider'] ?? 'OpenAI'} • ${settings['model'] ?? 'gpt-4o-mini'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const SectionTitle(title: 'Configuration', icon: Icons.build_circle_outlined),
              const SizedBox(height: 12),

              _MenuItem(
                icon: Icons.key,
                label: 'Paramètres de l\'IA',
                description: 'Fournisseur, modèle, clé API',
                color: NabuColors.violetElectric,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.dark_mode,
                label: 'Mode sombre',
                description: isDark ? 'Activé - touche pour désactiver' : 'Désactivé - touche pour activer',
                color: NabuColors.blueDeep,
                onTap: () => ref.read(settingsProvider.notifier).toggleDarkMode(),
              ),
              _MenuItem(
                icon: Icons.menu_book_outlined,
                label: '📖 Mode d\'emploi',
                description: 'Découvre toutes les fonctionnalités',
                color: NabuColors.cyanSoft,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManualScreen()),
                ),
              ),
              const SizedBox(height: 24),

              const SectionTitle(title: 'Confidentialité', icon: Icons.lock_outline),
              const SizedBox(height: 12),
              GlassCard(
                tintColor: NabuColors.orange.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: NabuColors.orange, size: 20),
                        SizedBox(width: 8),
                        Text('🔒 Tes données te appartiennent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tes explications, fiches et flashcards sont stockées localement sur ton téléphone.\n\n'
                      'Quand tu poses une question à l\'IA, ton contenu est envoyé au fournisseur IA externe que tu as configuré. '
                      'Tes clés API ne sont jamais partagées et sont stockées de manière sécurisée sur ton appareil.',
                      style: TextStyle(fontSize: 12, height: 1.5,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const SectionTitle(title: 'À propos', icon: Icons.info_outline),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NabuExplain', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0\n'
                      '« Ce que tu ne comprends pas aujourd\'hui deviendra simple demain. »\n\n'
                      'NabuExplain est un professeur IA universel qui t\'aide à voir, questionner, comprendre, approfondir, pratiquer, vérifier et retenir.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        tintColor: color.withValues(alpha: 0.08),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : NabuColors.blueDeep,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}