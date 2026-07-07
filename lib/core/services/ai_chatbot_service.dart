// lib/core/services/ai_chatbot_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import '../../features/ai_chatbot/models/chatbot_message.dart';

class AIChatbotService {
  static const String _model = 'gemini-1.5-flash';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// Sends a message and retrieves the model's response.
  /// If the model generates a SQL query, this function executes the query,
  /// passes the result back to the model, and returns the final natural language response.
  static Future<ChatbotMessage> sendMessage({
    required String prompt,
    required List<ChatbotMessage> history,
    required String apiKey,
    required int businessId,
  }) async {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    // ── Offline Demo Mode Fallback ──
    if (apiKey.trim().isEmpty) {
      return _generateDemoResponse(prompt, businessId);
    }

    try {
      // 1. Initial Prompt to Gemini: Ask it to answer or generate SQL
      final responseJson = await _callGemini(
        prompt: prompt,
        history: history,
        apiKey: apiKey,
        businessId: businessId,
        systemInstruction: _buildSystemInstruction(businessId),
      );

      final sql = responseJson['sql'] as String?;
      final initialResponse = responseJson['response'] as String? ?? '';

      if (sql == null || sql.trim().isEmpty) {
        // No SQL needed, direct response
        return ChatbotMessage(
          id: messageId,
          text: initialResponse,
          isUser: false,
          timestamp: DateTime.now(),
          status: MessageStatus.success,
        );
      }

      // Check for SQL safety (Only allow SELECT queries)
      final sqlLower = sql.toLowerCase().trim();
      if (!sqlLower.startsWith('select')) {
        return ChatbotMessage(
          id: messageId,
          text: "I generated a query, but it contains unauthorized operations. For security, only search/select queries are allowed.",
          isUser: false,
          timestamp: DateTime.now(),
          sqlQuery: sql,
          status: MessageStatus.error,
          errorMessage: "Security violation: Non-SELECT query generated.",
        );
      }

      // 2. Execute SQL query on local SQLite database
      List<Map<String, dynamic>> queryResultList = [];
      String queryResultStr = '';
      try {
        final db = await DatabaseHelper.instance.database;
        queryResultList = await db.rawQuery(sql);
        queryResultStr = jsonEncode(queryResultList);
      } catch (dbError) {
        if (kDebugMode) print("DB Error: $dbError");
        return ChatbotMessage(
          id: messageId,
          text: "I attempted to search the database but encountered an error processing the query.",
          isUser: false,
          timestamp: DateTime.now(),
          sqlQuery: sql,
          status: MessageStatus.error,
          errorMessage: dbError.toString(),
        );
      }

      // 3. Second call to Gemini: Give it the SQL query results to format into text
      final updatedHistory = [
        ...history,
        ChatbotMessage(
          id: 'temp_user',
          text: prompt,
          isUser: true,
          timestamp: DateTime.now(),
        ),
        ChatbotMessage(
          id: 'temp_model_sql',
          text: jsonEncode(responseJson),
          isUser: false,
          timestamp: DateTime.now(),
          sqlQuery: sql,
        ),
      ];

      final sqlResultPrompt = "The SQL query executed successfully. Result data: $queryResultStr. Please write a natural language summary explaining these results to the business owner. Keep it friendly and concise.";
      
      final finalResponseJson = await _callGemini(
        prompt: sqlResultPrompt,
        history: updatedHistory,
        apiKey: apiKey,
        businessId: businessId,
        systemInstruction: _buildSystemInstruction(businessId),
        forceTextResponse: true,
      );

      final finalText = finalResponseJson['response'] as String? ?? "Here are the query results: $queryResultStr";

      return ChatbotMessage(
        id: messageId,
        text: finalText,
        isUser: false,
        timestamp: DateTime.now(),
        sqlQuery: sql,
        queryResult: "Found ${queryResultList.length} rows.\nPreview: ${queryResultStr.length > 300 ? '${queryResultStr.substring(0, 300)}...' : queryResultStr}",
        status: MessageStatus.success,
      );

    } catch (e) {
      if (kDebugMode) print("Gemini Service Error: $e");
      return ChatbotMessage(
        id: messageId,
        text: "I'm having trouble communicating with the AI service. Please check your network connection or verify your API key.",
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Direct API Call to Gemini
  static Future<Map<String, dynamic>> _callGemini({
    required String prompt,
    required List<ChatbotMessage> history,
    required String apiKey,
    required int businessId,
    required String systemInstruction,
    bool forceTextResponse = false,
  }) async {
    final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');
    
    // Format conversation history for Gemini
    final List<Map<String, dynamic>> contents = [];

    for (final msg in history) {
      // Map message status and format appropriately
      String msgText = msg.text;
      if (msg.sqlQuery != null && !msg.isUser) {
        // If it was a SQL generation message, mock the JSON structure it sent
        msgText = jsonEncode({
          'sql': msg.sqlQuery,
          'response': msg.text,
        });
      }
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msgText}
        ]
      });
    }

    // Add current user prompt
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ]
    });

    final body = {
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'generationConfig': {
        'temperature': 0.1, // low temperature for precise SQL generation
        if (!forceTextResponse) 'responseMimeType': 'application/json',
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final errBody = jsonDecode(response.body);
      final errMsg = errBody['error']?['message'] ?? 'Status Code ${response.statusCode}';
      throw Exception(errMsg);
    }

    final responseBody = jsonDecode(response.body);
    final responseText = responseBody['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;

    if (responseText == null || responseText.isEmpty) {
      throw Exception("Empty response from AI model.");
    }

    if (forceTextResponse) {
      return {'sql': null, 'response': responseText};
    }

    try {
      return jsonDecode(responseText) as Map<String, dynamic>;
    } catch (e) {
      // If JSON parsing failed, return it as plain text response
      return {'sql': null, 'response': responseText};
    }
  }

  /// System instruction defining the DB schema & guidelines
  static String _buildSystemInstruction(int businessId) {
    return '''
You are "BizNext AI", a helpful, database-aware business assistant.
Your task is to assist the business owner by explaining accounting concepts, analyzing wallet/account balances, or generating SQLite queries to look up local account/ledger information.

CRITICAL SCOPE RULE:
- You must ONLY consider and query financial accounts, wallets, cash balances, and accounting transaction/ledger data.
- Do NOT query or reference products, inventory, customers, suppliers, or sales tables.
- If the user asks about products, sales, customers, suppliers, or inventory, politely inform them that you are configured to only assist with financial accounts, wallet balances, and transaction history.

The SQLite database tables and columns available are:
1. accounts (id, business_id, name, type, opening_balance, balance, account_number, is_default)
2. transactions (id, business_id, category_id, type, amount, description, payment_mode, date) -- type: 'credit' or 'debit'

CRITICAL SAFETY & CORRECTNESS RULES:
- The current active business ID is: $businessId.
- ALWAYS filter all SQL queries with "business_id = $businessId". 
- ONLY write SELECT queries. Do not write INSERT, UPDATE, DELETE, or DROP.
- Date format is YYYY-MM-DD HH:MM:SS (standard SQLite string dates). Use `date(date) = date('now')` for today's queries.
- Return a JSON object with two fields: "sql" and "response".
  - If a SQL database lookup is required, write the query in the "sql" field and explain what you are searching for in the "response" field.
  - If it is a conversational message, set "sql" to null and put your direct answer in the "response" field.

JSON Response Format Example 1 (Database query required):
{
  "sql": "SELECT name, balance FROM accounts WHERE business_id = $businessId",
  "response": "Let me look up your current wallet and account balances..."
}

JSON Response Format Example 2 (Direct advice):
{
  "sql": null,
  "response": "Hello! How can I help you manage your financial accounts today?"
}
''';
  }

  /// offline Demo Response generator
  static ChatbotMessage _generateDemoResponse(String prompt, int businessId) {
    final query = prompt.toLowerCase();
    String? sql;
    String? result;
    String text = '';

    if (query.contains('balance') || query.contains('account') || query.contains('wallet') || query.contains('bank')) {
      sql = 'SELECT name, balance FROM accounts WHERE business_id = $businessId';
      result = '[{"name": "Main Bank Account", "balance": 45000.00}, {"name": "Cash Wallet", "balance": 12500.00}]';
      text = "*(Demo Offline Mode)*\nI simulated a query on your financial accounts and found these balances:\n\n"
          "* **Main Bank Account**: ₹45,000.00\n"
          "* **Cash Wallet**: ₹12,500.00\n\n"
          "Your total available cash across these accounts is **₹57,500.00**.";
    } else if (query.contains('transaction') || query.contains('history') || query.contains('credit') || query.contains('debit')) {
      sql = "SELECT type, amount, description, date FROM transactions WHERE business_id = $businessId ORDER BY date DESC LIMIT 3";
      result = '[{"type": "debit", "amount": 1200.00, "description": "Office Supplies", "date": "2026-07-07 10:30:00"}, {"type": "credit", "amount": 8500.00, "description": "Invoice Payment", "date": "2026-07-07 09:15:00"}]';
      text = "*(Demo Offline Mode)*\nHere are your recent account ledger transactions:\n\n"
          "* **Credit**: ₹8,500.00 (Invoice Payment)\n"
          "* **Debit**: ₹1,200.00 (Office Supplies)\n\n"
          "These transactions were processed today.";
    } else if (query.contains('stock') || query.contains('inventory') || query.contains('product') || query.contains('sale') || query.contains('customer') || query.contains('supplier')) {
      text = "Hello! I am your BizNext AI Assistant. Please note that I am configured to only assist with financial accounts, wallet balances, and transaction history. I cannot query or look up inventory, products, sales invoices, or client list details.";
    } else if (query.contains('hello') || query.contains('hi') || query.contains('hey') || query.contains('who')) {
      text = "Hello! I am your BizNext AI Assistant. I can help you check wallet balances, view transaction history, or query cash levels.\n\n"
          "👉 *I am currently running in **Offline Demo Mode***. Try asking me about \"account balances\" or \"recent transactions\" to see it in action!\n\n"
          "To query your actual live store database, please add a free Gemini API Key by clicking the **API Key** button in the top right.";
    } else {
      text = "*(Demo Offline Mode)*\nI received your message: \"$prompt\"\n\n"
          "I am configured to only assist with financial accounts, wallet balances, and ledger transaction history. "
          "Try asking me about \"account balances\" or \"recent transactions\" to see my database query generation.\n\n"
          "To enable live database lookups, please paste your Gemini API Key in the top-right settings.";
    }

    return ChatbotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      sqlQuery: sql,
      queryResult: result,
      status: MessageStatus.success,
    );
  }
}
