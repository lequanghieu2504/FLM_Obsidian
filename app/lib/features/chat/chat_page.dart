import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/badge_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/chat_history.dart';
import '../../models/search_result.dart';
import '../../repositories/providers.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
  });

  final String text;
  final bool isUser;
  final List<SearchResult> sources;
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final focusNode = FocusNode();
  bool loading = false;
  final List<ChatMessage> messages = [];
  List<Conversation> conversations = [];
  String? selectedConversationId;
  bool historyLoading = true;

  void _selectPromptTemplate(String template) {
    controller.text = template;
    focusNode.requestFocus();
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final loaded = await ref
          .read(chatHistoryRepositoryProvider)
          .getConversations();
      if (!mounted) return;
      setState(() {
        conversations = loaded;
        historyLoading = false;
      });
      if (loaded.isNotEmpty) await _openConversation(loaded.first.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => historyLoading = false);
      _showError('Could not load local chat history: $error');
    }
  }

  Future<void> _refreshConversations() async {
    final loaded = await ref
        .read(chatHistoryRepositoryProvider)
        .getConversations();
    if (mounted) setState(() => conversations = loaded);
  }

  Future<void> _openConversation(String id) async {
    if (loading) return;
    setState(() {
      selectedConversationId = id;
      historyLoading = true;
    });
    try {
      final stored = await ref
          .read(chatHistoryRepositoryProvider)
          .getMessages(id);
      if (!mounted || selectedConversationId != id) return;
      setState(() {
        messages
          ..clear()
          ..addAll(
            stored.map(
              (message) => ChatMessage(
                text: message.content,
                isUser: message.isUser,
                sources: message.sources,
              ),
            ),
          );
        historyLoading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() => historyLoading = false);
      _showError('Could not open conversation: $error');
    }
  }

  void _newChat() {
    if (loading) return;
    setState(() {
      selectedConversationId = null;
      messages.clear();
    });
    controller.clear();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.dispose();
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
    final question = (customPrompt ?? controller.text).trim();
    if (question.isEmpty || loading) {
      return;
    }

    try {
      final repository = ref.read(chatHistoryRepositoryProvider);
      var conversationId = selectedConversationId;
      if (conversationId == null) {
        final conversation = await repository.createConversation(question);
        conversationId = conversation.id;
        if (!mounted) return;
        setState(() => selectedConversationId = conversation.id);
      }
      await repository.addMessage(
        conversationId: conversationId,
        role: 'user',
        content: question,
      );
      if (!mounted) return;
      controller.clear();
      setState(() {
        messages.add(ChatMessage(text: question, isUser: true));
        loading = true;
      });
      await _refreshConversations();
      _scrollToBottom();

      final context = await ref
          .read(retrievalServiceProvider)
          .retrieve(question);
      final settings = await ref.read(keyStorageServiceProvider).readSettings();
      final apiKey =
          await ref.read(keyStorageServiceProvider).readApiKey() ?? '';

      final response = await ref
          .read(llmServiceProvider)
          .answer(
            apiKey: apiKey,
            baseUrl: settings.baseUrl,
            model: settings.model,
            question: question,
            context: context,
          );

      final assistant = await repository.addMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: response,
        sources: context,
      );

      if (!mounted) return;
      setState(() {
        messages.add(
          ChatMessage(
            text: assistant.content,
            isUser: false,
            sources: assistant.sources,
          ),
        );
      });
      await _refreshConversations();
    } catch (error) {
      if (!mounted) return;
      _showError(
        'Error generating response: $error. Verify your LLM settings and API key.',
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    if (loading) return;
    await ref
        .read(chatHistoryRepositoryProvider)
        .deleteConversation(conversation.id);
    if (selectedConversationId == conversation.id) _newChat();
    await _refreshConversations();
  }

  Future<void> _clearAllHistory() async {
    if (loading || conversations.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This permanently deletes every local conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(chatHistoryRepositoryProvider).clearAll();
    _newChat();
    await _refreshConversations();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        SizedBox(width: 230, child: _buildHistorySidebar(context)),
        const VerticalDivider(width: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'BYOK AI Assistant',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(width: 10),
                            BadgeTag(
                              label: 'RAG Powered',
                              style: BadgeStyle.emerald,
                              icon: Icons.auto_awesome_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ask questions about course syllabi using your custom LLM API key and local database context.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: loading ? null : _newChat,
                      icon: const Icon(Icons.add_comment_outlined, size: 16),
                      label: const Text('New Chat'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Message Stream Area
                Expanded(
                  child: historyLoading
                      ? const Center(child: CircularProgressIndicator())
                      : messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: AppColors.crystalGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryViolet.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Hỏi bất kỳ thông tin nào từ dữ liệu FLM',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Chọn một câu hỏi gợi ý bên dưới hoặc nhập câu hỏi của bạn vào ô chat.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Starter Prompts Grid
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  _PromptChip(
                                    icon: Icons.numbers_rounded,
                                    label: 'Môn ... có mấy tín chỉ?',
                                    onTap: () => _selectPromptTemplate(
                                      'Môn ... có mấy tín chỉ?',
                                    ),
                                  ),
                                  _PromptChip(
                                    icon: Icons.calculate_rounded,
                                    label:
                                        'Cách tính điểm môn ... như thế nào?',
                                    onTap: () => _selectPromptTemplate(
                                      'Cách tính điểm môn ... như thế nào?',
                                    ),
                                  ),
                                  _PromptChip(
                                    icon: Icons.link_rounded,
                                    label:
                                        'Môn ... có yêu cầu điều kiện tiên quyết gì không?',
                                    onTap: () => _selectPromptTemplate(
                                      'Môn ... có yêu cầu điều kiện tiên quyết gì không?',
                                    ),
                                  ),
                                  _PromptChip(
                                    icon: Icons.warning_amber_rounded,
                                    label:
                                        'Nếu rớt môn ... thì các kỳ sau sẽ không được học những môn nào?',
                                    onTap: () => _selectPromptTemplate(
                                      'Nếu rớt môn ... thì các kỳ sau sẽ không được học những môn nào?',
                                    ),
                                  ),
                                  _PromptChip(
                                    icon: Icons.menu_book_rounded,
                                    label:
                                        'Nội dung học môn ... gồm những phần nào?',
                                    onTap: () => _selectPromptTemplate(
                                      'Nội dung học môn ... gồm những phần nào?',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: messages.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return _ChatMessageTile(message: message);
                          },
                        ),
                ),

                if (loading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    color: AppColors.primaryViolet,
                  ),
                ],

                const SizedBox(height: 12),

                // Quick Suggestions Bar
                _buildQuickSuggestionsBar(context),

                const SizedBox(height: 10),

                // Bottom Input Controls Container
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Nhập câu hỏi của bạn về môn học, syllabus, tín chỉ, điểm số...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _ask(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: loading ? null : () => _ask(),
                        icon: const Icon(Icons.send_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSuggestionsBar(BuildContext context) {
    final suggestions = [
      'Môn ... có mấy tín chỉ?',
      'Cách tính điểm môn ...?',
      'Điều kiện tiên quyết môn ...?',
      'Nếu rớt môn ... sẽ bị khóa môn nào?',
      'Nội dung học môn ...?',
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tips_and_updates_rounded,
                  size: 15,
                  color: AppColors.primaryViolet,
                ),
                const SizedBox(width: 4),
                Text(
                  'Gợi ý:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          for (final suggestion in suggestions) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                label: Text(
                  suggestion,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF334155),
                  ),
                ),
                backgroundColor: isDark
                    ? AppColors.darkCard
                    : AppColors.lightCard,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onPressed: loading ? null : () => _selectPromptTemplate(suggestion),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorySidebar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: loading ? null : _newChat,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Chat'),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'LOCAL HISTORY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: historyLoading && conversations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : conversations.isEmpty
                ? const Center(
                    child: Text(
                      'No conversations yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return ListTile(
                        dense: true,
                        selected: conversation.id == selectedConversationId,
                        contentPadding: const EdgeInsets.only(left: 10),
                        title: Text(
                          conversation.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete conversation',
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: loading
                              ? null
                              : () => _deleteConversation(conversation),
                        ),
                        onTap: loading
                            ? null
                            : () => _openConversation(conversation.id),
                      );
                    },
                  ),
          ),
          TextButton.icon(
            onPressed: loading || conversations.isEmpty
                ? null
                : _clearAllHistory,
            icon: const Icon(Icons.delete_sweep_outlined, size: 17),
            label: const Text('Clear all history'),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 20,
      hoverable: true,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryViolet),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (message.isUser) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryViolet.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SelectableText(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primaryViolet,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      );
    }

    // Assistant Response Tile
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppColors.cyanGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryCyan.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FLM Assistant',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryCyan,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy answer',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Answer copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                SelectableText(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF0F172A),
                  ),
                ),

                // Sources References Accordion / Chips
                if (message.sources.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Row(
                    children: [
                      Icon(
                        Icons.library_books_rounded,
                        size: 14,
                        color: AppColors.primaryViolet,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Retrieved Context Sources',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final source in message.sources)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBackground
                                : AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BadgeTag(
                                label: source.subjectCode,
                                style: BadgeStyle.cyan,
                                fontSize: 10,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                source.section,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
