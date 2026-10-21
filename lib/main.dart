import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/providers/app_provider.dart';
import 'package:nabu_explain/screens/onboarding/onboarding_screen.dart';
import 'package:nabu_explain/screens/home/main_screen.dart';
import 'package:nabu_explain/screens/settings/settings_screen.dart';
import 'package:nabu_explain/screens/manual/manual_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await StorageService.init();

  runApp(const ProviderScope(child: NabuExplainApp()));
}

class NabuExplainApp extends ConsumerWidget {
  const NabuExplainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);
    final onboardingDone = ref.watch(onboardingDoneProvider);

    return MaterialApp(
      title: 'NabuExplain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/home': (_) => const MainScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/manual': (_) => const ManualScreen(),
      },
      home: onboardingDone ? const MainScreen() : const OnboardingScreen(),
    );
  }
}
