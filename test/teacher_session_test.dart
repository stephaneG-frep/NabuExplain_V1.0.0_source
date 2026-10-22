import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nabu_explain/models/conversation.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/screens/teacher/teacher_session.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';
import 'package:nabu_explain/services/ai/ai_service.dart';

/// Faux contrôleur : répond sans réseau et garde trace des appels.
class FakeAI extends AIController {
  final List<List<AIMessage>> histories = [];
  final List<String> queries = [];
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<Explanation> explain({
    required String query,
    required String level,
    required int complexity,
    List<String>? imagePaths,
    String type = 'notion',
    List<AIMessage> history = const [],
  }) async {
    queries.add(query);
    histories.add(history);
    if (gate != null) await gate!.future;
    if (fail) throw AIException('panne');
    return Explanation(query: query, response: 'Réponse à $query ($level)', level: level);
  }

  @override
  Future<String> generateWhy(String topic, int depth, {List<AIMessage> history = const []}) async {
    histories.add(history);
    return 'Parce que (niveau $depth)';
  }
}

void main() {
  // Sans StorageService.init(), les sauvegardes de la session (historique,
  // progression) vont dans le dossier temporaire du système.

  test('une question ajoute la question et la réponse, et fixe le sujet', () async {
    final ai = FakeAI();
    final session = TeacherSession(initialType: 'notion', aiController: ai);

    expect(session.send('  Qu\'est-ce qu\'une API ?  '), isTrue);
    await pumpEventQueue();

    expect(session.messages.map((m) => m.isUser), [true, false]);
    expect(session.messages.first.content, 'Qu\'est-ce qu\'une API ?');
    expect(session.currentTopic, 'Qu\'est-ce qu\'une API ?');
    expect(session.hasExplanation, isTrue);
    expect(session.isLoading, isFalse);
  });

  test('un texte vide n\'est pas envoyé', () {
    final session = TeacherSession(initialType: 'notion', aiController: FakeAI());
    expect(session.send('   '), isFalse);
    expect(session.messages, isEmpty);
  });

  test('les questions suivantes reçoivent la conversation, sans les erreurs', () async {
    final ai = FakeAI();
    final session = TeacherSession(initialType: 'notion', aiController: ai);

    session.send('Question 1');
    await pumpEventQueue();
    ai.fail = true;
    session.send('Question 2');
    await pumpEventQueue();
    expect(session.messages.last.content, startsWith('😕'));

    ai.fail = false;
    await session.askWhy();

    final history = ai.histories.last;
    expect(history.map((m) => m.content), ['Question 1', 'Réponse à Question 1 (beginner)', 'Question 2']);
  });

  test('pas de deuxième question pendant une réponse en cours', () async {
    final ai = FakeAI()..gate = Completer<void>();
    final session = TeacherSession(initialType: 'notion', aiController: ai);

    session.send('A');
    expect(session.isLoading, isTrue);
    expect(session.send('B'), isFalse);
    ai.gate!.complete();
    await pumpEventQueue();
    expect(ai.queries, ['A']);
  });

  test('changer de niveau reformule seulement s\'il y a déjà une explication', () async {
    final ai = FakeAI();
    final session = TeacherSession(initialType: 'notion', aiController: ai);

    session.updateLevel('expert', 50, levelLabel: 'Expert');
    await pumpEventQueue();
    expect(ai.queries, isEmpty);

    session.send('Git');
    await pumpEventQueue();
    session.updateLevel('very_simple', 50, levelLabel: 'Très simple');
    await pumpEventQueue();
    expect(ai.queries, ['Git', 'Git']);
    expect(session.lastExplanation, 'Réponse à Git (very_simple)');
  });

  test('une réponse arrivée après la fermeture de l\'écran ne plante pas', () async {
    final ai = FakeAI()..gate = Completer<void>();
    final session = TeacherSession(initialType: 'notion', aiController: ai);
    session.send('Lent');
    session.dispose();
    ai.gate!.complete();
    await pumpEventQueue();
    expect(session.messages.last.content, 'Réponse à Lent (beginner)');
  });

  test('reprend une conversation de l\'historique', () {
    final conversation = Conversation(
      title: 'Git',
      topic: 'Git',
      messages: [
        ChatMessage(content: 'Git ?', isUser: true),
        ChatMessage(content: 'Un gestionnaire de versions.', isUser: false),
        ChatMessage(content: '😕 erreur', isUser: false),
      ],
    );
    final session = TeacherSession(initialType: 'notion', conversation: conversation, aiController: FakeAI());
    expect(session.messages, hasLength(3));
    expect(session.currentTopic, 'Git');
    expect(session.lastExplanation, 'Un gestionnaire de versions.');
  });
}
