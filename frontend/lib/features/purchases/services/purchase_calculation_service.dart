// lib/features/purchases/services/purchase_calculation_service.dart

import '../models/purchase_model.dart';

/// Centralized Calculation Service for Purchase Management
/// Implements BizNext Purchase Specification v2.0 (Sections 5, 6, 7, 12, 24, 31, 32).
class PurchaseCalculationService {
  const PurchaseCalculationService._();

  /// Calculates gross line value: Quantity * Purchase Rate
  static double calculateLineGross({
    required double quantity,
    required double purchasePrice,
  }) {
    return quantity * purchasePrice;
  }

  /// Calculates line taxable amount: Line Gross - Line Discount
  static double calculateLineTaxable({
    required double lineGross,
    double lineDiscount = 0.0,
  }) {
    return (lineGross - lineDiscount).clamp(0.0, double.infinity);
  }

  /// Calculates line GST amount: Line Taxable * (GST% / 100)
  static double calculateLineGst({
    required double lineTaxable,
    required double gstPercent,
  }) {
    return lineTaxable * (gstPercent / 100);
  }

  /// Calculates effective unit cost for an item after line and bill-level discounts
  static double calculateEffectiveUnitCost({
    required double quantity,
    required double purchasePrice,
    double lineDiscount = 0.0,
    double billDiscount = 0.0,
    double grossSubtotal = 0.0,
  }) {
    if (quantity <= 0) return purchasePrice;
    final lineGross = calculateLineGross(quantity: quantity, purchasePrice: purchasePrice);
    final lineTaxable = calculateLineTaxable(lineGross: lineGross, lineDiscount: lineDiscount);

    if (billDiscount > 0 && grossSubtotal > 0) {
      final billShare = (lineGross / grossSubtotal) * billDiscount;
      final netCost = (lineTaxable - billShare).clamp(0.0, double.infinity);
      return netCost / quantity;
    }

    return lineTaxable / quantity;
  }

  /// Computes new Weighted Average Cost (WAC)
  static double calculateNewWac({
    required double currentStock,
    required double currentWac,
    required double inwardQty,
    required double effectiveUnitCost,
  }) {
    if (currentStock + inwardQty <= 0) {
      return effectiveUnitCost;
    }
    return ((currentStock * currentWac) + (inwardQty * effectiveUnitCost)) / (currentStock + inwardQty);
  }

  /// Calculates total GST across items using pre-tax discount distribution
  static double calculateTotalGst({
    required List<PurchaseItemModel> items,
    double billDiscount = 0.0,
  }) {
    final subtotal = items.fold(0.0, (sum, i) => sum + i.lineGross);
    return items.fold(0.0, (sum, item) {
      if (billDiscount > 0 && subtotal > 0) {
        final billShare = (item.lineGross / subtotal) * billDiscount;
        final netTaxable = (item.taxableAmount - billShare).clamp(0.0, double.infinity);
        return sum + (netTaxable * (item.gstPercent / 100));
      }
      return sum + (item.taxableAmount * (item.gstPercent / 100));
    });
  }

  /// Comprehensive purchase calculation breakdown
  static PurchaseCalculationSummary calculateSummary({
    required List<PurchaseItemModel> items,
    double billDiscount = 0.0,
    double paidAmount = 0.0,
  }) {
    final grossSubtotal = items.fold(0.0, (sum, i) => sum + i.lineGross);
    final lineDiscountTotal = items.fold(0.0, (sum, i) => sum + i.discount);
    final totalDiscount = lineDiscountTotal + billDiscount;
    final taxableAmount = (grossSubtotal - totalDiscount).clamp(0.0, double.infinity);
    final totalGst = calculateTotalGst(items: items, billDiscount: billDiscount);
    final grandTotal = taxableAmount + totalGst;
    final balanceDue = (grandTotal - paidAmount).clamp(0.0, double.infinity);
    final paymentStatus = PurchaseModel.calculatePaymentStatus(paidAmount, grandTotal);

    return PurchaseCalculationSummary(
      grossSubtotal: grossSubtotal,
      lineDiscountTotal: lineDiscountTotal,
      billDiscount: billDiscount,
      totalDiscount: totalDiscount,
      taxableAmount: taxableAmount,
      totalGst: totalGst,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      balanceDue: balanceDue,
      paymentStatus: paymentStatus,
    );
  }
}

/// Result summary of purchase calculations
class PurchaseCalculationSummary {
  final double grossSubtotal;
  final double lineDiscountTotal;
  final double billDiscount;
  final double totalDiscount;
  final double taxableAmount;
  final double totalGst;
  final double grandTotal;
  final double paidAmount;
  final double balanceDue;
  final String paymentStatus;

  const PurchaseCalculationSummary({
    required this.grossSubtotal,
    required this.lineDiscountTotal,
    required this.billDiscount,
    required this.totalDiscount,
    required this.taxableAmount,
    required this.totalGst,
    required this.grandTotal,
    required this.paidAmount,
    required this.balanceDue,
    required this.paymentStatus,
  });

  /// Verifies the fundamental accounting balance rule: Total Debits == Total Credits
  bool get isAccountingBalanced {
    final totalDebits = taxableAmount + totalGst;
    final totalCredits = paidAmount + balanceDue;
    return (totalDebits - totalCredits).abs() <= 0.05;
  }
}
