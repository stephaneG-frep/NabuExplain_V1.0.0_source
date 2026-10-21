import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Un message précédent de la conversation, envoyé comme contexte.
class AIMessage {
  final String role; // 'user' ou 'assistant'
  final String content;
  const AIMessage({required this.role, required this.content});
}

/// Image prête à l'envoi : base64 + type MIME réel.
class EncodedImage {
  final String data;
  final String mimeType;
  const EncodedImage(this.data, this.mimeType);
}

abstract class AIService {
  /// Adresse du serveur (utilisée par Ollama).
  final String? baseUrl;
  AIService({this.baseUrl});

  String get name;

  static const _timeout = Duration(seconds: 180);
  static const _maxHistoryChars = 6000;

  Future<String> generate({
    required String userPrompt,
    required String systemPrompt,
    required String model,
    required String apiKey,
    List<String>? imagePaths,
    double temperature = 0.7,
    List<AIMessage> history = const [],
  }) async {
    final images = await encodeImages(imagePaths);
    final response = await callApi(
      userPrompt: userPrompt,
      systemPrompt: systemPrompt,
      model: model,
      apiKey: apiKey,
      images: images,
      temperature: temperature,
      history: normalizeHistory(history),
    );
    final text = extractText(response);
    if (text.trim().isEmpty) {
      throw AIException('$name a renvoyé une réponse vide. Réessaie.');
    }
    return text;
  }

  Future<Map<String, dynamic>> callApi({
    required String userPrompt,
    required String systemPrompt,
    required String model,
    required String apiKey,
    required List<EncodedImage> images,
    required double temperature,
    required List<AIMessage> history,
  });

  String extractText(Map<String, dynamic> response);

  /// Renvoie null si la connexion fonctionne, sinon le message d'erreur.
  Future<String?> testConnection({required String model, required String apiKey}) async {
    try {
      await generate(
        userPrompt: 'Réponds uniquement avec le mot OK.',
        systemPrompt: 'Tu es un assistant.',
        model: model,
        apiKey: apiKey,
      );
      return null;
    } on AIException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur inattendue : $e';
    }
  }

  /// Alterne strictement user/assistant, commence par user et finit par
  /// assistant (le message courant est ajouté ensuite) : c'est ce qu'exigent
  /// Claude et Gemini, et ça ne gêne pas les autres.
  static List<AIMessage> normalizeHistory(List<AIMessage> history) {
    final result = <AIMessage>[];
    for (final m in history) {
      var content = m.content.trim();
      if (content.isEmpty) continue;
      if (content.length > _maxHistoryChars) {
        content = '${content.substring(0, _maxHistoryChars)}…';
      }
      if (result.isEmpty && m.role != 'user') continue;
      if (result.isNotEmpty && result.last.role == m.role) {
        result[result.length - 1] = AIMessage(role: m.role, content: '${result.last.content}\n\n$content');
      } else {
        result.add(AIMessage(role: m.role, content: content));
      }
    }
    while (result.isNotEmpty && result.last.role == 'user') {
      result.removeLast();
    }
    return result;
  }

  Future<http.Response> post(Uri uri, Map<String, String> headers, Object body) async {
    try {
      return await http
          .post(uri, headers: {'Content-Type': 'application/json', ...headers}, body: jsonEncode(body))
          .timeout(_timeout);
    } on TimeoutException {
      throw AIException('$name met trop de temps à répondre. Réessaie dans un instant.');
    } on SocketException {
      throw AIException(_unreachableMessage());
    } on http.ClientException {
      throw AIException(_unreachableMessage());
    }
  }

  String _unreachableMessage() => 'Impossible de joindre $name. Vérifie ta connexion Internet.';

  Map<String, dynamic> decodeOrThrow(http.Response response) {
    if (response.statusCode != 200) {
      throw AIException(errorMessage(name, response.statusCode, response.body));
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw AIException('Réponse illisible de $name.');
    }
  }

  // ── Images ────────────────────────────────────────────────
  static const _maxImageBytes = 3 * 1024 * 1024;
  static const _maxImageSide = 2048;

  static Future<List<EncodedImage>> encodeImages(List<String>? imagePaths) async {
    if (imagePaths == null || imagePaths.isEmpty) return [];
    final encoded = <EncodedImage>[];
    for (final path in imagePaths) {
      final file = File(path);
      if (!await file.exists()) continue;
      encoded.add(await Isolate.run(() => prepareImage(file.readAsBytesSync())));
    }
    return encoded;
  }

  /// Détecte le vrai format ; réduit et recompresse en JPEG les images trop
  /// lourdes ou dans un format non accepté par les API (HEIC, BMP…).
  static EncodedImage prepareImage(Uint8List bytes) {
    final mime = detectMimeType(bytes);
    if (mime != null && bytes.length <= _maxImageBytes) {
      return EncodedImage(base64Encode(bytes), mime);
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Impossible à décoder : on tente l'envoi tel quel.
      return EncodedImage(base64Encode(bytes), mime ?? 'image/jpeg');
    }
    var resized = decoded;
    if (decoded.width > _maxImageSide || decoded.height > _maxImageSide) {
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: _maxImageSide)
          : img.copyResize(decoded, height: _maxImageSide);
    }
    var quality = 85;
    var jpg = img.encodeJpg(resized, quality: quality);
    while (jpg.length > _maxImageBytes && quality > 40) {
      quality -= 15;
      jpg = img.encodeJpg(resized, quality: quality);
    }
    return EncodedImage(base64Encode(jpg), 'image/jpeg');
  }

  static String? detectMimeType(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
    if (b.length >= 4 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return 'image/gif';
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }
}

class OpenAIService extends AIService {
  @override
  String get name => 'OpenAI';

  // Les modèles de raisonnement (o1, o3, o4, gpt-5…) refusent `temperature`.
  static bool isReasoningModel(String model) => RegExp(r'^(o\d|gpt-5)').hasMatch(model);

  @override
  Future<Map<String, dynamic>> callApi({
    required String userPrompt,
    required String systemPrompt,
    required String model,
    required String apiKey,
    required List<EncodedImage> images,
    required double temperature,
    required List<AIMessage> history,
  }) async {
    final reasoning = isReasoningModel(model);
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': userPrompt},
      for (final image in images)
        {
          'type': 'image_url',
          'image_url': {'url': 'data:${image.mimeType};base64,${image.data}'},
        },
    ];

    final response = await post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      {'Authorization': 'Bearer $apiKey'},
      {
        'model': model,
        if (!reasoning) 'temperature': temperature,
        'messages': [
          {'role': reasoning ? 'developer' : 'system', 'content': systemPrompt},
          for (final m in history) {'role': m.role, 'content': m.content},
          {'role': 'user', 'content': content},
        ],
      },
    );
    return decodeOrThrow(response);
  }

  @override
  String extractText(Map<String, dynamic> response) {
    final choices = response['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    return choices.first['message']?['content'] as String? ?? '';
  }
}

class ClaudeService extends AIService {
  @override
  String get name => 'Claude';

  // Le repli automatique en cas de refus n'existe que pour ces modèles.
  static const _fallbackModels = {'claude-opus-5-5', 'claude-sonnet-5-5'};

  @override
  Future<Map<String, dynamic>> callApi({
    required String userPrompt,
    required String systemPrompt,
    required String model,
    required String apiKey,
    required List<EncodedImage> images,
    required double temperature,
    required List<AIMessage> history,
  }) async {
    final content = <Map<String, dynamic>>[
      for (final image in images)
        {
          'type': 'image',
          'source': {'type': 'base64', 'media_type': image.mimeType, 'data': image.data},
        },
      {'type': 'text', 'text': userPrompt},
    ];
    final fallback = _fallbackModels.contains(model);

    // Pas de `temperature` : les modèles Claude actuels la refusent (erreur 400).
    final response = await post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        if (fallback) 'anthropic-beta': 'server-side-fallback-2026-07-01',
      },
      {
        'model': model,
        'max_tokens': 16000,
        'system': systemPrompt,
        if (fallback) 'fallbacks': 'default',
        'messages': [
          for (final m in history) {'role': m.role, 'content': m.content},
          {'role': 'user', 'content': content},
        ],
      },
    );
    final data = decodeOrThrow(response);
    if (data['stop_reason'] == 'refusal') {
      throw AIException('Claude a refusé de répondre à cette demande. Essaie de la reformuler.');
    }
    return data;
  }

  @override
  String extractText(Map<String, dynamic> response) {
    final content = response['content'] as List?;
    if (content == null || content.isEmpty) return '';
    return content
        .whereType<Map<String, dynamic>>()
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join('\n');
  }
}

class GeminiService extends AIService {
  @override
  String get name => 'Gemini';

  @override
  Future<Map<String, dynamic>> callApi({
    required String userPrompt,
    required String systemPrompt,
    required String model,
    required String apiKey,
    required List<EncodedImage> images,
    required double temperature,
    required List<AIMessage> history,
  }) async {
    // La clé passe en en-tête et non dans l'URL, pour ne pas finir dans des logs.
    final response = await post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
      {'x-goog-api-key': apiKey},
      {
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'contents': [
          for (final m in history)
            {
              'role': m.role == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': m.content},
              ],
            },
          {
            'role': 'user',
            'parts': [
              {'text': userPrompt},
              for (final image in images)
                {
                  'inline_data': {'mime_type': image.mimeType, 'data': image.data},
                },
            ],
          },
        ],
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': 8192,
        },
      },
    );
    final data = decodeOrThrow(response);
    final blockReason = data['promptFeedback']?['blockReason'];
    if (blockReason != null) {
      throw AIException('Gemini a bloqué cette demande ($blockReason). Essaie de la reformuler.');
    }
    return data;
  }

  @override
  String extractText(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    final content = candidates.first['content'] as Map<String, dynamic>?;
    if (content == null) return '';
    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';
    return parts
        .whereType<Map<String, dynamic>>()
        .where((p) => p['thought'] != true)
        .map((p) => p['text'] as String? ?? '')
        .join('\n');
  }
}

class MistralService extends AIService {
  @override
  String get name => 'Mistral';

  @override
  Future<Map<String, dynamic>> callApi({
    required String userPrompt,
    required String systemPrompt,
    required String model,
    required String apiKey,
    required List<EncodedImage> images,
    required double temperature,
    required List<AIMessage> history,
  }) async {
    // Les images nécessitent un modèle vision (pixtral, mistral-medium/small récents).
    final Object content = images.isEmpty
        ? userPrompt
        : [
            {'type': 'text', 'text': userPrompt},
            for (final image in images)
              {'type': 'image_url', 'image_url': 'data:${image.mimeType};base64,${image.data}'},
          ];

    final response = await post(
      Uri.parse('https://api.mistral.ai/v1/chat/completions'),
      {'Authorization': 'Bearer $apiKey'},
      {
        'model': model,
        'temperature': temperature,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          for (final m in history) {'role': m.role, 'content': m.content},
          {'role': 'user', 'content': content},
        ],
      },
    );
    return decodeOrThrow(response);
  }

  @override
  String extractText(Map<String, dynamic> response) {
    final choices = response['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    final content = choices.first['message']?['content'];
    if (content is String) return content;
    // Certains modèles renvoient une liste de blocs.
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'] as String? ?? '')
          .join('\n');
    }
    return '';
  }
}

class OllamaService extends AIService {
  static const defaultUrl = 'http://10.0.2.2:11434';

  OllamaService({super.baseUrl});

  @override
  String get name => 'Ollama';

  String get _base {
    final url = (baseUrl == null || baseUrl!.trim().isEmpty) ? defaultUrl : baseUrl!.trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  @override
  Future<Map<String, dynamic>> callApi({
    required String userPrompt,
    required String systemPrompt,
    required String model,
    required String apiKey,
    required List<EncodedImage> images,
    required double temperature,
    required List<AIMessage> history,
  }) async {
    final response = await post(
      Uri.parse('$_base/api/chat'),
      // Clé facultative : utile seulement derrière un proxy authentifié.
      {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
      {
        'model': model,
        'stream': false,
        'options': {'temperature': temperature},
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          for (final m in history) {'role': m.role, 'content': m.content},
          {
            'role': 'user',
            'content': userPrompt,
            // Pris en compte par les modèles vision (llava, llama3.2-vision…).
            if (images.isNotEmpty) 'images': [for (final image in images) image.data],
          },
        ],
      },
    );
    return decodeOrThrow(response);
  }

  @override
  Future<http.Response> post(Uri uri, Map<String, String> headers, Object body) async {
    try {
      return await super.post(uri, headers, body);
    } on AIException catch (e) {
      if (e.message.startsWith('Impossible de joindre')) {
        throw AIException(
          'Impossible de joindre Ollama à $_base. Vérifie que le serveur tourne, '
          'qu\'il écoute sur le réseau (OLLAMA_HOST=0.0.0.0) et que l\'adresse est correcte dans les paramètres.',
        );
      }
      rethrow;
    }
  }

  @override
  String extractText(Map<String, dynamic> response) {
    return response['message']?['content'] as String? ?? '';
  }
}

class AIException implements Exception {
  final String message;
  AIException(this.message);
  @override
  String toString() => message;
}

/// Message d'erreur lisible, avec le détail renvoyé par le fournisseur.
String errorMessage(String provider, int statusCode, String body) {
  final detail = _providerDetail(body);
  final suffix = detail == null ? '' : '\n\nDétail : $detail';
  switch (statusCode) {
    case 400:
      return 'Requête refusée par $provider (le modèle choisi ne gère peut-être pas les images ou ce type de demande).$suffix';
    case 401:
    case 403:
      return 'Clé API incorrecte, expirée ou sans accès à ce modèle. Vérifie ta clé dans les paramètres.$suffix';
    case 404:
      return 'Modèle introuvable chez $provider. Vérifie le nom du modèle dans les paramètres.$suffix';
    case 429:
      return 'Quota dépassé ou trop de requêtes. Réessaie dans quelques instants.$suffix';
    case 500:
    case 502:
    case 503:
    case 529:
      return 'Le service $provider est momentanément indisponible. Réessaie plus tard.';
    default:
      return 'Erreur $statusCode de $provider.$suffix';
  }
}

String? _providerDetail(String body) {
  try {
    final data = jsonDecode(body);
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] is String) return _truncate(error['message'] as String);
      if (error is String) return _truncate(error);
      if (data['message'] is String) return _truncate(data['message'] as String);
    }
  } catch (_) {}
  return body.trim().isEmpty ? null : _truncate(body);
}

String _truncate(String s) {
  if (s.length <= 300) return s;
  return '${s.substring(0, 300)}…';
}

class AIServiceFactory {
  static AIService? create(String providerName, {String? baseUrl}) {
    switch (providerName) {
      case 'OpenAI': return OpenAIService();
      case 'Claude': return ClaudeService();
      case 'Gemini': return GeminiService();
      case 'Mistral': return MistralService();
      case 'Ollama': return OllamaService(baseUrl: baseUrl);
      default: return null;
    }
  }

  /// Ollama est le seul fournisseur utilisable sans clé.
  static bool requiresApiKey(String providerName) => providerName != 'Ollama';
}
