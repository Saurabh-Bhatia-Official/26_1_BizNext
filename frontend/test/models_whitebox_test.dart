// test/models_whitebox_test.dart

import 'package:flutter_test/flutter_test.dart';

// Core Utils
import 'package:biz_next/core/utils/currency_formatter.dart';

// Accounts
import 'package:biz_next/features/accounts/models/account_model.dart';
import 'package:biz_next/features/accounts/models/account_summary_model.dart';
import 'package:biz_next/features/accounts/models/ledger_model.dart';
import 'package:biz_next/features/accounts/models/transaction_model.dart';

// AI Chatbot
import 'package:biz_next/features/ai_chatbot/models/chatbot_message.dart';

// Auth
import 'package:biz_next/features/auth/models/business_model.dart';
import 'package:biz_next/features/auth/models/user_model.dart';

// Billing
import 'package:biz_next/features/billing/models/pos_model.dart';
import 'package:biz_next/features/billing/models/sale_history_model.dart';
import 'package:biz_next/features/billing/models/sale_model.dart';

// Budgeting
import 'package:biz_next/features/budgeting/models/budget_model.dart';

// Customers
import 'package:biz_next/features/customers/models/customer_model.dart';
import 'package:biz_next/features/customers/models/customer_discount.dart';

// Discounts
import 'package:biz_next/features/discounts/models/offer.dart';

// Inventory
import 'package:biz_next/features/inventory/models/product_model.dart';
import 'package:biz_next/features/inventory/models/product_discount.dart';

// Loyalty
import 'package:biz_next/features/loyalty/models/loyalty_model.dart';

// Purchases
import 'package:biz_next/features/purchases/models/purchase_model.dart';

// Reports
import 'package:biz_next/features/reports/models/report_model.dart';

// Settings
import 'package:biz_next/features/settings/models/app_settings.dart';

// Suppliers
import 'package:biz_next/features/suppliers/models/supplier_model.dart';

// Updater
import 'package:biz_next/features/updater/models/update_info.dart';

void main() {
  group('White-Box: Currency & Monetary Precision Strategy', () {
    test('CurrencyFormatter.round - Resolves floating point rounding artifacts', () {
      expect(CurrencyFormatter.round(399.9999999997), 400.00);
      expect(CurrencyFormatter.round(68.3999999999), 68.40);
      expect(CurrencyFormatter.round(100.0000000001), 100.00);
      expect(CurrencyFormatter.round(12.345), 12.35);
      expect(CurrencyFormatter.round(0.004), 0.00);
      expect(CurrencyFormatter.round(0.005), 0.01);
    });

    test('CurrencyFormatter - Indian Rupee formatting', () {
      expect(CurrencyFormatter.format(1500.5), '₹1,500.50');
      expect(CurrencyFormatter.format(0), '₹0.00');
      expect(CurrencyFormatter.formatQty(5.0), '5');
      expect(CurrencyFormatter.formatQty(5.75), '5.75');
    });
  });

  group('White-Box: Accounts Models', () {
    test('AccountModel - Serialization, defaults, and boundary values', () {
      final account = AccountModel(
        id: 1,
        businessId: 10,
        name: 'HDFC Bank',
        type: 'Bank',
        openingBalance: 5000.0,
        balance: 12500.5,
        accountNumber: '123456789',
        isDefault: true,
      );

      final map = account.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'HDFC Bank');
      expect(map['is_default'], 1);

      final restored = AccountModel.fromMap(map);
      expect(restored.id, 1);
      expect(restored.businessId, 10);
      expect(restored.name, 'HDFC Bank');
      expect(restored.type, 'Bank');
      expect(restored.openingBalance, 5000.0);
      expect(restored.balance, 12500.5);
      expect(restored.accountNumber, '123456789');
      expect(restored.isDefault, true);

      // Boundary: Empty / default map
      final defaultAcc = AccountModel.fromMap({'business_id': 1, 'name': 'Cash Box'});
      expect(defaultAcc.type, 'Cash');
      expect(defaultAcc.openingBalance, 0.0);
      expect(defaultAcc.balance, 0.0);
      expect(defaultAcc.isDefault, false);
    });

    test('AccountSummaryModel - Zero factory & properties', () {
      final zero = AccountSummaryModel.zero();
      expect(zero.cashInHand, 0);
      expect(zero.totalReceivable, 0);
      expect(zero.totalPayable, 0);
      expect(zero.totalExpenses, 0);
      expect(zero.totalIncome, 0);
    });

    test('LedgerModel - Serialization, defaults, and LEFT JOIN simulations', () {
      final now = DateTime(2026, 8, 31, 10, 30);
      final ledger = LedgerModel(
        id: 5,
        businessId: 1,
        entityType: 'customer',
        entityId: 12,
        entityName: 'John Doe',
        categoryName: 'Sales Invoice',
        type: 'debit',
        amount: 2500.0,
        balance: 5000.0,
        referenceId: 101,
        accountId: 2,
        accountName: 'Main Cash',
        description: 'Partial payment',
        date: now,
      );

      final map = ledger.toMap();
      expect(map['entity_type'], 'customer');
      expect(map['amount'], 2500.0);

      // Simulating SQL Join Query row mapping
      final sqlJoinMap = {
        ...map,
        'entity_name': 'John Doe',
      };
      final restored = LedgerModel.fromMap(sqlJoinMap);
      expect(restored.id, 5);
      expect(restored.entityName, 'John Doe');
      expect(restored.amount, 2500.0);
      expect(restored.balance, 5000.0);
      expect(restored.date, now);

      // Simulating Missing LEFT JOIN values (null joins)
      final missingJoinMap = {
        ...map,
        'entity_name': null,
        'category_name': null,
        'account_name': null,
      };
      final restoredNullJoin = LedgerModel.fromMap(missingJoinMap);
      expect(restoredNullJoin.entityName, isNull);
      expect(restoredNullJoin.categoryName, isNull);
      expect(restoredNullJoin.accountName, isNull);
    });

    test('TransactionModel and TransactionCategoryModel - Serialization & Getters', () {
      final now = DateTime(2026, 8, 31, 12, 0);
      final tx = TransactionModel(
        id: 7,
        businessId: 1,
        categoryId: 3,
        categoryName: 'Office Rent',
        type: 'debit',
        amount: 15000.0,
        description: 'Monthly office rent',
        paymentMode: 'Bank Transfer',
        accountId: 1,
        date: now,
      );

      expect(tx.isExpense, true);
      expect(tx.isIncome, false);

      final map = tx.toMap();
      final restored = TransactionModel.fromMap(map);
      expect(restored.id, 7);
      expect(restored.amount, 15000.0);
      expect(restored.paymentMode, 'Bank Transfer');

      final incomeTx = TransactionModel(
        businessId: 1,
        type: 'credit',
        amount: 5000.0,
      );
      expect(incomeTx.isIncome, true);
      expect(incomeTx.isExpense, false);

      final cat = TransactionCategoryModel(id: 3, businessId: 1, name: 'Rent', type: 'expense');
      final catMap = cat.toMap();
      final restoredCat = TransactionCategoryModel.fromMap(catMap);
      expect(restoredCat.id, 3);
      expect(restoredCat.name, 'Rent');
      expect(restoredCat.type, 'expense');
    });
  });

  group('White-Box: AI Chatbot Models & Defensive Parsing', () {
    test('ChatbotMessage - JSON serialization, copyWith, & safe enum fallback', () {
      final now = DateTime(2026, 8, 31, 14, 0);
      final msg = ChatbotMessage(
        id: 'msg-1',
        text: 'What are my total sales today?',
        isUser: true,
        timestamp: now,
        status: MessageStatus.success,
      );

      final json = msg.toJson();
      expect(json['id'], 'msg-1');
      expect(json['status'], 'success');

      final restored = ChatbotMessage.fromJson(json);
      expect(restored.id, 'msg-1');
      expect(restored.text, 'What are my total sales today?');
      expect(restored.isUser, true);
      expect(restored.status, MessageStatus.success);

      // Defensive test: Unknown or invalid enum string gracefully falls back
      final invalidJson = {
        ...json,
        'status': 'UNKNOWN_STATUS_VALUE',
      };
      final fallbackMsg = ChatbotMessage.fromJson(invalidJson);
      expect(fallbackMsg.status, MessageStatus.success);

      final updated = restored.copyWith(text: 'Updated Query', status: MessageStatus.executingSql);
      expect(updated.text, 'Updated Query');
      expect(updated.status, MessageStatus.executingSql);
    });
  });

  group('White-Box: Auth Models', () {
    test('BusinessModel - Initials calculation, serialization & copyWith', () {
      const b1 = BusinessModel(id: 1, name: 'Acme Supermarket', type: 'Retail');
      expect(b1.initials, 'AS');

      const b2 = BusinessModel(id: 2, name: 'Single', type: 'Store');
      expect(b2.initials, 'SI');

      const b3 = BusinessModel(id: 3, name: '', type: 'Store');
      expect(b3.initials, 'B');

      final map = b1.toMap();
      final restored = BusinessModel.fromMap(map);
      expect(restored.id, 1);
      expect(restored.name, 'Acme Supermarket');
      expect(restored.isActive, true);

      final updated = b1.copyWith(name: 'New Acme', phone: '9876543210');
      expect(updated.name, 'New Acme');
      expect(updated.phone, '9876543210');
      expect(updated.id, 1);
      // Ensure original is immutable
      expect(b1.name, 'Acme Supermarket');
    });

    test('UserModel - Initials calculation, serialization & copyWith', () {
      const u1 = UserModel(
        id: 1,
        username: 'admin',
        passwordHash: 'hash123',
        fullName: 'Alex Morgan',
        role: 'owner',
      );
      expect(u1.initials, 'AM');

      const u2 = UserModel(
        id: 2,
        username: 'cashier',
        passwordHash: 'hash456',
        fullName: 'Cashier',
        role: 'cashier',
      );
      expect(u2.initials, 'C');

      const u3 = UserModel(
        id: 3,
        username: 'empty',
        passwordHash: 'hash789',
        fullName: '',
      );
      expect(u3.initials, 'U');

      final map = u1.toMap();
      final restored = UserModel.fromMap(map);
      expect(restored.id, 1);
      expect(restored.fullName, 'Alex Morgan');
      expect(restored.role, 'owner');

      final updated = u1.copyWith(
        username: 'superadmin',
        passwordHash: 'newhash',
        fullName: 'Super Alex',
        email: 'alex@example.com',
        phone: '1234567890',
        role: 'admin',
        isActive: false,
      );
      expect(updated.username, 'superadmin');
      expect(updated.fullName, 'Super Alex');
      expect(updated.email, 'alex@example.com');
      expect(updated.phone, '1234567890');
      expect(updated.role, 'admin');
      expect(updated.isActive, false);
      expect(u1.username, 'admin'); // original immutable
    });
  });

  group('White-Box: Comprehensive GST & POS Billing Model Matrix', () {
    const productBase = Product(
      id: 1,
      name: 'Coffee Mug',
      sellingPrice: 200.0,
      purchasePrice: 120.0,
      stock: 50,
    );

    test('GST Matrix: Exclusive GST Calculations across tax slabs', () {
      // Slab 1: 0% GST
      final p0 = productBase.copyWith(gstPercent: 0.0);
      final item0 = PosItemModel(product: p0, quantity: 2, isTaxInclusive: false);
      expect(item0.subtotal, 400.0);
      expect(item0.gstAmount, 0.0);
      expect(item0.total, 400.0);

      // Slab 2: 5% GST
      final p5 = productBase.copyWith(gstPercent: 5.0);
      final item5 = PosItemModel(product: p5, quantity: 2, discount: 20.0, isTaxInclusive: false);
      // Taxable = 400 - 20 = 380. GST 5% = 19.0. Total = 399.0
      expect(item5.gstAmount, 19.0);
      expect(item5.total, 399.0);

      // Slab 3: 12% GST
      final p12 = productBase.copyWith(gstPercent: 12.0);
      final item12 = PosItemModel(product: p12, quantity: 2, discount: 0, isTaxInclusive: false);
      expect(item12.gstAmount, 48.0);
      expect(item12.total, 448.0);

      // Slab 4: 18% GST with discount (Verified Prompt Example)
      final p18 = productBase.copyWith(gstPercent: 18.0);
      final item18 = PosItemModel(product: p18, quantity: 2, discount: 20.0, isTaxInclusive: false);
      expect(item18.effectivePrice, 200.0);
      expect(item18.subtotal, 400.0);
      expect(item18.gstAmount, closeTo(68.40, 0.001));
      expect(item18.total, closeTo(448.40, 0.001));

      // Slab 5: 28% GST
      final p28 = productBase.copyWith(gstPercent: 28.0);
      final item28 = PosItemModel(product: p28, quantity: 1, discount: 0, isTaxInclusive: false);
      expect(item28.gstAmount, 56.0);
      expect(item28.total, 256.0);
    });

    test('GST Matrix: Inclusive GST Calculations (Reverse Tax Formula)', () {
      // Inclusive 18% GST (Verified Prompt Example)
      final p18 = productBase.copyWith(gstPercent: 18.0);
      final item18Inc = PosItemModel(product: p18, quantity: 2, discount: 0.0, isTaxInclusive: true);
      expect(item18Inc.subtotal, 400.0);
      expect(item18Inc.total, 400.0);
      // Taxable = 400 / 1.18 = 338.98305. Embedded GST = 400 - 338.98305 = 61.0169
      expect(item18Inc.gstAmount, closeTo(61.02, 0.01));

      // Inclusive 5% GST
      final p5 = productBase.copyWith(gstPercent: 5.0);
      final item5Inc = PosItemModel(product: p5, quantity: 1, discount: 0.0, isTaxInclusive: true);
      expect(item5Inc.total, 200.0);
      expect(item5Inc.gstAmount, closeTo(200.0 - (200.0 / 1.05), 0.01));
    });

    test('POS Item Edge Cases: Zero quantities, zero prices, decimal quantities, discounts', () {
      final p = productBase.copyWith(gstPercent: 18.0);

      // Decimal quantity (e.g. 1.75 kg)
      final itemDec = PosItemModel(product: p, quantity: 1.75, isTaxInclusive: false);
      expect(itemDec.subtotal, 350.0);
      expect(itemDec.gstAmount, closeTo(63.0, 0.001));
      expect(itemDec.total, closeTo(413.0, 0.001));

      // Zero quantity
      final itemZeroQty = PosItemModel(product: p, quantity: 0);
      expect(itemZeroQty.subtotal, 0.0);
      expect(itemZeroQty.gstAmount, 0.0);
      expect(itemZeroQty.total, 0.0);

      // Discount equals subtotal (100% discount)
      final itemFree = PosItemModel(product: p, quantity: 2, discount: 400.0, isTaxInclusive: false);
      expect(itemFree.gstAmount, 0.0);
      expect(itemFree.total, 0.0);

      // Manual price override
      final itemOverride = PosItemModel(product: p, quantity: 1, manualPrice: 300.0, isTaxInclusive: false);
      expect(itemOverride.effectivePrice, 300.0);
      expect(itemOverride.subtotal, 300.0);
    });

    test('PosModel - Aggregations, grand total clamping, loyalty & held order integration', () {
      const p1 = Product(id: 1, name: 'Item 1', sellingPrice: 100.0, gstPercent: 10.0);
      const p2 = Product(id: 2, name: 'Item 2', sellingPrice: 200.0, gstPercent: 0.0);

      final pos = PosModel(
        items: [
          const PosItemModel(product: p1, quantity: 2, discount: 10.0), // subtotal 200, disc 10 -> 190 + 19 (gst) = 209
          const PosItemModel(product: p2, quantity: 1, discount: 0.0),  // subtotal 200, gst 0 = 200
        ],
        manualDiscount: 15.0,
        autoBillDiscount: 5.0,
        loyaltyDiscount: 8.0,
        selectedCustomerId: 3,
        selectedCustomerName: 'Bob Client',
        paymentMode: 'Cash',
      );

      expect(pos.subtotal, 400.0);
      expect(pos.totalGst, 19.0);
      expect(pos.itemDiscounts, 10.0);
      // Total discounts: 10 (item) + 15 (manual) + 5 (auto) + 8 (loyalty) = 38
      expect(pos.totalDiscounts, 38.0);
      // Grand total = 400 + 19 - 38 = 381
      expect(pos.grandTotal, 381.0);
      expect(pos.totalItemCount, 3);

      // Edge case: Excessive discount clamped to 0.0 (no negative grand totals)
      final excessiveDiscountPos = pos.copyWith(manualDiscount: 1000.0);
      expect(excessiveDiscountPos.grandTotal, 0.0);

      final held = HeldOrderModel(
        id: 'hold-123',
        customerName: 'Bob Client',
        customerId: 3,
        items: pos.items,
        manualDiscount: 15.0,
      );
      expect(held.itemCount, 3);
      expect(held.grandTotal, (209 + 200) - 15);
    });

    test('SaleHistoryModel and SaleModel - Complete serialization round-trip', () {
      final now = DateTime(2026, 8, 31, 15, 30);
      final sale = SaleHistoryModel(
        id: 50,
        businessId: 1,
        invoiceNo: 'INV-2026-001',
        customerId: 2,
        customerName: 'Jane Smith',
        subtotal: 1000.0,
        discount: 50.0,
        gstAmount: 171.0,
        grandTotal: 1121.0,
        paidAmount: 1121.0,
        balanceDue: 0.0,
        paymentMode: 'UPI',
        date: now,
        items: [
          SaleHistoryItemModel(
            id: 1,
            saleId: 50,
            productId: 10,
            productName: 'Product A',
            quantity: 2,
            price: 500.0,
            gstPercent: 18.0,
            gstAmount: 171.0,
            total: 1121.0,
          ),
        ],
      );

      final map = sale.toMap();
      expect(map['invoice_no'], 'INV-2026-001');
      expect(map['payment_mode'], 'UPI');

      final restored = SaleHistoryModel.fromMap(map, sale.items);
      expect(restored.id, 50);
      expect(restored.invoiceNo, 'INV-2026-001');
      expect(restored.grandTotal, 1121.0);
      expect(restored.items.length, 1);
      expect(restored.items.first.productName, 'Product A');

      // SaleModel and SaleItemModel round-trip
      final saleItem = SaleItemModel(
        id: 10,
        saleId: 100,
        productId: 5,
        productName: 'Widget',
        quantity: 3,
        price: 150.0,
        discount: 10.0,
        gstPercent: 18.0,
        gstAmount: 79.2,
        total: 519.2,
        purchasePrice: 100.0,
      );
      final itemMap = saleItem.toMap(100);
      expect(itemMap['sale_id'], 100);
      final restoredSaleItem = SaleItemModel.fromMap(itemMap);
      expect(restoredSaleItem.productName, 'Widget');
      expect(restoredSaleItem.purchasePrice, 100.0);

      final saleModel = SaleModel(
        id: 100,
        businessId: 1,
        invoiceNo: 'INV-100',
        customerId: 2,
        customerName: 'Alice',
        customerPhone: '9988776655',
        customerAddress: 'City Center',
        subtotal: 450.0,
        discount: 10.0,
        gstAmount: 79.2,
        grandTotal: 519.2,
        paidAmount: 519.2,
        balanceDue: 0.0,
        paymentMode: 'Cash',
        notes: 'Express Delivery',
        date: now,
        items: [saleItem],
      );
      final saleModelMap = saleModel.toMap();
      expect(saleModelMap['invoice_no'], 'INV-100');
      final restoredSaleModel = SaleModel.fromMap(saleModelMap, saleModel.items);
      expect(restoredSaleModel.id, 100);
      expect(restoredSaleModel.invoiceNo, 'INV-100');
      expect(restoredSaleModel.items.length, 1);
    });

    test('PosModel - toSaleHistory and fromSaleHistory round-trip conversion', () {
      const p = Product(id: 10, name: 'Item X', sellingPrice: 200.0, gstPercent: 18.0);
      final pos = PosModel(
        items: [const PosItemModel(product: p, quantity: 2, discount: 0)],
        selectedCustomerId: 5,
        selectedCustomerName: 'Customer X',
        paymentMode: 'Card',
        manualDiscount: 10.0,
      );

      final saleHistory = pos.toSaleHistory(businessId: 1, invoiceNo: 'INV-POS-1');
      expect(saleHistory.invoiceNo, 'INV-POS-1');
      expect(saleHistory.subtotal, 400.0);
      expect(saleHistory.items.length, 1);

      final restoredPos = PosModel.fromSaleHistory(saleHistory);
      expect(restoredPos.selectedCustomerId, 5);
      expect(restoredPos.paymentMode, 'Card');
      expect(restoredPos.items.length, 1);
    });
  });

  group('White-Box: Budgeting Models', () {
    test('BudgetModel - Serialization, copyWith, and period handling', () {
      final start = DateTime(2026, 8, 1);
      final end = DateTime(2026, 8, 31);
      final budget = BudgetModel(
        id: 2,
        businessId: 1,
        categoryId: 4,
        targetType: 'category',
        amount: 50000.0,
        period: 'monthly',
        startDate: start,
        endDate: end,
        spent: 18500.0,
      );

      final map = budget.toMap();
      expect(map['amount'], 50000.0);
      expect(map['period'], 'monthly');

      final restored = BudgetModel.fromMap(map, spent: 18500.0);
      expect(restored.id, 2);
      expect(restored.amount, 50000.0);
      expect(restored.spent, 18500.0);

      final updated = budget.copyWith(amount: 60000.0);
      expect(updated.amount, 60000.0);
      expect(updated.id, 2);
      expect(budget.amount, 50000.0); // original unmodified
    });
  });

  group('White-Box: Customer Models', () {
    test('CustomerModel - Serialization, copyWith, & LEFT JOIN simulations', () {
      final now = DateTime(2026, 8, 31);
      final customer = CustomerModel(
        id: 10,
        businessId: 1,
        name: 'Sarah Connor',
        phone: '9988776655',
        email: 'sarah@example.com',
        address: '123 Tech Park',
        gstNumber: '27AAAAA0000A1Z5',
        customerTypeId: 2,
        customerTypeName: 'Wholesale',
        balance: 3500.0,
        loyaltyPoints: 120.0,
        createdAt: now,
      );

      final map = customer.toMap();
      final baseRestored = CustomerModel.fromMap(map);
      expect(baseRestored.id, 10);
      expect(baseRestored.name, 'Sarah Connor');

      // SQL Join mapping
      final sqlJoinMap = {
        ...map,
        'customer_type_name': 'Wholesale',
      };
      final restored = CustomerModel.fromMap(sqlJoinMap);
      expect(restored.id, 10);
      expect(restored.name, 'Sarah Connor');
      expect(restored.customerTypeName, 'Wholesale');
      expect(restored.balance, 3500.0);
      expect(restored.loyaltyPoints, 120.0);

      final updated = customer.copyWith(balance: 4000.0, loyaltyPoints: 150.0);
      expect(updated.balance, 4000.0);
      expect(updated.loyaltyPoints, 150.0);
    });

    test('CustomerDiscount - Active state and serialization', () {
      final now = DateTime(2026, 8, 31);
      final disc = CustomerDiscount(
        id: 1,
        businessId: 1,
        customerId: 10,
        discountType: 'percentage',
        discountValue: 10.0,
        isActive: true,
        createdAt: now,
      );

      final map = disc.toMap();
      final restored = CustomerDiscount.fromMap(map);
      expect(restored.id, 1);
      expect(restored.discountType, 'percentage');
      expect(restored.discountValue, 10.0);
      expect(restored.isActive, true);

      final updated = disc.copyWith(discountValue: 20.0, isActive: false);
      expect(updated.discountValue, 20.0);
      expect(updated.isActive, false);
      expect(disc.discountValue, 10.0); // original immutable
    });
  });

  group('White-Box: Discount & Offer Models & Date Boundaries', () {
    test('Offer - Deterministic time injection and boundary conditions', () {
      final start = DateTime(2026, 8, 10, 0, 0, 0);
      final end = DateTime(2026, 8, 20, 23, 59, 59);

      final offer = Offer(
        id: 1,
        businessId: 1,
        name: 'Festive Mega Deal',
        offerType: 'buy_x_get_y',
        discountType: 'free_product',
        discountValue: 0,
        buyQty: 2,
        getQty: 1,
        startDate: start,
        endDate: end,
        isActive: true,
        createdAt: DateTime(2026, 8, 1),
      );

      // Test before start date
      expect(offer.isCurrentlyValidAt(DateTime(2026, 8, 9, 23, 59, 59)), false);
      // Test exactly at start date
      expect(offer.isCurrentlyValidAt(start), true);
      // Test in active window
      expect(offer.isCurrentlyValidAt(DateTime(2026, 8, 15, 12, 0, 0)), true);
      // Test exactly at end date
      expect(offer.isCurrentlyValidAt(end), true);
      // Test 1 second after end date
      expect(offer.isCurrentlyValidAt(DateTime(2026, 8, 21, 0, 0, 0)), false);

      // Inactive offer returns false regardless of dates
      final inactiveOffer = offer.copyWith(isActive: false);
      expect(inactiveOffer.isCurrentlyValidAt(DateTime(2026, 8, 15)), false);

      // Offer with no dates is always valid when active
      final openOffer = offer.copyWith(clearDates: true);
      expect(openOffer.isCurrentlyValidAt(DateTime(2030, 1, 1)), true);

      // Descriptions
      expect(offer.getOfferDescription('Soda'), 'Buy 2 get 1 free');
      final productOffer = offer.copyWith(applyTo: 'product');
      expect(productOffer.getOfferDescription('Soda'), 'Buy 2 get 1 free on Soda');

      // Round-trip toMap and fromMap
      final offerMap = offer.toMap();
      expect(offerMap['name'], 'Festive Mega Deal');
      final restoredOffer = Offer.fromMap(offerMap);
      expect(restoredOffer.id, 1);
      expect(restoredOffer.name, 'Festive Mega Deal');
      expect(restoredOffer.buyQty, 2.0);
    });
  });

  group('White-Box: Inventory, Product & Division-by-Zero Protection', () {
    test('Product - Profit, margins, stock status & division-by-zero protection', () {
      const p = Product(
        id: 100,
        name: 'Wireless Mouse',
        sku: 'MS-100',
        barcode: '8901234567890',
        purchasePrice: 300.0,
        mrp: 600.0,
        sellingPrice: 500.0,
        minSellingPrice: 400.0,
        wholesalePrice: 420.0,
        dealerPrice: 380.0,
        stock: 3.0,
        minStock: 5.0,
        unit: 'pcs',
        gstPercent: 18.0,
      );

      expect(p.profit, 200.0); // 500 - 300
      expect(p.profitPercent, closeTo(66.67, 0.01)); // (200/300)*100
      expect(p.isLowStock, true); // stock 3 <= minStock 5
      expect(p.isOutOfStock, false);

      // Zero purchase price must return 0% profitPercent (No Infinity/NaN)
      const pZeroCost = Product(name: 'Free Sample', sellingPrice: 50.0, purchasePrice: 0.0);
      expect(pZeroCost.profitPercent, 0.0);
      expect(pZeroCost.profitPercent.isFinite, true);

      // Negative purchase price guard
      const pNegCost = Product(name: 'Invalid Cost', sellingPrice: 50.0, purchasePrice: -10.0);
      expect(pNegCost.profitPercent, 0.0);

      // Out of stock
      const outOfStockP = Product(name: 'Empty', stock: 0);
      expect(outOfStockP.isOutOfStock, true);
      const negStockP = Product(name: 'Backorder', stock: -2);
      expect(negStockP.isOutOfStock, true);

      final map = p.toMap();
      final restored = Product.fromMap(map);
      expect(restored.id, 100);
      expect(restored.name, 'Wireless Mouse');
      expect(restored.sku, 'MS-100');
      expect(restored.sellingPrice, 500.0);
      expect(restored.wholesalePrice, 420.0);

      final updated = p.copyWith(stock: 25.0);
      expect(updated.stock, 25.0);
      expect(updated.isLowStock, false);
      expect(p.stock, 3.0); // original immutable
    });

    test('Product Tiered Pricing, Categories, Batches with Deterministic Expiry', () {
      const tier = ProductTierPrice(
        id: 1,
        productId: 100,
        categoryId: 2,
        categoryName: 'Wholesale',
        minQty: 10,
        maxQty: 100,
        price: 420.0,
      );
      final tierMap = tier.toMap();
      final sqlJoinMap = {
        ...tierMap,
        'category_name': 'Wholesale',
      };
      final restoredTier = ProductTierPrice.fromMap(sqlJoinMap);
      expect(restoredTier.price, 420.0);
      expect(restoredTier.categoryName, 'Wholesale');

      const cat = Category(id: 5, name: 'Electronics', code: 'ELEC', displayOrder: 1);
      final catMap = cat.toMap();
      final restoredCat = Category.fromMap(catMap);
      expect(restoredCat.id, 5);
      expect(restoredCat.name, 'Electronics');

      final expiry = DateTime(2026, 8, 15);
      final batch = ProductBatch(
        id: 1,
        productId: 100,
        batchNumber: 'B2026-A',
        purchaseRate: 280.0,
        quantity: 50.0,
        expiryDate: expiry,
      );

      // Deterministic expiry test
      expect(batch.isExpiredAt(DateTime(2026, 8, 10)), false);
      expect(batch.isExpiredAt(DateTime(2026, 8, 20)), true);
    });

    test('ProductDiscount - Validity checking, deterministic date boundaries & serialization', () {
      final pDisc = ProductDiscount(
        id: 1,
        businessId: 1,
        productId: 100,
        discountType: 'percentage',
        discountValue: 12.0,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 15),
        createdAt: DateTime(2026, 8, 1),
      );

      expect(pDisc.isCurrentlyValidAt(DateTime(2026, 8, 10)), true);
      expect(pDisc.isCurrentlyValidAt(DateTime(2026, 8, 20)), false);
      expect(pDisc.isCurrentlyValidAt(DateTime(2026, 7, 30)), false);

      final map = pDisc.toMap();
      expect(map['discount_value'], 12.0);
      final restored = ProductDiscount.fromMap(map);
      expect(restored.id, 1);
      expect(restored.discountType, 'percentage');
      expect(restored.productId, 100);

      final updated = pDisc.copyWith(discountValue: 15.0);
      expect(updated.discountValue, 15.0);
    });

    test('CustomerType, PriceCategory, Subcategory, SupplierProduct serialization', () {
      const cType = CustomerType(id: 1, name: 'Wholesale', code: 'WS', description: 'Wholesale client');
      final cTypeMap = cType.toMap();
      final restoredCType = CustomerType.fromMap(cTypeMap);
      expect(restoredCType.name, 'Wholesale');
      expect(restoredCType.code, 'WS');

      const pCat = PriceCategory(id: 2, name: 'Retail');
      final pCatMap = pCat.toMap();
      final restoredPCat = PriceCategory.fromMap(pCatMap);
      expect(restoredPCat.name, 'Retail');

      const subCat = Subcategory(id: 3, categoryId: 1, name: 'Smartphones');
      final subCatMap = subCat.toMap();
      final restoredSubCat = Subcategory.fromMap(subCatMap);
      expect(restoredSubCat.name, 'Smartphones');

      final suppProd = SupplierProduct(
        id: 4,
        supplierId: 10,
        productId: 100,
        supplierSku: 'SUP-100',
        lastPurchasePrice: 250.0,
        lastPurchaseQty: 50.0,
      );
      final suppProdMap = suppProd.toMap();
      final restoredSuppProd = SupplierProduct.fromMap(suppProdMap);
      expect(restoredSuppProd.supplierSku, 'SUP-100');
      expect(restoredSuppProd.lastPurchasePrice, 250.0);
    });
  });

  group('White-Box: Loyalty Models & Calculation Safety', () {
    test('LoyaltySettings - Point calculations, bounds, & division-by-zero protection', () {
      final settings = LoyaltySettings(
        id: 1,
        businessId: 1,
        earnRate: 2.0,
        earnSpendAmount: 100.0,
        redeemValue: 0.5,
        minRedeemPoints: 50,
        maxRedeemLimit: 500,
        welcomePoints: 25,
      );

      // Normal calculations: Spend ₹500 -> 10 points
      expect(settings.calculateEarnedPoints(500.0), 10.0);
      // Redeem 100 points -> ₹50 discount
      expect(settings.calculateDiscount(100.0), 50.0);
      // Max redeem limit threshold: Redeem 1000 points -> capped at 500 pts = ₹250 discount
      expect(settings.calculateDiscount(1000.0), 250.0);

      // Division by zero protection: earnSpendAmount = 0
      final zeroSpendRate = settings.copyWith(earnSpendAmount: 0.0);
      expect(zeroSpendRate.calculateEarnedPoints(500.0), 0.0);
      expect(zeroSpendRate.calculateEarnedPoints(500.0).isFinite, true);

      // Inactive settings
      final inactiveSettings = settings.copyWith(isActive: false);
      expect(inactiveSettings.calculateEarnedPoints(500.0), 0.0);
      expect(inactiveSettings.calculateDiscount(100.0), 0.0);

      final map = settings.toMap();
      final restored = LoyaltySettings.fromMap(map);
      expect(restored.id, 1);
      expect(restored.earnRate, 2.0);
      expect(restored.maxRedeemLimit, 500.0);
    });
  });

  group('White-Box: Purchases Models', () {
    test('PurchaseModel and PurchaseItemModel - Serialization and item calculations', () {
      final now = DateTime(2026, 8, 31, 11, 0);
      final item = PurchaseItemModel(
        id: 1,
        purchaseId: 10,
        productId: 5,
        productName: 'Sugar 1kg',
        quantity: 100,
        purchasePrice: 40.0,
        gstPercent: 5.0,
        total: 4000.0,
      );

      final itemMap = item.toMap(10);
      expect(itemMap['purchase_id'], 10);
      expect(itemMap['gst_amount'], 200.0); // 4000 * 0.05

      final restoredItem = PurchaseItemModel.fromMap(itemMap);
      expect(restoredItem.productName, 'Sugar 1kg');
      expect(restoredItem.purchasePrice, 40.0);

      final purchase = PurchaseModel(
        id: 10,
        businessId: 1,
        billNo: 'BILL-889',
        supplierId: 4,
        supplierName: 'Global Traders',
        subtotal: 4000.0,
        discount: 100.0,
        gstAmount: 200.0,
        grandTotal: 4100.0,
        paidAmount: 4100.0,
        balanceDue: 0.0,
        paymentMode: 'Bank Transfer',
        date: now,
      );

      final purchaseMap = purchase.toMap();
      final sqlJoinMap = {
        ...purchaseMap,
        'supplier_name': 'Global Traders',
      };
      final restoredPurchase = PurchaseModel.fromMap(sqlJoinMap);
      expect(restoredPurchase.id, 10);
      expect(restoredPurchase.billNo, 'BILL-889');
      expect(restoredPurchase.supplierName, 'Global Traders');
      expect(restoredPurchase.grandTotal, 4100.0);
    });
  });

  group('White-Box: Reports Models & Division-by-Zero Safety', () {
    test('ReportFilter - Deterministic factory constructors with injected now', () {
      final fixedDate = DateTime(2026, 8, 31, 12, 0, 0);

      final today = ReportFilter.today(now: fixedDate);
      expect(today.type, 'today');
      expect(today.startDate, DateTime(2026, 8, 31));
      expect(today.endDate, DateTime(2026, 8, 31, 23, 59, 59, 999));

      final yesterday = ReportFilter.yesterday(now: fixedDate);
      expect(yesterday.type, 'yesterday');
      expect(yesterday.startDate.day, 30);

      final thisMonth = ReportFilter.thisMonth(now: fixedDate);
      expect(thisMonth.type, 'thisMonth');
      expect(thisMonth.startDate, DateTime(2026, 8, 1));

      final thisQuarter = ReportFilter.thisQuarter(now: fixedDate);
      expect(thisQuarter.type, 'thisQuarter');
      expect(thisQuarter.startDate, DateTime(2026, 7, 1)); // Q3 starts July

      final thisYear = ReportFilter.thisYear(now: fixedDate);
      expect(thisYear.type, 'thisYear');
      expect(thisYear.startDate, DateTime(2026, 1, 1));
      expect(thisYear.endDate, DateTime(2026, 12, 31, 23, 59, 59, 999));
    });

    test('SalesReport - AOV & division-by-zero protection', () {
      final report = SalesReport(
        sales: [],
        totalAmount: 15000.0,
        netSales: 13500.0,
        totalGst: 1500.0,
        totalDiscount: 300.0,
        transactionCount: 10,
        paymentModeBreakdown: {'Cash': 10000.0, 'Card': 5000.0},
        trendPoints: [
          SalesTrendPoint(date: DateTime(2026, 8, 30), label: '30/08', amount: 8000.0, count: 5),
          SalesTrendPoint(date: DateTime(2026, 8, 31), label: '31/08', amount: 7000.0, count: 5),
        ],
      );

      expect(report.averageOrderValue, 1500.0); // 15000 / 10

      // Zero transaction count guard (No Infinity/NaN)
      final zeroReport = SalesReport(
        sales: [],
        totalAmount: 0.0,
        netSales: 0.0,
        totalGst: 0.0,
        totalDiscount: 0.0,
        transactionCount: 0,
        paymentModeBreakdown: {},
      );
      expect(zeroReport.averageOrderValue, 0.0);
      expect(zeroReport.averageOrderValue.isFinite, true);
    });

    test('ProfitLossReport - Margin calculation and zero revenue guard', () {
      final pnl = ProfitLossReport(
        totalRevenue: 100000.0,
        totalCost: 60000.0,
        totalExpenses: 15000.0,
        netProfit: 25000.0,
        margin: 25.0,
      );
      expect(pnl.netProfit, 25000.0);
      expect(pnl.marginPercent, 25.0);

      // Zero revenue guard
      final zeroRevenuePnl = ProfitLossReport(
        totalRevenue: 0.0,
        totalCost: 0.0,
        totalExpenses: 5000.0,
        netProfit: -5000.0,
        margin: 0.0,
      );
      expect(zeroRevenuePnl.marginPercent, 0.0);
      expect(zeroRevenuePnl.marginPercent.isFinite, true);
    });

    test('TaxReport & SalesVsPurchasesReport', () {
      final tax = TaxReport(gstCollected: 18000.0, gstPaid: 10000.0, netGstPayable: 8000.0);
      expect(tax.netGstPayable, 8000.0);

      final vs = SalesVsPurchasesReport(
        totalSales: 50000.0,
        totalPurchases: 30000.0,
        salesCount: 20,
        purchasesCount: 5,
        dataPoints: [
          SalesVsPurchasesDataPoint(label: 'Day 1', salesAmount: 10000.0, purchasesAmount: 8000.0),
        ],
      );
      expect(vs.totalSales, 50000.0);
      expect(vs.dataPoints.first.salesAmount, 10000.0);

      final stockDetail = StockItemDetail(
        productId: 1,
        productName: 'Item 1',
        currentStock: 10,
        purchasePrice: 50,
        salePrice: 100,
        value: 500,
      );
      expect(stockDetail.value, 500);

      final stockReport = StockReport(
        items: [stockDetail],
        totalInventoryValue: 500,
        lowStockCount: 0,
      );
      expect(stockReport.totalInventoryValue, 500);

      final txReport = TransactionReport(
        transactions: [],
        categoryBreakdown: {'Sales': 10000, 'Rent': 4000},
        totalIncome: 10000,
        totalExpense: 4000,
      );
      expect(txReport.netCashFlow, 6000);
    });
  });

  group('White-Box: Settings, Supplier & Updater Models', () {
    test('AppFeatureSettings - SQL mapping and fromSqlList', () {
      final settings = AppFeatureSettings(
        customerDiscountEnabled: true,
        productDiscountEnabled: false,
        offersEnabled: true,
        loyaltyEnabled: true,
        gstEnabled: true,
        scannerDevice: 'external',
        selectedCameraIndex: 1,
      );

      final sqlMap = settings.toSqlMap();
      expect(sqlMap['customer_discount_enabled'], '1');
      expect(sqlMap['product_discount_enabled'], '0');
      expect(sqlMap['scanner_device'], 'external');

      final sqlList = sqlMap.entries.map((e) => {'key': e.key, 'value': e.value}).toList();
      final restored = AppFeatureSettings.fromSqlList(sqlList);
      expect(restored.customerDiscountEnabled, true);
      expect(restored.productDiscountEnabled, false);
      expect(restored.scannerDevice, 'external');
      expect(restored.selectedCameraIndex, 1);

      final updated = settings.copyWith(
        customerDiscountEnabled: false,
        loyaltyEnabled: false,
        gstEnabled: false,
        autoSyncEnabled: false,
        inventoryTrackingEnabled: false,
        notificationsEnabled: false,
        productDiscountEnabled: true,
        offersEnabled: false,
        scannerDevice: 'camera',
        selectedCameraIndex: 0,
      );
      expect(updated.customerDiscountEnabled, false);
      expect(updated.loyaltyEnabled, false);
      expect(updated.gstEnabled, false);
      expect(updated.productDiscountEnabled, true);
      expect(settings.customerDiscountEnabled, true); // original immutable
    });

    test('SupplierModel - Serialization and copyWith', () {
      final now = DateTime(2026, 8, 31);
      final supplier = SupplierModel(
        id: 4,
        businessId: 1,
        name: 'Apex Wholesale',
        companyName: 'Apex Corp',
        phone: '9123456780',
        email: 'sales@apex.com',
        creditLimit: 100000.0,
        openingBalance: 15000.0,
        balance: 22000.0,
        gstNumber: '29ABCDE1234F1Z5',
        isActive: true,
        createdAt: now,
      );

      final map = supplier.toMap();
      final restored = SupplierModel.fromMap(map);
      expect(restored.id, 4);
      expect(restored.name, 'Apex Wholesale');
      expect(restored.balance, 22000.0);
      expect(restored.creditLimit, 100000.0);

      final updated = supplier.copyWith(balance: 10000.0);
      expect(updated.balance, 10000.0);
      expect(updated.id, 4);
      expect(supplier.balance, 22000.0); // original immutable
    });

    test('UpdateInfo - JSON serialization', () {
      final now = DateTime(2026, 8, 31, 8, 0);
      final info = UpdateInfo(
        version: '2.1.0',
        releaseNotes: 'Performance improvements and bug fixes',
        apkUrl: 'https://example.com/app.apk',
        exeUrl: 'https://example.com/app.exe',
        releaseDate: now,
      );

      final json = info.toJson();
      expect(json['version'], '2.1.0');

      final restored = UpdateInfo.fromJson(json);
      expect(restored.version, '2.1.0');
      expect(restored.releaseNotes, 'Performance improvements and bug fixes');
      expect(restored.apkUrl, 'https://example.com/app.apk');
      expect(restored.releaseDate, now);
    });
  });

  group('White-Box: Database Deserialization Null-Safety Defense (num/int/double casts)', () {
    test('SaleModel & SaleItemModel - Empty/Null maps deserialization without throwing', () {
      final nullSaleMap = <String, dynamic>{
        'id': 1,
        'business_id': null,
        'invoice_no': null,
        'subtotal': null,
        'discount': null,
        'gst_amount': null,
        'grand_total': null,
        'paid_amount': null,
        'balance_due': null,
        'round_off': null,
        'date': null,
      };
      final sale = SaleModel.fromMap(nullSaleMap);
      expect(sale.subtotal, 0.0);
      expect(sale.grandTotal, 0.0);
      expect(sale.businessId, 0);

      final nullSaleItemMap = <String, dynamic>{
        'id': 1,
        'sale_id': null,
        'product_id': null,
        'quantity': null,
        'price': null,
        'purchase_price': null,
        'gst_percent': null,
        'discount': null,
        'total': null,
      };
      final item = SaleItemModel.fromMap(nullSaleItemMap);
      expect(item.quantity, 1.0);
      expect(item.price, 0.0);
      expect(item.total, 0.0);
    });

    test('SaleHistoryModel & SaleHistoryItemModel - Empty/Null maps deserialization without throwing', () {
      final nullHistoryMap = <String, dynamic>{
        'id': 1,
        'business_id': null,
        'subtotal': null,
        'discount': null,
        'gst_amount': null,
        'grand_total': null,
        'paid_amount': null,
        'balance_due': null,
        'round_off': null,
        'date': null,
      };
      final history = SaleHistoryModel.fromMap(nullHistoryMap);
      expect(history.subtotal, 0.0);
      expect(history.grandTotal, 0.0);

      final nullHistoryItemMap = <String, dynamic>{
        'id': 1,
        'sale_id': null,
        'product_id': null,
        'quantity': null,
        'price': null,
        'purchase_price': null,
        'gst_percent': null,
        'discount': null,
        'total': null,
      };
      final item = SaleHistoryItemModel.fromMap(nullHistoryItemMap);
      expect(item.quantity, 1.0);
      expect(item.total, 0.0);
    });

    test('PurchaseModel & PurchaseItemModel - Empty/Null maps deserialization without throwing', () {
      final nullPurchaseMap = <String, dynamic>{
        'id': 1,
        'business_id': null,
        'subtotal': null,
        'discount': null,
        'gst_amount': null,
        'grand_total': null,
        'paid_amount': null,
        'balance_due': null,
        'date': null,
      };
      final purchase = PurchaseModel.fromMap(nullPurchaseMap);
      expect(purchase.subtotal, 0.0);
      expect(purchase.grandTotal, 0.0);

      final nullPurchaseItemMap = <String, dynamic>{
        'id': 1,
        'purchase_id': null,
        'product_id': null,
        'quantity': null,
        'price': null,
        'gst_percent': null,
        'total': null,
      };
      final pItem = PurchaseItemModel.fromMap(nullPurchaseItemMap);
      expect(pItem.quantity, 1.0);
      expect(pItem.purchasePrice, 0.0);
    });

    test('LedgerModel, TransactionModel, LoyaltySettings, Offer, ProductTierPrice - Null maps deserialization', () {
      final ledger = LedgerModel.fromMap({
        'id': 1,
        'business_id': null,
        'amount': null,
        'balance': null,
        'date': null,
      });
      expect(ledger.amount, 0.0);
      expect(ledger.balance, 0.0);

      final txn = TransactionModel.fromMap({
        'id': 1,
        'business_id': null,
        'amount': null,
        'date': null,
      });
      expect(txn.amount, 0.0);

      final loyalty = LoyaltySettings.fromMap({
        'id': 1,
        'business_id': null,
        'earn_rate': null,
        'earn_spend_amount': null,
        'redeem_value': null,
        'min_redeem_pts': null,
      });
      expect(loyalty.earnRate, 1.0);
      expect(loyalty.redeemValue, 1.0);

      final offer = Offer.fromMap({
        'id': 1,
        'business_id': null,
        'discount_value': null,
        'min_qty': null,
        'min_amount': null,
        'buy_qty': null,
        'get_qty': null,
      });
      expect(offer.discountValue, 0.0);
      expect(offer.minQty, 0.0);

      final tier = ProductTierPrice.fromMap({
        'id': null,
        'product_id': null,
        'category_id': null,
        'price': null,
      });
      expect(tier.price, 0.0);
      expect(tier.productId, 0);
    });
  });
}
