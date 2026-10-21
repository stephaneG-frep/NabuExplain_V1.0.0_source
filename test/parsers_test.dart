import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/models/models.dart';
import 'package:nabu_explain/screens/teacher/quiz_screen.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';
import 'package:nabu_explain/services/ai/ai_service.dart';
import 'package:nabu_explain/services/pdf/pdf_service.dart';

void main() {
  group('parseQuiz', () {
    test('lit un quiz entouré de texte et de balises ```json', () {
      const raw = '''Voici ton quiz :
```json
{"questions": [
  {"question": "Capitale de la France ?", "type": "qcm",
   "options": ["Lyon", "Paris", "Nice", "Lille"], "correctAnswer": "Paris",
   "explanation": "Paris est la capitale."}
]}
```''';
      final quiz = AIController.parseQuiz(raw, 'Géo', 'beginner');
      expect(quiz.questions, hasLength(1));
      expect(quiz.questions.first.correctAnswer, 'Paris');
    });

    test('convertit une réponse donnée par lettre', () {
      const raw = '{"questions": [{"question": "Q ?", "type": "qcm", '
          '"options": ["un", "deux", "trois"], "correctAnswer": "B"}]}';
      final quiz = AIController.parseQuiz(raw, 't', 'beginner');
      expect(quiz.questions.first.correctAnswer, 'deux');
    });

    test('normalise les vrai/faux', () {
      const raw = '{"questions": [{"question": "Q ?", "type": "true_false", '
          '"options": [], "correctAnswer": "true"}]}';
      final q = AIController.parseQuiz(raw, 't', 'beginner').questions.first;
      expect(q.options, ['Vrai', 'Faux']);
      expect(q.correctAnswer, 'Vrai');
    });

    test('refuse un quiz sans question exploitable', () {
      expect(
        () => AIController.parseQuiz('{"questions": []}', 't', 'beginner'),
        throwsA(isA<AIException>()),
      );
      expect(
        () => AIController.parseQuiz('pas du json', 't', 'beginner'),
        throwsA(isA<AIException>()),
      );
    });
  });

  group('parseFlashcards', () {
    test('ignore les cartes vides', () {
      const raw = '{"cards": [{"front": "A ?", "back": "a"}, {"front": "", "back": "x"}]}';
      expect(AIController.parseFlashcards(raw), hasLength(1));
    });

    test('refuse une liste vide', () {
      expect(() => AIController.parseFlashcards('{"cards": []}'), throwsA(isA<AIException>()));
    });
  });

  group('parseExercise', () {
    test('garde les sections de plusieurs paragraphes', () {
      const raw = '''**EXERCICE:**
Écris une fonction.

Elle doit renvoyer la somme.

INDICE:
Pense à une boucle.

DEUXIEME_INDICE:
Utilise un accumulateur.

SOLUTION:
```python
def somme(l):
    return sum(l)
```

EXPLICATION_SOLUTION:
sum parcourt la liste.''';
      final ex = AIController.parseExercise(raw, 'Python', 'Normal');
      expect(ex.content, contains('Elle doit renvoyer la somme.'));
      expect(ex.hint, contains('Pense à une boucle.'));
      expect(ex.hint, contains('Utilise un accumulateur.'));
      expect(ex.solution, contains('return sum(l)'));
      expect(ex.solution, contains('sum parcourt la liste.'));
    });

    test('ne confond pas SOLUTION et EXPLICATION_SOLUTION', () {
      const raw = 'EXERCICE:\nfais x\n\nEXPLICATION_SOLUTION:\nparce que\n\nSOLUTION:\nx';
      final ex = AIController.parseExercise(raw, 't', 'Normal');
      expect(ex.solution, 'x\n\nparce que');
    });
  });

  group('normalizeHistory', () {
    test('alterne les rôles, commence par user et finit par assistant', () {
      final history = AIService.normalizeHistory(const [
        AIMessage(role: 'assistant', content: 'bonjour'),
        AIMessage(role: 'user', content: 'a'),
        AIMessage(role: 'user', content: 'b'),
        AIMessage(role: 'assistant', content: 'réponse'),
        AIMessage(role: 'user', content: 'dernier'),
      ]);
      expect(history.map((m) => m.role), ['user', 'assistant']);
      expect(history.first.content, 'a\n\nb');
    });
  });

  group('images', () {
    test('détecte le vrai type MIME', () {
      expect(AIService.detectMimeType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0])), 'image/png');
      expect(AIService.detectMimeType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
      expect(AIService.detectMimeType(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });

  group('réponses du quiz', () {
    test('ignore casse, accents et ponctuation', () {
      expect(quizAnswerMatches('  ELECTRON. ', 'électron'), isTrue);
      expect(quizAnswerMatches('Lyon', 'Paris'), isFalse);
    });

    test('accepte une réponse libre qui contient la bonne réponse', () {
      expect(quizAnswerMatches("c'est Paris", 'Paris', freeText: true), isTrue);
      expect(quizAnswerMatches("c'est Paris", 'Paris'), isFalse);
      expect(quizAnswerMatches('comparaison', 'paris', freeText: true), isFalse);
    });

    test('reset efface la réponse de l\'élève', () {
      final q = QuizQuestion(question: 'Q', type: 'qcm', correctAnswer: 'a')
          .copyWith(userAnswer: 'b', isCorrect: false)
          .reset();
      expect(q.userAnswer, isNull);
      expect(q.isCorrect, isNull);
    });
  });

  group('progression', () {
    test('calcule le taux de réussite global', () {
      final p = ProgressData(quizCorrectAnswers: 3, quizTotalQuestions: 4);
      expect(p.successRate, 75);
      expect(ProgressData().successRate, 0);
      expect(ProgressData.fromMap(p.toMap()).successRate, 75);
    });
  });

  test('génère un PDF avec émojis, accents et code', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await PdfExportService().buildExplanationPdf(Explanation(
      query: 'Qu\'est-ce qu\'une API ?',
      response: '## 🧠 En une phrase\nUne **API** permet à deux programmes de se parler.\n\n'
          '- point_un\n- a*b reste intact\n\n```python\ndef __init__(self):\n    pass\n```\n'
          'Voir [la doc](https://exemple.fr). Éléphant œuvre ç à ù',
      level: 'beginner',
    ));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('nom de fichier PDF sans caractères interdits', () {
    expect(PdfExportService.safeFileName('C/C++ : pointeurs\net mémoire ?'), 'C_C++_pointeurs_et_mémoire');
    expect(PdfExportService.safeFileName('///'), 'nabuexplain');
  });
}
