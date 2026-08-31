// lib/features/notifications/repositories/notification_repository.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/notification_item_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

class NotificationRepository {
  final DatabaseHelper _dbHelper;

  NotificationRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Fetches notifications for a business, sorted with unread and newest first.
  Future<List<NotificationItemModel>> getNotifications({
    required int businessId,
    bool? unreadOnly,
    String? type,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>['business_id = ?'];
    final whereArgs = <dynamic>[businessId];

    if (unreadOnly == true) {
      whereClauses.add('is_read = 0');
    }

    if (type != null && type.isNotEmpty && type != 'all') {
      whereClauses.add('type = ?');
      whereArgs.add(type);
    }

    final whereString = whereClauses.join(' AND ');

    final maps = await db.query(
      AppConstants.tblNotifications,
      where: whereString,
      whereArgs: whereArgs,
      orderBy: 'is_read ASC, timestamp DESC',
      limit: 100,
    );

    return maps.map((m) => NotificationItemModel.fromMap(m)).toList();
  }

  /// Returns count of unread notifications for a business.
  Future<int> getUnreadCount(int businessId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tblNotifications} WHERE business_id = ? AND is_read = 0',
      [businessId],
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// Inserts a notification into SQLite.
  Future<int> insertNotification(NotificationItemModel item) async {
    final db = await _dbHelper.database;
    final id = await db.insert(AppConstants.tblNotifications, item.toMap());
    _dbHelper.notify(AppConstants.tblNotifications);
    return id;
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(int notificationId) async {
    final db = await _dbHelper.database;
    await db.update(
      AppConstants.tblNotifications,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
    _dbHelper.notify(AppConstants.tblNotifications);
  }

  /// Marks all notifications as read for the business.
  Future<void> markAllAsRead(int businessId) async {
    final db = await _dbHelper.database;
    await db.update(
      AppConstants.tblNotifications,
      {'is_read': 1},
      where: 'business_id = ?',
      whereArgs: [businessId],
    );
    _dbHelper.notify(AppConstants.tblNotifications);
  }

  /// Deletes a specific notification.
  Future<void> deleteNotification(int notificationId) async {
    final db = await _dbHelper.database;
    await db.delete(
      AppConstants.tblNotifications,
      where: 'id = ?',
      whereArgs: [notificationId],
    );
    _dbHelper.notify(AppConstants.tblNotifications);
  }

  /// Clears all notifications for the business.
  Future<void> clearAll(int businessId) async {
    final db = await _dbHelper.database;
    await db.delete(
      AppConstants.tblNotifications,
      where: 'business_id = ?',
      whereArgs: [businessId],
    );
    _dbHelper.notify(AppConstants.tblNotifications);
  }

  /// Automated Smart Alert Scanner:
  /// Evaluates inventory stock thresholds, customer overdue dues, and sales records,
  /// generating smart notification alerts without duplicate spamming.
  Future<int> generateSmartAlerts(int businessId) async {
    final db = await _dbHelper.database;
    int generatedCount = 0;
    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(hours: 24)).toIso8601String();

    try {
      // 1. Scan Low Stock Products
      final lowStockProducts = await db.rawQuery('''
        SELECT id, name, stock, min_stock, unit 
        FROM ${AppConstants.tblProducts} 
        WHERE business_id = ? AND is_active = 1 AND (stock <= min_stock OR stock <= 0)
        LIMIT 20
      ''', [businessId]);

      for (final row in lowStockProducts) {
        final productId = (row['id'] as num?)?.toInt() ?? 0;
        final name = row['name'] as String? ?? 'Product';
        final stock = (row['stock'] as num?)?.toDouble() ?? 0.0;
        final minAlert = (row['min_stock'] as num?)?.toDouble() ?? 5.0;
        final unit = row['unit'] as String? ?? 'pcs';

        // Check if alert was already logged within 24h
        final existing = await db.rawQuery('''
          SELECT id FROM ${AppConstants.tblNotifications}
          WHERE business_id = ? AND type = 'low_stock' AND action_data = ? AND timestamp >= ?
          LIMIT 1
        ''', [businessId, '$productId', oneDayAgo]);

        if (existing.isEmpty) {
          final isOut = stock <= 0;
          await insertNotification(
            NotificationItemModel.now(
              businessId: businessId,
              title: isOut ? 'Out of Stock: $name' : 'Low Stock Warning: $name',
              message: isOut
                  ? 'Item "$name" is completely out of stock. Reorder immediately from your supplier.'
                  : 'Item "$name" has only ${stock.toInt()} $unit remaining (Threshold: ${minAlert.toInt()} $unit).',
              type: SystemNotificationType.lowStock,
              priority: isOut ? SystemNotificationPriority.urgent : SystemNotificationPriority.high,
              actionType: 'nav_inventory',
              actionData: '$productId',
              now: now,
            ),
          );
          generatedCount++;
        }
      }

      // 2. Scan Customer Overdue Balances
      final highDueCustomers = await db.rawQuery('''
        SELECT id, name, balance_due, phone
        FROM ${AppConstants.tblCustomers}
        WHERE business_id = ? AND balance_due > 500
        ORDER BY balance_due DESC
        LIMIT 10
      ''', [businessId]);

      for (final cust in highDueCustomers) {
        final customerId = (cust['id'] as num?)?.toInt() ?? 0;
        final custName = cust['name'] as String? ?? 'Customer';
        final balanceDue = (cust['balance_due'] as num?)?.toDouble() ?? 0.0;

        final existing = await db.rawQuery('''
          SELECT id FROM ${AppConstants.tblNotifications}
          WHERE business_id = ? AND type = 'due_payment' AND action_data = ? AND timestamp >= ?
          LIMIT 1
        ''', [businessId, '$customerId', oneDayAgo]);

        if (existing.isEmpty) {
          await insertNotification(
            NotificationItemModel.now(
              businessId: businessId,
              title: 'Pending Credit Due: $custName',
              message: 'Customer "$custName" has an outstanding balance of ₹${balanceDue.toStringAsFixed(2)}.',
              type: SystemNotificationType.duePayment,
              priority: balanceDue > 5000 ? SystemNotificationPriority.urgent : SystemNotificationPriority.medium,
              actionType: 'nav_customers',
              actionData: '$customerId',
              now: now,
            ),
          );
          generatedCount++;
        }
      }

      // 3. Scan System Welcome / Daily Check
      final totalNotifs = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.tblNotifications} WHERE business_id = ?',
        [businessId],
      );
      final count = (totalNotifs.first['count'] as num?)?.toInt() ?? 0;

      if (count == 0) {
        await insertNotification(
          NotificationItemModel.now(
            businessId: businessId,
            title: 'Welcome to Notifications Center',
            message: 'All your automated inventory alerts, customer payment dues, and system updates will appear here in real-time.',
            type: SystemNotificationType.system,
            priority: SystemNotificationPriority.low,
            now: now,
          ),
        );
        generatedCount++;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error running smart alerts scanner: $e');
      }
    }

    return generatedCount;
  }
}
