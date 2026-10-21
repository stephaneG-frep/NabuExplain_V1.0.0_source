import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

abstract class AIService {
  String get name;
  
  Future<String> generate({
    required String userPrompt,
    required String systemPrompt,
    required String model,
    required String apiKey,
    List<String>? imagePaths,
    double temperature = 0.7,
  }) async {
    final endpoint = await getEndpoint(model, apiKey);
    final response = await _callApi(endpoint, userPrompt, systemPrompt, model, apiKey, imagePaths, temperature);
    return _extractText(response);
  }

  Future<String> getEndpoint(String model, String apiKey);

  Future<Map<String, dynamic>> _callApi(
    String endpoint,
    String userPrompt,
    String systemPrompt,
    String model,
    String apiKey,
    List<String>? imagePaths,
    double temperature,
  );

  String _extractText(Map<String, dynamic> response);

  Future<bool> testConnection({required String model, required String apiKey}) async {
    try {
      final result = await generate(
        userPrompt: 'Réponds uniquement avec le mot OK.',
        systemPrompt: 'Tu es un assistant.',
        model: model,
        apiKey: apiKey,
      );
      return result.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _encodeImages(List<String>? imagePaths) async {
    if (imagePaths == null || imagePaths.isEmpty) return [];
    final encoded = <String>[];
    for (final path in imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          final compressed = await _compressImage(bytes);
          encoded.add(base64Encode(compressed));
        } else {
          encoded.add(base64Encode(bytes));
        }
      }
    }
    return encoded;
  }

  Future<List<int>> _compressImage(List<int> bytes) async {
    // Simple downscale of large images is done by image provider before this point.
    // If still too large, just return as-is (base64 large but functional).
    return bytes;
  }
}

class OpenAIService extends AIService {
  @override
  String get name => 'OpenAI';

  @override
  Future<String> getEndpoint(String model, String apiKey) async {
    return 'https://api.openai.com/v1/chat/completions';
  }

  @override
  Future<Map<String, dynamic>> _callApi(
    String endpoint,
    String userPrompt,
    String systemPrompt,
    String model,
    String apiKey,
    List<String>? imagePaths,
    double temperature,
  ) async {
    final images = await _encodeImages(imagePaths);
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': userPrompt},
    ];
    for (final img in images) {
      content.add({
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$img'},
      });
    }

    final body = jsonEncode({
      'model': model,
      'temperature': temperature,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': content},
      ],
    });

    final response = await http
        .post(Uri.parse(endpoint), headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        }, body: body)
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw AIException(_errorMessage(response.statusCode, response.body));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  String _extractText(Map<String, dynamic> response) {
    final choices = response['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw AIException('Réponse OpenAI vide');
    }
    return choices.first['message']['content'] as String? ?? '';
  }
}

class ClaudeService extends AIService {
  @override
  String get name => 'Claude';

  @override
  Future<String> getEndpoint(String model, String apiKey) async {
    return 'https://api.anthropic.com/v1/messages';
  }

  @override
  Future<Map<String, dynamic>> _callApi(
    String endpoint,
    String userPrompt,
    String systemPrompt,
    String model,
    String apiKey,
    List<String>? imagePaths,
    double temperature,
  ) async {
    final images = await _encodeImages(imagePaths);
    final content = <Map<String, dynamic>>[];
    if (images.isNotEmpty) {
      for (final img in images) {
        content.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': 'image/jpeg',
            'data': img,
          },
        });
      }
    }
    content.add({'type': 'text', 'text': userPrompt});

    final body = jsonEncode({
      'model': model,
      'max_tokens': 4096,
      'temperature': temperature,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': content},
      ],
    });

    final response = await http
        .post(Uri.parse(endpoint), headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        }, body: body)
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw AIException(_errorMessage(response.statusCode, response.body));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  String _extractText(Map<String, dynamic> response) {
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
  Future<String> getEndpoint(String model, String apiKey) async {
    return 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
  }

  @override
  Future<Map<String, dynamic>> _callApi(
    String endpoint,
    String userPrompt,
    String systemPrompt,
    String model,
    String apiKey,
    List<String>? imagePaths,
    double temperature,
  ) async {
    final images = await _encodeImages(imagePaths);
    final parts = <Map<String, dynamic>>[
      {'text': '$systemPrompt\n\n$userPrompt'},
    ];
    for (final img in images) {
      parts.add({
        'inline_data': {'mime_type': 'image/jpeg', 'data': img},
      });
    }

    final body = jsonEncode({
      'contents': [
        {'role': 'user', 'parts': parts},
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': 4096,
      },
    });

    final response = await http
        .post(Uri.parse(endpoint), headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw AIException(_errorMessage(response.statusCode, response.body));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  String _extractText(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    final content = candidates.first['content'] as Map<String, dynamic>?;
    if (content == null) return '';
    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';
    return parts
        .whereType<Map<String, dynamic>>()
        .map((p) => p['text'] as String? ?? '')
        .join('\n');
  }
}

class MistralService extends AIService {
  @override
  String get name => 'Mistral';

  @override
  Future<String> getEndpoint(String model, String apiKey) async {
    return 'https://api.mistral.ai/v1/chat/completions';
  }

  @override
  Future<Map<String, dynamic>> _callApi(
    String endpoint,
    String userPrompt,
    String systemPrompt,
    String model,
    String apiKey,
    List<String>? imagePaths,
    double temperature,
  ) async {
    final body = jsonEncode({
      'model': model,
      'temperature': temperature,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    });

    final response = await http
        .post(Uri.parse(endpoint), headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        }, body: body)
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw AIException(_errorMessage(response.statusCode, response.body));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  String _extractText(Map<String, dynamic> response) {
    final choices = response['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    return choices.first['message']['content'] as String? ?? '';
  }
}

class OllamaService extends AIService {
  @override
  String get name => 'Ollama';

  @override
  Future<String> getEndpoint(String model, String apiKey) async {
    return 'http://10.0.2.2:11434/api/chat';
  }

  @override
  Future<Map<String, dynamic>> _callApi(
    String endpoint,
    String userPrompt,
    String systemPrompt,
    String model,
    String apiKey,
    List<String>? imagePaths,
    double temperature,
  ) async {
    final body = jsonEncode({
      'model': model,
      'stream': false,
      'options': {'temperature': temperature},
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    });

    final response = await http
        .post(Uri.parse(endpoint), headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw AIException('Erreur Ollama (${response.statusCode}) : ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  String _extractText(Map<String, dynamic> response) {
    return response['message']['content'] as String? ?? '';
  }
}

class AIException implements Exception {
  final String message;
  AIException(this.message);
  @override
  String toString() => message;
}

String _errorMessage(int statusCode, String body) {
  switch (statusCode) {
    case 401:
      return 'Clé API incorrecte ou expirée. Vérifie ta clé dans les paramètres.';
    case 429:
      return 'Quota dépassé ou trop de requêtes. Réessaie dans quelques instants.';
    case 500:
    case 502:
    case 503:
      return 'Le service IA est momentanément indisponible. Réessaie plus tard.';
    default:
      return 'Erreur $statusCode : ${_truncate(body)}';
  }
}

String _truncate(String s) {
  if (s.length <= 200) return s;
  return s.substring(0, 200);
}

class AIServiceFactory {
  static AIService? create(String providerName) {
    switch (providerName) {
      case 'OpenAI': return OpenAIService();
      case 'Claude': return ClaudeService();
      case 'Gemini': return GeminiService();
      case 'Mistral': return MistralService();
      case 'Ollama': return OllamaService();
      default: return null;
    }
  }
}