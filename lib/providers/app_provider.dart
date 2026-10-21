import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, Map<String, dynamic>>(
  (ref) => SettingsNotifier(ref),
);

class SettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  SettingsNotifier(this.ref) : super({
    'darkMode': false,
    'onboardingDone': false,
    'provider': 'OpenAI',
    'model': 'gpt-4o-mini',
    'selectedLevel': 'beginner',
    'complexity': 50,
  }) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    final settings = await StorageService.instance.loadSettings();
    state = settings;
  }

  Future<void> update(String key, dynamic value) async {
    final settings = {...state};
    settings[key] = value;
    state = settings;
    await StorageService.instance.saveSettings(settings);
  }

  String get provider => state['provider'] as String? ?? 'OpenAI';
  String get model => state['model'] as String? ?? 'gpt-4o-mini';
  String get selectedLevel => state['selectedLevel'] as String? ?? 'beginner';
  int get complexity => state['complexity'] as int? ?? 50;
}

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) => DarkModeNotifier());

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.instance.getDarkMode();
  }

  Future<void> toggle() async {
    state = !state;
    await StorageService.instance.setDarkMode(state);
  }
}

final onboardingDoneProvider = StateNotifierProvider<OnboardingNotifier, bool>(
  (ref) => OnboardingNotifier(),
);

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.instance.getOnboardingDone();
  }

  Future<void> complete() async {
    await StorageService.instance.setOnboardingDone();
    state = true;
  }
}

final explanationsProvider = FutureProvider<List<dynamic>>((ref) async {
  return StorageService.instance.getExplanations();
});

final conversationsProvider = FutureProvider<List<dynamic>>((ref) async {
  return StorageService.instance.getConversations();
});

final memosProvider = FutureProvider<List<dynamic>>((ref) async {
  return StorageService.instance.getMemos();
});

final flashcardsProvider = FutureProvider<List<dynamic>>((ref) async {
  return StorageService.instance.getFlashcards();
});

final quizzesProvider = FutureProvider<List<dynamic>>((ref) async {
  return StorageService.instance.getQuizzes();
});

final exercisesProvider = FutureProvider<List<dynamic>>((ref) async {
  return StorageService.instance.getExercises();
});

final progressProvider = FutureProvider<dynamic>((ref) async {
  return StorageService.instance.loadProgress();
});