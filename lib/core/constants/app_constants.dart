// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  static const String appName = 'BizNext';
  static const String appVersion = '1.0.0';

  // Database
  static const String dbName = 'biz_next.sys';
  static const int dbVersion = 22;
  static const String backupExtension = 'bzcfg';

  // ── Auth Tables ────────────────────────────────────────────────────────────
  static const String tblUsers = 'users';
  static const String tblBusinesses = 'businesses';
  static const String tblUserBusinesses = 'user_businesses';

  // ── Data Tables ────────────────────────────────────────────────────────────
  static const String tblCategories = 'categories';
  static const String tblProducts = 'products';
  static const String tblPriceCategories = 'price_categories';
  static const String tblProductPrices = 'product_tiered_prices';
  static const String tblCustomers = 'customers';
  static const String tblSuppliers = 'suppliers';
  static const String tblSales = 'sales';
  static const String tblSaleItems = 'sale_items';
  static const String tblPurchases = 'purchases';
  static const String tblPurchaseItems = 'purchase_items';
  static const String tblLedger = 'ledger';
  static const String tblAccounts = 'accounts'; // ADDED
  static const String tblExpenses = 'expenses';
  static const String tblExpenseCategories = 'expense_categories';
  static const String tblTransactions = 'transactions';
  static const String tblTransactionCategories = 'transaction_categories';
  static const String tblCustomerDiscounts = 'customer_discounts';
  static const String tblProductDiscounts = 'product_discounts';
  static const String tblOffers = 'offers';
  static const String tblLoyaltySettings = 'loyalty_settings';
  static const String tblAppSettings = 'app_settings';
  static const String tblBudgets = 'budgets';
  static const String tblInventoryTransactions = 'inventory_transactions';
  static const String tblAuditLogs = 'audit_logs';
  static const String tblPurchaseReturns = 'purchase_returns';
  static const String tblPurchaseReturnItems = 'purchase_return_items';
  static const String tblSalesReturns = 'sales_returns';
  static const String tblSalesReturnItems = 'sales_return_items';
  static const String tblWarehouses = 'warehouses';
  static const String tblWarehouseStocks = 'warehouse_stocks';
  static const String tblWarehouseTransfers = 'warehouse_transfers';
  static const String tblWarehouseTransferItems = 'warehouse_transfer_items';
  static const String tblInventoryAdjustments = 'inventory_adjustments';
  static const String tblInventoryAdjustmentItems = 'inventory_adjustment_items';


  // ── Restaurant Tables ──────────────────────────────────────────────────────
  static const String tblRestaurantTables = 'restaurant_tables';
  static const String tblKot = 'kot';
  static const String tblKotItems = 'kot_items';

  // ── SharedPreferences Keys ─────────────────────────────────────────────────
  static const String prefUserId = 'active_user_id';
  static const String prefBusinessId = 'active_business_id';
  static const String prefThemeMode = 'theme_mode';
  static const String prefSyncMode = 'sync_mode';

  // ── Payment Modes ──────────────────────────────────────────────────────────
  static const String paymentCash = 'Cash';
  static const String paymentCard = 'Card';
  static const String paymentUpi = 'UPI';
  static const String paymentCredit = 'Credit';

  static const List<String> paymentModes = [
    paymentCash,
    paymentCard,
    paymentUpi,
    paymentCredit,
  ];

  // ── User Roles ─────────────────────────────────────────────────────────────
  static const String roleOwner = 'owner';
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleCashier = 'cashier';
  static const String roleWaiter = 'waiter';
  static const String roleKitchen = 'kitchen';

  static const List<String> userRoles = [
    roleOwner,
    roleAdmin,
    roleManager,
    roleCashier,
    roleWaiter,
    roleKitchen,
  ];

  // ── Business Types ─────────────────────────────────────────────────────────
  static const List<String> businessTypes = [
    'Retail Shop',
    'Wholesale',
    'Restaurant / Café',
    'Pharmacy',
    'Grocery',
    'Electronics',
    'Clothing',
    'Services',
    'Other',
  ];

  // ── Ledger Types ───────────────────────────────────────────────────────────
  static const String ledgerCredit = 'credit';
  static const String ledgerDebit = 'debit';
  static const String entityCustomer = 'customer';
  static const String entitySupplier = 'supplier';
  static const String entityBusiness = 'business'; // For walk-in ledger entries

  // ── GST Rates ──────────────────────────────────────────────────────────────
  static const List<double> gstRates = [0, 5, 12, 18, 28];

  // ── Layout ─────────────────────────────────────────────────────────────────
  static const double sidebarBreakpoint = 800;
}
