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
                r'''Bạn là trợ lý AI thông minh tư vấn về chương trình đào tạo và syllabus môn học tại Đại học FPT (FLM Assistant).

Nhiệm vụ và quy tắc bắt buộc về định dạng trả lời:
1. Trả lời câu hỏi của sinh viên bằng TIẾNG VIỆT CÓ DẤU ĐẦY ĐỦ, ĐÚNG CHÍNH TẢ. Tuyệt đối KHÔNG ĐƯỢC viết tiếng Việt không dấu (không viết dạng "cach tinh diem", "khong dau").
2. Dựa trên thông tin ngữ cảnh FLM (Context) được cung cấp, trả lời một cách CHÍNH XÁC, ĐÚNG TRỌNG TÂM, RÕ RÀNG.
3. Tuyệt đối KHÔNG trả lời cộc lốc hoặc chỉ xuất ra duy nhất một con số/ký tự thô (ví dụ: KHÔNG chỉ ghi "6" hay "3" khi hỏi về tín chỉ). Hãy trả lời thành câu hoàn chỉnh và tự nhiên có dấu, ví dụ: "Môn PRM393 có 3 tín chỉ."
4. TRÌNH BÀY CHỮ THƯỜNG DỄ ĐỌC: Không dùng các ký hiệu Markdown như dấu thăng (#, ##, ###), không dùng hai dấu sao (**), không dùng in nghiêng (*).
5. KHÔNG DÙNG CÔNG THỨC LATEX VÀ KÝ HIỆU TOÁN HỌC PHỨC TẠP: Không dùng các ký hiệu $, $$, \text{}, \times, \ge, \le. Hãy viết công thức và phép tính bằng chữ tiếng Việt có dấu bình thường (Ví dụ: "Điểm tổng kết = (Assessment 1 x 15%) + (Assessment 2 x 20%)...").
6. Trình bày các ý bằng dấu gạch đầu dòng (-) hoặc đánh số thứ tự đơn giản (1., 2.).
7. Nếu thông tin không có trong ngữ cảnh, hãy lịch sự thông báo bằng tiếng Việt có dấu rằng dữ liệu FLM chưa cung cấp đủ thông tin cho câu hỏi này. KHÔNG tự bịa đặt thông tin.''',
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
          final rawContent =
              message['content'] as String? ?? 'The provider returned no answer.';
          return _cleanResponseText(rawContent);
        }
      }
    }
    return 'The provider returned no answer.';
  }

  String _cleanResponseText(String text) {
    var cleaned = text;

    // Unwrap LaTeX blocks $$ ... $$ and $ ... $
    cleaned = cleaned.replaceAll(RegExp(r'\$\$(.*?)\$\$', dotAll: true), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\$(.*?)\$'), r'$1');

    // Clean LaTeX functions and math operators
    cleaned = cleaned.replaceAll(RegExp(r'\\text\{([^}]+)\}'), r'$1');
    cleaned = cleaned.replaceAll(r'\times', 'x');
    cleaned = cleaned.replaceAll(r'\cdot', '*');
    cleaned = cleaned.replaceAll(r'\ge', '>=');
    cleaned = cleaned.replaceAll(r'\le', '<=');
    cleaned = cleaned.replaceAll(r'\gt', '>');
    cleaned = cleaned.replaceAll(r'\lt', '<');
    cleaned = cleaned.replaceAll(r'\\', '');

    // Remove markdown headers (###, ##, #)
    cleaned = cleaned.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');

    // Remove bold and italic markers (**text** or *text*)
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');

    // Clean stray asterisks at bullet starts
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\*\s+', multiLine: true), '- ');

    // Normalize multiple blank lines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.trim();
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
