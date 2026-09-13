// test/purchase_model_flow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:biz_next/features/purchases/models/purchase_model.dart';
import 'package:biz_next/features/purchases/services/purchase_calculation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BizNext v2.0 Purchase Model & Flow Control Suite', () {
    test('1. Worked Example verification matching purchase.md Section 9', () {
      final item = PurchaseItemModel(
        productId: 101,
        productName: 'Commercial Basmati Rice',
        quantity: 10,
        purchasePrice: 1000.0,
        gstPercent: 18.0,
        total: 10000.0,
      );

      expect(item.lineGross, 10000.0);
      expect(item.taxableAmount, 10000.0);
      expect(item.effectiveUnitCost, 1000.0);

      final purchase = PurchaseModel(
        businessId: 1,
        billNo: 'BILL-2026-001',
        supplierId: 5,
        subtotal: 10000.0,
        discount: 500.0,
        gstAmount: 1710.0, // (10000 - 500) * 0.18
        grandTotal: 11210.0, // 9500 + 1710
        paidAmount: 5000.0,
        balanceDue: 6210.0,
        items: [item],
      );

      // Section 5 & 6 verification
      expect(purchase.taxableAmount, 9500.0,
          reason: 'Net Taxable Value must equal Subtotal - Discount');
      expect(purchase.grandTotal, 11210.0);
      expect(purchase.balanceDue, 6210.0);
      expect(purchase.paymentStatus, 'partially_paid');
    });

    test('2. Double-Entry Accounting balance verification matching purchase.md Section 10 & 32', () {
      final purchase = PurchaseModel(
        businessId: 1,
        billNo: 'BILL-ACC-01',
        supplierId: 3,
        subtotal: 10000.0,
        discount: 500.0,
        gstAmount: 1710.0,
        grandTotal: 11210.0,
        paidAmount: 5000.0,
        balanceDue: 6210.0,
      );

      // Simulated ledger postings from PurchaseRepository
      final debitInventoryAsset = purchase.taxableAmount; // ₹9,500
      final debitInputGstAsset = purchase.gstAmount; // ₹1,710
      final creditBankPayment = purchase.paidAmount; // ₹5,000
      final creditSupplierPayable = purchase.balanceDue; // ₹6,210

      final totalDebits = debitInventoryAsset + debitInputGstAsset;
      final totalCredits = creditBankPayment + creditSupplierPayable;

      expect(totalDebits, 11210.0);
      expect(totalCredits, 11210.0);
      expect(totalDebits, totalCredits,
          reason: 'TOTAL DEBITS must strictly equal TOTAL CREDITS without discrepancy');
    });

    test('3. Payment status transitions: unpaid, partially_paid, paid', () {
      final unpaid = PurchaseModel(
        businessId: 1,
        subtotal: 5000.0,
        gstAmount: 250.0,
        grandTotal: 5250.0,
        paidAmount: 0.0,
        balanceDue: 5250.0,
      );
      expect(unpaid.paymentStatus, 'unpaid');
      expect(unpaid.isUnpaid, isTrue);
      expect(unpaid.isFullyPaid, isFalse);

      final partial = PurchaseModel(
        businessId: 1,
        subtotal: 5000.0,
        gstAmount: 250.0,
        grandTotal: 5250.0,
        paidAmount: 2000.0,
        balanceDue: 3250.0,
      );
      expect(partial.paymentStatus, 'partially_paid');
      expect(partial.isPartiallyPaid, isTrue);
      expect(partial.hasPendingBalance, isTrue);

      final paid = PurchaseModel(
        businessId: 1,
        subtotal: 5000.0,
        gstAmount: 250.0,
        grandTotal: 5250.0,
        paidAmount: 5250.0,
        balanceDue: 0.0,
      );
      expect(paid.paymentStatus, 'paid');
      expect(paid.isFullyPaid, isTrue);
      expect(paid.hasPendingBalance, isFalse);
    });

    test('4. Effective Unit Cost & Line-level discount in PurchaseItemModel', () {
      final itemWithLineDiscount = PurchaseItemModel(
        productId: 202,
        productName: 'Edible Oil 15L Tin',
        quantity: 5,
        purchasePrice: 2000.0, // Gross: 10000
        discount: 500.0, // Line discount
        gstPercent: 5.0,
        total: 10000.0,
      );

      expect(itemWithLineDiscount.lineGross, 10000.0);
      expect(itemWithLineDiscount.taxableAmount, 9500.0);
      expect(itemWithLineDiscount.gstAmount, 475.0); // 9500 * 0.05
      expect(itemWithLineDiscount.effectiveUnitCost, 1900.0, // 9500 / 5
          reason: 'Effective unit cost must reflect net cost divided by inward qty');
    });

    test('5. Serialization & backward-compatible deserialization', () {
      final purchase = PurchaseModel(
        id: 77,
        businessId: 2,
        billNo: 'INV-TEST-77',
        supplierId: 10,
        supplierName: 'National Agri Corp',
        subtotal: 20000.0,
        discount: 2000.0,
        taxableAmount: 18000.0,
        gstAmount: 900.0,
        grandTotal: 18900.0,
        paidAmount: 18900.0,
        balanceDue: 0.0,
        paymentMode: 'UPI',
        paymentStatus: 'paid',
      );

      final map = purchase.toMap();
      expect(map['taxable_amount'], 18000.0);
      expect(map['payment_status'], 'paid');

      final restored = PurchaseModel.fromMap(map);
      expect(restored.id, 77);
      expect(restored.taxableAmount, 18000.0);
      expect(restored.paymentStatus, 'paid');
      expect(restored.isFullyPaid, isTrue);

      // Backward compatibility: map missing taxable_amount and payment_status
      final legacyMap = <String, dynamic>{
        'id': 78,
        'business_id': 2,
        'bill_no': 'LEGACY-01',
        'subtotal': 1000.0,
        'discount': 100.0,
        'gst_amount': 50.0,
        'grand_total': 950.0,
        'paid_amount': 500.0,
        'balance_due': 450.0,
      };
      final fromLegacy = PurchaseModel.fromMap(legacyMap);
      expect(fromLegacy.taxableAmount, 900.0); // 1000 - 100
      expect(fromLegacy.paymentStatus, 'partially_paid');
    });

    test('6. PurchaseCalculationService full summary and WAC calculation', () {
      final item1 = PurchaseItemModel(
        productId: 1,
        productName: 'Item 1',
        quantity: 10,
        purchasePrice: 100.0,
        gstPercent: 18.0,
        total: 1000.0,
      );
      final item2 = PurchaseItemModel(
        productId: 2,
        productName: 'Item 2',
        quantity: 5,
        purchasePrice: 200.0,
        gstPercent: 12.0,
        total: 1000.0,
      );

      final summary = PurchaseCalculationService.calculateSummary(
        items: [item1, item2],
        billDiscount: 200.0,
        paidAmount: 1000.0,
      );

      expect(summary.grossSubtotal, 2000.0);
      expect(summary.totalDiscount, 200.0);
      expect(summary.taxableAmount, 1800.0);
      expect(summary.isAccountingBalanced, isTrue);
      expect(summary.paymentStatus, 'partially_paid');

      // WAC verification
      final newWac = PurchaseCalculationService.calculateNewWac(
        currentStock: 10,
        currentWac: 100.0,
        inwardQty: 10,
        effectiveUnitCost: 80.0,
      );
      expect(newWac, 90.0);
    });
  });
}
