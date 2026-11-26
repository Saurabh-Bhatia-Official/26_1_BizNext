// lib/features/ai_chatbot/models/chatbot_message.dart

enum MessageStatus {
  sending,
  executingSql,
  success,
  error,
}

class ChatbotMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? sqlQuery;
  final String? queryResult;
  final MessageStatus status;
  final String? errorMessage;

  const ChatbotMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sqlQuery,
    this.queryResult,
    this.status = MessageStatus.success,
    this.errorMessage,
  });

  ChatbotMessage copyWith({
    String? text,
    MessageStatus? status,
    String? sqlQuery,
    String? queryResult,
    String? errorMessage,
  }) {
    return ChatbotMessage(
      id: id,
      text: text ?? this.text,
      isUser: isUser,
      timestamp: timestamp,
      sqlQuery: sqlQuery ?? this.sqlQuery,
      queryResult: queryResult ?? this.queryResult,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'sqlQuery': sqlQuery,
      'queryResult': queryResult,
      'status': status.name,
      'errorMessage': errorMessage,
    };
  }

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) {
    return ChatbotMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sqlQuery: json['sqlQuery'] as String?,
      queryResult: json['queryResult'] as String?,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.success,
      ),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
