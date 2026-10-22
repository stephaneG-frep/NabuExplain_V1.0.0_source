import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/screens/home/home_screen.dart';
import 'package:nabu_explain/screens/teacher/teacher_screen.dart';
import 'package:nabu_explain/screens/library/library_screen.dart';
import 'package:nabu_explain/screens/progression/progression_screen.dart';
import 'package:nabu_explain/screens/profile/profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _index = 0;

  static const _titles = [
    'Accueil',
    'Le Professeur',
    'Bibliothèque',
    'Progression',
    'Profil',
  ];
  static const _icons = [
    Icons.home_rounded,
    Icons.forum_rounded,
    Icons.book_rounded,
    Icons.insights_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Retour système depuis un autre onglet : revenir à l'accueil plutôt que
    // quitter l'appli.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            TeacherScreen(),
            LibraryScreen(),
            ProgressionScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? NabuColors.surfaceDark : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                for (int i = 0; i < _titles.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _icons[i],
                      label: _titles[i],
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                gradient: selected ? NabuColors.gradientViolet : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: selected
                    ? Colors.white
                    : Theme.of(context).brightness == Brightness.dark
                    ? Colors.white38
                    : Colors.black38,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? NabuColors.violetElectric
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white38
                          : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
