// lib/features/ai_chatbot/screens/chatbot_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/chatbot_message.dart';
import '../providers/chatbot_provider.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    ref.read(chatbotProvider.notifier).sendMessage(text);
    _focusNode.requestFocus();
    
    // Scroll down after frame layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _sendSuggestion(String suggestion) {
    ref.read(chatbotProvider.notifier).sendMessage(suggestion);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;

    // Trigger auto-scroll on list update
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // ── Header Panel ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "BizNext AI Assistant",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Local NLP Mode",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      tooltip: "Clear History",
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : AppColors.error.withValues(alpha: 0.08),
                        foregroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            title: const Text("Clear chat history?"),
                            content: const Text("This will permanently clear your conversation with the AI."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  ref.read(chatbotProvider.notifier).clearHistory();
                                  Navigator.of(ctx).pop();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                child: const Text("Clear"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Messages Area ──
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: state.messages.isEmpty
                      ? const Center(
                          child: Text(
                            "No messages yet. Say hello!",
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: state.messages.length + (state.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == state.messages.length) {
                              return const _TypingIndicatorBubble()
                                  .animate()
                                  .fade(duration: 150.ms);
                            }
                            final msg = state.messages[index];
                            return _ChatBubble(message: msg)
                                .animate()
                                .fade(duration: 200.ms)
                                .slideY(begin: 0.1, curve: Curves.easeOut);
                          },
                        ),
                ),
              ),

              // ── Suggestions & Input Area ──
              const SizedBox(height: 12),
              
              // Only show suggestions when NOT loading
              if (!state.isLoading && state.messages.length <= 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SuggestionChip(
                          label: "Stock Levels",
                          icon: Icons.inventory_2_rounded,
                          onTap: () => _sendSuggestion("Which products are low in stock?"),
                        ),
                        _SuggestionChip(
                          label: "Today's Sales",
                          icon: Icons.monetization_on_rounded,
                          onTap: () => _sendSuggestion("What was my revenue today?"),
                        ),
                        _SuggestionChip(
                          label: "Top Customers",
                          icon: Icons.star_rounded,
                          onTap: () => _sendSuggestion("Who is my top customer by balance?"),
                        ),
                        _SuggestionChip(
                          label: "Net vs Gross",
                          icon: Icons.help_outline_rounded,
                          onTap: () => _sendSuggestion("Explain the difference between net and gross profit."),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Input Bar ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Ask AI Assistant about stock, sales, concepts...",
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                    Material(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _sendMessage,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 14, color: AppColors.primary),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onTap,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.primary.withValues(alpha: 0.05),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.primary.withValues(alpha: 0.12),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final ChatbotMessage message;

  const _ChatBubble({required this.message});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  bool _showSqlDetails = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = widget.message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 12, top: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : AppColors.primary.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : AppColors.primary.withValues(alpha: 0.1),
                          ),
                  ),
                  child: _buildFormattedText(widget.message.text, context, isUser),
                ),
              ),
            ],
          ),

          // ── SQL / Database Query Details ──
          if (widget.message.sqlQuery != null && !isUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 44.0, top: 6),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showSqlDetails = !_showSqlDetails;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        size: 13,
                        color: widget.message.status == MessageStatus.error
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.message.status == MessageStatus.error
                            ? "Database Query Failed"
                            : "Local SQL Executed",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: widget.message.status == MessageStatus.error
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showSqlDetails
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showSqlDetails)
              Container(
                margin: const EdgeInsets.only(left: 44.0, top: 6, right: 20),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C0C15) : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "GENERATED SQL:",
                      style: TextStyle(
                        fontFamily: "monospace",
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      widget.message.sqlQuery!,
                      style: TextStyle(
                        fontFamily: "monospace",
                        fontSize: 11,
                        color: isDark ? Colors.amber[200] : Colors.blue[800],
                        height: 1.3,
                      ),
                    ),
                    if (widget.message.queryResult != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        "DATABASE RESPONSE SUMMARY:",
                        style: TextStyle(
                          fontFamily: "monospace",
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        widget.message.queryResult!,
                        style: TextStyle(
                          fontFamily: "monospace",
                          fontSize: 10.5,
                          color: isDark ? Colors.green[200] : Colors.green[800],
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (widget.message.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Error Details: ${widget.message.errorMessage}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fade(duration: 150.ms).slideY(begin: -0.05),
          ],
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, BuildContext context, bool isUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isUser ? Colors.white : (isDark ? AppColors.textDark : AppColors.textLight);
    final textStyle = TextStyle(
      fontSize: 13.5,
      height: 1.45,
      color: defaultColor,
      fontWeight: FontWeight.w500,
    );

    final List<String> lines = text.split('\n');
    final List<Widget> widgets = [];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Check if it's a bullet point
      final trimmed = line.trim();
      if (trimmed.startsWith('*') || trimmed.startsWith('-')) {
        final content = trimmed.substring(1).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: textStyle.copyWith(fontWeight: FontWeight.bold)),
                Expanded(
                  child: RichText(
                    text: _parseBoldText(content, textStyle),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RichText(
              text: _parseBoldText(line, textStyle),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  TextSpan _parseBoldText(String text, TextStyle baseStyle) {
    final parts = text.split('**');
    final List<TextSpan> spans = [];
    
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: part,
          style: baseStyle.copyWith(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      );
    }
    
    return TextSpan(children: spans);
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 12, top: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .scale(
          duration: 300.ms,
          delay: (index * 150).ms,
          begin: const Offset(1, 1),
          end: const Offset(1.5, 1.5),
        )
        .then()
        .scale(
          duration: 300.ms,
          begin: const Offset(1.5, 1.5),
          end: const Offset(1, 1),
        );
  }
}
