import 'package:flutter/material.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  static const _steps = [
    ('Découvrir NabuExplain', 'NabuExplain est un professeur IA universel. Tu peux lui poser n\'importe quelle question : une notion, du code, une erreur, une photo, une formule... Il s\'adapte à ton niveau et t\'explique jusqu\'à ce que tu comprennes.'),
    ('Poser une question', 'Depuis l\'accueil, écris ta question dans le champ « Que veux-tu comprendre ? » puis touche « EXPLIQUE-MOI ». Tu peux aussi discuter librement dans l\'onglet « Le Professeur ».'),
    ('Choisir son niveau', 'Sélectionne ton niveau : 🌱 Très simple, 🎓 Débutant, 📘 Intermédiaire, 🧠 Avancé ou 🚀 Expert. Tu peux changer de niveau à tout moment : NabuExplain reformulera entièrement son explication.'),
    ('Photographier quelque chose', 'Touche « 📷 Photographier » sur l\'accueil. Prends une photo d\'un composant, d\'un schéma, d\'un tableau, d\'une page... NabuExplain analyse ce qu\'il voit !'),
    ('Expliquer du code', 'Touche « 💻 Expliquer du code ». Colle ton code. NabuExplain détecte le langage (Dart, Python, JS, Java, etc.) et l\'explique avec coloration syntaxique.'),
    ('Comprendre une erreur', 'Touche « 🐞 Comprendre une erreur ». Colle ton message d\'erreur ou ta stack trace. NabuExplain te dit CE QUE ça signifie, la cause probable, où chercher, et comment vérifier.'),
    ('Utiliser le mode pas à pas', 'Touche « 🪜 Pas à pas » pendant une discussion. Le sujet est découpé en étapes numérotées. Tu avances avec « J\'ai compris » ou tu demandes une reformulation avec « Je n\'ai pas compris ».'),
    ('Utiliser les analogies', 'Touche « 🎭 Analogie ». NabuExplain choisit une analogie adaptée (cuisine, voiture, Lego, ville...) pour faire passer le concept autrement.'),
    ('Utiliser « Je n\'ai pas compris »', 'Le bouton central : « 😕 Pas compris ». NabuExplain ne répète JAMAIS la même chose : il change d\'approche. Une analogie, un exemple, une visualisation, une démonstration...'),
    ('Faire un quiz', 'Touche « 🎯 Teste-moi ». Un quiz de 5 questions est généré. Chaque mauvaise réponse donne une explication pédagogique. Ton score est sauvegardé dans ta progression.'),
    ('Faire des exercices', 'Touche « 🏋️ Exercice ». Choisis la difficulté (Facile à Challenge). Utilise les indices, puis vérifie avec la solution expliquée.'),
    ('Créer une fiche mémo', 'Touche « 📝 Fiche mémo » après une explication. NabuExplain transforme tout en fiche courte : définition, à retenir, exemple, piège. Sauvegardée dans ta bibliothèque.'),
    ('Utiliser les flashcards', 'Touche « 🗂️ Flashcards ». 5 cartes question/réponse sont générées. Retourne-les et indique « Je savais », « À revoir » ou « Je ne savais pas ».'),
    ('Sauvegarder une explication', 'Touche « 💾 Sauvegarder ». L\'explication est stockée sur ton téléphone dans « 📚 Ma bibliothèque ». Elle reste disponible HORS CONNEXION.'),
    ('Consulter sa progression', 'Ouvre l\'onglet « 🎯 Progression ». Vois les sujets étudiés, les quiz, les exercices, et ton taux de réussite. Tout est là pour te motiver, sans jugement.'),
    ('Configurer son fournisseur IA', 'Va dans Profil → Paramètres de l\'IA. Choisis un fournisseur (OpenAI, Claude, Gemini, Mistral, Ollama), un modèle, entre ta clé API et teste la connexion.'),
    ('Exporter en PDF', 'Dans une explication sauvegardée, touche « Exporter PDF ». L\'explication devient un document propre partageable via Android.'),
    ('Utiliser l\'application hors connexion', 'Toutes les explications sauvegardées, les fiches mémo, les flashcards, la progression et les paramètres restent accessibles sans Internet. Seules les nouvelles questions IA nécessitent une connexion.'),
  ];

  static const _examples = [
    '« Explique-moi ce code. »',
    '« Pourquoi le ciel est bleu ? »',
    '« Explique-moi Git comme si je débutais. »',
    '« Quelle est cette pièce ? »',
    '« Explique cette formule. »',
    '« Pourquoi cette erreur Flutter apparaît-elle ? »',
    '« Je n\'ai rien compris aux API. »',
    '« Explique-moi Docker avec une analogie. »',
    '« Apprends-moi SQL progressivement. »',
    '« Qu\'est-ce que la photosynthèse ? »',
    '« Explique-moi la relativité. »',
    '« Comment marche une blockchain ? »',
    '« Que fait cette fonction JavaScript ? »',
    '« Pourquoi mon app crash ? Voici la stack... »',
    '« C\'est quoi une variable en programmation ? »',
    '« Explique-moi les nombres premiers. »',
    '« Fais-moi réfléchir sur la gravité. »',
    '« Crée un quiz sur les migrations humaines. »',
    '« Donne-moi un exercice sur les équations. »',
    '« Pourquoi les étoiles scintillent ? »',
    '« Apprends-moi le cycle de l\'eau. »',
    '« Explique les bases de la cryptographie. »',
    '« Comment fonctionne un moteur à réaction ? »',
    '« C\'est quoi le cloud computing ? »',
    '« Explique la photosynthèse à un enfant. »',
    '« Je ne comprends pas les fonctions en maths. »',
    '« Pourquoi le soleil brille ? »',
    '« Explique-moi les réseaux de neurones. »',
    '« Comment apprendre l\'anglais ? »',
    '« Explique la Révolution française simplement. »',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Mode d\'emploi'),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : NabuColors.violetElectric,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [NabuColors.backgroundDark, const Color(0xFF1D244B)]
                : [NabuColors.backgroundLight, const Color(0xFFEAF6FF)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GradientCard(
              gradient: NabuColors.gradientMulti,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🦉', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 10),
                  Text(
                    'Je suis NabuExplain, ton professeur IA universel.',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Je ne te donne pas seulement des réponses.\nJe t\'aide à VOIR, QUESTIONNER, COMPRENDRE, APPROFONDIR, PRATIQUER, VÉRIFIER et RETENIR.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SectionTitle(
              title: '1. Les 18 modes d\'emploi',
              subtitle: 'Toutes les façons d\'utiliser NabuExplain',
              icon: Icons.list_alt,
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _steps.length; i++)
              _ManualItem(
                number: i + 1,
                title: _steps[i].$1,
                content: _steps[i].$2,
              ),
            const SizedBox(height: 24),

            const SectionTitle(
              title: '💡 30 exemples de demandes',
              subtitle: 'Pour commencer à t\'entraîner',
              icon: Icons.lightbulb,
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (int i = 0; i < _examples.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: NabuColors.cyanSoft,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _examples[i],
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _ManualItem extends StatelessWidget {
  final int number;
  final String title;
  final String content;

  const _ManualItem({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: number.isEven ? NabuColors.gradientViolet : NabuColors.gradientCyan,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : NabuColors.blueDeep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}