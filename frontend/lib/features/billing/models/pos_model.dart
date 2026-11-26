// lib/features/billing/models/pos_model.dart

import '../../../core/utils/currency_formatter.dart';
import '../../inventory/models/product_model.dart';
import 'sale_history_model.dart';

/// Model representing a single item in the POS cart/session.
/// This is used during the active billing process.
class PosItemModel {
  final Product product;
  final double quantity;
  final double discount;
  final double manualPrice; // Allow manual price override in POS
  final String? priceScaleName; // Track which price tier / scale was selected
  final bool isTaxInclusive;

  const PosItemModel({
    required this.product,
    this.quantity = 1,
    this.discount = 0,
    this.manualPrice = 0,
    this.priceScaleName,
    this.isTaxInclusive = false,
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
      priceScaleName: 'Previous Order',
    );
  }

  double get effectivePrice => manualPrice > 0 ? manualPrice : product.sellingPrice;
  double get subtotal => CurrencyFormatter.round(effectivePrice * quantity);
  
  double get gstAmount {
    if (product.gstPercent <= 0) return 0.0;
    if (isTaxInclusive) {
      // Reverse calculate GST component from inclusive price
      final taxableAmount = (subtotal - discount);
      return CurrencyFormatter.round(taxableAmount - (taxableAmount / (1 + (product.gstPercent / 100))));
    } else {
      return CurrencyFormatter.round((subtotal - discount) * (product.gstPercent / 100));
    }
  }

  double get total {
    if (isTaxInclusive) {
      return CurrencyFormatter.round(subtotal - discount);
    } else {
      return CurrencyFormatter.round(subtotal - discount + gstAmount);
    }
  }

  PosItemModel copyWith({
    Product? product,
    double? quantity,
    double? discount,
    double? manualPrice,
    String? priceScaleName,
    bool? isTaxInclusive,
  }) {
    return PosItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      manualPrice: manualPrice ?? this.manualPrice,
      priceScaleName: priceScaleName ?? this.priceScaleName,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
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

/// Model representing a parked / held order in the POS session.
class HeldOrderModel {
  final String id;
  final String? customerName;
  final int? customerId;
  final List<PosItemModel> items;
  final double manualDiscount;
  final String paymentMode;
  final String? notes;
  final DateTime createdAt;

  HeldOrderModel({
    required this.id,
    this.customerName,
    this.customerId,
    required this.items,
    this.manualDiscount = 0,
    this.paymentMode = 'Cash',
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get grandTotal => items.fold(0.0, (sum, i) => sum + i.total) - manualDiscount;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity.toInt());
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
      manualDiscount: 0,
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

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get totalGst => items.fold(0.0, (sum, item) => sum + item.gstAmount);
  double get itemDiscounts => items.fold(0.0, (sum, item) => sum + item.discount);
  double get totalDiscounts => itemDiscounts + manualDiscount + autoBillDiscount + loyaltyDiscount;
  
  double get grandTotal {
    if (isTaxInclusive) {
      return (subtotal - totalDiscounts).clamp(0.0, double.infinity);
    } else {
      return (subtotal + totalGst - totalDiscounts).clamp(0.0, double.infinity);
    }
  }
  
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
    double? autoBillDiscount,
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
      autoBillDiscount: autoBillDiscount ?? this.autoBillDiscount,
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
      loyaltyDiscount: loyaltyDiscount,
      date: date,
      items: items.map((i) => i.toSaleItem()).toList(),
    );
  }
}
