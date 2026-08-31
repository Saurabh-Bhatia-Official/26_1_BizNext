// lib/core/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

class SyncService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const String _baseUrl = "http://localhost:8000/api/v1";
  
  Timer? _syncTimer;
  bool _isSyncing = false;

  void startAutoSync(String token) {
    _syncTimer?.cancel();
    // Auto-sync every 60 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      syncNow(token);
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> syncNow(String token) async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      // if (kDebugMode) print("Starting background sync..."); // Suppress noisy starting log
      await pushLocalChanges(token);
      await pullRemoteChanges(token);
      // if (kDebugMode) print("Sync completed successfully."); // Suppress noisy success log
    } catch (e) {
      final errStr = e.toString();
      if (!errStr.contains("Failed to fetch") && !errStr.contains("Connection refused") && !errStr.contains("SocketException")) {
        if (kDebugMode) print("Sync failed: $e");
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> pushLocalChanges(String token) async {
    final queueItems = await _db.queryAll('sync_queue', orderBy: 'id ASC', limit: 100);
    if (queueItems.isEmpty) return;

    final records = queueItems.map((item) {
      Map<String, dynamic> payload = {};
      if (item['payload'] != null) {
        try {
          payload = jsonDecode(item['payload'] as String);
        } catch (_) {}
      }
      return {
        "table_name": item['table_name'],
        "record_id": item['record_id'],
        "operation": item['operation'],
        "payload": payload,
      };
    }).toList();

    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/sync/push"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"records": records}),
      );

      if (response.statusCode == 200) {
        // Clear successful records from sync_queue
        final idsToDelete = queueItems.map((item) => (item['id'] as num?)?.toInt()).whereType<int>().toList();
        for (final id in idsToDelete) {
          await _db.delete('sync_queue', id);
        }
      }
    } catch (e) {
      final errStr = e.toString();
      if (!errStr.contains("Failed to fetch") && !errStr.contains("Connection refused") && !errStr.contains("SocketException")) {
        if (kDebugMode) print("Push synchronization error: $e");
      }
      rethrow;
    }
  }

  Future<void> pullRemoteChanges(String token) async {
    // List of tables to pull updates for
    final tables = [
      'categories', 'products', 'customers', 'suppliers', 
      'sales', 'purchases', 'accounts', 'expenses', 'transactions',
      'offers', 'loyalty_settings', 'customer_discounts', 'product_discounts', 'app_settings'
    ];

    for (final table in tables) {
      try {
        final response = await http.get(
          Uri.parse("$_baseUrl/sync/pull?table_name=$table"),
          headers: {
            "Authorization": "Bearer $token",
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> remoteRecords = data['records'] ?? [];
          
          if (remoteRecords.isNotEmpty) {
            final db = await _db.database;
            await db.transaction((txn) async {
              for (final rec in remoteRecords) {
                final recId = rec['record_id'];
                final operation = rec['sync_operation'];
                
                // Clean system metadata out of record
                final Map<String, dynamic> cleanRecord = Map.from(rec)
                  ..remove('sync_operation')
                  ..remove('record_id');

                if (operation == 'DELETE') {
                  await txn.delete(table, where: 'id = ?', whereArgs: [recId]);
                } else {
                  // SQLite upsert block
                  final existing = await txn.query(table, where: 'id = ?', whereArgs: [recId]);
                  if (existing.isEmpty) {
                    await txn.insert(table, {...cleanRecord, 'id': recId});
                  } else {
                    await txn.update(table, cleanRecord, where: 'id = ?', whereArgs: [recId]);
                  }
                }
              }
            });
          }
        }
      } catch (e) {
        final errStr = e.toString();
        if (!errStr.contains("Failed to fetch") && !errStr.contains("Connection refused") && !errStr.contains("SocketException")) {
          if (kDebugMode) print("Pull sync error for table $table: $e");
        }
      }
    }
  }
}
