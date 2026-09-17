import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/badge_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/search_result.dart';
import '../../repositories/providers.dart';

class EmbeddedChatMessage {
  EmbeddedChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
  });

  final String text;
  final bool isUser;
  final List<SearchResult> sources;
}

class EmbeddedChatWidget extends ConsumerStatefulWidget {
  const EmbeddedChatWidget({
    this.subjectCode,
    super.key,
  });

  final String? subjectCode;

  @override
  ConsumerState<EmbeddedChatWidget> createState() => _EmbeddedChatWidgetState();
}

class _EmbeddedChatWidgetState extends ConsumerState<EmbeddedChatWidget> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  bool loading = false;
  final List<EmbeddedChatMessage> messages = [];

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _selectPromptTemplate(String template) {
    controller.text = template;
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _ask([String? customPrompt]) async {
    final rawQuestion = (customPrompt ?? controller.text).trim();
    if (rawQuestion.isEmpty || loading) return;

    // Auto-scope question with subject code if available
    final subjectCode = widget.subjectCode;
    final scopedQuery = (subjectCode != null &&
            !rawQuestion.toLowerCase().contains(subjectCode.toLowerCase()))
        ? '$subjectCode $rawQuestion'
        : rawQuestion;

    controller.clear();
    setState(() {
      messages.add(EmbeddedChatMessage(text: rawQuestion, isUser: true));
      loading = true;
    });
    _scrollToBottom();

    try {
      final context = await ref
          .read(retrievalServiceProvider)
          .retrieve(scopedQuery);
      final settings =
          await ref.read(keyStorageServiceProvider).readSettings();
      final apiKey =
          await ref.read(keyStorageServiceProvider).readApiKey() ?? '';

      final response = await ref
          .read(llmServiceProvider)
          .answer(
            apiKey: apiKey,
            baseUrl: settings.baseUrl,
            model: settings.model,
            question: scopedQuery,
            context: context,
          );

      if (!mounted) return;
      setState(() {
        messages.add(
          EmbeddedChatMessage(
            text: response,
            isUser: false,
            sources: context,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi phản hồi: $error'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectCode = widget.subjectCode;

    final suggestions = subjectCode != null
        ? [
            'Môn $subjectCode có mấy tín chỉ?',
            'Cách tính điểm môn $subjectCode?',
            'Điều kiện tiên quyết môn $subjectCode?',
            'Nếu rớt $subjectCode sẽ bị khóa môn nào?',
            'Nội dung các buổi học môn $subjectCode?',
          ]
        : [
            'Môn ... có mấy tín chỉ?',
            'Cách tính điểm môn ...?',
            'Điều kiện tiên quyết môn ...?',
            'Nếu rớt môn ... sẽ bị khóa môn nào?',
          ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSidebar : AppColors.lightSidebar,
        border: Border(
          left: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Embedded Chat Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2638)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF0284C7),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            subjectCode != null
                                ? 'Hỏi AI môn '
                                : 'AI Assistant ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (subjectCode != null)
                            BadgeTag(
                              label: subjectCode,
                              style: BadgeStyle.cyan,
                              fontSize: 11,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subjectCode != null
                            ? 'Tự động lấy dữ liệu từ $subjectCode'
                            : 'Vui lòng chọn môn hoặc nhập mã môn',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Messages List / Empty State
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 40,
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            subjectCode != null
                                ? 'Hỏi bất kỳ điều gì về môn $subjectCode'
                                : 'Nhập câu hỏi để bắt đầu',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subjectCode != null
                                ? 'Hệ thống tự động lọc nguồn từ $subjectCode'
                                : 'Chọn gợi ý bên dưới để tạo mẫu câu hỏi',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = messages[index];
                      return _EmbeddedMessageBubble(message: item);
                    },
                  ),
          ),

          if (loading) ...[
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: AppColors.primaryIndigo,
            ),
          ],

          // Quick Suggestion Chips Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final suggestion in suggestions) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        child: InkWell(
                          onTap: loading
                              ? null
                              : () => _selectPromptTemplate(suggestion),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Input Box
          Padding(
            padding: const EdgeInsets.all(12),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: subjectCode != null
                            ? 'Hỏi về môn $subjectCode...'
                            : 'Nhập câu hỏi...',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _ask(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: loading ? null : () => _ask(),
                    icon: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: AppColors.primaryIndigo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbeddedMessageBubble extends StatelessWidget {
  const _EmbeddedMessageBubble({required this.message});

  final EmbeddedChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2563EB) : const Color(0xFF1D4ED8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: AppColors.primaryCyan,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'FLM AI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryCyan,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            message.text,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFF0F172A),
            ),
          ),
          if (message.sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final src in message.sources.take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackground
                          : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${src.subjectCode} • ${src.section}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
