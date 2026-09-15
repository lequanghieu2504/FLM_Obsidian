import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/search_result.dart';

abstract class LlmService {
  Future<String> answer({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String question,
    required List<SearchResult> context,
  });
}

class OpenAICompatibleLlmService implements LlmService {
  @override
  Future<String> answer({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String question,
    required List<SearchResult> context,
  }) async {
    if (apiKey.isEmpty || baseUrl.isEmpty || model.isEmpty) {
      return 'Configure base URL, API key, and model in Settings first.';
    }
    if (context.isEmpty) {
      return 'No matching local syllabus context was found.';
    }
    final url = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions',
    );
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'Answer only using the supplied FLM knowledge context. If the context does not contain enough information, state that the FLM knowledge base does not provide enough information.',
          },
          {
            'role': 'user',
            'content':
                'Context:\n${_formatContext(context)}\n\nQuestion:\n$question',
          },
        ],
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return 'LLM request failed with HTTP ${response.statusCode}.';
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          return message['content'] as String? ??
              'The provider returned no answer.';
        }
      }
    }
    return 'The provider returned no answer.';
  }

  String _formatContext(List<SearchResult> context) {
    return context
        .map(
          (item) =>
              '[${item.subjectCode} ${item.section} ${item.title} ${item.sourcePath}]\n${item.content}',
        )
        .join('\n\n');
  }
}
