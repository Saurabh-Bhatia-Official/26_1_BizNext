// lib/core/database/database_helper.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  
  // Change Notification
  final _changeController = StreamController<String>.broadcast();
  Stream<String> get changeStream => _changeController.stream;

  void notify(String table) {
    _changeController.add(table);
  }

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      return MockDatabase();
    }

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'BizNext', AppConstants.dbName);
    
    // Print the internal storage offline database name and path
    debugPrint('==================================================');
    debugPrint('INTERNAL OFFLINE DATABASE NAME: ${AppConstants.dbName}');
    debugPrint('DATABASE PATH: $dbPath');
    debugPrint('==================================================');

    final oldDbPath = join(documentsDir.path, 'BizNext', 'biz_manager.db');

    // ── Migration ──
    if (await File(oldDbPath).exists() && !await File(dbPath).exists()) {
      await File(oldDbPath).rename(dbPath);
    }

    await Directory(dirname(dbPath)).create(recursive: true);

    return await openDatabase(
      dbPath,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
        } catch (_) {}
      },
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE ${AppConstants.tblOffers} ADD COLUMN poster_path TEXT');
        } catch (_) {}
      },
    );
  }

  // ── Password Hashing ───────────────────────────────────────────────────────
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }

  // ── onCreate ───────────────────────────────────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await _createAuthTables(txn);
      await _createDataTables(txn);
      await _createSyncTable(txn);
      await _createIndexes(txn);
      await _seedDefaultData(txn);
    });
  }

  Future<void> _createAuthTables(Transaction txn) async {
    // Users
    await txn.execute('''
      CREATE TABLE ${AppConstants.tblUsers} (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT    NOT NULL UNIQUE,
        password_hash TEXT    NOT NULL,
        full_name     TEXT    NOT NULL,
        email         TEXT,
        phone         TEXT,
        role          TEXT    NOT NULL DEFAULT '${AppConstants.roleOwner}',
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Businesses
    await txn.execute('''
      CREATE TABLE ${AppConstants.tblBusinesses} (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT    NOT NULL,
        type            TEXT    NOT NULL DEFAULT 'Retail Shop',
        address         TEXT,
        phone           TEXT,
        email           TEXT,
        gst_number      TEXT,
        currency        TEXT    NOT NULL DEFAULT 'INR',
        currency_symbol TEXT    NOT NULL DEFAULT '₹',
        owner_id        INTEGER REFERENCES ${AppConstants.tblUsers}(id),
        is_active       INTEGER NOT NULL DEFAULT 1,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // User ↔ Business membership
    await txn.execute('''
      CREATE TABLE ${AppConstants.tblUserBusinesses} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL REFERENCES ${AppConstants.tblUsers}(id) ON DELETE CASCADE,
        business_id INTEGER NOT NULL REFERENCES ${AppConstants.tblBusinesses}(id) ON DELETE CASCADE,
        role        TEXT    NOT NULL DEFAULT '${AppConstants.roleAdmin}',
        UNIQUE(user_id, business_id)
      )
    ''');
  }

  /// Helper to create a table only if it doesn't exist (useful for upgrades)
  Future<void> _safeExecute(Transaction txn, String sql) async {
    try {
      await txn.execute(sql);
    } catch (_) {}
  }

  Future<void> _createDataTables(Transaction txn) async {
    // Categories
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblCategories} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        name        TEXT    NOT NULL,
        description TEXT,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, name)
      )
    ''');

    // Products
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblProducts} (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id    INTEGER NOT NULL DEFAULT 1,
        name           TEXT    NOT NULL,
        sku            TEXT,
        barcode        TEXT,
        description    TEXT,
        category_id    INTEGER REFERENCES ${AppConstants.tblCategories}(id) ON DELETE SET NULL,
        purchase_price REAL    NOT NULL DEFAULT 0,
        selling_price  REAL    NOT NULL DEFAULT 0,
        wholesale_price REAL   NOT NULL DEFAULT 0,
        dealer_price   REAL    NOT NULL DEFAULT 0,
        stock          REAL    NOT NULL DEFAULT 0,
        min_stock      REAL    NOT NULL DEFAULT 5,
        unit           TEXT    NOT NULL DEFAULT 'pcs',
        gst_percent    REAL    NOT NULL DEFAULT 0,
        is_active      INTEGER NOT NULL DEFAULT 1,
        image_path     TEXT,
        created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at     TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
 
    // Price Categories
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblPriceCategories} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        name        TEXT    NOT NULL,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, name)
      )
    ''');
 
    // Product Tiered Prices
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblProductPrices} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id  INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
        category_id INTEGER NOT NULL REFERENCES ${AppConstants.tblPriceCategories}(id) ON DELETE CASCADE,
        price       REAL    NOT NULL DEFAULT 0,
        UNIQUE(product_id, category_id)
      )
    ''');

    // Customers
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblCustomers} (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id    INTEGER NOT NULL DEFAULT 1,
        name           TEXT    NOT NULL,
        phone          TEXT,
        email          TEXT,
        address        TEXT,
        gst_number     TEXT,
        balance        REAL    NOT NULL DEFAULT 0,
        loyalty_points REAL    NOT NULL DEFAULT 0,
        created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Suppliers
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblSuppliers} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        name        TEXT    NOT NULL,
        phone       TEXT,
        email       TEXT,
        address     TEXT,
        gst_number  TEXT,
        balance     REAL    NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Sales
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblSales} (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id     INTEGER NOT NULL DEFAULT 1,
        invoice_no      TEXT    NOT NULL,
        customer_id     INTEGER REFERENCES ${AppConstants.tblCustomers}(id) ON DELETE SET NULL,
        subtotal        REAL    NOT NULL DEFAULT 0,
        discount        REAL    NOT NULL DEFAULT 0,
        gst_amount      REAL    NOT NULL DEFAULT 0,
        grand_total     REAL    NOT NULL DEFAULT 0,
        paid_amount     REAL    NOT NULL DEFAULT 0,
        balance_due     REAL    NOT NULL DEFAULT 0,
        payment_mode    TEXT    NOT NULL DEFAULT 'Cash',
        account_id      INTEGER REFERENCES ${AppConstants.tblAccounts}(id) ON DELETE SET NULL,
        notes           TEXT,
        status          TEXT    NOT NULL DEFAULT 'completed',
        points_earned   REAL    NOT NULL DEFAULT 0,
        points_redeemed REAL    NOT NULL DEFAULT 0,
        loyalty_discount REAL   NOT NULL DEFAULT 0,
        date            TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, invoice_no)
      )
    ''');

    // Sale Items
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblSaleItems} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id      INTEGER NOT NULL REFERENCES ${AppConstants.tblSales}(id) ON DELETE CASCADE,
        product_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE RESTRICT,
        product_name TEXT    NOT NULL,
        quantity     REAL    NOT NULL,
        price        REAL    NOT NULL,
        purchase_price REAL    NOT NULL DEFAULT 0,
        discount     REAL    NOT NULL DEFAULT 0,
        gst_percent  REAL    NOT NULL DEFAULT 0,
        gst_amount   REAL    NOT NULL DEFAULT 0,
        total        REAL    NOT NULL
      )
    ''');

    // Purchases
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblPurchases} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id  INTEGER NOT NULL DEFAULT 1,
        bill_no      TEXT,
        supplier_id  INTEGER REFERENCES ${AppConstants.tblSuppliers}(id) ON DELETE SET NULL,
        subtotal     REAL    NOT NULL DEFAULT 0,
        discount     REAL    NOT NULL DEFAULT 0,
        gst_amount   REAL    NOT NULL DEFAULT 0,
        grand_total  REAL    NOT NULL DEFAULT 0,
        paid_amount  REAL    NOT NULL DEFAULT 0,
        balance_due  REAL    NOT NULL DEFAULT 0,
        payment_mode TEXT    NOT NULL DEFAULT 'Cash',
        account_id   INTEGER REFERENCES ${AppConstants.tblAccounts}(id) ON DELETE SET NULL,
        notes        TEXT,
        status       TEXT    NOT NULL DEFAULT 'completed',
        date         TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Purchase Items
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblPurchaseItems} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id  INTEGER NOT NULL REFERENCES ${AppConstants.tblPurchases}(id) ON DELETE CASCADE,
        product_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE RESTRICT,
        product_name TEXT    NOT NULL,
        quantity     REAL    NOT NULL,
        price        REAL    NOT NULL,
        gst_percent  REAL    NOT NULL DEFAULT 0,
        gst_amount   REAL    NOT NULL DEFAULT 0,
        total        REAL    NOT NULL
      )
    ''');

    // Accounts
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblAccounts} (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id     INTEGER NOT NULL DEFAULT 1,
        name            TEXT    NOT NULL,
        type            TEXT    NOT NULL DEFAULT 'Cash',
        opening_balance REAL    NOT NULL DEFAULT 0,
        balance         REAL    NOT NULL DEFAULT 0,
        account_number  TEXT,
        is_default      INTEGER NOT NULL DEFAULT 0,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Ledger
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblLedger} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id  INTEGER NOT NULL DEFAULT 1,
        entity_type  TEXT    NOT NULL,
        entity_id    INTEGER NOT NULL,
        type         TEXT    NOT NULL,
        amount       REAL    NOT NULL,
        balance      REAL    NOT NULL DEFAULT 0,
        reference_id INTEGER,
        account_id   INTEGER REFERENCES ${AppConstants.tblAccounts}(id) ON DELETE SET NULL,
        description  TEXT,
        date         TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Expense Categories
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblExpenseCategories} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        name        TEXT    NOT NULL
      )
    ''');

    // Expenses
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblExpenses} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id  INTEGER NOT NULL DEFAULT 1,
        category_id  INTEGER REFERENCES ${AppConstants.tblExpenseCategories}(id) ON DELETE SET NULL,
        amount       REAL    NOT NULL,
        description  TEXT,
        payment_mode TEXT    NOT NULL DEFAULT 'Cash',
        account_id   INTEGER REFERENCES ${AppConstants.tblAccounts}(id) ON DELETE SET NULL,
        date         TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Transaction Categories
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblTransactionCategories} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        name        TEXT    NOT NULL,
        type        TEXT    NOT NULL DEFAULT 'expense' -- 'income' or 'expense'
      )
    ''');

    // Transactions (General Credit/Debit)
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblTransactions} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id  INTEGER NOT NULL DEFAULT 1,
        category_id  INTEGER REFERENCES ${AppConstants.tblTransactionCategories}(id) ON DELETE SET NULL,
        type         TEXT    NOT NULL, -- 'credit' or 'debit'
        amount       REAL    NOT NULL,
        description  TEXT,
        payment_mode TEXT    NOT NULL DEFAULT 'Cash',
        account_id   INTEGER REFERENCES ${AppConstants.tblAccounts}(id) ON DELETE SET NULL,
        date         TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // App Settings
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblAppSettings} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        key         TEXT    NOT NULL,
        value       TEXT    NOT NULL,
        UNIQUE(business_id, key)
      )
    ''');

    // Loyalty Settings
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblLoyaltySettings} (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id      INTEGER NOT NULL DEFAULT 1,
        earn_rate        REAL    NOT NULL DEFAULT 1.0,
        earn_spend_amount REAL   NOT NULL DEFAULT 100.0,
        redeem_value     REAL    NOT NULL DEFAULT 1.0,
        min_redeem_pts   REAL    NOT NULL DEFAULT 100,
        expiry_days      INTEGER NOT NULL DEFAULT 365,
        point_name       TEXT    NOT NULL DEFAULT 'Points',
        max_redeem_limit REAL    NOT NULL DEFAULT 0,
        welcome_points   REAL    NOT NULL DEFAULT 0,
        is_active        INTEGER NOT NULL DEFAULT 1,
        UNIQUE(business_id)
      )
    ''');

    // Offers
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblOffers} (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id    INTEGER NOT NULL DEFAULT 1,
        name           TEXT    NOT NULL,
        offer_type     TEXT    NOT NULL,
        discount_type  TEXT    NOT NULL,
        discount_value REAL    NOT NULL,
        min_qty        REAL    NOT NULL DEFAULT 0,
        min_amount     REAL    NOT NULL DEFAULT 0,
        apply_to       TEXT    NOT NULL DEFAULT 'all',
        target_id      INTEGER,
        buy_qty        REAL    NOT NULL DEFAULT 0,
        get_qty        REAL    NOT NULL DEFAULT 0,
        start_date     TEXT,
        end_date       TEXT,
        is_active      INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
        poster_path    TEXT
      )
    ''');

    // Customer Discounts
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblCustomerDiscounts} (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id    INTEGER NOT NULL DEFAULT 1,
        customer_id    INTEGER NOT NULL REFERENCES ${AppConstants.tblCustomers}(id) ON DELETE CASCADE,
        discount_type  TEXT    NOT NULL DEFAULT 'percentage',
        discount_value REAL    NOT NULL DEFAULT 0,
        is_active      INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, customer_id)
      )
    ''');

    // Product Discounts
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblProductDiscounts} (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id    INTEGER NOT NULL DEFAULT 1,
        product_id     INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
        discount_type  TEXT    NOT NULL DEFAULT 'percentage',
        discount_value REAL    NOT NULL DEFAULT 0,
        start_date     TEXT,
        end_date       TEXT,
        is_active      INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, product_id)
      )
    ''');

    // Restaurant Tables
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblRestaurantTables} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id  INTEGER NOT NULL DEFAULT 1,
        table_number TEXT    NOT NULL,
        capacity     INTEGER NOT NULL DEFAULT 4,
        status       TEXT    NOT NULL DEFAULT 'Available',
        qr_code      TEXT,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, table_number)
      )
    ''');

    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblKot} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id  INTEGER NOT NULL DEFAULT 1,
        sale_id      INTEGER REFERENCES ${AppConstants.tblSales}(id) ON DELETE CASCADE,
        table_id     INTEGER REFERENCES ${AppConstants.tblRestaurantTables}(id) ON DELETE SET NULL,
        status       TEXT    NOT NULL DEFAULT 'Pending',
        notes        TEXT,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblKotItems} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        kot_id       INTEGER NOT NULL REFERENCES ${AppConstants.tblKot}(id) ON DELETE CASCADE,
        product_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE RESTRICT,
        product_name TEXT    NOT NULL,
        quantity     REAL    NOT NULL,
        status       TEXT    NOT NULL DEFAULT 'Pending',
        notes        TEXT
      )
    ''');

    // Budgets Table
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblBudgets} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id  INTEGER NOT NULL,
        category_id  INTEGER,
        account_id   INTEGER,
        target_type  TEXT NOT NULL,
        target_name  TEXT,
        amount       REAL NOT NULL,
        period       TEXT NOT NULL,
        start_date   TEXT NOT NULL,
        end_date     TEXT NOT NULL
      )
    ''');

    await _createErpTables(txn);
  }

  Future<void> _createErpTables(Transaction txn) async {
    // Warehouses
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblWarehouses} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        name        TEXT    NOT NULL,
        code        TEXT,
        address     TEXT,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, name)
      )
    ''');

    // Warehouse Stocks
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblWarehouseStocks} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_id INTEGER NOT NULL REFERENCES ${AppConstants.tblWarehouses}(id) ON DELETE CASCADE,
        product_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
        stock        REAL    NOT NULL DEFAULT 0,
        UNIQUE(warehouse_id, product_id)
      )
    ''');

    // Inventory Transactions
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblInventoryTransactions} (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id       INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
        warehouse_id     INTEGER REFERENCES ${AppConstants.tblWarehouses}(id) ON DELETE SET NULL,
        transaction_type TEXT NOT NULL,
        reference_number TEXT NOT NULL,
        quantity         REAL NOT NULL,
        unit_cost        REAL NOT NULL DEFAULT 0,
        opening_stock    REAL NOT NULL DEFAULT 0,
        closing_stock    REAL NOT NULL DEFAULT 0,
        created_by       INTEGER,
        created_date     TEXT NOT NULL DEFAULT (datetime('now')),
        remarks          TEXT
      )
    ''');

    // Audit Logs
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblAuditLogs} (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id        INTEGER,
        timestamp      TEXT NOT NULL DEFAULT (datetime('now')),
        module         TEXT NOT NULL,
        action_type    TEXT NOT NULL,
        record_id      INTEGER,
        previous_state TEXT,
        new_state      TEXT,
        ip_address     TEXT,
        device_info    TEXT
      )
    ''');

    // Purchase Returns
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblPurchaseReturns} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id  INTEGER NOT NULL DEFAULT 1,
        purchase_id  INTEGER REFERENCES ${AppConstants.tblPurchases}(id) ON DELETE SET NULL,
        return_no    TEXT NOT NULL,
        supplier_id  INTEGER REFERENCES ${AppConstants.tblSuppliers}(id) ON DELETE SET NULL,
        subtotal     REAL NOT NULL DEFAULT 0,
        discount     REAL NOT NULL DEFAULT 0,
        gst_amount   REAL NOT NULL DEFAULT 0,
        grand_total  REAL NOT NULL DEFAULT 0,
        refund_amount REAL NOT NULL DEFAULT 0,
        status       TEXT NOT NULL DEFAULT 'completed',
        date         TEXT NOT NULL DEFAULT (datetime('now')),
        notes        TEXT
      )
    ''');

    // Purchase Return Items
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblPurchaseReturnItems} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id    INTEGER NOT NULL REFERENCES ${AppConstants.tblPurchaseReturns}(id) ON DELETE CASCADE,
        product_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE RESTRICT,
        product_name TEXT NOT NULL,
        quantity     REAL NOT NULL,
        price        REAL NOT NULL,
        gst_percent  REAL NOT NULL DEFAULT 0,
        gst_amount   REAL NOT NULL DEFAULT 0,
        total        REAL NOT NULL
      )
    ''');

    // Sales Returns
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblSalesReturns} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id  INTEGER NOT NULL DEFAULT 1,
        sale_id      INTEGER REFERENCES ${AppConstants.tblSales}(id) ON DELETE SET NULL,
        return_no    TEXT NOT NULL,
        customer_id  INTEGER REFERENCES ${AppConstants.tblCustomers}(id) ON DELETE SET NULL,
        subtotal     REAL NOT NULL DEFAULT 0,
        discount     REAL NOT NULL DEFAULT 0,
        gst_amount   REAL NOT NULL DEFAULT 0,
        grand_total  REAL NOT NULL DEFAULT 0,
        refund_amount REAL NOT NULL DEFAULT 0,
        status       TEXT NOT NULL DEFAULT 'completed',
        date         TEXT NOT NULL DEFAULT (datetime('now')),
        notes        TEXT
      )
    ''');

    // Sales Return Items
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblSalesReturnItems} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id    INTEGER NOT NULL REFERENCES ${AppConstants.tblSalesReturns}(id) ON DELETE CASCADE,
        product_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE RESTRICT,
        product_name TEXT NOT NULL,
        quantity     REAL NOT NULL,
        price        REAL NOT NULL,
        gst_percent  REAL NOT NULL DEFAULT 0,
        gst_amount   REAL NOT NULL DEFAULT 0,
        total        REAL NOT NULL
      )
    ''');

    // Warehouse Transfers
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblWarehouseTransfers} (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id         INTEGER NOT NULL DEFAULT 1,
        transfer_no         TEXT NOT NULL,
        source_warehouse_id INTEGER NOT NULL REFERENCES ${AppConstants.tblWarehouses}(id) ON DELETE CASCADE,
        dest_warehouse_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblWarehouses}(id) ON DELETE CASCADE,
        status              TEXT NOT NULL DEFAULT 'completed',
        date                TEXT NOT NULL DEFAULT (datetime('now')),
        notes               TEXT
      )
    ''');

    // Warehouse Transfer Items
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblWarehouseTransferItems} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id  INTEGER NOT NULL REFERENCES ${AppConstants.tblWarehouseTransfers}(id) ON DELETE CASCADE,
        product_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE RESTRICT,
        product_name TEXT NOT NULL,
        quantity     REAL NOT NULL
      )
    ''');

    // Inventory Adjustments
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblInventoryAdjustments} (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id     INTEGER NOT NULL DEFAULT 1,
        adjustment_no   TEXT NOT NULL,
        warehouse_id    INTEGER NOT NULL REFERENCES ${AppConstants.tblWarehouses}(id) ON DELETE CASCADE,
        adjustment_type TEXT NOT NULL,
        status          TEXT NOT NULL DEFAULT 'completed',
        date            TEXT NOT NULL DEFAULT (datetime('now')),
        notes           TEXT
      )
    ''');

    // Inventory Adjustment Items
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblInventoryAdjustmentItems} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        adjustment_id INTEGER NOT NULL REFERENCES ${AppConstants.tblInventoryAdjustments}(id) ON DELETE CASCADE,
        product_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE RESTRICT,
        product_name TEXT NOT NULL,
        quantity     REAL NOT NULL,
        remarks      TEXT
      )
    ''');
  }

  Future<void> _createIndexes(Transaction txn) async {
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_products_business ON ${AppConstants.tblProducts}(business_id)');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON ${AppConstants.tblProducts}(barcode)');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_sales_business ON ${AppConstants.tblSales}(business_id)');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_sales_date ON ${AppConstants.tblSales}(date)');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_ledger_entity ON ${AppConstants.tblLedger}(entity_type, entity_id)');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_ledger_account ON ${AppConstants.tblLedger}(account_id)');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_user_businesses ON ${AppConstants.tblUserBusinesses}(user_id)');
  }

  Future<void> _seedDefaultData(Transaction txn) async {
    // Default admin user (password: admin123)
    final adminId = await txn.rawInsert('''
      INSERT INTO ${AppConstants.tblUsers}
        (username, password_hash, full_name, email, role)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      'admin',
      hashPassword('admin123'),
      'Admin User',
      'admin@biznext.com',
      AppConstants.roleOwner,
    ]);

    // Default business
    final bizId = await txn.rawInsert('''
      INSERT INTO ${AppConstants.tblBusinesses}
        (name, type, phone, owner_id)
      VALUES (?, ?, ?, ?)
    ''', ['My Business', 'Retail Shop', '', adminId]);

    // Link admin to business
    await txn.rawInsert('''
      INSERT INTO ${AppConstants.tblUserBusinesses} (user_id, business_id, role)
      VALUES (?, ?, ?)
    ''', [adminId, bizId, AppConstants.roleOwner]);

    // Seed all default data for initial business (Categories, Accounts, Settings)
    await seedBusinessDefaults(bizId, txn: txn);
  }

  // ── onUpgrade ──────────────────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        await _createAuthTables(txn);
        await _createDataTables(txn); 
        await _createIndexes(txn);

        // Add business_id to existing tables (in case they existed but were missing this column)
        const tablesNeedingBusinessId = [
          AppConstants.tblCategories,
          AppConstants.tblProducts,
          AppConstants.tblCustomers,
          AppConstants.tblSuppliers,
          AppConstants.tblSales,
          AppConstants.tblPurchases,
          AppConstants.tblLedger,
          AppConstants.tblExpenseCategories,
          AppConstants.tblExpenses,
        ];

        for (final table in tablesNeedingBusinessId) {
          try {
            await txn.execute('ALTER TABLE $table ADD COLUMN business_id INTEGER NOT NULL DEFAULT 1');
          } catch (_) {}
        }
      });
    }

    if (oldVersion < 3) {
      await db.transaction((txn) async {
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblProducts} ADD COLUMN image_path TEXT');
        } catch (_) {}
      });
    }

    if (oldVersion < 4) {
      await db.transaction((txn) async {
        // Transaction Categories
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblTransactionCategories} (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id INTEGER NOT NULL DEFAULT 1,
            name        TEXT    NOT NULL,
            type        TEXT    NOT NULL DEFAULT 'expense'
          )
        ''');

        // Transactions
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblTransactions} (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id  INTEGER NOT NULL DEFAULT 1,
            category_id  INTEGER REFERENCES ${AppConstants.tblTransactionCategories}(id) ON DELETE SET NULL,
            type         TEXT    NOT NULL,
            amount       REAL    NOT NULL,
            description  TEXT,
            payment_mode TEXT    NOT NULL DEFAULT 'Cash',
            date         TEXT    NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      });
    }

    if (oldVersion < 5) {
      await db.transaction((txn) async {
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblSaleItems} ADD COLUMN purchase_price REAL NOT NULL DEFAULT 0');
        } catch (_) {}
      });
    }

    if (oldVersion < 6) {
      await db.transaction((txn) async {
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblAccounts} ADD COLUMN opening_balance REAL NOT NULL DEFAULT 0');
        } catch (_) {}
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblTransactions} ADD COLUMN account_id INTEGER REFERENCES ${AppConstants.tblAccounts}(id) ON DELETE SET NULL');
        } catch (_) {}
      });
    }

    if (oldVersion < 7) {
      await db.transaction((txn) async {
        final tables = [
          AppConstants.tblSales,
          AppConstants.tblPurchases,
          AppConstants.tblLedger,
          AppConstants.tblExpenses,
        ];
        for (final table in tables) {
          try {
            await txn.execute('ALTER TABLE $table ADD COLUMN account_id INTEGER REFERENCES ${AppConstants.tblAccounts}(id) ON DELETE SET NULL');
          } catch (_) {}
        }
      });
    }

    if (oldVersion < 8) {
      await db.transaction((txn) async {
        await _createDataTables(txn);
      });
    }

    if (oldVersion < 9) {
      await db.transaction((txn) async {
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblProducts} ADD COLUMN wholesale_price REAL NOT NULL DEFAULT 0');
          await txn.execute('ALTER TABLE ${AppConstants.tblProducts} ADD COLUMN dealer_price REAL NOT NULL DEFAULT 0');
        } catch (_) {}
      });
    }

    if (oldVersion < 10) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblPriceCategories} (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id INTEGER NOT NULL DEFAULT 1,
            name        TEXT    NOT NULL,
            created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
            UNIQUE(business_id, name)
          )
        ''');
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblProductPrices} (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id  INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
            category_id INTEGER NOT NULL REFERENCES ${AppConstants.tblPriceCategories}(id) ON DELETE CASCADE,
            price       REAL    NOT NULL DEFAULT 0,
            UNIQUE(product_id, category_id)
          )
        ''');
        
        // Seed initial categories for existing businesses
        final businesses = await txn.query(AppConstants.tblBusinesses);
        for (var b in businesses) {
          final bId = b['id'];
          await txn.insert(AppConstants.tblPriceCategories, {'business_id': bId, 'name': 'Wholesale'});
          await txn.insert(AppConstants.tblPriceCategories, {'business_id': bId, 'name': 'Dealer'});
        }
      });
    }

    if (oldVersion < 11) {
      await db.transaction((txn) async {
        // Customer Discounts
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblCustomerDiscounts} (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id    INTEGER NOT NULL DEFAULT 1,
            customer_id    INTEGER NOT NULL REFERENCES ${AppConstants.tblCustomers}(id) ON DELETE CASCADE,
            discount_type  TEXT    NOT NULL, -- 'percentage' or 'fixed'
            discount_value REAL    NOT NULL DEFAULT 0,
            is_active      INTEGER NOT NULL DEFAULT 1,
            created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
            UNIQUE(business_id, customer_id)
          )
        ''');

        // Product Discounts
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblProductDiscounts} (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id    INTEGER NOT NULL DEFAULT 1,
            product_id     INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
            discount_type  TEXT    NOT NULL, -- 'percentage' or 'fixed'
            discount_value REAL    NOT NULL DEFAULT 0,
            start_date     TEXT,
            end_date       TEXT,
            is_active      INTEGER NOT NULL DEFAULT 1,
            created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
            UNIQUE(business_id, product_id)
          )
        ''');

        // Offers & Promotions
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblOffers} (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id    INTEGER NOT NULL DEFAULT 1,
            name           TEXT    NOT NULL,
            offer_type     TEXT    NOT NULL, -- 'buy_x_get_y', 'festival', 'loyalty', 'bulk', 'first_purchase', 'bill_amount'
            discount_type  TEXT    NOT NULL, -- 'percentage', 'fixed', 'free_product'
            discount_value REAL    NOT NULL DEFAULT 0,
            min_qty        REAL    NOT NULL DEFAULT 0,
            min_amount     REAL    NOT NULL DEFAULT 0,
            apply_to       TEXT    NOT NULL DEFAULT 'all', -- 'all', 'category', 'product'
            target_id      INTEGER, -- category_id or product_id
            buy_qty        REAL    NOT NULL DEFAULT 0,
            get_qty        REAL    NOT NULL DEFAULT 0,
            start_date     TEXT,
            end_date       TEXT,
            is_active      INTEGER NOT NULL DEFAULT 1,
            created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
          )
        ''');

        // App Settings / Feature Toggles
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblAppSettings} (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id INTEGER NOT NULL DEFAULT 1,
            key         TEXT    NOT NULL,
            value       TEXT    NOT NULL,
            UNIQUE(business_id, key)
          )
        ''');

        // Seed default settings for existing businesses
        final businesses = await txn.query(AppConstants.tblBusinesses);
        for (var b in businesses) {
          final bId = b['id'];
          final defaultSettings = {
            'customer_discount_enabled': '1',
            'product_discount_enabled': '1',
            'offers_enabled': '1',
            'loyalty_enabled': '0',
            'gst_enabled': '1',
            'inventory_tracking_enabled': '1',
            'notifications_enabled': '0',
          };
          for (var entry in defaultSettings.entries) {
            await txn.insert(AppConstants.tblAppSettings, {
              'business_id': bId,
              'key': entry.key,
              'value': entry.value,
            });
          }
        }
      });
    }
    if (oldVersion < 12) {
      await db.transaction((txn) async {
        // Loyalty Settings
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblLoyaltySettings} (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id      INTEGER NOT NULL DEFAULT 1,
            earn_rate        REAL    NOT NULL DEFAULT 1.0, -- Points per ₹100
            redeem_value     REAL    NOT NULL DEFAULT 1.0, -- ₹ value per 1 point
            min_redeem_pts   REAL    NOT NULL DEFAULT 100,
            is_active        INTEGER NOT NULL DEFAULT 1,
            UNIQUE(business_id)
          )
        ''');

        // Add loyalty_points to customers
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblCustomers} ADD COLUMN loyalty_points REAL NOT NULL DEFAULT 0');
        } catch (_) {}

        // Add loyalty info to sales
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblSales} ADD COLUMN points_earned REAL NOT NULL DEFAULT 0');
          await txn.execute('ALTER TABLE ${AppConstants.tblSales} ADD COLUMN points_redeemed REAL NOT NULL DEFAULT 0');
        } catch (_) {}

        // Seed default loyalty settings for existing businesses
        final businesses = await txn.query(AppConstants.tblBusinesses);
        for (var b in businesses) {
          final bId = b['id'];
          await txn.insert(AppConstants.tblLoyaltySettings, {
            'business_id': bId,
            'earn_rate': 1.0,
            'redeem_value': 1.0,
            'min_redeem_pts': 100,
            'is_active': 1,
          });
        }
      });
    }
    if (oldVersion < 13) {
      await db.transaction((txn) async {
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblLoyaltySettings} ADD COLUMN expiry_days INTEGER NOT NULL DEFAULT 365');
        } catch (_) {}
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblSales} ADD COLUMN loyalty_discount REAL NOT NULL DEFAULT 0');
        } catch (_) {}
      });
    }
    if (oldVersion < 14) {
      await db.transaction((txn) async {
        try {
          await txn.execute("ALTER TABLE ${AppConstants.tblLoyaltySettings} ADD COLUMN point_name TEXT NOT NULL DEFAULT 'Points'");
          await txn.execute('ALTER TABLE ${AppConstants.tblLoyaltySettings} ADD COLUMN max_redeem_limit REAL NOT NULL DEFAULT 0');
          await txn.execute('ALTER TABLE ${AppConstants.tblLoyaltySettings} ADD COLUMN welcome_points REAL NOT NULL DEFAULT 0');
        } catch (_) {}
      });
    }
    if (oldVersion < 15) {
      await db.transaction((txn) async {
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblLoyaltySettings} ADD COLUMN earn_spend_amount REAL NOT NULL DEFAULT 100.0');
        } catch (_) {}
      });
    }
    if (oldVersion < 16) {
      await db.transaction((txn) async {
        try {
          await txn.execute('DROP TABLE IF EXISTS ${AppConstants.tblOffers}');
          await txn.execute('''
            CREATE TABLE IF NOT EXISTS ${AppConstants.tblOffers} (
              id             INTEGER PRIMARY KEY AUTOINCREMENT,
              business_id    INTEGER NOT NULL DEFAULT 1,
              name           TEXT    NOT NULL,
              offer_type     TEXT    NOT NULL,
              discount_type  TEXT    NOT NULL,
              discount_value REAL    NOT NULL,
              min_qty        REAL    NOT NULL DEFAULT 0,
              min_amount     REAL    NOT NULL DEFAULT 0,
              apply_to       TEXT    NOT NULL DEFAULT 'all',
              target_id      INTEGER,
              buy_qty        REAL    NOT NULL DEFAULT 0,
              get_qty        REAL    NOT NULL DEFAULT 0,
              start_date     TEXT,
              end_date       TEXT,
              is_active      INTEGER NOT NULL DEFAULT 1,
              created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
            )
          ''');
        } catch (_) {}
      });
    }

    if (oldVersion < 17) {
      await db.transaction((txn) async {
        // Repair Customers table
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblCustomers} ADD COLUMN loyalty_points REAL NOT NULL DEFAULT 0');
        } catch (_) {}

        // Repair Sales table
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblSales} ADD COLUMN points_earned REAL NOT NULL DEFAULT 0');
        } catch (_) {}
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblSales} ADD COLUMN points_redeemed REAL NOT NULL DEFAULT 0');
        } catch (_) {}
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblSales} ADD COLUMN loyalty_discount REAL NOT NULL DEFAULT 0');
        } catch (_) {}

        // Repair Customer Discounts (if it has old 'percent' column)
        try {
          final columns = await txn.rawQuery('PRAGMA table_info(${AppConstants.tblCustomerDiscounts})');
          final hasPercent = columns.any((c) => c['name'] == 'percent');
          if (hasPercent) {
            // Recreate table correctly
            await txn.execute('DROP TABLE IF EXISTS ${AppConstants.tblCustomerDiscounts}');
            await txn.execute('''
              CREATE TABLE ${AppConstants.tblCustomerDiscounts} (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                business_id    INTEGER NOT NULL DEFAULT 1,
                customer_id    INTEGER NOT NULL REFERENCES ${AppConstants.tblCustomers}(id) ON DELETE CASCADE,
                discount_type  TEXT    NOT NULL DEFAULT 'percentage',
                discount_value REAL    NOT NULL DEFAULT 0,
                is_active      INTEGER NOT NULL DEFAULT 1,
                created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
                UNIQUE(business_id, customer_id)
              )
            ''');
          }
        } catch (_) {}

        // Repair Product Discounts
        try {
          final columns = await txn.rawQuery('PRAGMA table_info(${AppConstants.tblProductDiscounts})');
          final hasPercent = columns.any((c) => c['name'] == 'percent');
          if (hasPercent) {
            await txn.execute('DROP TABLE IF EXISTS ${AppConstants.tblProductDiscounts}');
            await txn.execute('''
              CREATE TABLE ${AppConstants.tblProductDiscounts} (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                business_id    INTEGER NOT NULL DEFAULT 1,
                product_id     INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
                discount_type  TEXT    NOT NULL DEFAULT 'percentage',
                discount_value REAL    NOT NULL DEFAULT 0,
                start_date     TEXT,
                end_date       TEXT,
                is_active      INTEGER NOT NULL DEFAULT 1,
                created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
                UNIQUE(business_id, product_id)
              )
            ''');
          }
        } catch (_) {}
      });
    }
    if (oldVersion < 18) {
      await db.transaction((txn) async {
        try {
          await txn.execute('ALTER TABLE ${AppConstants.tblOffers} ADD COLUMN poster_path TEXT');
        } catch (_) {}
      });
    }

    if (oldVersion < 19) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblRestaurantTables} (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id  INTEGER NOT NULL DEFAULT 1,
            table_number TEXT    NOT NULL,
            capacity     INTEGER NOT NULL DEFAULT 4,
            status       TEXT    NOT NULL DEFAULT 'Available',
            qr_code      TEXT,
            created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
            UNIQUE(business_id, table_number)
          )
        ''');

        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblKot} (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id  INTEGER NOT NULL DEFAULT 1,
            sale_id      INTEGER REFERENCES ${AppConstants.tblSales}(id) ON DELETE CASCADE,
            table_id     INTEGER REFERENCES ${AppConstants.tblRestaurantTables}(id) ON DELETE SET NULL,
            status       TEXT    NOT NULL DEFAULT 'Pending',
            notes        TEXT,
            created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
            updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
          )
        ''');

        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblKotItems} (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            kot_id       INTEGER NOT NULL REFERENCES ${AppConstants.tblKot}(id) ON DELETE CASCADE,
            product_id   INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE RESTRICT,
            product_name TEXT    NOT NULL,
            quantity     REAL    NOT NULL,
            status       TEXT    NOT NULL DEFAULT 'Pending',
            notes        TEXT
          )
        ''');
      });
    }
    if (oldVersion < 20) {
      await db.transaction((txn) async {
        await _createSyncTable(txn);
      });
    }
    if (oldVersion < 21) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tblBudgets} (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id  INTEGER NOT NULL,
            category_id  INTEGER,
            account_id   INTEGER,
            target_type  TEXT NOT NULL,
            target_name  TEXT,
            amount       REAL NOT NULL,
            period       TEXT NOT NULL,
            start_date   TEXT NOT NULL,
            end_date     TEXT NOT NULL
          )
        ''');
      });
    }

    if (oldVersion < 22) {
      await db.transaction((txn) async {
        await _createErpTables(txn);
        
        final businesses = await txn.query(AppConstants.tblBusinesses);
        for (var b in businesses) {
          final bId = b['id'] as int;
          final wId = await txn.insert(AppConstants.tblWarehouses, {
            'business_id': bId,
            'name': 'Default Warehouse',
            'code': 'WH-DF',
            'address': 'Main Business Location',
            'is_active': 1,
          });
          
          final products = await txn.query(AppConstants.tblProducts, where: 'business_id = ?', whereArgs: [bId]);
          for (var p in products) {
            final pId = p['id'] as int;
            final stock = (p['stock'] as num?)?.toDouble() ?? 0.0;
            await txn.insert(AppConstants.tblWarehouseStocks, {
              'warehouse_id': wId,
              'product_id': pId,
              'stock': stock,
            });
          }
        }
      });
    }
  }

  Future<void> _createSyncTable(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name   TEXT    NOT NULL,
        record_id    INTEGER NOT NULL,
        operation    TEXT    NOT NULL,
        payload      TEXT,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  // ── Generic CRUD ───────────────────────────────────────────────────────────
  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (table != 'sync_queue') {
      await _enforceFreeLimits(table);
    }
    final db = await database;
    final id = await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    if (id > 0) {
      notify(table);
      if (table != 'sync_queue') {
        await _addToSyncQueue(table, id, 'INSERT', data);
      }
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> queryAll(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit, offset: offset);
  }

  Future<Map<String, dynamic>?> queryById(String table, int id) async {
    final db = await database;
    final r = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> update(String table, Map<String, dynamic> data, int id) async {
    final db = await database;
    final count = await db.update(table, data, where: 'id = ?', whereArgs: [id]);
    if (count > 0) {
      notify(table);
      await _addToSyncQueue(table, id, 'UPDATE', data);
    }
    return count;
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    final count = await db.delete(table, where: 'id = ?', whereArgs: [id]);
    if (count > 0) {
      notify(table);
      await _addToSyncQueue(table, id, 'DELETE', null);
    }
    return count;
  }

  Future<void> _enforceFreeLimits(String table) async {
    final prefs = await SharedPreferences.getInstance();
    final tier = prefs.getString('subscription_tier') ?? 'free';
    if (tier == 'pro') return;

    if (table == AppConstants.tblProducts) {
      final countResult = await rawQuery('SELECT COUNT(*) as count FROM ${AppConstants.tblProducts} WHERE is_active = 1');
      final count = countResult.isNotEmpty ? (countResult.first['count'] as int) : 0;
      if (count >= 10) {
        throw Exception('Free tier limit reached: Maximum 10 products allowed. Please upgrade to Pro.');
      }
    } else if (table == AppConstants.tblSales) {
      final countResult = await rawQuery('SELECT COUNT(*) as count FROM ${AppConstants.tblSales}');
      final count = countResult.isNotEmpty ? (countResult.first['count'] as int) : 0;
      if (count >= 10) {
        throw Exception('Free tier limit reached: Maximum 10 sales invoices allowed. Please upgrade to Pro.');
      }
    } else if (table == AppConstants.tblCustomers) {
      final countResult = await rawQuery('SELECT COUNT(*) as count FROM ${AppConstants.tblCustomers}');
      final count = countResult.isNotEmpty ? (countResult.first['count'] as int) : 0;
      if (count >= 10) {
        throw Exception('Free tier limit reached: Maximum 10 customers allowed. Please upgrade to Pro.');
      }
    } else if (table == AppConstants.tblOffers) {
      throw Exception('Offers & Promotions require a Pro subscription. Please upgrade.');
    } else if (table == AppConstants.tblLoyaltySettings) {
      throw Exception('Loyalty Program configuration requires a Pro subscription. Please upgrade.');
    }
  }

  Future<void> _addToSyncQueue(String table, int recordId, String operation, Map<String, dynamic>? data) async {
    final prefs = await SharedPreferences.getInstance();
    final tier = prefs.getString('subscription_tier') ?? 'free';
    if (tier != 'pro') return;

    final syncable = [
      AppConstants.tblCategories,
      AppConstants.tblProducts,
      AppConstants.tblCustomers,
      AppConstants.tblSuppliers,
      AppConstants.tblSales,
      AppConstants.tblSaleItems,
      AppConstants.tblPurchases,
      AppConstants.tblPurchaseItems,
      AppConstants.tblLedger,
      AppConstants.tblAccounts,
      AppConstants.tblExpenses,
      AppConstants.tblTransactions,
      AppConstants.tblCustomerDiscounts,
      AppConstants.tblProductDiscounts,
      AppConstants.tblOffers,
      AppConstants.tblLoyaltySettings,
      AppConstants.tblAppSettings,
    ];

    if (!syncable.contains(table)) return;

    final db = await database;
    await db.insert('sync_queue', {
      'table_name': table,
      'record_id': recordId,
      'operation': operation,
      'payload': data != null ? jsonEncode(data) : null,
    });
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<int> rawInsert(String sql, [List<dynamic>? args]) async {
    final db = await database;
    final id = await db.rawInsert(sql, args);
    if (id > 0) {
      // Try to extract table name from SQL (rough heuristic)
      final match = RegExp(r'INSERT\s+INTO\s+([a-zA-Z0-9_]+)', caseSensitive: false).firstMatch(sql);
      if (match != null) {
        notify(match.group(1)!);
      } else {
        notify('unknown');
      }
    }
    return id;
  }

  Future<int> rawUpdate(String sql, [List<dynamic>? args]) async {
    final db = await database;
    final count = await db.rawUpdate(sql, args);
    if (count > 0) {
      final match = RegExp(r'UPDATE\s+([a-zA-Z0-9_]+)', caseSensitive: false).firstMatch(sql);
      if (match != null) {
        notify(match.group(1)!);
      } else {
        notify('unknown');
      }
    }
    return count;
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static Future<void> resetDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'BizNext', AppConstants.dbName);
    
    // Close existing connection
    await instance.close();
    
    // Delete the file
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ── Secure Deletion ────────────────────────────────────────────────────────
  Future<void> resetSoftware() async {
    await resetDatabase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> resetAccountData(String username) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Find the user
      final users = await txn.query(AppConstants.tblUsers, where: 'username = ?', whereArgs: [username]);
      if (users.isEmpty) return false;
      final userId = users.first['id'] as int;

      // Find all businesses owned by this user
      final businesses = await txn.query(AppConstants.tblBusinesses, where: 'owner_id = ?', whereArgs: [userId]);
      final businessIds = businesses.map((b) => b['id'] as int).toList();

      // Delete all data for these businesses
      for (final bid in businessIds) {
        // Data linked to business_id
        final tables = [
          AppConstants.tblSales,
          AppConstants.tblSaleItems, // Note: Sale items might not have business_id, but they CASCADE from sales
          AppConstants.tblPurchases,
          AppConstants.tblPurchaseItems,
          AppConstants.tblProducts,
          AppConstants.tblCategories,
          AppConstants.tblCustomers,
          AppConstants.tblSuppliers,
          AppConstants.tblAccounts,
          AppConstants.tblLedger,
          AppConstants.tblLoyaltySettings,
          AppConstants.tblPriceCategories,
          AppConstants.tblAppSettings,
          AppConstants.tblExpenses,
          AppConstants.tblExpenseCategories,
          AppConstants.tblTransactions,
          AppConstants.tblTransactionCategories,
          AppConstants.tblCustomerDiscounts,
          AppConstants.tblProductDiscounts,
          AppConstants.tblOffers,
          AppConstants.tblRestaurantTables,
          AppConstants.tblKot,
          AppConstants.tblKotItems,
        ];

        for (final table in tables) {
          try {
            await txn.delete(table, where: 'business_id = ?', whereArgs: [bid]);
          } catch (_) {
            // Some tables might not have business_id or might be deleted via CASCADE
          }
        }
      }

      // Delete the businesses themselves
      await txn.delete(AppConstants.tblBusinesses, where: 'owner_id = ?', whereArgs: [userId]);
      
      // Delete user-business associations
      await txn.delete(AppConstants.tblUserBusinesses, where: 'user_id = ?', whereArgs: [userId]);

      // NOTE: We no longer delete the user record itself (tblUsers)
      // as per user request to keep the account but delete its data.
      
      return true;
    });
  }

  Future<void> resetBusinessData(int businessId) async {
    final db = await database;
    await db.transaction((txn) async {
      final tables = [
        AppConstants.tblSales,
        AppConstants.tblPurchases,
        AppConstants.tblProducts,
        AppConstants.tblCategories,
        AppConstants.tblCustomers,
        AppConstants.tblSuppliers,
        AppConstants.tblAccounts,
        AppConstants.tblLedger,
        AppConstants.tblLoyaltySettings,
        AppConstants.tblPriceCategories,
        AppConstants.tblAppSettings,
        AppConstants.tblExpenses,
        AppConstants.tblExpenseCategories,
        AppConstants.tblTransactions,
        AppConstants.tblTransactionCategories,
        AppConstants.tblCustomerDiscounts,
        AppConstants.tblProductDiscounts,
        AppConstants.tblOffers,
        AppConstants.tblRestaurantTables,
        AppConstants.tblKot,
        AppConstants.tblKotItems,
      ];

      // Disable foreign keys temporarily to avoid constraint errors during bulk delete
      await txn.execute('PRAGMA foreign_keys = OFF');

      for (final table in tables) {
        try {
          await txn.delete(table, where: 'business_id = ?', whereArgs: [businessId]);
        } catch (_) {
          // If a table doesn't have business_id, it should be deleted via CASCADE from its parent
        }
      }

      // Re-enable foreign keys
      await txn.execute('PRAGMA foreign_keys = ON');

      // Re-seed all default data for this business
      await seedBusinessDefaults(businessId, txn: txn);
    });
  }

  /// Seeds all default data for a business (Categories, Accounts, Settings)
  Future<void> seedBusinessDefaults(int businessId, {Transaction? txn}) async {
    final database = txn ?? await this.database;

    // 1. Product Categories
    for (final cat in ['Electronics', 'Clothing', 'Food & Beverages', 'Stationery', 'General']) {
      await database.rawInsert(
        'INSERT OR IGNORE INTO ${AppConstants.tblCategories} (business_id, name) VALUES (?, ?)',
        [businessId, cat],
      );
    }

    // 2. Default Accounts
    await database.rawInsert('''
      INSERT OR IGNORE INTO ${AppConstants.tblAccounts} (business_id, name, type, balance, is_default)
      VALUES (?, ?, ?, ?, ?)
    ''', [businessId, 'Main Cash', 'Cash', 0.0, 1]);
    
    await database.rawInsert('''
      INSERT OR IGNORE INTO ${AppConstants.tblAccounts} (business_id, name, type, balance, is_default)
      VALUES (?, ?, ?, ?, ?)
    ''', [businessId, 'Primary Bank', 'Bank', 0.0, 0]);

    // 3. Expense Categories
    for (final cat in ['Rent', 'Salary', 'Utilities', 'Transport', 'Maintenance', 'Marketing', 'Other']) {
      await database.rawInsert(
        'INSERT OR IGNORE INTO ${AppConstants.tblExpenseCategories} (business_id, name) VALUES (?, ?)',
        [businessId, cat],
      );
    }

    // 4. App Settings
    final defaultSettings = {
      'customer_discount_enabled': '1',
      'product_discount_enabled': '1',
      'offers_enabled': '1',
      'loyalty_enabled': '0',
      'gst_enabled': '1',
      'inventory_tracking_enabled': '1',
      'notifications_enabled': '0',
    };
    for (var entry in defaultSettings.entries) {
      await database.insert(AppConstants.tblAppSettings, {
        'business_id': businessId,
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 5. Loyalty Settings
    await database.insert(AppConstants.tblLoyaltySettings, {
      'business_id': businessId,
      'earn_rate': 1.0,
      'redeem_value': 1.0,
      'min_redeem_pts': 100,
      'is_active': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 6. Default Warehouse
    await database.insert(AppConstants.tblWarehouses, {
      'business_id': businessId,
      'name': 'Default Warehouse',
      'code': 'WH-DF',
      'address': 'Main Business Location',
      'is_active': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

// ── Web Fallback Mock Database Implementation ────────────────────────────────

class MockDatabase implements Database {
  @override
  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async {
    if (table == AppConstants.tblUsers) {
      return [
        {
          'id': 1,
          'username': 'admin',
          'password_hash': DatabaseHelper.hashPassword('admin123'),
          'full_name': 'Admin User',
          'role': AppConstants.roleOwner,
          'is_active': 1,
        }
      ];
    }
    if (table == AppConstants.tblBusinesses) {
      return [
        {
          'id': 1,
          'name': 'Demo Business',
          'type': 'Retail Shop',
          'owner_id': 1,
          'is_active': 1,
        }
      ];
    }
    if (table == AppConstants.tblUserBusinesses) {
      return [
        {
          'id': 1,
          'user_id': 1,
          'business_id': 1,
          'role': AppConstants.roleOwner,
        }
      ];
    }
    if (table == AppConstants.tblAppSettings) {
      return [
        {'key': 'customer_discount_enabled', 'value': '1'},
        {'key': 'product_discount_enabled', 'value': '1'},
        {'key': 'offers_enabled', 'value': '1'},
        {'key': 'loyalty_enabled', 'value': '0'},
        {'key': 'gst_enabled', 'value': '1'},
        {'key': 'inventory_tracking_enabled', 'value': '1'},
        {'key': 'notifications_enabled', 'value': '0'},
      ];
    }
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (sql.contains(AppConstants.tblUsers)) {
      return [
        {
          'id': 1,
          'username': 'admin',
          'password_hash': DatabaseHelper.hashPassword('admin123'),
          'full_name': 'Admin User',
          'role': AppConstants.roleOwner,
          'is_active': 1,
        }
      ];
    }
    return [];
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    final mockTxn = MockTransaction();
    return await action(mockTxn as Transaction);
  }

  @override
  Batch batch() => MockBatch();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains("insert") || name.contains("update") || name.contains("delete")) {
      return Future.value(1);
    }
    if (name.contains("execute")) {
      return Future.value();
    }
    if (name.contains("isOpen")) {
      return true;
    }
    if (name.contains("path")) {
      return "in_memory";
    }
    return super.noSuchMethod(invocation);
  }
}

class MockTransaction implements Transaction {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains("query") || name.contains("rawQuery")) {
      return Future.value(<Map<String, Object?>>[]);
    }
    if (name.contains("insert") || name.contains("update") || name.contains("delete") || name.contains("rawInsert")) {
      return Future.value(1);
    }
    if (name.contains("execute")) {
      return Future.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class MockBatch implements Batch {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #commit) {
      return Future.value(<Object?>[]);
    }
    return null;
  }
}
