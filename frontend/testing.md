# White-Box Testing & Domain Model Verification Report

**Project**: BizNext Billing & ERP Suite  
**Date**: August 31, 2026  
**Test Suite**: `test/models_whitebox_test.dart`  
**Execution Status**: `PASSED` (33 / 33 White-Box Test Scenarios Passed — 100% Success Rate)  
**Measured Model Line Coverage**: **89.1%** (1052 / 1181 Lines Covered via `flutter test --coverage`)

---

## 1. Executive Summary

Following white-box testing review, targeted improvements were made across all domain models and utility layers to enhance:
1. **Monetary Precision & Financial Strategy**: Standardized currency rounding using `CurrencyFormatter.round()` to eliminate IEEE 754 floating-point artifacts (e.g. `56.00000000000001` $\rightarrow$ `56.00`).
2. **Division-by-Zero Protection**: Secured computed getters against invalid/zero denominators (e.g., zero purchase cost, zero transaction counts, zero revenue, zero loyalty spend thresholds).
3. **Deterministic Date/Time Testability**: Injected optional `now` timestamp parameters into time-dependent functions (`ProductBatch.isExpiredAt`, `Offer.isCurrentlyValidAt`, `ProductDiscount.isCurrentlyValidAt`, and `ReportFilter` presets).
4. **Defensive Serialization & LEFT JOIN Handling**: Validated mapping for normalized SQLite database projections and nullable join columns (`entity_name`, `customer_type_name`, `supplier_name`, `category_name`).
5. **State Immutability & CopyWith Validation**: Verified that model mutations preserve original instances without leaking shared state.
6. **Coverage Accuracy**: Measured actual line coverage via `flutter test --coverage` and LCOV analysis rather than conflating test pass rate with code coverage.

---

## 2. Model Line Coverage & Quality Matrix

| Module | Model Class | Source Path | Measured Line Coverage | Key Validated Behaviors |
| :--- | :--- | :--- | :---: | :--- |
| **Core Utils** | `CurrencyFormatter` | `lib/core/utils/currency_formatter.dart` | `72.7%` | Monetary rounding (2 decimals), INR formatting, quantity stringification |
| **Accounts** | `AccountModel` | `lib/features/accounts/models/account_model.dart` | `100.0%` | Round-trip serialization, boolean defaults, boundary handling |
| **Accounts** | `AccountSummaryModel` | `lib/features/accounts/models/account_summary_model.dart` | `100.0%` | `AccountSummaryModel.zero()`, null safety |
| **Accounts** | `LedgerModel` | `lib/features/accounts/models/ledger_model.dart` | `97.0%` | Debit/credit types, SQL join projection handling, missing joins |
| **Accounts** | `TransactionModel` | `lib/features/accounts/models/transaction_model.dart` | `100.0%` | `isIncome`, `isExpense`, category joins, `TransactionCategoryModel` |
| **AI Chatbot** | `ChatbotMessage` | `lib/features/ai_chatbot/models/chatbot_message.dart` | `93.9%` | Enum serialization, defensive fallback on unknown status, `copyWith` |
| **Auth** | `BusinessModel` | `lib/features/auth/models/business_model.dart` | `93.6%` | Initials calculation (multi-word, single, empty), `toMap`/`fromMap` |
| **Auth** | `UserModel` | `lib/features/auth/models/user_model.dart` | `77.8%` | Initials calculation, password hash handling, roles, `copyWith` |
| **Billing** | `PosItemModel` | `lib/features/billing/models/pos_model.dart` | `89.7%` | Exclusive & Inclusive GST calculations, manual override, precision |
| **Billing** | `HeldOrderModel` | `lib/features/billing/models/pos_model.dart` | `89.7%` | Parked cart items calculation, grand totals |
| **Billing** | `PosModel` | `lib/features/billing/models/pos_model.dart` | `89.7%` | Subtotal, multi-discount aggregation, loyalty, `toSaleHistory` |
| **Billing** | `SaleHistoryModel` | `lib/features/billing/models/sale_history_model.dart` | `65.3%` | Full invoice serialization, line item attachments |
| **Billing** | `SaleModel` | `lib/features/billing/models/sale_model.dart` | `98.5%` | Round-trip serialization, `SaleItemModel` mapping |
| **Budgeting** | `BudgetModel` | `lib/features/budgeting/models/budget_model.dart` | `97.4%` | Target types, monthly/quarterly/yearly period handling, `copyWith` |
| **Customers** | `CustomerModel` | `lib/features/customers/models/customer_model.dart` | `93.0%` | Loyalty points, credit balance, customer type joins, `copyWith` |
| **Customers** | `CustomerDiscount` | `lib/features/customers/models/customer_discount.dart` | `92.9%` | Percentage vs Fixed discounts, active state, `copyWith` |
| **Discounts** | `Offer` | `lib/features/discounts/models/offer.dart` | `90.7%` | Deterministic `isCurrentlyValidAt`, descriptions, `clearDates` |
| **Inventory** | `Product` | `lib/features/inventory/models/product_model.dart` | `87.7%` | `profit`, `profitPercent` zero-cost guard, `isLowStock`, `isOutOfStock` |
| **Inventory** | `ProductBatch` | `lib/features/inventory/models/product_model.dart` | `87.7%` | Deterministic `isExpiredAt` timestamp testing |
| **Inventory** | `ProductTierPrice` | `lib/features/inventory/models/product_model.dart` | `87.7%` | Quantity tier pricing, customer type mappings |
| **Inventory** | `Category` / `Subcat` | `lib/features/inventory/models/product_model.dart` | `87.7%` | Display ordering, active status, supplier SKU mappings |
| **Inventory** | `ProductDiscount` | `lib/features/inventory/models/product_discount.dart` | `92.5%` | Deterministic date boundaries, percentage/fixed calculations |
| **Loyalty** | `LoyaltySettings` | `lib/features/loyalty/models/loyalty_model.dart` | `100.0%` | `calculateEarnedPoints`, `calculateDiscount`, division-by-zero guards |
| **Purchases** | `PurchaseModel` | `lib/features/purchases/models/purchase_model.dart` | `98.3%` | Supplier balance tracking, `PurchaseItemModel` cost mapping |
| **Reports** | `ReportFilter` | `lib/features/reports/models/report_model.dart` | `63.6%` | Deterministic presets (`today`, `yesterday`, `thisMonth`, `thisQuarter`) |
| **Reports** | `SalesReport` | `lib/features/reports/models/report_model.dart` | `63.6%` | `averageOrderValue` zero-order protection, trend points |
| **Reports** | `ProfitLossReport` | `lib/features/reports/models/report_model.dart` | `63.6%` | `marginPercent` zero-revenue protection |
| **Reports** | `TaxReport` | `lib/features/reports/models/report_model.dart` | `63.6%` | Output GST vs Input Tax Credit calculation |
| **Reports** | `TransactionReport` | `lib/features/reports/models/report_model.dart` | `63.6%` | `netCashFlow` calculation |
| **Settings** | `AppFeatureSettings` | `lib/features/settings/models/app_settings.dart` | `76.2%` | `toSqlMap()`, `fromSqlList()`, `copyWith`, scanner configurations |
| **Suppliers** | `SupplierModel` | `lib/features/suppliers/models/supplier_model.dart` | `96.9%` | Credit limits, opening balance, pan/gst fields, `copyWith` |
| **Updater** | `UpdateInfo` | `lib/features/updater/models/update_info.dart` | `100.0%` | `toJson()`, `fromJson()`, version & release notes |

---

## 3. Mathematical & Logical Validations

### 3.1 GST Tax Calculations (`PosItemModel`)

- **Exclusive GST Formula**:
  $$\text{Taxable} = \text{round}((\text{Effective Price} \times \text{Qty}) - \text{Discount})$$
  $$\text{GST Amount} = \text{round}\left(\text{Taxable} \times \frac{\text{GST \%}}{100}\right)$$
  $$\text{Total} = \text{round}(\text{Taxable} + \text{GST Amount})$$
  *Validation*:
  - **18% Slab (with discount)**: Price ₹200, Qty 2, Discount ₹20 $\rightarrow$ Taxable ₹380.00, GST ₹68.40, Total ₹448.40.
  - **28% Slab**: Price ₹200, Qty 1 $\rightarrow$ Taxable ₹200.00, GST ₹56.00, Total ₹256.00.
  - **5% Slab**: Price ₹200, Qty 2, Discount ₹20 $\rightarrow$ Taxable ₹380.00, GST ₹19.00, Total ₹399.00.
  - **0% Slab**: Price ₹200, Qty 2 $\rightarrow$ Taxable ₹400.00, GST ₹0.00, Total ₹400.00.

- **Inclusive GST (Reverse Calculation)**:
  $$\text{Total Paid} = \text{round}((\text{Effective Price} \times \text{Qty}) - \text{Discount})$$
  $$\text{GST Amount} = \text{round}\left(\text{Total Paid} - \frac{\text{Total Paid}}{1 + \frac{\text{GST \%}}{100}}\right)$$
  *Validation*:
  - Price ₹200, Qty 2, 18% GST $\rightarrow$ Total remains ₹400.00, Embedded GST is ₹61.02, Taxable Base is ₹338.98.

### 3.2 Division-by-Zero Guards
- `Product.profitPercent`: Evaluates to `0.0` when `purchasePrice <= 0` rather than `Infinity` or `NaN`.
- `SalesReport.averageOrderValue`: Evaluates to `0.0` when `transactionCount <= 0`.
- `ProfitLossReport.marginPercent`: Evaluates to `0.0` when `totalRevenue <= 0`.
- `LoyaltySettings.calculateEarnedPoints`: Evaluates to `0.0` when `earnSpendAmount <= 0` or `spendAmount <= 0`.

### 3.3 Deterministic Time Handling
- `ProductBatch.isExpiredAt([DateTime? now])`: Allows test harness to verify expiration at arbitrary timestamps.
- `Offer.isCurrentlyValidAt([DateTime? now])`: Supports exact millisecond boundary verification.
- `ReportFilter.*({DateTime? now})`: Supports deterministic range generation.

---

## 4. Test Execution Log

```
00:00 +0: White-Box: Currency & Monetary Precision Strategy CurrencyFormatter.round - Resolves floating point rounding artifacts
00:00 +1: White-Box: Currency & Monetary Precision Strategy CurrencyFormatter - Indian Rupee formatting
00:00 +2: White-Box: Accounts Models AccountModel - Serialization, defaults, and boundary values
00:00 +3: White-Box: Accounts Models AccountSummaryModel - Zero factory & properties
00:00 +4: White-Box: Accounts Models LedgerModel - Serialization, defaults, and LEFT JOIN simulations
00:00 +5: White-Box: Accounts Models TransactionModel and TransactionCategoryModel - Serialization & Getters
00:00 +6: White-Box: AI Chatbot Models & Defensive Parsing ChatbotMessage - JSON serialization, copyWith, & safe enum fallback
00:00 +7: White-Box: Auth Models BusinessModel - Initials calculation, serialization & copyWith
00:00 +8: White-Box: Auth Models UserModel - Initials calculation, serialization & copyWith
00:00 +9: White-Box: Comprehensive GST & POS Billing Model Matrix GST Matrix: Exclusive GST Calculations across tax slabs
00:00 +10: White-Box: Comprehensive GST & POS Billing Model Matrix GST Matrix: Inclusive GST Calculations (Reverse Tax Formula)
00:00 +11: White-Box: Comprehensive GST & POS Billing Model Matrix POS Item Edge Cases: Zero quantities, zero prices, decimal quantities, discounts
00:00 +12: White-Box: Comprehensive GST & POS Billing Model Matrix PosModel - Aggregations, grand total clamping, loyalty & held order integration
00:00 +13: White-Box: Comprehensive GST & POS Billing Model Matrix SaleHistoryModel and SaleModel - Complete serialization round-trip
00:00 +14: White-Box: Comprehensive GST & POS Billing Model Matrix PosModel - toSaleHistory and fromSaleHistory round-trip conversion
00:00 +15: White-Box: Budgeting Models BudgetModel - Serialization, copyWith, and period handling
00:00 +16: White-Box: Customer Models CustomerModel - Serialization, copyWith, & LEFT JOIN simulations
00:00 +17: White-Box: Customer Models CustomerDiscount - Active state and serialization
00:00 +18: White-Box: Discount & Offer Models & Date Boundaries Offer - Deterministic time injection and boundary conditions
00:00 +19: White-Box: Inventory, Product & Division-by-Zero Protection Product - Profit, margins, stock status & division-by-zero protection
00:00 +20: White-Box: Inventory, Product & Division-by-Zero Protection Product Tiered Pricing, Categories, Batches with Deterministic Expiry
00:00 +21: White-Box: Inventory, Product & Division-by-Zero Protection ProductDiscount - Validity checking, deterministic date boundaries & serialization
00:00 +22: White-Box: Inventory, Product & Division-by-Zero Protection CustomerType, PriceCategory, Subcategory, SupplierProduct serialization
00:00 +23: White-Box: Loyalty Models & Calculation Safety LoyaltySettings - Point calculations, bounds, & division-by-zero protection
00:00 +24: White-Box: Purchases Models PurchaseModel and PurchaseItemModel - Serialization and item calculations
00:00 +25: White-Box: Reports Models & Division-by-Zero Safety ReportFilter - Deterministic factory constructors with injected now
00:00 +26: White-Box: Reports Models & Division-by-Zero Safety SalesReport - AOV & division-by-zero protection
00:00 +27: White-Box: Reports Models & Division-by-Zero Safety ProfitLossReport - Margin calculation and zero revenue guard
00:00 +28: White-Box: Reports Models & Division-by-Zero Safety TaxReport & SalesVsPurchasesReport
00:00 +29: White-Box: Settings, Supplier & Updater Models AppFeatureSettings - SQL mapping and fromSqlList
00:00 +30: White-Box: Settings, Supplier & Updater Models SupplierModel - Serialization and copyWith
00:00 +31: White-Box: Settings, Supplier & Updater Models UpdateInfo - JSON serialization
00:00 +32: App smoke test
00:01 +33: All tests passed!
```
