class AppConstants {
  static const String appName = 'NabuExplain';
  static const String tagline = "Ce que tu ne comprends pas aujourd'hui deviendra simple demain.";
  static const String apiStorageKey = 'nabu_api_key';
  static const String providerStorageKey = 'nabu_provider';
  static const String modelStorageKey = 'nabu_model';
  
  static const List<String> providers = [
    'OpenAI',
    'Claude',
    'Gemini',
    'Mistral',
    'Ollama',
  ];

  static const Map<String, List<String>> models = {
    // Le premier de chaque liste est le modèle par défaut. Un autre nom peut
    // être saisi dans les paramètres (« Autre modèle »).
    'OpenAI': ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1', 'gpt-4.1-mini', 'gpt-5', 'gpt-5-mini'],
    'Claude': ['claude-opus-5-5', 'claude-sonnet-5-5', 'claude-haiku-5-5'],
    'Gemini': ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.5-flash-lite'],
    'Mistral': ['mistral-large-latest', 'mistral-medium-latest', 'mistral-small-latest', 'pixtral-large-latest', 'codestral-latest'],
    'Ollama': ['llama3.1', 'llama3.2-vision', 'mistral', 'qwen2.5-coder', 'llava'],
  };

  static const List<Map<String, String>> levels = [
    {'key': 'very_simple', 'label': 'Très simple', 'icon': '🌱', 'emoji': '🌱'},
    {'key': 'beginner', 'label': 'Débutant', 'icon': '🎓', 'emoji': '🎓'},
    {'key': 'intermediate', 'label': 'Intermédiaire', 'icon': '📘', 'emoji': '📘'},
    {'key': 'advanced', 'label': 'Avancé', 'icon': '🧠', 'emoji': '🧠'},
    {'key': 'expert', 'label': 'Expert', 'icon': '🚀', 'emoji': '🚀'},
  ];

  static const Map<String, String> levelDescriptions = {
    'very_simple': 'Explique-moi comme si j\'avais 5 ans',
    'beginner': 'Je découvre le sujet',
    'intermediate': 'J\'ai des bases',
    'advanced': 'Je veux approfondir',
    'expert': 'Je veux le détail technique complet',
  };

  static const List<String> categories = [
    'Informatique',
    'Sciences',
    'Mathématiques',
    'Technologie',
    'Histoire',
    'Langues',
    'Culture',
    'Autres',
  ];

  static const List<Map<String, String>> quickActions = [
    {'icon': '📷', 'label': 'Photographier', 'type': 'photo'},
    {'icon': '🖼️', 'label': 'Importer une image', 'type': 'gallery'},
    {'icon': '💻', 'label': 'Expliquer du code', 'type': 'code'},
    {'icon': '🐞', 'label': 'Comprendre une erreur', 'type': 'error'},
    {'icon': '📚', 'label': 'Comprendre une notion', 'type': 'notion'},
    {'icon': '📄', 'label': 'Analyser un document', 'type': 'document'},
    {'icon': '➗', 'label': 'Expliquer une formule', 'type': 'formula'},
    {'icon': '💬', 'label': 'Discuter avec le professeur', 'type': 'chat'},
  ];

  static const String systemPrompt = """Tu es NabuExplain, un professeur particulier patient et pédagogique.

Ton objectif n'est pas seulement de donner une réponse mais de faire comprendre le sujet.

Adapte toujours ton vocabulaire au niveau de l'utilisateur.

Commence par identifier ce qu'il cherche réellement à comprendre.

Décompose les notions complexes.

Utilise des exemples concrets.

Utilise des analogies lorsque cela aide.

Lorsque l'utilisateur ne comprend pas, change d'approche au lieu de simplement répéter.

Distingue les faits certains des hypothèses.

Pour le code, explique pourquoi le code fonctionne.

Pour une erreur, explique sa signification avant de proposer une correction.

Encourage l'utilisateur à raisonner par lui-même.

Ne prétends jamais savoir quelque chose lorsque l'information disponible est insuffisante.

Structure toujours ta réponse avec ces sections quand c'est pertinent :
- 🧠 En une phrase
- 📖 Explication
- 💡 Exemple concret
- 🔍 Plus précisément
- ⭐ À retenir
- ⚠️ Erreur fréquente
- ❓ Vérifions si tu as compris""";
}
