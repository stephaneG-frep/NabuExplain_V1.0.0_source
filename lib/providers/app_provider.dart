import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nabu_explain/models/conversation.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

/// Source unique des paramètres : le mode sombre et l'onboarding en dérivent,
/// et chaque modification est fusionnée dans le fichier (jamais réécrite en bloc).
final settingsProvider = StateNotifierProvider<SettingsNotifier, Map<String, dynamic>>(
  (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  // Les paramètres sont chargés par StorageService.init() avant runApp :
  // pas de premier écran avec des valeurs par défaut.
  SettingsNotifier() : super(StorageService.instance.cachedSettings);

  Future<void> update(String key, dynamic value) => updateAll({key: value});

  Future<void> updateAll(Map<String, dynamic> changes) async {
    state = {...state, ...changes};
    state = await StorageService.instance.updateSettings(changes);
  }

  Future<void> toggleDarkMode() => update('darkMode', !(state['darkMode'] == true));

  Future<void> completeOnboarding() => update('onboardingDone', true);

  String get provider => state['provider'] as String? ?? 'OpenAI';
  String get model => state['model'] as String? ?? 'gpt-4o-mini';
  String get selectedLevel => state['selectedLevel'] as String? ?? 'beginner';
  int get complexity => state['complexity'] as int? ?? 50;
}

final darkModeProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider)['darkMode'] == true,
);

final onboardingDoneProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider)['onboardingDone'] == true,
);

/// Recharge le provider dès que [collection] est modifiée dans le stockage.
void _reloadOnChange(Ref ref, String collection) {
  final sub = StorageService.instance.changes
      .where((c) => c == collection)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
}

final explanationsProvider = FutureProvider<List<Explanation>>((ref) async {
  _reloadOnChange(ref, 'explanations');
  return StorageService.instance.getExplanations();
});

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  _reloadOnChange(ref, 'conversations');
  return StorageService.instance.getConversations();
});

final memosProvider = FutureProvider<List<MemoCard>>((ref) async {
  _reloadOnChange(ref, 'memos');
  return StorageService.instance.getMemos();
});

final flashcardsProvider = FutureProvider<List<Flashcard>>((ref) async {
  _reloadOnChange(ref, 'flashcards');
  return StorageService.instance.getFlashcards();
});

final quizzesProvider = FutureProvider<List<Quiz>>((ref) async {
  _reloadOnChange(ref, 'quiz');
  return StorageService.instance.getQuizzes();
});

final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  _reloadOnChange(ref, 'exercises');
  return StorageService.instance.getExercises();
});

final progressProvider = FutureProvider<ProgressData>((ref) async {
  _reloadOnChange(ref, 'progress');
  return StorageService.instance.loadProgress();
});
