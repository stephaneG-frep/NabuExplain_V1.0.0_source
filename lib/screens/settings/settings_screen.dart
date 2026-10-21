import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nabu_explain/core/constants/app_constants.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';
import 'package:nabu_explain/providers/app_provider.dart';
import 'package:nabu_explain/services/ai/ai_controller.dart';
import 'package:nabu_explain/services/storage/storage_service.dart';
import 'package:nabu_explain/widgets/common/cards.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _provider = 'OpenAI';
  String _model = 'gpt-4o-mini';
  String _apiKey = '';
  bool _obscureKey = true;
  bool _testingConnection = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await StorageService.instance.loadSettings();
    final provider = settings['provider'] as String? ?? 'OpenAI';
    final model = settings['model'] as String? ?? 'gpt-4o-mini';
    final apiKey = await StorageService.instance.getApiKey(provider) ?? '';
    setState(() {
      _provider = provider;
      _model = model;
      _apiKey = apiKey;
    });
  }

  Future<void> _save() async {
    await StorageService.instance.saveApiKey(_provider, _apiKey);
    await ref.read(settingsProvider.notifier).update('provider', _provider);
    await ref.read(settingsProvider.notifier).update('model', _model);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Configuration IA sauvegardée')),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _testResult = null;
    });
    final ok = await AIController().testConnection(
      provider: _provider,
      apiKey: _apiKey,
      model: _model,
    );
    setState(() {
      _testingConnection = false;
      _testResult = ok ? '✅ Connexion réussie ! Le modèle répond.' : '❌ Échec de la connexion. Vérifie ta clé, ton modèle et ta connexion Internet.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        final models = AppConstants.models[p];
                        _model = models != null && models.isNotEmpty ? models.first : 'default';
                        _apiKey = '';
                      });
                      _loadKey();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Model selection
            Text(
              'Modèle',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : NabuColors.blueDeep,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: AppConstants.models[_provider]?.contains(_model) == true ? _model : (AppConstants.models[_provider]?.first ?? ''),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.memory),
              ),
              items: (AppConstants.models[_provider] ?? [])
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _model = v ?? _model),
            ),
            const SizedBox(height: 24),

            // API Key
            Text(
              'Clé API',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : NabuColors.blueDeep,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _apiKey),
              obscureText: _obscureKey,
              onChanged: (v) => setState(() => _apiKey = v),
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
                    'Ta clé est stockée dans le stockage sécurisé de ton téléphone. Elle n\'est jamais exposée dans les logs.',
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
                tintColor: _testResult!.contains('✅') ? NabuColors.green.withValues(alpha: 0.1) : NabuColors.red.withValues(alpha: 0.1),
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
                      '• Installe Ollama sur ta machine\n'
                      '• Ollama se connecte via l\'IP de ton serveur.\n'
                      '• Par défaut : http://10.0.2.2:11434 (émulateur Android)\n'
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
    final key = await StorageService.instance.getApiKey(_provider);
    if (mounted) {
      setState(() => _apiKey = key ?? '');
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