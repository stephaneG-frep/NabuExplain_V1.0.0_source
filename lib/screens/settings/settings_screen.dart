import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nabu_explain/core/constants/app_constants.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/providers/app_provider.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';
import 'package:nabu_explain/services/ai/ai_service.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _customModel = '__custom__';

  String _provider = 'OpenAI';
  String _selectedModel = 'gpt-4o-mini';
  final _keyController = TextEditingController();
  final _customModelController = TextEditingController();
  final _ollamaUrlController = TextEditingController();
  bool _obscureKey = true;
  bool _testingConnection = false;
  bool? _testOk;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _customModelController.dispose();
    _ollamaUrlController.dispose();
    super.dispose();
  }

  List<String> get _models => AppConstants.models[_provider] ?? const [];

  String get _model =>
      _selectedModel == _customModel ? _customModelController.text.trim() : _selectedModel;

  void _setModel(String model) {
    if (_models.contains(model)) {
      _selectedModel = model;
    } else {
      _selectedModel = _customModel;
      _customModelController.text = model;
    }
  }

  Future<void> _load() async {
    final settings = await StorageService.instance.loadSettings();
    final provider = settings['provider'] as String? ?? 'OpenAI';
    final model = settings['model'] as String? ?? 'gpt-4o-mini';
    final apiKey = await StorageService.instance.getApiKey(provider) ?? '';
    if (!mounted) return;
    setState(() {
      _provider = provider;
      _setModel(model);
      _keyController.text = apiKey;
      _ollamaUrlController.text = settings['ollamaUrl'] as String? ?? OllamaService.defaultUrl;
    });
  }

  Future<void> _save() async {
    if (_model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique le nom du modèle.')),
      );
      return;
    }
    await StorageService.instance.saveApiKey(_provider, _keyController.text.trim());
    await ref.read(settingsProvider.notifier).updateAll({
      'provider': _provider,
      'model': _model,
      'ollamaUrl': _ollamaUrlController.text.trim(),
    });
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('✅ Configuration IA sauvegardée')),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _testResult = null;
    });
    final error = await AIController().testConnection(
      provider: _provider,
      apiKey: _keyController.text.trim(),
      model: _model,
      baseUrl: _ollamaUrlController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _testingConnection = false;
      _testOk = error == null;
      _testResult = error == null ? '✅ Connexion réussie ! Le modèle répond.' : '❌ Échec de la connexion.\n\n$error';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: isDark ? Colors.white : NabuColors.blueDeep,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Paramètres IA'),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : NabuColors.violetElectric,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [NabuColors.backgroundDark, const Color(0xFF3B253D)]
                : [NabuColors.backgroundLight, const Color(0xFFFDF0F0)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionTitle(
              title: 'Fournisseur IA',
              subtitle: 'Choisis le service qui répond à tes questions',
              icon: Icons.cloud_outlined,
            ),
            const SizedBox(height: 16),

            // Provider selection
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in AppConstants.providers)
                  CategoryChip(
                    label: p,
                    icon: _providerIcon(p),
                    color: _providerColor(p),
                    selected: _provider == p,
                    onTap: () {
                      setState(() {
                        _provider = p;
                        _selectedModel = _models.isNotEmpty ? _models.first : _customModel;
                        _customModelController.clear();
                        _keyController.clear();
                        _testResult = null;
                      });
                      _loadKey();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Model selection
            Text('Modèle', style: labelStyle),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // initialValue n'est lu qu'à la création : la clé force la
              // reconstruction quand le fournisseur ou le modèle chargé change.
              key: ValueKey('$_provider/$_selectedModel'),
              initialValue: _selectedModel,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.memory),
              ),
              items: [
                for (final m in _models) DropdownMenuItem(value: m, child: Text(m)),
                const DropdownMenuItem(value: _customModel, child: Text('Autre modèle…')),
              ],
              onChanged: (v) => setState(() => _selectedModel = v ?? _selectedModel),
            ),
            if (_selectedModel == _customModel) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customModelController,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Nom exact du modèle (ex. gpt-4.1-nano)',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
            ],
            const SizedBox(height: 24),

            if (_provider == 'Ollama') ...[
              Text('Adresse du serveur Ollama', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _ollamaUrlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.1.10:11434',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // API Key
            Text(_provider == 'Ollama' ? 'Clé API (facultative)' : 'Clé API', style: labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              obscureText: _obscureKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'sk-... (ta clé est stockée de façon sécurisée)',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: NabuColors.green,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Ta clé est stockée dans le stockage sécurisé de ton téléphone et n\'est envoyée qu\'au fournisseur choisi.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Test connection
            NabuButton(
              label: _testingConnection ? 'Test en cours...' : '🔌 Tester la connexion',
              icon: Icons.bolt,
              gradient: NabuColors.gradientCyan,
              loading: _testingConnection,
              onPressed: _testingConnection ? null : _testConnection,
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                tintColor: _testOk == true ? NabuColors.green.withValues(alpha: 0.1) : NabuColors.red.withValues(alpha: 0.1),
                child: Text(
                  _testResult!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Info for Ollama
            if (_provider == 'Ollama')
              GlassCard(
                tintColor: NabuColors.orange.withValues(alpha: 0.1),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💡 Ollama local', style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text(
                      'Ollama tourne sur ton ordinateur/machine locale.\n'
                      '• Lance Ollama avec OLLAMA_HOST=0.0.0.0 pour qu\'il soit joignable depuis le téléphone.\n'
                      '• Indique l\'adresse IP de ta machine sur le réseau local (ex. http://192.168.1.10:11434).\n'
                      '• http://10.0.2.2:11434 ne fonctionne que dans l\'émulateur Android.\n'
                      '• Aucune clé API n\'est nécessaire.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),
            NabuButton(
              label: '💾 Sauvegarder',
              icon: Icons.save_outlined,
              onPressed: _save,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _loadKey() async {
    final provider = _provider;
    final key = await StorageService.instance.getApiKey(provider);
    if (mounted && provider == _provider) {
      setState(() => _keyController.text = key ?? '');
    }
  }

  IconData _providerIcon(String provider) {
    switch (provider) {
      case 'OpenAI': return Icons.public;
      case 'Claude': return Icons.psychology;
      case 'Gemini': return Icons.auto_awesome;
      case 'Mistral': return Icons.air;
      case 'Ollama': return Icons.language;
      default: return Icons.cloud;
    }
  }

  Color _providerColor(String provider) {
    switch (provider) {
      case 'OpenAI': return NabuColors.green;
      case 'Claude': return NabuColors.orange;
      case 'Gemini': return NabuColors.blueDeep;
      case 'Mistral': return NabuColors.orange;
      case 'Ollama': return NabuColors.violetElectric;
      default: return NabuColors.cyanSoft;
    }
  }
}
