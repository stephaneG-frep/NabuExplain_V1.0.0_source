# 🦉 NabuExplain v1.0.0

**Ton professeur IA universel.**

« Ce que tu ne comprends pas aujourd'hui deviendra simple demain. »

---

## 🚀 Description

NabuExplain est un professeur particulier IA sur ton téléphone Android.

Son principe : **« Montre-moi ce que tu ne comprends pas, je te l'explique. »**

- Questions, mots, notions, textes
- Photos, captures d'écran
- Code informatique (Dart, Python, JS, Java, Kotlin, Go, Rust, SQL, etc.)
- Messages d'erreur, stack traces
- Formules mathématiques, schémas
- Documents, consignes

---

## ✨ Fonctionnalités

### 🎓 Niveau d'explication
- 🌱 Très simple (analogie accessible)
- 🎓 Débutant (principe + exemple concret)
- 📘 Intermédiaire (vocabulaire technique)
- 🧠 Avancé (architecture, cas d'usage)
- 🚀 Expert (implémentation, performance, sécurité)

### 📸 Mode Photo
Prends une photo ou importe une image → NabuExplain l'analyse et l'explique. Zoom possible.

### 💻 Mode Code
Du code Dart, Flutter, Python, JS, Java, Kotlin, Swift, PHP, C, C++, Rust, Go, SQL, etc. Coloration syntaxique et explication ligne par ligne.

### 🐞 Mode Erreur
Colle ton message d'erreur, stack trace, erreur compilation → NabuExplain enseigne la cause et la solution.

### 🧠 Mode Socratique
NabuExplain ne donne pas la réponse directement. Il guide par des questions.

### 🪜 Mode Pas à pas
Concept complexe découpé en étapes progressives avec vérification.

### 🎭 Analogie
Exemple de la vie quotidienne pour comprendre.

### 🎯 Quiz
5 questions (QCM, vrai/faux, réponse courte). Score et correction pédagogique.

### 🏋️ Exercices
Énoncé progressif avec indices, solution, et explication.

### 📝 Fiches mémo
Transformation rapide en fiche courte : définition, à retenir, exemple, piège.

### 🗂️ Flashcards
Cartes question/réponse avec suivi : « Je savais », « À revoir », « Je ne savais pas ».

### 📊 Progression
Suivi des sujets, quiz, exercices, taux de réussite.

### 💾 Bibliothèque
Sauvegarde locale, recherche, catégories, favoris.

### 📤 Export PDF
Génère et partage un PDF propre depuis Android.

### 📖 Mode d'emploi intégré
18 sections d'aide + 30 exemples de demandes.

---

## 🏗️ Architecture

- **Architecture** : MVVM+ avec séparation UI / logique métier / stockage / IA
- **State Management** : Riverpod
- **Stockage** : Fichiers JSON (secure storage pour les clés API)
- **IA** : Multi-fournisseur (OpenAI, Claude, Gemini, Mistral, Ollama)
- **Design** : Material 3, glassmorphism, gradients, animations

---

## ⚙️ Configuration IA

1. Va dans **Profil → Paramètres de l'IA**
2. Choisis ton fournisseur
3. Entre ta clé API
4. Teste la connexion

**Fournisseurs supportés :**
- OpenAI (gpt-4o-mini, gpt-4o, gpt-4.1, gpt-5, etc.)
- Claude (claude-opus-5-5, claude-sonnet-5-5, claude-haiku-5-5)
- Gemini (gemini-2.5-flash, gemini-2.5-pro, etc.)
- Mistral (mistral-large-latest, pixtral-large-latest pour les images, etc.)
- Ollama (llama3.1, llama3.2-vision, qwen2.5-coder, etc.) — sans clé API

Un autre modèle peut être saisi via « Autre modèle… ».

**Ollama sur un vrai téléphone :** lance Ollama avec `OLLAMA_HOST=0.0.0.0`, puis indique l'adresse IP de ta machine dans les paramètres (ex. `http://192.168.1.10:11434`). L'adresse par défaut `http://10.0.2.2:11434` ne fonctionne que dans l'émulateur.

---

## 📦 Installation

### APK (direct)
Installe le fichier `NabuExplain_V1.0.0_Android_arm64.apk` sur ton smartphone Android (activation de l'installation depuis sources inconnues si nécessaire).

### Compilation depuis la source
```bash
# Vérifier que Flutter est installé
flutter --version

# Cloner / décompresser le projet
unzip NabuExplain_V1.0.0_source.zip
cd nabu_explain

# Résoudre les dépendances
flutter pub get

# Lancer en développement
flutter run

# Lancer les tests
flutter test

# Analyser le code
flutter analyze

# Build APK release
flutter build apk --release --target-platform android-arm64
```

---

## 🔒 Confidentialité

- Tes données (explications, fiches, flashcards) sont stockées **localement** sur ton téléphone.
- Les questions envoyées à l'IA transitent par le fournisseur IA que **tu** choisis (OpenAI, Claude, Gemini, etc.).
- Les clés API sont stockées de manière **sécurisée** via Flutter Secure Storage.
- Aucune donnée n'est partagée avec des tiers sans ton action.

---

## 📱 Mode Hors Connexion

Sans Internet, tu peux consulter :
- Explications sauvegardées
- Fiches mémo
- Flashcards
- Historique
- Progression
- Paramètres

---

## 📄 Fonctionnalités v1.0.0

✅ 5 niveaux d'explication  
✅ Curseur de complexité  
✅ Mode photo (caméra + galerie)  
✅ Mode code (20+ langages)  
✅ Mode erreur (stack traces, compilation, etc.)  
✅ Mode pas à pas  
✅ Mode socratique  
✅ Quiz automatisé (4 types)  
✅ Exercices progressifs  
✅ Flashcards  
✅ Fiches mémo  
✅ Bibliothèque locale  
✅ Suivi de progression  
✅ Export PDF  
✅ IA multi-fournisseurs (5 fournisseurs)  
✅ Mode hors connexion  
✅ Mode d'emploi intégré  
✅ 30 exemples de demandes  
✅ Thème clair et sombre  
✅ Onboarding  
✅ « Pourquoi ? » progressif  
✅ « Je n'ai pas compris » avec reformulation  
✅ Analogie  
✅ Apprends-moi (parcours complet)  
✅ Navigation contextuelle (revenir au sujet)  

---

## 📁 Structure du projet

```
lib/
├── core/
│   ├── constants/   → Paramètres globaux
│   ├── theme/       → Design system, couleurs, thème
│   └── utils/       → Prompt builder, utilitaires
├── models/          → Data models (explanations, quiz, flashcards...)
├── providers/       → State management (Riverpod)
├── screens/
│   ├── onboarding/  → 5 écrans d'onboarding
│   ├── home/        → Accueil + navigation
│   ├── teacher/     → Professeur, quiz, exercices, flashcards
│   ├── library/     → Bibliothèque, fiches
│   ├── progression/ → Progression
│   ├── profile/     → Profil
│   ├── settings/    → Configuration IA
│   └── manual/      → Mode d'emploi
├── services/
│   ├── ai/          → Multi-provider AI service
│   ├── storage/     → Persistance locale JSON
│   └── pdf/         → Export PDF
└── widgets/
    ├── common/      → Cards, boutons, chips
    ├── code/        → CodeView syntax highlighting
    ├── explanations/→ Explications structurées
    └── inputs/      → Sélecteur niveau, curseur
```

---

## 📧 Contact

Projet NabuExplain — v1.0.0
