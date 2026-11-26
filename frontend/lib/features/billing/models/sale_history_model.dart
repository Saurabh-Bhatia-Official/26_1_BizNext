// lib/features/billing/models/sale_history_model.dart

/// Model representing a finalized sale record in the database.
/// This is used for sales history, reports, and receipts.
class SaleHistoryModel {
  final int? id;
  final int businessId;
  final String invoiceNo;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final double subtotal;
  final double discount;
  final double gstAmount;
  final double grandTotal;
  final double paidAmount;
  final double balanceDue;
  final String paymentMode;
  final int? accountId;
  final String? accountName;
  final String? notes;
  final String status;
  final DateTime date;
  final double pointsEarned;
  final double pointsRedeemed;
  final double loyaltyDiscount;
  final List<SaleHistoryItemModel> items;

  SaleHistoryModel({
    this.id,
    required this.businessId,
    required this.invoiceNo,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.subtotal,
    this.discount = 0,
    required this.gstAmount,
    required this.grandTotal,
    this.paidAmount = 0,
    this.balanceDue = 0,
    this.paymentMode = 'Cash',
    this.accountId,
    this.accountName,
    this.notes,
    this.status = 'completed',
    this.pointsEarned = 0,
    this.pointsRedeemed = 0,
    this.loyaltyDiscount = 0,
    DateTime? date,
    this.items = const [],
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'invoice_no': invoiceNo,
      'customer_id': customerId,
      'subtotal': subtotal,
      'discount': discount,
      'gst_amount': gstAmount,
      'grand_total': grandTotal,
      'paid_amount': paidAmount,
      'balance_due': balanceDue,
      'payment_mode': paymentMode,
      'account_id': accountId,
      'notes': notes,
      'status': status,
      'points_earned': pointsEarned,
      'points_redeemed': pointsRedeemed,
      'loyalty_discount': loyaltyDiscount,
      'date': date.toIso8601String(),
    };
  }

  factory SaleHistoryModel.fromMap(Map<String, dynamic> map, [List<SaleHistoryItemModel> items = const []]) {
    return SaleHistoryModel(
      id: map['id'],
      businessId: (map['business_id'] as num?)?.toInt() ?? 0,
      invoiceNo: map['invoice_no'] ?? '',
      customerId: map['customer_id'],
      customerName: map['customer_name'],
      customerPhone: map['customer_phone'],
      customerAddress: map['customer_address'],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (map['gst_amount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grand_total'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceDue: (map['balance_due'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['payment_mode'] ?? 'Cash',
      accountId: map['account_id'],
      accountName: map['account_name'],
      notes: map['notes'],
      status: map['status'] ?? 'completed',
      pointsEarned: (map['points_earned'] as num?)?.toDouble() ?? 0.0,
      pointsRedeemed: (map['points_redeemed'] as num?)?.toDouble() ?? 0.0,
      loyaltyDiscount: (map['loyalty_discount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] != null ? DateTime.tryParse(map['date']) ?? DateTime.now() : DateTime.now(),
      items: items,
    );
  }
}

/// Model representing an individual item within a finalized sale history record.
class SaleHistoryItemModel {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final double quantity;
  final double price;
  final double discount;
  final double gstPercent;
  final double gstAmount;
  final double total;
  final double purchasePrice;

  SaleHistoryItemModel({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.discount = 0,
    this.gstPercent = 0,
    required this.gstAmount,
    required this.total,
    this.purchasePrice = 0,
  });

  Map<String, dynamic> toMap(int saleId) {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'gst_percent': gstPercent,
      'gst_amount': gstAmount,
      'total': total,
      'purchase_price': purchasePrice,
    };
  }

  factory SaleHistoryItemModel.fromMap(Map<String, dynamic> map) {
    return SaleHistoryItemModel(
      id: map['id'],
      saleId: map['sale_id'],
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      productName: map['product_name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      gstPercent: (map['gst_percent'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (map['gst_amount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
