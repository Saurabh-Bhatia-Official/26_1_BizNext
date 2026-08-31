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
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ${AppConstants.tblNotifications} (
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
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id   INTEGER NOT NULL DEFAULT 1,
        name          TEXT    NOT NULL,
        code          TEXT,
        description   TEXT,
        image_path    TEXT,
        display_order INTEGER NOT NULL DEFAULT 0,
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, name)
      )
    ''');

    // Subcategories
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblSubcategories} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        category_id INTEGER NOT NULL REFERENCES ${AppConstants.tblCategories}(id) ON DELETE CASCADE,
        name        TEXT    NOT NULL,
        code        TEXT,
        description TEXT,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, category_id, name)
      )
    ''');

    // Products
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblProducts} (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id         INTEGER NOT NULL DEFAULT 1,
        name                TEXT    NOT NULL,
        sku                 TEXT,
        barcode             TEXT,
        description         TEXT,
        category_id         INTEGER REFERENCES ${AppConstants.tblCategories}(id) ON DELETE SET NULL,
        subcategory_id      INTEGER REFERENCES ${AppConstants.tblSubcategories}(id) ON DELETE SET NULL,
        brand               TEXT,
        unit                TEXT    NOT NULL DEFAULT 'pcs',
        hsn_sac             TEXT,
        gst_percent         REAL    NOT NULL DEFAULT 0,
        purchase_price      REAL    NOT NULL DEFAULT 0,
        mrp                 REAL    NOT NULL DEFAULT 0,
        selling_price       REAL    NOT NULL DEFAULT 0,
        min_selling_price   REAL    NOT NULL DEFAULT 0,
        wholesale_price     REAL    NOT NULL DEFAULT 0,
        dealer_price        REAL    NOT NULL DEFAULT 0,
        stock               REAL    NOT NULL DEFAULT 0,
        min_stock           REAL    NOT NULL DEFAULT 5,
        default_supplier_id INTEGER REFERENCES ${AppConstants.tblSuppliers}(id) ON DELETE SET NULL,
        is_active           INTEGER NOT NULL DEFAULT 1,
        image_path          TEXT,
        created_at          TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at          TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
 
    // Customer Types (Pricing Categories)
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblCustomerTypes} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        name        TEXT    NOT NULL,
        code        TEXT,
        description TEXT,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, name)
      )
    ''');

    // Price Categories (Legacy Compatibility alias)
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblPriceCategories} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL DEFAULT 1,
        name        TEXT    NOT NULL,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, name)
      )
    ''');
 
    // Product Tiered Prices (Quantity Brackets)
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblProductPrices} (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id       INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
        category_id      INTEGER NOT NULL REFERENCES ${AppConstants.tblPriceCategories}(id) ON DELETE CASCADE,
        min_qty          REAL    NOT NULL DEFAULT 1,
        max_qty          REAL    NOT NULL DEFAULT 999999,
        price            REAL    NOT NULL DEFAULT 0,
        discount_percent REAL    NOT NULL DEFAULT 0,
        UNIQUE(product_id, category_id, min_qty)
      )
    ''');

    // Customers
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblCustomers} (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id      INTEGER NOT NULL DEFAULT 1,
        name             TEXT    NOT NULL,
        phone            TEXT,
        email            TEXT,
        address          TEXT,
        gst_number       TEXT,
        customer_type_id INTEGER REFERENCES ${AppConstants.tblCustomerTypes}(id) ON DELETE SET NULL,
        balance          REAL    NOT NULL DEFAULT 0,
        loyalty_points   REAL    NOT NULL DEFAULT 0,
        created_at       TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Suppliers
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblSuppliers} (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id     INTEGER NOT NULL DEFAULT 1,
        name            TEXT    NOT NULL,
        company_name    TEXT,
        gst_number      TEXT,
        pan             TEXT,
        contact_person  TEXT,
        phone           TEXT,
        email           TEXT,
        address         TEXT,
        state           TEXT,
        payment_terms   TEXT,
        credit_limit    REAL    NOT NULL DEFAULT 0,
        opening_balance REAL    NOT NULL DEFAULT 0,
        balance         REAL    NOT NULL DEFAULT 0,
        bank_details    TEXT,
        notes           TEXT,
        is_active       INTEGER NOT NULL DEFAULT 1,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Supplier Product Mapping
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblSupplierProducts} (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id         INTEGER NOT NULL DEFAULT 1,
        supplier_id         INTEGER NOT NULL REFERENCES ${AppConstants.tblSuppliers}(id) ON DELETE CASCADE,
        product_id          INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
        supplier_sku        TEXT,
        supplier_barcode    TEXT,
        last_purchase_price REAL    NOT NULL DEFAULT 0,
        last_purchase_date  TEXT,
        last_purchase_qty   REAL    NOT NULL DEFAULT 0,
        created_at          TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(business_id, supplier_id, product_id)
      )
    ''');

    // Product Batches (FEFO & Expiry Management)
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblProductBatches} (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id   INTEGER NOT NULL DEFAULT 1,
        product_id    INTEGER NOT NULL REFERENCES ${AppConstants.tblProducts}(id) ON DELETE CASCADE,
        batch_number  TEXT    NOT NULL,
        mfg_date      TEXT,
        expiry_date   TEXT,
        purchase_rate REAL    NOT NULL DEFAULT 0,
        quantity      REAL    NOT NULL DEFAULT 0,
        supplier_id   INTEGER REFERENCES ${AppConstants.tblSuppliers}(id) ON DELETE SET NULL,
        warehouse_id  INTEGER REFERENCES ${AppConstants.tblWarehouses}(id) ON DELETE SET NULL,
        created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
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

    // Notifications Table
    await _safeExecute(txn, '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tblNotifications} (
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
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_subcategories_cat ON ${AppConstants.tblSubcategories}(category_id)');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_supplier_products ON ${AppConstants.tblSupplierProducts}(supplier_id, product_id)');
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

    if (oldVersion < 23) {
      await db.transaction((txn) async {
        // 1. Safe ALTER TABLE on categories
        for (final colSql in [
          'ALTER TABLE ${AppConstants.tblCategories} ADD COLUMN code TEXT',
          'ALTER TABLE ${AppConstants.tblCategories} ADD COLUMN image_path TEXT',
          'ALTER TABLE ${AppConstants.tblCategories} ADD COLUMN display_order INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE ${AppConstants.tblCategories} ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        ]) {
          try { await txn.execute(colSql); } catch (_) {}
        }

        // 2. Safe ALTER TABLE on products
        for (final colSql in [
          'ALTER TABLE ${AppConstants.tblProducts} ADD COLUMN subcategory_id INTEGER REFERENCES ${AppConstants.tblSubcategories}(id) ON DELETE SET NULL',
          'ALTER TABLE ${AppConstants.tblProducts} ADD COLUMN brand TEXT',
          'ALTER TABLE ${AppConstants.tblProducts} ADD COLUMN hsn_sac TEXT',
          'ALTER TABLE ${AppConstants.tblProducts} ADD COLUMN mrp REAL NOT NULL DEFAULT 0',
          'ALTER TABLE ${AppConstants.tblProducts} ADD COLUMN min_selling_price REAL NOT NULL DEFAULT 0',
          'ALTER TABLE ${AppConstants.tblProducts} ADD COLUMN default_supplier_id INTEGER REFERENCES ${AppConstants.tblSuppliers}(id) ON DELETE SET NULL',
        ]) {
          try { await txn.execute(colSql); } catch (_) {}
        }

        // 3. Safe ALTER TABLE on suppliers
        for (final colSql in [
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN company_name TEXT',
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN pan TEXT',
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN contact_person TEXT',
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN state TEXT',
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN payment_terms TEXT',
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN credit_limit REAL NOT NULL DEFAULT 0',
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN opening_balance REAL NOT NULL DEFAULT 0',
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN bank_details TEXT',
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN notes TEXT',
          'ALTER TABLE ${AppConstants.tblSuppliers} ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        ]) {
          try { await txn.execute(colSql); } catch (_) {}
        }

        // 4. Safe ALTER TABLE on customers
        for (final colSql in [
          'ALTER TABLE ${AppConstants.tblCustomers} ADD COLUMN customer_type_id INTEGER REFERENCES ${AppConstants.tblCustomerTypes}(id) ON DELETE SET NULL',
        ]) {
          try { await txn.execute(colSql); } catch (_) {}
        }

        // 5. Safe ALTER TABLE on product_tiered_prices
        for (final colSql in [
          'ALTER TABLE ${AppConstants.tblProductPrices} ADD COLUMN min_qty REAL NOT NULL DEFAULT 1',
          'ALTER TABLE ${AppConstants.tblProductPrices} ADD COLUMN max_qty REAL NOT NULL DEFAULT 999999',
          'ALTER TABLE ${AppConstants.tblProductPrices} ADD COLUMN discount_percent REAL NOT NULL DEFAULT 0',
        ]) {
          try { await txn.execute(colSql); } catch (_) {}
        }

        // 6. Create new tables
        await _createDataTables(txn);
        await _createIndexes(txn);

        // 7. Seed default customer types for existing businesses
        final businesses = await txn.query(AppConstants.tblBusinesses);
        for (var b in businesses) {
          final bId = b['id'] as int;
          final types = [
            {'name': 'Retail', 'code': 'RET'},
            {'name': 'Wholesale', 'code': 'WHOLE'},
            {'name': 'Dealer', 'code': 'DEAL'},
            {'name': 'Distributor', 'code': 'DIST'},
            {'name': 'Special', 'code': 'SPEC'},
          ];
          for (var t in types) {
            await txn.rawInsert(
              'INSERT OR IGNORE INTO ${AppConstants.tblCustomerTypes} (business_id, name, code) VALUES (?, ?, ?)',
              [bId, t['name'], t['code']],
            );
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
  Future<int?> getActiveBusinessId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.prefBusinessId);
  }

  bool _isBusinessScopedTable(String table) {
    const scopedTables = {
      AppConstants.tblCategories,
      AppConstants.tblSubcategories,
      AppConstants.tblProducts,
      AppConstants.tblPriceCategories,
      AppConstants.tblProductPrices,
      AppConstants.tblCustomerTypes,
      AppConstants.tblCustomers,
      AppConstants.tblSuppliers,
      AppConstants.tblSupplierProducts,
      AppConstants.tblProductBatches,
      AppConstants.tblSales,
      AppConstants.tblPurchases,
      AppConstants.tblLedger,
      AppConstants.tblAccounts,
      AppConstants.tblExpenses,
      AppConstants.tblExpenseCategories,
      AppConstants.tblTransactions,
      AppConstants.tblTransactionCategories,
      AppConstants.tblCustomerDiscounts,
      AppConstants.tblProductDiscounts,
      AppConstants.tblOffers,
      AppConstants.tblLoyaltySettings,
      AppConstants.tblAppSettings,
      AppConstants.tblBudgets,
      AppConstants.tblInventoryTransactions,
      AppConstants.tblPurchaseReturns,
      AppConstants.tblSalesReturns,
      AppConstants.tblWarehouses,
    };
    return scopedTables.contains(table);
  }

  Map<String, dynamic> _scopeWhereClause(String? where, List<dynamic>? whereArgs, int businessId) {
    if (where == null || where.trim().isEmpty) {
      return {
        'where': 'business_id = ?',
        'whereArgs': [businessId],
      };
    }
    if (where.contains('business_id')) {
      return {
        'where': where,
        'whereArgs': whereArgs,
      };
    }
    return {
      'where': '($where) AND business_id = ?',
      'whereArgs': [...?whereArgs, businessId],
    };
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (table != 'sync_queue') {
      await _enforceFreeLimits(table);
    }
    final db = await database;
    final activeBizId = await getActiveBusinessId();
    final Map<String, dynamic> securedData = Map<String, dynamic>.from(data);
    if (activeBizId != null && _isBusinessScopedTable(table)) {
      securedData['business_id'] = activeBizId;
    }
    final id = await db.insert(table, securedData, conflictAlgorithm: ConflictAlgorithm.replace);
    if (id > 0) {
      notify(table);
      if (table != 'sync_queue') {
        await _addToSyncQueue(table, id, 'INSERT', securedData);
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
    final activeBizId = await getActiveBusinessId();
    if (activeBizId != null && _isBusinessScopedTable(table)) {
      final queryParams = _scopeWhereClause(where, whereArgs, activeBizId);
      final scopedWhere = queryParams['where'] as String?;
      final scopedWhereArgs = queryParams['whereArgs'] as List<dynamic>?;
      return db.query(table, where: scopedWhere, whereArgs: scopedWhereArgs, orderBy: orderBy, limit: limit, offset: offset);
    }
    return db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit, offset: offset);
  }

  Future<Map<String, dynamic>?> queryById(String table, int id) async {
    final db = await database;
    final activeBizId = await getActiveBusinessId();
    if (activeBizId != null && _isBusinessScopedTable(table)) {
      final r = await db.query(table, where: 'id = ? AND business_id = ?', whereArgs: [id, activeBizId]);
      return r.isNotEmpty ? r.first : null;
    }
    final r = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> update(String table, Map<String, dynamic> data, int id) async {
    final db = await database;
    final activeBizId = await getActiveBusinessId();
    
    if (activeBizId != null) {
      if (_isBusinessScopedTable(table)) {
        final updatedData = Map<String, dynamic>.from(data);
        updatedData['business_id'] = activeBizId;
        final count = await db.update(table, updatedData, where: 'id = ? AND business_id = ?', whereArgs: [id, activeBizId]);
        if (count > 0) {
          notify(table);
          await _addToSyncQueue(table, id, 'UPDATE', updatedData);
        }
        return count;
      }
      if (table == AppConstants.tblBusinesses && id != activeBizId) {
        throw Exception("Security violation: Unauthorized attempt to modify business ID $id.");
      }
    }

    final count = await db.update(table, data, where: 'id = ?', whereArgs: [id]);
    if (count > 0) {
      notify(table);
      await _addToSyncQueue(table, id, 'UPDATE', data);
    }
    return count;
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    final activeBizId = await getActiveBusinessId();
    
    if (activeBizId != null) {
      if (_isBusinessScopedTable(table)) {
        final count = await db.delete(table, where: 'id = ? AND business_id = ?', whereArgs: [id, activeBizId]);
        if (count > 0) {
          notify(table);
          await _addToSyncQueue(table, id, 'DELETE', null);
        }
        return count;
      }
      if (table == AppConstants.tblBusinesses && id != activeBizId) {
        throw Exception("Security violation: Unauthorized attempt to delete business ID $id.");
      }
    }

    final count = await db.delete(table, where: 'id = ?', whereArgs: [id]);
    if (count > 0) {
      notify(table);
      await _addToSyncQueue(table, id, 'DELETE', null);
    }
    return count;
  }

  Future<void> _enforceFreeLimits(String table) async {
    // Limits removed - all features are completely unlocked
  }

  Future<void> _addToSyncQueue(String table, int recordId, String operation, Map<String, dynamic>? data) async {
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
      final businessIds = businesses.map((b) => (b['id'] as num?)?.toInt()).whereType<int>().toList();

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
          AppConstants.tblWarehouses,
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
        AppConstants.tblWarehouses,
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

    // 1. Product Categories & Subcategories
    for (final cat in ['Electronics', 'Clothing', 'Food & Beverages', 'Stationery', 'General']) {
      final catId = await database.rawInsert(
        'INSERT OR IGNORE INTO ${AppConstants.tblCategories} (business_id, name, is_active) VALUES (?, ?, 1)',
        [businessId, cat],
      );
      if (cat == 'Electronics') {
        final actualCatId = catId > 0 ? catId : 1;
        for (final sub in ['Mobile', 'Accessories', 'Computers']) {
          await database.rawInsert(
            'INSERT OR IGNORE INTO ${AppConstants.tblSubcategories} (business_id, category_id, name, is_active) VALUES (?, ?, ?, 1)',
            [businessId, actualCatId, sub],
          );
        }
      }
    }

    // 2. Default Customer Types
    final defaultTypes = [
      {'name': 'Retail', 'code': 'RET'},
      {'name': 'Wholesale', 'code': 'WHOLE'},
      {'name': 'Dealer', 'code': 'DEAL'},
      {'name': 'Distributor', 'code': 'DIST'},
      {'name': 'Special', 'code': 'SPEC'},
    ];
    for (final t in defaultTypes) {
      await database.rawInsert(
        'INSERT OR IGNORE INTO ${AppConstants.tblCustomerTypes} (business_id, name, code, is_active) VALUES (?, ?, ?, 1)',
        [businessId, t['name'], t['code']],
      );
    }

    // 3. Default Accounts
    await database.rawInsert('''
      INSERT OR IGNORE INTO ${AppConstants.tblAccounts} (business_id, name, type, balance, is_default)
      VALUES (?, ?, ?, ?, ?)
    ''', [businessId, 'Main Cash', 'Cash', 0.0, 1]);
    
    await database.rawInsert('''
      INSERT OR IGNORE INTO ${AppConstants.tblAccounts} (business_id, name, type, balance, is_default)
      VALUES (?, ?, ?, ?, ?)
    ''', [businessId, 'Primary Bank', 'Bank', 0.0, 0]);

    // 4. Expense Categories
    for (final cat in ['Rent', 'Salary', 'Utilities', 'Transport', 'Maintenance', 'Marketing', 'Other']) {
      await database.rawInsert(
        'INSERT OR IGNORE INTO ${AppConstants.tblExpenseCategories} (business_id, name) VALUES (?, ?)',
        [businessId, cat],
      );
    }

    // 5. App Settings
    final defaultSettings = {
      'customer_discount_enabled': '1',
      'product_discount_enabled': '1',
      'offers_enabled': '1',
      'loyalty_enabled': '0',
      'gst_enabled': '1',
      'inventory_tracking_enabled': '1',
      'notifications_enabled': '0',
      'allow_negative_stock': '0',
    };
    for (var entry in defaultSettings.entries) {
      await database.insert(AppConstants.tblAppSettings, {
        'business_id': businessId,
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 6. Loyalty Settings
    await database.insert(AppConstants.tblLoyaltySettings, {
      'business_id': businessId,
      'earn_rate': 1.0,
      'redeem_value': 1.0,
      'min_redeem_pts': 100,
      'is_active': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 7. Default Warehouse
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
  static final Map<String, List<Map<String, dynamic>>> _cache = {};

  Future<List<Map<String, dynamic>>> _getTable(String table) async {
    if (_cache.containsKey(table)) {
      return _cache[table]!;
    }
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mock_db_$table');
    List<Map<String, dynamic>> list = [];
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    } else {
      if (table == AppConstants.tblUsers) {
        list = [
          {
            'id': 1,
            'username': 'admin',
            'password_hash': DatabaseHelper.hashPassword('admin123'),
            'full_name': 'Admin User',
            'role': AppConstants.roleOwner,
            'is_active': 1,
          }
        ];
      } else if (table == AppConstants.tblBusinesses) {
        list = [
          {
            'id': 1,
            'name': 'Demo Business',
            'type': 'Retail Shop',
            'owner_id': 1,
            'is_active': 1,
          }
        ];
      } else if (table == AppConstants.tblUserBusinesses) {
        list = [
          {
            'id': 1,
            'user_id': 1,
            'business_id': 1,
            'role': AppConstants.roleOwner,
          }
        ];
      } else if (table == AppConstants.tblAppSettings) {
        list = [
          {'key': 'customer_discount_enabled', 'value': '1'},
          {'key': 'product_discount_enabled', 'value': '1'},
          {'key': 'offers_enabled', 'value': '1'},
          {'key': 'loyalty_enabled', 'value': '0'},
          {'key': 'gst_enabled', 'value': '1'},
          {'key': 'inventory_tracking_enabled', 'value': '1'},
          {'key': 'notifications_enabled', 'value': '0'},
        ];
      }
      prefs.setString('mock_db_$table', jsonEncode(list));
    }
    _cache[table] = list;
    return list;
  }

  Future<void> _saveTable(String table, List<Map<String, dynamic>> data) async {
    _cache[table] = data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mock_db_$table', jsonEncode(data));
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    final list = await _getTable(table);
    final row = Map<String, dynamic>.from(values);
    if (!row.containsKey('id')) {
      row['id'] = list.isEmpty ? 1 : (list.map((e) => (e['id'] as num?)?.toInt() ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    } else {
      final existingIndex = list.indexWhere((e) => e['id'] == row['id']);
      if (existingIndex != -1) {
        list[existingIndex] = row;
        await _saveTable(table, list);
        return row['id'] as int;
      }
    }
    list.add(row);
    await _saveTable(table, list);
    return row['id'] as int;
  }

  @override
  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async {
    final list = await _getTable(table);
    var filtered = List<Map<String, dynamic>>.from(list);
    
    if (where != null && whereArgs != null) {
      final parts = where.split('AND');
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i].trim();
        if (part.contains('=')) {
          final key = part.split('=').first.trim().replaceAll('(', '').replaceAll(')', '');
          if (i < whereArgs.length) {
            final val = whereArgs[i];
            filtered = filtered.where((row) => row[key]?.toString() == val?.toString()).toList();
          }
        }
      }
    }

    if (limit != null) {
      filtered = filtered.take(limit).toList();
    }
    return filtered.map((e) => Map<String, Object?>.from(e)).toList();
  }

  @override
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    final list = await _getTable(table);
    int count = 0;
    
    for (var i = 0; i < list.length; i++) {
      bool matches = true;
      if (where != null && whereArgs != null) {
        final parts = where.split('AND');
        for (var j = 0; j < parts.length; j++) {
          final part = parts[j].trim();
          if (part.contains('=')) {
            final key = part.split('=').first.trim().replaceAll('(', '').replaceAll(')', '');
            if (j < whereArgs.length) {
              final val = whereArgs[j];
              if (list[i][key]?.toString() != val?.toString()) {
                matches = false;
              }
            }
          }
        }
      }
      if (matches) {
        list[i] = {...list[i], ...values};
        count++;
      }
    }
    await _saveTable(table, list);
    return count;
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final list = await _getTable(table);
    final initialLength = list.length;
    
    if (where == null) {
      await _saveTable(table, []);
      return initialLength;
    }

    list.removeWhere((row) {
      bool matches = true;
      if (whereArgs != null) {
        final parts = where.split('AND');
        for (var j = 0; j < parts.length; j++) {
          final part = parts[j].trim();
          if (part.contains('=')) {
            final key = part.split('=').first.trim().replaceAll('(', '').replaceAll(')', '');
            if (j < whereArgs.length) {
              final val = whereArgs[j];
              if (row[key]?.toString() != val?.toString()) {
                matches = false;
              }
            }
          }
        }
      }
      return matches;
    });
    
    await _saveTable(table, list);
    return initialLength - list.length;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final lowerSql = sql.toLowerCase();
    String? matchedTable;
    for (var table in [
      AppConstants.tblUsers, AppConstants.tblBusinesses, AppConstants.tblUserBusinesses,
      AppConstants.tblCategories, AppConstants.tblSubcategories, AppConstants.tblProducts, AppConstants.tblPriceCategories,
      AppConstants.tblProductPrices, AppConstants.tblCustomerTypes, AppConstants.tblCustomers, AppConstants.tblSuppliers,
      AppConstants.tblSupplierProducts, AppConstants.tblProductBatches, AppConstants.tblSales,
      AppConstants.tblSaleItems, AppConstants.tblPurchases, AppConstants.tblPurchaseItems,
      AppConstants.tblLedger, AppConstants.tblAccounts, AppConstants.tblExpenses,
      AppConstants.tblAppSettings, AppConstants.tblBudgets, AppConstants.tblOffers,
      AppConstants.tblLoyaltySettings, AppConstants.tblTransactions, AppConstants.tblInventoryTransactions,
    ]) {
      if (lowerSql.contains(table)) {
        matchedTable = table;
        break;
      }
    }

    if (matchedTable != null) {
      var list = await _getTable(matchedTable);
      
      // Filter list based on arguments
      if (arguments != null && arguments.isNotEmpty) {
        if (lowerSql.contains('business_id = ?') || lowerSql.contains('business_id =')) {
          final bizId = arguments.first;
          list = list.where((row) => row['business_id']?.toString() == bizId?.toString()).toList();
        } else if (lowerSql.contains('username = ?') || lowerSql.contains('username =')) {
          list = list.where((row) => row['username'] == arguments.first).toList();
        }

        // Apply date filter logic for stats/dashboard (date >= ? and date < ?)
        if (lowerSql.contains('date >= ?') && arguments.length > 1) {
          final dateStartStr = arguments[1] as String?;
          if (dateStartStr != null) {
            list = list.where((row) {
              final rowDate = row['date'];
              if (rowDate is String) {
                return rowDate.compareTo(dateStartStr) >= 0;
              }
              return true;
            }).toList();
          }
        }
        if (lowerSql.contains('date < ?') && arguments.length > 2) {
          final dateEndStr = arguments[2] as String?;
          if (dateEndStr != null) {
            list = list.where((row) {
              final rowDate = row['date'];
              if (rowDate is String) {
                return rowDate.compareTo(dateEndStr) < 0;
              }
              return true;
            }).toList();
          }
        }
      }

      // Check for aggregates
      if (lowerSql.contains('sum(') || lowerSql.contains('count(')) {
        final Map<String, Object?> resultRow = {};

        // Find all aliases in the SQL query dynamically
        // Matches e.g. "as total", "as net_sales", "as gst", "as discount", "as count"
        final aliasMatches = RegExp(r'as\s+(\w+)').allMatches(lowerSql);
        for (var m in aliasMatches) {
          final alias = m.group(1);
          if (alias != null) {
            resultRow[alias] = 0.0; // Default all double/numeric aggregates to 0.0 to prevent null checks throwing
          }
        }

        // 1. Check for count
        if (lowerSql.contains('count(*)')) {
          String alias = 'count';
          if (lowerSql.contains('as count')) alias = 'count';
          else if (lowerSql.contains('as transaction_count')) alias = 'transaction_count';
          else if (lowerSql.contains('as total_products')) alias = 'total_products';
          resultRow[alias] = list.length;
        }

        // 2. Check for inventory value
        if (lowerSql.contains('stock * purchase_price')) {
          double sum = 0.0;
          for (var row in list) {
            final stock = (row['stock'] as num?)?.toDouble() ?? 0.0;
            final price = (row['purchase_price'] as num?)?.toDouble() ?? 0.0;
            sum += stock * price;
          }
          resultRow['inventory_value'] = sum;
        }

        // 3. Check for low stock count
        if (lowerSql.contains('stock <= min_stock')) {
          int count = 0;
          for (var row in list) {
            final stock = (row['stock'] as num?)?.toDouble() ?? 0.0;
            final minStock = (row['min_stock'] as num?)?.toDouble() ?? 0.0;
            if (stock <= minStock) count++;
          }
          resultRow['low_stock_count'] = count;
        }

        // 4. Check for out of stock count
        if (lowerSql.contains('stock <= 0')) {
          int count = 0;
          for (var row in list) {
            final stock = (row['stock'] as num?)?.toDouble() ?? 0.0;
            if (stock <= 0) count++;
          }
          resultRow['out_of_stock_count'] = count;
        }

        // 5. Check for general sum(grand_total)
        if (lowerSql.contains('grand_total')) {
          double grandTotalSum = 0.0;
          double balanceDueSum = 0.0;
          double gstSum = 0.0;
          double discountSum = 0.0;
          double netSalesSum = 0.0;
          for (var row in list) {
            final gt = (row['grand_total'] as num?)?.toDouble() ?? 0.0;
            final gst = (row['gst_amount'] as num?)?.toDouble() ?? 0.0;
            final disc = (row['discount'] as num?)?.toDouble() ?? 0.0;
            grandTotalSum += gt;
            balanceDueSum += (row['balance_due'] as num?)?.toDouble() ?? 0.0;
            gstSum += gst;
            discountSum += disc;
            netSalesSum += (gt - gst);
          }
          if (lowerSql.contains('total_purchases')) {
            resultRow['total_purchases'] = grandTotalSum;
            resultRow['total_payable'] = balanceDueSum;
          } else {
            resultRow['total'] = grandTotalSum;
            resultRow['net_sales'] = netSalesSum;
            resultRow['gst'] = gstSum;
            resultRow['discount'] = discountSum;
          }
        }

        // 6. Check for general sum(amount)
        if (lowerSql.contains('amount')) {
          double amountSum = 0.0;
          for (var row in list) {
            amountSum += (row['amount'] as num?)?.toDouble() ?? 0.0;
          }
          resultRow['total'] = amountSum;
        }

        // 7. Check for general sum(balance)
        if (lowerSql.contains('balance')) {
          double balanceSum = 0.0;
          for (var row in list) {
            balanceSum += (row['balance'] as num?)?.toDouble() ?? 0.0;
          }
          resultRow['total'] = balanceSum;
        }

        // 8. Custom evaluation for cogsRes query (si.quantity * si.purchase_price)
        if (lowerSql.contains('quantity *')) {
          double cogsSum = 0.0;
          for (var row in list) {
            final qty = (row['quantity'] as num?)?.toDouble() ?? 0.0;
            final pPrice = (row['purchase_price'] as num?)?.toDouble() ?? 0.0;
            cogsSum += qty * pPrice;
          }
          resultRow['total'] = cogsSum;
        }

        return [resultRow];
      }

      if (arguments != null && arguments.isNotEmpty) {
        if (lowerSql.contains('username =')) {
          final filtered = list.where((row) => row['username'] == arguments[0]).toList();
          return filtered.map((e) => Map<String, Object?>.from(e)).toList();
        }
      }

      return list.map((e) => Map<String, Object?>.from(e)).toList();
    }
    return [];
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    final mockTxn = MockTransaction(this);
    return await action(mockTxn as Transaction);
  }

  @override
  Batch batch() => MockBatch();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
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
  final MockDatabase _db;
  MockTransaction(this._db);

  @override
  Future<int> insert(String table, Map<String, dynamic> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) =>
      _db.insert(table, values, nullColumnHack: nullColumnHack, conflictAlgorithm: conflictAlgorithm);

  @override
  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) =>
      _db.query(table, distinct: distinct, columns: columns, where: where, whereArgs: whereArgs, groupBy: groupBy, having: having, orderBy: orderBy, limit: limit, offset: offset);

  @override
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) =>
      _db.update(table, values, where: where, whereArgs: whereArgs, conflictAlgorithm: conflictAlgorithm);

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      _db.delete(table, where: where, whereArgs: whereArgs);

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) =>
      _db.rawQuery(sql, arguments);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains("execute") || name.contains("rawInsert") || name.contains("rawUpdate")) {
      return Future.value(1);
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
