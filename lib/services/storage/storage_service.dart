import 'dart:async';
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

  static const Map<String, dynamic> defaultSettings = {
    'darkMode': false,
    'onboardingDone': false,
    'provider': 'OpenAI',
    'model': 'gpt-4o-mini',
    'selectedLevel': 'beginner',
    'complexity': 50,
    'ollamaUrl': 'http://10.0.2.2:11434',
  };

  final _secureStorage = const FlutterSecureStorage();
  Directory? _baseDir;
  Map<String, dynamic>? _settingsCache;

  // Sérialise les lectures-modifications-écritures (paramètres, progression)
  // pour que deux mises à jour simultanées ne s'écrasent pas.
  Future<void> _lock = Future.value();

  // Notifie les providers qu'une collection a changé ('explanations', 'memos',
  // 'flashcards', 'quiz', 'exercises', 'conversations', 'progress').
  final _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;

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
    await instance.loadSettings();
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

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final previous = _lock;
    final done = Completer<void>();
    _lock = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }

  /// Écrit dans un fichier temporaire puis renomme : un crash pendant
  /// l'écriture ne laisse jamais un JSON à moitié écrit.
  Future<void> _writeJson(String path, Object data) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(path);
  }

  void _notify(String collection) {
    if (!_changes.isClosed) _changes.add(collection);
  }

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
  /// Paramètres connus en mémoire (valeurs par défaut avant [init]).
  Map<String, dynamic> get cachedSettings => {...defaultSettings, ...?_settingsCache};

  Future<Map<String, dynamic>> loadSettings() async {
    if (_settingsCache != null) return {..._settingsCache!};
    final settings = {...defaultSettings};
    final file = File(settingsFile);
    try {
      if (await file.exists()) {
        settings.addAll(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      }
    } catch (_) {
      // Fichier corrompu : on repart des valeurs par défaut plutôt que planter.
    }
    _settingsCache = settings;
    return {...settings};
  }

  /// Fusionne [changes] dans les paramètres enregistrés et renvoie le résultat.
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> changes) {
    return _synchronized(() async {
      final settings = await loadSettings();
      settings.addAll(changes);
      await _writeJson(settingsFile, settings);
      _settingsCache = settings;
      return {...settings};
    });
  }

  Future<bool> getOnboardingDone() async {
    final s = await loadSettings();
    return s['onboardingDone'] ?? false;
  }

  Future<void> setOnboardingDone() async {
    await updateSettings({'onboardingDone': true});
  }

  Future<bool> getDarkMode() async {
    final s = await loadSettings();
    return s['darkMode'] ?? false;
  }

  Future<void> setDarkMode(bool dark) async {
    await updateSettings({'darkMode': dark});
  }

  // ── Images ─────────────────────────────────────────────────
  Future<String> saveImage(File file, {String? prefix}) async {
    // p.extension renvoie déjà le point (".jpg").
    final filename = '${prefix ?? 'img'}_${DateTime.now().microsecondsSinceEpoch}${p.extension(file.path)}';
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

  // ── Generic JSON collections ───────────────────────────────
  Future<List<T>> _readAll<T>(String dirPath, T Function(Map<String, dynamic>) fromMap) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final list = <T>[];
    for (final f in files) {
      try {
        list.add(fromMap(jsonDecode(await f.readAsString()) as Map<String, dynamic>));
      } catch (_) {
        // Fichier illisible : ignoré pour ne pas bloquer toute la liste.
      }
    }
    return list;
  }

  Future<void> _delete(String dirPath, String id, String collection) async {
    final file = File(p.join(dirPath, '$id.json'));
    if (await file.exists()) await file.delete();
    _notify(collection);
  }

  // ── Explanations ───────────────────────────────────────────
  Future<Explanation> saveExplanation(Explanation exp) async {
    await _writeJson(p.join(explanationsDir, '${exp.id}.json'), exp.toMap());
    _notify('explanations');
    return exp;
  }

  Future<List<Explanation>> getExplanations() async {
    final list = await _readAll(explanationsDir, Explanation.fromMap);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> deleteExplanation(String id) => _delete(explanationsDir, id, 'explanations');

  // ── Conversations ──────────────────────────────────────────
  Future<Conversation> saveConversation(Conversation conv) async {
    await _writeJson(p.join(conversationsDir, '${conv.id}.json'), conv.toMap());
    _notify('conversations');
    return conv;
  }

  Future<List<Conversation>> getConversations() async {
    final list = await _readAll(conversationsDir, Conversation.fromMap);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> deleteConversation(String id) => _delete(conversationsDir, id, 'conversations');

  // ── Memos ──────────────────────────────────────────────────
  Future<MemoCard> saveMemo(MemoCard memo) async {
    await _writeJson(p.join(fichesDir, '${memo.id}.json'), memo.toMap());
    _notify('memos');
    return memo;
  }

  Future<List<MemoCard>> getMemos() async {
    final list = await _readAll(fichesDir, MemoCard.fromMap);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> deleteMemo(String id) => _delete(fichesDir, id, 'memos');

  // ── Flashcards ─────────────────────────────────────────────
  Future<Flashcard> saveFlashcard(Flashcard card) async {
    await _writeJson(p.join(flashcardsDir, '${card.id}.json'), card.toMap());
    _notify('flashcards');
    return card;
  }

  Future<void> saveFlashcards(List<Flashcard> cards) async {
    for (final c in cards) {
      await saveFlashcard(c);
    }
  }

  Future<List<Flashcard>> getFlashcards() async {
    final list = await _readAll(flashcardsDir, Flashcard.fromMap);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> deleteFlashcard(String id) => _delete(flashcardsDir, id, 'flashcards');

  // ── Quiz ───────────────────────────────────────────────────
  Future<Quiz> saveQuiz(Quiz quiz) async {
    await _writeJson(p.join(quizDir, '${quiz.id}.json'), quiz.toMap());
    _notify('quiz');
    return quiz;
  }

  Future<List<Quiz>> getQuizzes() async {
    final list = await _readAll(quizDir, Quiz.fromMap);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // ── Exercises ──────────────────────────────────────────────
  Future<Exercise> saveExercise(Exercise ex) async {
    await _writeJson(p.join(exercisesDir, '${ex.id}.json'), ex.toMap());
    _notify('exercises');
    return ex;
  }

  Future<List<Exercise>> getExercises() async {
    final list = await _readAll(exercisesDir, Exercise.fromMap);
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
    await _writeJson(progressFile, progress.toMap());
    _notify('progress');
  }

  /// Lecture-modification-écriture atomique de la progression.
  Future<ProgressData> updateProgress(void Function(ProgressData progress) change) {
    return _synchronized(() async {
      final progress = await loadProgress();
      change(progress);
      await saveProgress(progress);
      return progress;
    });
  }

  Future<void> incrementProgress(String field, {int amount = 1}) async {
    await updateProgress((p) {
      switch (field) {
        case 'topicsStudied': p.topicsStudied += amount; break;
        case 'explanationsViewed': p.explanationsViewed += amount; break;
        case 'quizzesTaken': p.quizzesTaken += amount; break;
        case 'exercisesDone': p.exercisesDone += amount; break;
        case 'flashcardsReviewed': p.flashcardsReviewed += amount; break;
      }
    });
  }

  /// Enregistre un quiz terminé : met à jour le taux de réussite global et la
  /// liste des sujets à revoir (ajouté sous 60 % de réussite, retiré au-dessus).
  Future<void> recordQuizResult({required String topic, required int score, required int total}) async {
    if (total <= 0) return;
    await updateProgress((p) {
      p.quizzesTaken++;
      p.quizCorrectAnswers += score;
      p.quizTotalQuestions += total;
      final rate = score / total;
      p.topicsToReview.remove(topic);
      if (rate < 0.6) p.topicsToReview.insert(0, topic);
    });
  }
}
