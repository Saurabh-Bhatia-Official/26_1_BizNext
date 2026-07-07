// lib/features/billing/models/pos_model.dart

import '../../inventory/models/product_model.dart';
import 'sale_history_model.dart';

/// Model representing a single item in the POS cart/session.
/// This is used during the active billing process.
class PosItemModel {
  final Product product;
  final double quantity;
  final double discount;
  final double manualPrice; // U10: Allow manual price override in POS
  final String? priceScaleName; // U14: Track which scale was selected

  const PosItemModel({
    required this.product,
    this.quantity = 1,
    this.discount = 0,
    this.manualPrice = 0,
    this.priceScaleName,
  });

  factory PosItemModel.fromSaleItem(SaleHistoryItemModel item) {
    return PosItemModel(
      product: Product(
        id: item.productId,
        name: item.productName,
        sellingPrice: item.price,
        purchasePrice: item.purchasePrice,
        gstPercent: item.gstPercent,
        stock: 99999, // Assumption: history items can be re-added/edited even if current stock is low
        unit: 'pcs',
      ),
      quantity: item.quantity,
      discount: item.discount,
      manualPrice: item.price, // Preserve the price from history as manual override
      priceScaleName: 'Previous Order', // Or determine from price if possible
    );
  }

  double get effectivePrice => manualPrice > 0 ? manualPrice : product.sellingPrice;
  double get subtotal => effectivePrice * quantity;
  double get gstAmount => (subtotal - discount) * (product.gstPercent / 100);
  double get total => subtotal - discount + gstAmount;

  PosItemModel copyWith({
    Product? product,
    double? quantity,
    double? discount,
    double? manualPrice,
    String? priceScaleName,
  }) {
    return PosItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      manualPrice: manualPrice ?? this.manualPrice,
      priceScaleName: priceScaleName ?? this.priceScaleName,
    );
  }

  SaleHistoryItemModel toSaleItem() {
    return SaleHistoryItemModel(
      productId: product.id!,
      productName: product.name,
      quantity: quantity,
      price: effectivePrice,
      purchasePrice: product.purchasePrice,
      discount: discount,
      gstPercent: product.gstPercent,
      gstAmount: gstAmount,
      total: total,
    );
  }
}

/// Model representing an active POS session/cart state.
/// This separates the interactive POS state from the finalized Sale History.
class PosModel {
  final List<PosItemModel> items;
  final int? selectedCustomerId;
  final String? selectedCustomerName;
  final String paymentMode;
  final double manualDiscount;
  final double autoBillDiscount;
  final int? selectedAccountId;
  final int? editingSaleId;
  final String? customInvoiceNo;
  final String? originalInvoiceNo;
   final String? notes;
  final bool isTaxInclusive;
  final double pointsEarned;
  final double pointsRedeemed;
  final double loyaltyDiscount;

  const PosModel({
    this.items = const [],
    this.selectedCustomerId,
    this.selectedCustomerName,
    this.paymentMode = 'Cash',
    this.manualDiscount = 0,
    this.selectedAccountId,
    this.editingSaleId,
    this.customInvoiceNo,
    this.originalInvoiceNo,
    this.notes,
    this.isTaxInclusive = false,
    this.autoBillDiscount = 0,
    this.pointsEarned = 0,
    this.pointsRedeemed = 0,
    this.loyaltyDiscount = 0,
  });

  factory PosModel.fromSaleHistory(SaleHistoryModel sale) {
    return PosModel(
      items: sale.items.map((item) => PosItemModel.fromSaleItem(item)).toList(),
      selectedCustomerId: sale.customerId,
      selectedCustomerName: sale.customerName,
      paymentMode: sale.paymentMode,
      manualDiscount: 0, // Manual discount is usually recalculatable or reset
      selectedAccountId: sale.accountId,
      editingSaleId: sale.id,
      originalInvoiceNo: sale.invoiceNo,
      customInvoiceNo: sale.invoiceNo,
      notes: sale.notes,
      pointsEarned: sale.pointsEarned,
      pointsRedeemed: sale.pointsRedeemed,
      loyaltyDiscount: sale.loyaltyDiscount,
    );
  }

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalGst => items.fold(0, (sum, item) => sum + item.gstAmount);
  double get itemDiscounts => items.fold(0, (sum, item) => sum + item.discount);
  double get totalDiscounts => itemDiscounts + manualDiscount + autoBillDiscount + loyaltyDiscount;
  double get grandTotal => subtotal + totalGst - totalDiscounts;
  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity.toInt());

  PosModel copyWith({
    List<PosItemModel>? items,
    int? selectedCustomerId,
    String? selectedCustomerName,
    bool clearCustomer = false,
    String? paymentMode,
    double? manualDiscount,
    int? selectedAccountId,
    int? editingSaleId,
    String? customInvoiceNo,
    String? originalInvoiceNo,
    String? notes,
    bool? isTaxInclusive,
    double? pointsEarned,
    double? pointsRedeemed,
    double? loyaltyDiscount,
  }) {
    return PosModel(
      items: items ?? this.items,
      selectedCustomerId: clearCustomer ? null : (selectedCustomerId ?? this.selectedCustomerId),
      selectedCustomerName: clearCustomer ? null : (selectedCustomerName ?? this.selectedCustomerName),
      paymentMode: paymentMode ?? this.paymentMode,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      editingSaleId: editingSaleId ?? this.editingSaleId,
      customInvoiceNo: customInvoiceNo ?? this.customInvoiceNo,
      originalInvoiceNo: originalInvoiceNo ?? this.originalInvoiceNo,
      notes: notes ?? this.notes,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      autoBillDiscount: autoBillDiscount ?? autoBillDiscount,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      pointsRedeemed: pointsRedeemed ?? this.pointsRedeemed,
      loyaltyDiscount: loyaltyDiscount ?? this.loyaltyDiscount,
    );
  }

  SaleHistoryModel toSaleHistory({
    required int businessId,
    required String invoiceNo,
    DateTime? date,
    String? notesOverride,
  }) {
    final isCredit = paymentMode == 'Credit';
    return SaleHistoryModel(
      id: editingSaleId,
      businessId: businessId,
      invoiceNo: invoiceNo,
      customerId: selectedCustomerId,
      customerName: selectedCustomerName,
      subtotal: subtotal,
      discount: totalDiscounts,
      gstAmount: totalGst,
      grandTotal: grandTotal,
      paidAmount: isCredit ? 0 : grandTotal,
      balanceDue: isCredit ? grandTotal : 0,
      paymentMode: paymentMode,
      accountId: selectedAccountId,
      notes: notesOverride ?? notes,
      pointsEarned: pointsEarned,
      pointsRedeemed: pointsRedeemed,
      date: date,
      items: items.map((i) => i.toSaleItem()).toList(),
    );
  }
}
