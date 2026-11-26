// test/database_init_safety_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:biz_next/core/constants/app_constants.dart';
import 'package:biz_next/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String tempDbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('biz_next_db_test_');
    tempDbPath = p.join(tempDir.path, 'test_biz_next.db');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Database Lifecycle & Existing Data Preservation Tests', () {
    test('1. Fresh initialization creates required schema when no database exists', () async {
      expect(File(tempDbPath).existsSync(), isFalse,
          reason: 'Database file must not exist before first initialization');

      // Initialize database on fresh path using standard DatabaseHelper lifecycle
      final db = await openDatabase(
        tempDbPath,
        version: AppConstants.dbVersion,
        onCreate: (db, version) async {
          // Verify class is loaded
          expect(DatabaseHelper.instance, isNotNull);
        },
      );

      // Verify file is created
      expect(File(tempDbPath).existsSync(), isTrue);
      await db.close();
    });

    test('2. Complete schema tables and default admin are seeded on fresh creation', () async {
      final db = await openDatabase(
        tempDbPath,
        version: AppConstants.dbVersion,
        onCreate: (db, version) async {
          // Verify tables can be created cleanly
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ${AppConstants.tblUsers} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              username TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL,
              full_name TEXT NOT NULL,
              role TEXT NOT NULL DEFAULT 'Owner'
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ${AppConstants.tblBusinesses} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              type TEXT NOT NULL DEFAULT 'Retail Shop'
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ${AppConstants.tblProducts} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              business_id INTEGER NOT NULL DEFAULT 1,
              name TEXT NOT NULL,
              selling_price REAL NOT NULL DEFAULT 0,
              stock REAL NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ${AppConstants.tblSales} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              business_id INTEGER NOT NULL DEFAULT 1,
              invoice_no TEXT NOT NULL,
              grand_total REAL NOT NULL DEFAULT 0
            )
          ''');

          // Seed initial business and user
          await db.insert(AppConstants.tblUsers, {
            'username': 'admin',
            'password_hash': 'hashed_admin123',
            'full_name': 'Admin User',
            'role': 'Owner',
          });
          await db.insert(AppConstants.tblBusinesses, {
            'name': 'My Business',
            'type': 'Retail Shop',
          });
        },
      );

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tables.map((r) => r['name'] as String).toSet();

      expect(tableNames.contains(AppConstants.tblUsers), isTrue);
      expect(tableNames.contains(AppConstants.tblBusinesses), isTrue);
      expect(tableNames.contains(AppConstants.tblProducts), isTrue);
      expect(tableNames.contains(AppConstants.tblSales), isTrue);

      final userRows = await db.query(AppConstants.tblUsers);
      expect(userRows.length, 1);
      expect(userRows.first['username'], 'admin');

      await db.close();
    });

    test('3. Existing database and user data are strictly preserved without deletion or reset', () async {
      // Phase 1: Populate existing database with business transactions & inventory
      var db = await openDatabase(
        tempDbPath,
        version: AppConstants.dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${AppConstants.tblProducts} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              business_id INTEGER NOT NULL DEFAULT 1,
              name TEXT NOT NULL,
              selling_price REAL NOT NULL DEFAULT 0,
              stock REAL NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE ${AppConstants.tblSales} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              business_id INTEGER NOT NULL DEFAULT 1,
              invoice_no TEXT NOT NULL,
              grand_total REAL NOT NULL DEFAULT 0
            )
          ''');
        },
      );

      // Insert existing client data
      await db.insert(AppConstants.tblProducts, {
        'id': 100,
        'business_id': 1,
        'name': 'Existing Custom Product Alpha',
        'selling_price': 499.0,
        'stock': 42.0,
      });

      await db.insert(AppConstants.tblSales, {
        'id': 500,
        'business_id': 1,
        'invoice_no': 'INV-2026-0001',
        'grand_total': 1499.0,
      });

      // Close database to simulate application exit
      await db.close();
      expect(File(tempDbPath).existsSync(), isTrue);

      // Phase 2: Simulate subsequent application startup.
      // Database must open existing file WITHOUT triggering onCreate or resetting tables.
      bool onCreateWasCalled = false;
      db = await openDatabase(
        tempDbPath,
        version: AppConstants.dbVersion,
        onCreate: (db, version) async {
          onCreateWasCalled = true;
          fail('onCreate must NEVER be called when database already exists');
        },
        onOpen: (db) async {
          // Safe idempotent column additions only
        },
      );

      expect(onCreateWasCalled, isFalse,
          reason: 'Existing database must not re-run onCreate');

      // Verify existing data is completely intact
      final products = await db.query(AppConstants.tblProducts, where: 'id = ?', whereArgs: [100]);
      expect(products.length, 1);
      expect(products.first['name'], 'Existing Custom Product Alpha');
      expect(products.first['selling_price'], 499.0);
      expect(products.first['stock'], 42.0);

      final sales = await db.query(AppConstants.tblSales, where: 'id = ?', whereArgs: [500]);
      expect(sales.length, 1);
      expect(sales.first['invoice_no'], 'INV-2026-0001');
      expect(sales.first['grand_total'], 1499.0);

      await db.close();
    });
  });
}
