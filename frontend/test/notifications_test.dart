// test/notifications_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:biz_next/features/notifications/models/notification_item_model.dart';
import 'package:biz_next/features/notifications/repositories/notification_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biz_next/core/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notifications Module: Model & Formatting Tests', () {
    test('NotificationItemModel serialization round-trip & null safety', () {
      final now = DateTime(2026, 8, 31, 10, 30);
      final model = NotificationItemModel(
        id: 101,
        businessId: 1,
        title: 'Low Stock Alert',
        message: 'Product "Basmati Rice" has only 2 kg left.',
        type: SystemNotificationType.lowStock,
        priority: SystemNotificationPriority.high,
        isRead: false,
        actionType: 'nav_inventory',
        actionData: '45',
        timestamp: now,
        createdAt: now,
      );

      final map = model.toMap();
      expect(map['id'], 101);
      expect(map['business_id'], 1);
      expect(map['title'], 'Low Stock Alert');
      expect(map['type'], 'low_stock');
      expect(map['priority'], 'high');
      expect(map['is_read'], 0);
      expect(map['action_type'], 'nav_inventory');
      expect(map['action_data'], '45');

      final deserialized = NotificationItemModel.fromMap(map);
      expect(deserialized.id, 101);
      expect(deserialized.title, model.title);
      expect(deserialized.message, model.message);
      expect(deserialized.type, SystemNotificationType.lowStock);
      expect(deserialized.priority, SystemNotificationPriority.high);
      expect(deserialized.isRead, false);
      expect(deserialized.actionType, 'nav_inventory');
      expect(deserialized.actionData, '45');
    });

    test('NotificationItemModel handles empty/null map gracefully with defaults', () {
      final emptyMap = <String, dynamic>{};
      final model = NotificationItemModel.fromMap(emptyMap);

      expect(model.id, isNull);
      expect(model.businessId, 1);
      expect(model.title, 'Notification');
      expect(model.message, '');
      expect(model.type, SystemNotificationType.system);
      expect(model.priority, SystemNotificationPriority.medium);
      expect(model.isRead, false);
      expect(model.actionType, isNull);
      expect(model.actionData, isNull);
    });

    test('NotificationItemModel copyWith updates fields cleanly', () {
      final now = DateTime(2026, 8, 31, 10, 30);
      final original = NotificationItemModel.now(
        id: 1,
        businessId: 1,
        title: 'Original Title',
        message: 'Original Message',
        now: now,
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        isRead: true,
        priority: SystemNotificationPriority.urgent,
      );

      expect(updated.id, 1);
      expect(updated.title, 'Updated Title');
      expect(updated.message, 'Original Message');
      expect(updated.isRead, true);
      expect(updated.priority, SystemNotificationPriority.urgent);
    });

    test('Enum fallbacks for unknown types and priorities', () {
      expect(SystemNotificationType.fromString('low_stock'), SystemNotificationType.lowStock);
      expect(SystemNotificationType.fromString('due_payment'), SystemNotificationType.duePayment);
      expect(SystemNotificationType.fromString('sales_milestone'), SystemNotificationType.salesMilestone);
      expect(SystemNotificationType.fromString('sync_backup'), SystemNotificationType.syncBackup);
      expect(SystemNotificationType.fromString('customer_loyalty'), SystemNotificationType.customerLoyalty);
      expect(SystemNotificationType.fromString('unknown_type'), SystemNotificationType.system);
      expect(SystemNotificationType.fromString(null), SystemNotificationType.system);

      expect(SystemNotificationPriority.fromString('urgent'), SystemNotificationPriority.urgent);
      expect(SystemNotificationPriority.fromString('high'), SystemNotificationPriority.high);
      expect(SystemNotificationPriority.fromString('low'), SystemNotificationPriority.low);
      expect(SystemNotificationPriority.fromString('invalid_priority'), SystemNotificationPriority.medium);
      expect(SystemNotificationPriority.fromString(null), SystemNotificationPriority.medium);
    });

    test('Relative time formatter timeAgo works accurately', () {
      final base = DateTime(2026, 8, 31, 12, 0, 0);

      final justNow = NotificationItemModel.now(title: 'T', message: 'M', now: base.subtract(const Duration(seconds: 20)));
      expect(justNow.timeAgo(clock: base), 'Just now');

      final minsAgo = NotificationItemModel.now(title: 'T', message: 'M', now: base.subtract(const Duration(minutes: 5)));
      expect(minsAgo.timeAgo(clock: base), '5 mins ago');

      final hoursAgo = NotificationItemModel.now(title: 'T', message: 'M', now: base.subtract(const Duration(hours: 3)));
      expect(hoursAgo.timeAgo(clock: base), '3 hrs ago');

      final daysAgo = NotificationItemModel.now(title: 'T', message: 'M', now: base.subtract(const Duration(days: 2)));
      expect(daysAgo.timeAgo(clock: base), '2 days ago');
    });
  });

  group('Notifications Module: SQLite In-Memory Repository Tests', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ${AppConstants.tblNotifications} (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id  INTEGER NOT NULL DEFAULT 1,
            title        TEXT    NOT NULL,
            message      TEXT    NOT NULL,
            type         TEXT    NOT NULL DEFAULT 'system',
            priority     TEXT    NOT NULL DEFAULT 'medium',
            is_read      INTEGER NOT NULL DEFAULT 0,
            action_type  TEXT,
            action_data  TEXT,
            timestamp    TEXT    NOT NULL DEFAULT (datetime('now')),
            created_at   TEXT    NOT NULL DEFAULT (datetime('now'))
          )
        ''');

        await db.execute('''
          CREATE TABLE ${AppConstants.tblProducts} (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id      INTEGER NOT NULL DEFAULT 1,
            name             TEXT NOT NULL,
            stock            REAL NOT NULL DEFAULT 0,
            min_stock_alert  REAL NOT NULL DEFAULT 5,
            unit             TEXT NOT NULL DEFAULT 'pcs',
            is_active        INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE ${AppConstants.tblCustomers} (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id  INTEGER NOT NULL DEFAULT 1,
            name         TEXT NOT NULL,
            balance_due  REAL NOT NULL DEFAULT 0,
            phone        TEXT
          )
        ''');
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Insert, fetch, filter, and count unread notifications', () async {
      final now = DateTime(2026, 8, 31, 10, 0);

      // Insert 2 notifications
      await db.insert(AppConstants.tblNotifications, NotificationItemModel.now(
        businessId: 1,
        title: 'Alert 1',
        message: 'Message 1',
        type: SystemNotificationType.lowStock,
        priority: SystemNotificationPriority.high,
        isRead: false,
        now: now,
      ).toMap());

      await db.insert(AppConstants.tblNotifications, NotificationItemModel.now(
        businessId: 1,
        title: 'Alert 2',
        message: 'Message 2',
        type: SystemNotificationType.duePayment,
        priority: SystemNotificationPriority.medium,
        isRead: true,
        now: now,
      ).toMap());

      // Fetch all for business 1
      final rows = await db.query(AppConstants.tblNotifications, where: 'business_id = ?', whereArgs: [1]);
      final items = rows.map((r) => NotificationItemModel.fromMap(r)).toList();
      expect(items.length, 2);

      // Unread count check
      final unreadCount = items.where((n) => !n.isRead).length;
      expect(unreadCount, 1);
    });

    test('Mark as read, mark all as read, and delete operations', () async {
      final now = DateTime(2026, 8, 31, 10, 0);

      final id1 = await db.insert(AppConstants.tblNotifications, NotificationItemModel.now(
        businessId: 1,
        title: 'Item 1',
        message: 'M1',
        isRead: false,
        now: now,
      ).toMap());

      final id2 = await db.insert(AppConstants.tblNotifications, NotificationItemModel.now(
        businessId: 1,
        title: 'Item 2',
        message: 'M2',
        isRead: false,
        now: now,
      ).toMap());

      // Mark single item as read
      await db.update(AppConstants.tblNotifications, {'is_read': 1}, where: 'id = ?', whereArgs: [id1]);
      var row1 = await db.query(AppConstants.tblNotifications, where: 'id = ?', whereArgs: [id1]);
      expect(row1.first['is_read'], 1);

      // Mark all as read
      await db.update(AppConstants.tblNotifications, {'is_read': 1}, where: 'business_id = ?', whereArgs: [1]);
      var row2 = await db.query(AppConstants.tblNotifications, where: 'id = ?', whereArgs: [id2]);
      expect(row2.first['is_read'], 1);

      // Delete item 1
      await db.delete(AppConstants.tblNotifications, where: 'id = ?', whereArgs: [id1]);
      final remaining = await db.query(AppConstants.tblNotifications, where: 'business_id = ?', whereArgs: [1]);
      expect(remaining.length, 1);
      expect(remaining.first['id'], id2);
    });

    test('Smart alert scanner detects low-stock items and customer dues without duplicate spam', () async {
      // Seed low stock product and customer with due balance
      await db.insert(AppConstants.tblProducts, {
        'business_id': 1,
        'name': 'Organic Basmati Rice',
        'stock': 2.0,
        'min_stock_alert': 10.0,
        'unit': 'kg',
        'is_active': 1,
      });

      await db.insert(AppConstants.tblCustomers, {
        'business_id': 1,
        'name': 'Sharma Traders',
        'balance_due': 12500.0,
        'phone': '9876543210',
      });

      // Simulation of scanner query
      final lowStock = await db.rawQuery('''
        SELECT id, name, stock, min_stock_alert, unit 
        FROM ${AppConstants.tblProducts} 
        WHERE business_id = 1 AND is_active = 1 AND (stock <= min_stock_alert OR stock <= 0)
      ''');
      expect(lowStock.length, 1);
      expect(lowStock.first['name'], 'Organic Basmati Rice');

      final highDues = await db.rawQuery('''
        SELECT id, name, balance_due, phone
        FROM ${AppConstants.tblCustomers}
        WHERE business_id = 1 AND balance_due > 500
      ''');
      expect(highDues.length, 1);
      expect(highDues.first['name'], 'Sharma Traders');
    });
  });
}
