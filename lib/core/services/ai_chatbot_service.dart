// lib/core/services/ai_chatbot_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../../features/ai_chatbot/models/chatbot_message.dart';
import 'package:intl/intl.dart';

class AIChatbotService {
  /// Processes a natural language prompt locally using regex/keyword matching
  /// and executes local database queries to formulate a response.
  static Future<ChatbotMessage> sendMessage({
    required String prompt,
    required List<ChatbotMessage> history,
    required String apiKey, // Kept for compatibility but ignored
    required int businessId,
  }) async {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final query = prompt.toLowerCase().trim();

    String? sql;
    String? resultStr;
    String textResponse = '';
    MessageStatus status = MessageStatus.success;

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Sales Intent
      if (query.contains('sale') || query.contains('sold') || query.contains('earnings')) {
        String dateFilter = '';
        String periodText = 'total';
        
        if (query.contains('today')) {
          dateFilter = "AND date(date) = date('now', 'localtime')";
          periodText = 'today';
        } else if (query.contains('month')) {
          dateFilter = "AND strftime('%Y-%m', date) = strftime('%Y-%m', 'now', 'localtime')";
          periodText = 'this month';
        } else if (query.contains('week')) {
          // Approximate week
          dateFilter = "AND date(date) >= date('now', '-7 days', 'localtime')";
          periodText = 'this past week';
        }

        sql = "SELECT SUM(grand_total) as total_sales, COUNT(id) as invoice_count FROM sale_history WHERE business_id = $businessId $dateFilter";
        
        final result = await db.rawQuery(sql);
        resultStr = jsonEncode(result);
        
        final totalSales = result.first['total_sales'] ?? 0.0;
        final count = result.first['invoice_count'] ?? 0;
        
        final formatter = NumberFormat.currency(symbol: '₹');
        textResponse = "Your $periodText sales amount to **${formatter.format(totalSales)}** across $count invoice(s).";
      }
      
      // 2. Account/Balance Intent
      else if (query.contains('balance') || query.contains('account') || query.contains('wallet') || query.contains('bank')) {
        sql = 'SELECT name, balance FROM accounts WHERE business_id = $businessId';
        final result = await db.rawQuery(sql);
        resultStr = jsonEncode(result);
        
        if (result.isEmpty) {
          textResponse = "You don't have any accounts set up yet.";
        } else {
          final formatter = NumberFormat.currency(symbol: '₹');
          textResponse = "Here are your current account balances:\n\n";
          double total = 0;
          for (var row in result) {
            final name = row['name'] as String;
            final bal = row['balance'] as double? ?? 0.0;
            total += bal;
            textResponse += "* **$name**: ${formatter.format(bal)}\n";
          }
          textResponse += "\nTotal Available: **${formatter.format(total)}**";
        }
      }
      
      // 3. Transactions Intent
      else if (query.contains('transaction') || query.contains('history') || query.contains('recent')) {
        sql = "SELECT type, amount, description, date FROM transactions WHERE business_id = $businessId ORDER BY date DESC LIMIT 5";
        final result = await db.rawQuery(sql);
        resultStr = jsonEncode(result);
        
        if (result.isEmpty) {
          textResponse = "You have no recent transactions.";
        } else {
          final formatter = NumberFormat.currency(symbol: '₹');
          textResponse = "Here are your most recent transactions:\n\n";
          for (var row in result) {
            final type = row['type'] as String;
            final amount = row['amount'] as double? ?? 0.0;
            final desc = row['description'] as String? ?? 'No description';
            
            final icon = type == 'credit' ? '🟢' : '🔴';
            textResponse += "$icon **${type.toUpperCase()}**: ${formatter.format(amount)} ($desc)\n";
          }
        }
      }

      // 4. Inventory Intent
      else if (query.contains('stock') || query.contains('inventory') || query.contains('product')) {
        sql = "SELECT name, stock FROM inventory WHERE business_id = $businessId ORDER BY stock ASC LIMIT 5";
        final result = await db.rawQuery(sql);
        resultStr = jsonEncode(result);
        
        if (result.isEmpty) {
          textResponse = "Your inventory is currently empty.";
        } else {
          textResponse = "Here are your items with the lowest stock levels:\n\n";
          for (var row in result) {
            final name = row['name'] as String;
            final stock = row['stock'] as num? ?? 0;
            
            textResponse += "* **$name**: $stock in stock\n";
          }
          textResponse += "\nConsider restocking items that are running low.";
        }
      }

      // 5. Greeting/Help
      else if (query.contains('hello') || query.contains('hi') || query.contains('help') || query.contains('what can you do')) {
        textResponse = "Hello! I am your local BizNext AI Assistant running entirely on-device. Your data is private and secure.\n\n"
            "You can ask me things like:\n"
            "👉 \"What are my sales for today?\"\n"
            "👉 \"Show me my account balances.\"\n"
            "👉 \"What are my recent transactions?\"\n"
            "👉 \"Check my inventory stock levels.\"";
      }
      
      // Unrecognized
      else {
        textResponse = "I'm sorry, I didn't quite catch that. Since I'm running locally, my vocabulary is currently limited to questions about:\n\n"
            "• **Sales** (e.g. 'sales today', 'total earnings')\n"
            "• **Accounts** (e.g. 'wallet balance', 'bank accounts')\n"
            "• **Transactions** (e.g. 'recent transactions')\n"
            "• **Inventory** (e.g. 'low stock', 'inventory')";
      }
      
    } catch (e) {
      if (kDebugMode) print("Local NLP DB Error: $e");
      textResponse = "I encountered an internal error while trying to process your request.";
      status = MessageStatus.error;
    }

    return ChatbotMessage(
      id: messageId,
      text: textResponse,
      isUser: false,
      timestamp: DateTime.now(),
      sqlQuery: sql,
      queryResult: resultStr != null && resultStr.length > 300 
          ? '${resultStr.substring(0, 300)}...' 
          : resultStr,
      status: status,
    );
  }
}
