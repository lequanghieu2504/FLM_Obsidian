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
            'content':
                'Bạn là trợ lý AI thông minh chuyên tư vấn về chương trình đào tạo và syllabus môn học tại Đại học FPT (FLM Assistant).\n\n'
                'Nhiệm vụ của bạn:\n'
                '1. Dựa trên thông tin ngữ cảnh FLM (Context) được cung cấp, hãy trả lời câu hỏi của sinh viên một cách CHÍNH XÁC, ĐÚNG TRỌNG TÂM, RÕ RÀNG và ĐẦY ĐỦ CÂU BẰNG TIẾNG VIỆT.\n'
                '2. Tuyệt đối KHÔNG trả lời cộc lốc hoặc chỉ xuất ra duy nhất một con số/ký tự thô (ví dụ: KHÔNG chỉ ghi "**6**" hay "**3**" khi hỏi về tín chỉ). Hãy trả lời thành câu hoàn chỉnh và tự nhiên, ví dụ: "Môn PRM393 có 3 tín chỉ." hoặc giải thích rõ ràng chi tiết nếu có trong ngữ cảnh.\n'
                '3. Trình bày bài viết đẹp mắt, dễ đọc bằng định dạng Markdown (sử dụng in đậm, danh sách gạch đầu dòng khi thích hợp).\n'
                '4. Nếu thông tin không có hoặc không đủ trong ngữ cảnh được cung cấp, hãy lịch sự thông báo rằng cơ sở dữ liệu FLM chưa cung cấp đủ thông tin cho câu hỏi này. KHÔNG tự bịa đặt thông tin nằm ngoài ngữ cảnh.',
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
