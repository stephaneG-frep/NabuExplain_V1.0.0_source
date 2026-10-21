class PromptBuilder {
  static String levelInstruction(String level) {
    switch (level) {
      case 'very_simple':
        return "Explique comme à un enfant de 5 ans. Utilise une analogie simple de la vie quotidienne. Phrase courte. Pas de jargon technique. Vocabulaire très simple.";
      case 'beginner':
        return "Explique pour un débutant complet. Donne le principe général et un exemple concret tiré de la vie quotidienne. Évite le jargon ou définis-le si nécessaire.";
      case 'intermediate':
        return "Explique pour quelqu'un qui a des bases. Utilise un vocabulaire technique correct. Donne des exemples et des précisions. Introduis les concepts liés.";
      case 'advanced':
        return "Explique pour quelqu'un qui veut approfondir. Détaille les mécanismes, l'architecture, les cas d'usage avancés. Mentionne les limites et les considérations techniques.";
      case 'expert':
        return "Explique pour un expert. Approfondis la conception, les performances, la sécurité, l'architecture distribuée et les détails d'implémentation. Discute des compromis et des patterns avancés.";
      default:
        return "Explique pour un débutant.";
    }
  }

  static String complexityInstruction(int complexity) {
    if (complexity < 30) {
      return "Rends l'explication plus simple : moins de détails, des phrases plus courtes, des analogies plus accessibles.";
    } else if (complexity > 70) {
      return "Approfondis : ajoute des précisions techniques, des concepts connexes et des détails d'implémentation.";
    }
    return "Équilibre simplicité et précision.";
  }

  static String buildExplainPrompt({
    required String query,
    required String level,
    required int complexity,
    String? context,
  }) {
    return """
L'utilisateur pose la question suivante :

"$query"

${levelInstruction(level)}
${complexityInstruction(complexity)}
${context ?? ''}

Structure ta réponse en sections claires avec des émojis :
🧠 En une phrase
📖 Explication
💡 Exemple concret
🔍 Plus précisément
⭐ À retenir
⚠️ Erreur fréquente
❓ Vérifions si tu as compris

Termine par une question de vérification courte pour l'utilisateur.""";
  }

  static String buildCodeExplainPrompt({
    required String code,
    required String language,
    required String level,
    required int complexity,
    String? action,
  }) {
    final actionText = action ?? 'Explique tout le code en détail.';
    return """
Langage détecté : $language

Code à expliquer :
```$language
$code
```

$actionText

${levelInstruction(level)}
${complexityInstruction(complexity)}

Structure ta réponse avec :
🧠 En une phrase
📖 Explication (que fait ce code)
💡 Exemple concret (d'utilisation)
🔍 Plus précisément (détails techniques)
⭐ À retenir
⚠️ Erreur fréquente
❓ Vérifions si tu as compris

Explique pourquoi le code fonctionne, pas seulement ce qu'il fait.""";
  }

  static String buildErrorExplainPrompt({
    required String error,
    required String context,
    required String level,
  }) {
    return """
Voici une erreur/message reçu :

"$error"

Contexte : $context

${levelInstruction(level)}

Produis une explication complète avec ces sections :
1. 🐞 Ce que signifie l'erreur (traduit en langage clair)
2. 🔍 Cause probable
3. 📍 Où chercher
4. ✅ Comment vérifier
5. 🔧 Solution possible
6. 💡 Pourquoi cette solution fonctionne

Enseigne plutôt que de simplement donner une commande à copier.""";
  }

  static String buildErrorDetectPrompt(String rawText) {
    return """
Voici un texte. Détermine s'il s'agit d'une erreur/exception/stack trace.

$rawText

Répond par:
- "OUI" si c'est une erreur/exception/stack trace
- "NON" sinon

Répond uniquement par OUI ou NON.""";
  }

  static String buildQuizPrompt(String topic, String level) {
    return """
Crée un quiz de 5 questions sur le sujet : "$topic"
Niveau : $level

Génère un JSON valide avec cette structure exacte :
{
  "questions": [
    {
      "question": "Texte de la question",
      "type": "qcm" ou "true_false" ou "short_answer" ou "code_fill",
      "options": ["A", "B", "C", "D"] (pour qcm, sinon []),
      "correctAnswer": "réponse correcte",
      "explanation": "explication pédagogique de la réponse"
    }
  ]
}

Répond UNIQUEMENT avec le JSON, sans texte autour.""";
  }

  static String buildExercisePrompt(String topic, String difficulty, String level) {
    return """
Crée un exercice progressif sur le sujet : "$topic"
Difficulté : $difficulty
Niveau utilisateur : $level

Réponds avec ce format :

EXERCICE:
[Énoncé de l'exercice avec instructions claires]

INDICE:
[Un premier indice utile]

DEUXIEME_INDICE:
[Un deuxième indice]

SOLUTION:
[La solution complète]

EXPLICATION_SOLUTION:
[Explique pourquoi la solution est correcte, étape par étape]""";
  }

  static String buildFlashcardsPrompt(String explanation, String topic) {
    return """
À partir de cette explication sur "$topic", crée 5 flashcards pédagogiques (question → réponse).

EXPLICATION:
$explanation

Génère un JSON valide avec cette structure :
{
  "cards": [
    {"front": "question", "back": "réponse concise"}
  ]
}

Répond UNIQUEMENT avec le JSON.""";
  }

  static String buildMemoPrompt(String explanation, String topic) {
    return """
À partir de cette explication sur "$topic", crée une fiche mémo courte et structurée.

EXPLICATION:
$explanation

Format de réponse :
📌 DÉFINITION: (2-3 lignes maximum)
⭐ À RETENIR: (3 points essentiels en liste)
💡 EXEMPLE: (1 exemple concret)
⚠️ PIÈGE FRÉQUENT: (1 erreur courante)""";
  }

  static String buildAnalogiePrompt(String explanation, String topic) {
    return """
Le sujet est : "$topic"

Trouve une analogie parfaite pour l'expliquer (cuisine, maison, voiture, bibliothèque, Lego, courrier, ville, sport...).

Récupère l'analogie la plus efficace PUIS explique le sujet en t'appuyant dessus.

Structure :
🧠 L'analogie (en une phrase)
🎭 Comparaison détaillée (sujet vs analogie)
📖 Traduction (reformulation du sujet avec l'analogie)
⭐ Pourquoi ça marche""";
  }

  static String buildStepPrompt(String topic, String level) {
    return """
Explique le sujet "$topic" étape par étape pour un niveau $level.

Crée exactement 5 étapes progressives.

Format pour chaque étape :
ÉTAPE 1:
[Nom de l'étape]
[Contenu de l'étape - simple et clair]
(Vérification: [une petite question pour vérifier la compréhension])

...

ÉTAPE 5:
[Nom de l'étape]
[Contenu]
(Vérification: [question])""";
  }

  static String buildSocraticPrompt(String topic, String level) {
    return """
Sujet : "$topic"
Niveau : $level

Adopte la méthode socratique. Ne donne PAS la réponse directement.
Guide l'élève avec des questions progressives.

Réponds avec :
1. Une question de guidage (qui amène à réfléchir sur l'aspect clé du sujet)
2. Un indice discret en dessous (entre parenthèses)
3. Une courte phrase d'encouragement

Termine par : "Réfléchis un instant, puis dis-moi ce que tu penses.""";
  }

  static String buildWhyPrompt(String topic, int depth) {
    final suffixes = {
      1: "Explique-le moi à nouveau simplement.",
      2: "Approfondis maintenant : quel est le principe sous-jacent ?",
      3: "Maintenant, explique le fonctionnement interne complet et les mécanismes détaillés.",
    };
    return """
L'utilisateur demande "Pourquoi ?" à propos de : "$topic". C'est son ${'$depth'}${_ordinal(depth)} "Pourquoi".

${suffixes[depth.clamp(1, 3)] ?? suffixes[3]}

Va toujours plus profond. Structure la réponse en expliquant le niveau de cause correspondant.""";
  }

  static String buildNotUnderstoodPrompt(String topic, int attempts) {
    return """
L'utilisateur n'a toujours pas compris : "$topic".
C'est sa tentative numéro $attempts.

NON. Ne répète PAS la même explication.
Change complètement d'approche en utilisant l'une de ces stratégies (choisis SELON le cas) :
- Une analogie complètement différente
- Un exemple concret de la vie réelle
- Une visualisation en étapes/flux
- Une mini-démonstration avec un cas encore plus simple
- Une question-réponse guidée

Repart de zéro, comme si tu n'avais jamais expliqué le sujet.""";
  }

  static String buildLearnPrompt(String topic, String level) {
    return """
Crée un parcours d'apprentissage complet sur : "$topic"
Niveau : $level

Structure en 7 chapitres exactement :
1. Introduction (pourquoi ce sujet est important)
2. Concepts fondamentaux (les bases indispensables)
3. Premier exemple (une démonstration simple et complète)
4. Exercices (3 exercices progressifs)
5. Concepts intermédiaires (approfondissement)
6. Projet pratique (un petit projet à réaliser soi-même)
7. Quiz final (5 questions de vérification)

Pour chaque chapitre, donne le contenu pédagogique complet de manière claire et structurée.""";
  }

  static String _ordinal(int n) {
    if (n == 1) return 'er';
    return 'ème';
  }
}