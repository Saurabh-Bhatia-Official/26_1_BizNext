// lib/features/purchases/models/purchase_model.dart

class PurchaseModel {
  final int? id;
  final int businessId;
  final String? billNo;
  final int? supplierId;
  final String? supplierName;
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
  final List<PurchaseItemModel>? items;

  PurchaseModel({
    this.id,
    required this.businessId,
    this.billNo,
    this.supplierId,
    this.supplierName,
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
    DateTime? date,
    this.items,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'bill_no': billNo,
      'supplier_id': supplierId,
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
      'date': date.toIso8601String(),
    };
  }

  factory PurchaseModel.fromMap(Map<String, dynamic> map) {
    return PurchaseModel(
      id: map['id'],
      businessId: (map['business_id'] as num?)?.toInt() ?? 0,
      billNo: map['bill_no'] ?? '',
      supplierId: map['supplier_id'],
      supplierName: map['supplier_name'],
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
      date: map['date'] != null ? DateTime.tryParse(map['date']) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class PurchaseItemModel {
  final int? id;
  final int? purchaseId;
  final int productId;
  final String productName;
  final double quantity;
  final double purchasePrice; // We'll keep this in memory as purchasePrice but map to 'price' in DB
  final double gstPercent;
  final double total;

  PurchaseItemModel({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
    this.gstPercent = 0,
    required this.total,
  });

  Map<String, dynamic> toMap(int pId) {
    return {
      'id': id,
      'purchase_id': pId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': purchasePrice, // Use 'price' to match DB column
      'gst_percent': gstPercent,
      'gst_amount': total * (gstPercent / 100), // Added to match DB column
      'total': total,
    };
  }

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      id: map['id'],
      purchaseId: map['purchase_id'],
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      productName: map['product_name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      purchasePrice: (map['price'] as num?)?.toDouble() ?? 0.0, // Use 'price' from DB
      gstPercent: (map['gst_percent'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
