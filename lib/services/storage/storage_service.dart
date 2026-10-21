import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../models/explanation.dart';
import '../../models/conversation.dart';
import '../../models/models.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  final _secureStorage = const FlutterSecureStorage();
  Directory? _baseDir;

  static Future<void> init() async {
    try {
      instance._baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      instance._baseDir = Directory.systemTemp;
    }
    final dirs = [
      'nabu/images',
      'nabu/explications',
      'nabu/conversations',
      'nabu/fiches',
      'nabu/flashcards',
      'nabu/quiz',
      'nabu/exercises',
      'nabu/progress',
    ];
    for (final d in dirs) {
      final dir = Directory(p.join(instance._baseDir!.path, d));
      if (!await dir.exists()) await dir.create(recursive: true);
    }
  }

  Directory get baseDir {
    if (_baseDir == null) {
      try {
        _baseDir = Directory.systemTemp;
      } catch (_) {
        _baseDir = Directory('/tmp');
      }
    }
    return _baseDir!;
  }
  String get imagesDir => p.join(baseDir.path, 'nabu/images');
  String get explanationsDir => p.join(baseDir.path, 'nabu/explications');
  String get conversationsDir => p.join(baseDir.path, 'nabu/conversations');
  String get fichesDir => p.join(baseDir.path, 'nabu/fiches');
  String get flashcardsDir => p.join(baseDir.path, 'nabu/flashcards');
  String get quizDir => p.join(baseDir.path, 'nabu/quiz');
  String get exercisesDir => p.join(baseDir.path, 'nabu/exercises');
  String get progressFile => p.join(baseDir.path, 'nabu/progress/progress.json');
  String get settingsFile => p.join(baseDir.path, 'nabu/settings.json');

  // ── Secure storage (API keys) ──────────────────────────────
  Future<void> saveApiKey(String provider, String key) async {
    await _secureStorage.write(key: 'nabu_api_$provider', value: key);
  }

  Future<String?> getApiKey(String provider) async {
    return await _secureStorage.read(key: 'nabu_api_$provider');
  }

  Future<void> deleteApiKey(String provider) async {
    await _secureStorage.delete(key: 'nabu_api_$provider');
  }

  // ── Settings ───────────────────────────────────────────────
  Future<Map<String, dynamic>> loadSettings() async {
    final file = File(settingsFile);
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data;
    }
    return {
      'darkMode': false,
      'onboardingDone': false,
      'provider': 'OpenAI',
      'model': 'gpt-4o-mini',
      'selectedLevel': 'beginner',
      'complexity': 50,
    };
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final file = File(settingsFile);
    await file.writeAsString(jsonEncode(settings));
  }

  Future<bool> getOnboardingDone() async {
    final s = await loadSettings();
    return s['onboardingDone'] ?? false;
  }

  Future<void> setOnboardingDone() async {
    final s = await loadSettings();
    s['onboardingDone'] = true;
    await saveSettings(s);
  }

  Future<bool> getDarkMode() async {
    final s = await loadSettings();
    return s['darkMode'] ?? false;
  }

  Future<void> setDarkMode(bool dark) async {
    final s = await loadSettings();
    s['darkMode'] = dark;
    await saveSettings(s);
  }

  // ── Images ─────────────────────────────────────────────────
  Future<String> saveImage(File file, {String? prefix}) async {
    final filename = '${prefix ?? 'img'}_${DateTime.now().millisecondsSinceEpoch}.${p.extension(file.path)}';
    final dest = p.join(imagesDir, filename);
    await file.copy(dest);
    return dest;
  }

  Future<List<String>> saveImages(List<File> files) async {
    final paths = <String>[];
    for (final f in files) {
      paths.add(await saveImage(f));
    }
    return paths;
  }

  // ── Explanations ───────────────────────────────────────────
  Future<Explanation> saveExplanation(Explanation exp) async {
    final file = File(p.join(explanationsDir, '${exp.id}.json'));
    await file.writeAsString(jsonEncode(exp.toMap()));
    return exp;
  }

  Future<List<Explanation>> getExplanations() async {
    final dir = Directory(explanationsDir);
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final list = <Explanation>[];
    for (final f in files) {
      try {
        final data = jsonDecode(await f.readAsString());
        list.add(Explanation.fromMap(data));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> deleteExplanation(String id) async {
    final file = File(p.join(explanationsDir, '$id.json'));
    if (await file.exists()) await file.delete();
  }

  // ── Conversations ──────────────────────────────────────────
  Future<Conversation> saveConversation(Conversation conv) async {
    final file = File(p.join(conversationsDir, '${conv.id}.json'));
    await file.writeAsString(jsonEncode(conv.toMap()));
    return conv;
  }

  Future<List<Conversation>> getConversations() async {
    final dir = Directory(conversationsDir);
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final list = <Conversation>[];
    for (final f in files) {
      try {
        final data = jsonDecode(await f.readAsString());
        list.add(Conversation.fromMap(data));
      } catch (_) {}
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> deleteConversation(String id) async {
    final file = File(p.join(conversationsDir, '$id.json'));
    if (await file.exists()) await file.delete();
  }

  // ── Memos ──────────────────────────────────────────────────
  Future<MemoCard> saveMemo(MemoCard memo) async {
    final file = File(p.join(fichesDir, '${memo.id}.json'));
    await file.writeAsString(jsonEncode(memo.toMap()));
    return memo;
  }

  Future<List<MemoCard>> getMemos() async {
    final dir = Directory(fichesDir);
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final list = <MemoCard>[];
    for (final f in files) {
      try {
        list.add(MemoCard.fromMap(jsonDecode(await f.readAsString())));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> deleteMemo(String id) async {
    final file = File(p.join(fichesDir, '$id.json'));
    if (await file.exists()) await file.delete();
  }

  // ── Flashcards ─────────────────────────────────────────────
  Future<Flashcard> saveFlashcard(Flashcard card) async {
    final file = File(p.join(flashcardsDir, '${card.id}.json'));
    await file.writeAsString(jsonEncode(card.toMap()));
    return card;
  }

  Future<void> saveFlashcards(List<Flashcard> cards) async {
    for (final c in cards) {
      await saveFlashcard(c);
    }
  }

  Future<List<Flashcard>> getFlashcards() async {
    final dir = Directory(flashcardsDir);
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final list = <Flashcard>[];
    for (final f in files) {
      try {
        list.add(Flashcard.fromMap(jsonDecode(await f.readAsString())));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> deleteFlashcard(String id) async {
    final file = File(p.join(flashcardsDir, '$id.json'));
    if (await file.exists()) await file.delete();
  }

  // ── Quiz ───────────────────────────────────────────────────
  Future<Quiz> saveQuiz(Quiz quiz) async {
    final file = File(p.join(quizDir, '${quiz.id}.json'));
    await file.writeAsString(jsonEncode(quiz.toMap()));
    return quiz;
  }

  Future<List<Quiz>> getQuizzes() async {
    final dir = Directory(quizDir);
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final list = <Quiz>[];
    for (final f in files) {
      try {
        list.add(Quiz.fromMap(jsonDecode(await f.readAsString())));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // ── Exercises ──────────────────────────────────────────────
  Future<Exercise> saveExercise(Exercise ex) async {
    final file = File(p.join(exercisesDir, '${ex.id}.json'));
    await file.writeAsString(jsonEncode(ex.toMap()));
    return ex;
  }

  Future<List<Exercise>> getExercises() async {
    final dir = Directory(exercisesDir);
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final list = <Exercise>[];
    for (final f in files) {
      try {
        list.add(Exercise.fromMap(jsonDecode(await f.readAsString())));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> updateExercise(Exercise ex) async {
    await saveExercise(ex);
  }

  // ── Progress ───────────────────────────────────────────────
  Future<ProgressData> loadProgress() async {
    final file = File(progressFile);
    if (await file.exists()) {
      try {
        return ProgressData.fromMap(jsonDecode(await file.readAsString()));
      } catch (_) {}
    }
    return ProgressData();
  }

  Future<void> saveProgress(ProgressData progress) async {
    final file = File(progressFile);
    await file.writeAsString(jsonEncode(progress.toMap()));
  }

  Future<void> incrementProgress(String field, {int amount = 1}) async {
    final p = await loadProgress();
    final newP = p;
    switch (field) {
      case 'topicsStudied': newP.topicsStudied += amount; break;
      case 'explanationsViewed': newP.explanationsViewed += amount; break;
      case 'quizzesTaken': newP.quizzesTaken += amount; break;
      case 'exercisesDone': newP.exercisesDone += amount; break;
      case 'flashcardsReviewed': newP.flashcardsReviewed += amount; break;
    }
    await saveProgress(newP);
  }
}