// lib/features/ai_chatbot/providers/chatbot_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/ai_chatbot_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chatbot_message.dart';

class ChatbotState {
  final List<ChatbotMessage> messages;
  final bool isLoading;

  const ChatbotState({
    this.messages = const [],
    this.isLoading = false,
  });

  ChatbotState copyWith({
    List<ChatbotMessage>? messages,
    bool? isLoading,
  }) {
    return ChatbotState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatbotNotifier extends StateNotifier<ChatbotState> {
  final SharedPreferences _prefs;
  final Ref _ref;

  static const String _prefChatHistory = 'chatbot_chat_history_local_v1';

  ChatbotNotifier(this._prefs, this._ref) : super(const ChatbotState()) {
    _loadState();
  }

  void _loadState() {
    final historyStr = _prefs.getString(_prefChatHistory);
    List<ChatbotMessage> history = [];

    if (historyStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyStr);
        history = decoded.map((item) => ChatbotMessage.fromJson(item)).toList();
      } catch (_) {
        // Safe fallback
      }
    }

    // Seed greeting if history is empty
    if (history.isEmpty) {
      history = [
        ChatbotMessage(
          id: 'greeting',
          text: "Hello! I am your completely local BizNext AI Assistant. Ask me anything about your sales, inventory, or account balances. All queries are processed securely on your device!",
          isUser: false,
          timestamp: DateTime.now(),
        )
      ];
    }

    state = ChatbotState(
      messages: history,
      isLoading: false,
    );
  }

  Future<void> clearHistory() async {
    final defaultGreeting = [
      ChatbotMessage(
        id: 'greeting',
        text: "Hello! I am your completely local BizNext AI Assistant. Ask me anything about your sales, inventory, or account balances. All queries are processed securely on your device!",
        isUser: false,
        timestamp: DateTime.now(),
      )
    ];
    await _prefs.remove(_prefChatHistory);
    state = state.copyWith(messages: defaultGreeting);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatbotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // 1. Add User Message
    final updatedMessages = [...state.messages, userMessage];
    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
    );
    _saveHistoryToPrefs(updatedMessages);

    final businessId = _ref.read(activeBusinessIdProvider);

    // 2. Call Local NLP Service to get Response
    final botResponse = await AIChatbotService.sendMessage(
      prompt: text,
      history: state.messages.where((m) => m.id != 'greeting').toList(),
      apiKey: 'local_nlp_mode', // Ignored now
      businessId: businessId,
    );

    // 3. Update State with Bot Response
    final finalMessages = [...state.messages, botResponse];
    state = state.copyWith(
      messages: finalMessages,
      isLoading: false,
    );
    _saveHistoryToPrefs(finalMessages);
  }

  void _saveHistoryToPrefs(List<ChatbotMessage> list) {
    try {
      final List<Map<String, dynamic>> raw = list.map((m) => m.toJson()).toList();
      _prefs.setString(_prefChatHistory, jsonEncode(raw));
    } catch (_) {
      // Safe ignore
    }
  }
}

final chatbotProvider = StateNotifierProvider<ChatbotNotifier, ChatbotState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ChatbotNotifier(prefs, ref);
});
