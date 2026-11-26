// lib/features/purchases/models/purchase_model.dart

class PurchaseModel {
  final int? id;
  final int businessId;
  final String? billNo;
  final int? supplierId;
  final String? supplierName;
  final double subtotal; // Gross subtotal of all items
  final double discount; // Bill-level discount
  final double taxableAmount; // Net Taxable Value = (subtotal - discount)
  final double gstAmount; // Total GST
  final double grandTotal; // Net Taxable Value + GST
  final double paidAmount; // Disbursed payment
  final double balanceDue; // grandTotal - paidAmount
  final String paymentMode; // 'Cash', 'Bank Transfer', 'UPI', 'Credit'
  final String paymentStatus; // 'unpaid', 'partially_paid', 'paid'
  final int? accountId;
  final String? accountName;
  final String? notes;
  final String status; // 'completed', 'draft', 'cancelled'
  final DateTime date;
  final List<PurchaseItemModel>? items;

  PurchaseModel({
    this.id,
    required this.businessId,
    this.billNo,
    this.supplierId,
    this.supplierName,
    required this.subtotal,
    this.discount = 0.0,
    double? taxableAmount,
    required this.gstAmount,
    required this.grandTotal,
    this.paidAmount = 0.0,
    this.balanceDue = 0.0,
    this.paymentMode = 'Cash',
    String? paymentStatus,
    this.accountId,
    this.accountName,
    this.notes,
    this.status = 'completed',
    DateTime? date,
    this.items,
  })  : taxableAmount = taxableAmount ?? (subtotal - discount).clamp(0.0, double.infinity),
        paymentStatus = paymentStatus ?? calculatePaymentStatus(paidAmount, grandTotal),
        date = date ?? DateTime.now();

  static String calculatePaymentStatus(double paid, double total) {
    if (paid <= 0) return 'unpaid';
    if (paid >= total) return 'paid';
    return 'partially_paid';
  }

  bool get isFullyPaid => paymentStatus == 'paid' || balanceDue <= 0;
  bool get isPartiallyPaid => paymentStatus == 'partially_paid';
  bool get isUnpaid => paymentStatus == 'unpaid';
  bool get hasPendingBalance => balanceDue > 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'bill_no': billNo,
      'supplier_id': supplierId,
      'subtotal': subtotal,
      'discount': discount,
      'taxable_amount': taxableAmount,
      'gst_amount': gstAmount,
      'grand_total': grandTotal,
      'paid_amount': paidAmount,
      'balance_due': balanceDue,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
      'account_id': accountId,
      'notes': notes,
      'status': status,
      'date': date.toIso8601String(),
    };
  }

  factory PurchaseModel.fromMap(Map<String, dynamic> map, {List<PurchaseItemModel>? items}) {
    final sub = (map['subtotal'] as num?)?.toDouble() ?? 0.0;
    final disc = (map['discount'] as num?)?.toDouble() ?? 0.0;
    final taxAmt = (map['taxable_amount'] as num?)?.toDouble() ?? (sub - disc).clamp(0.0, double.infinity);
    final gst = (map['gst_amount'] as num?)?.toDouble() ?? 0.0;
    final grand = (map['grand_total'] as num?)?.toDouble() ?? (taxAmt + gst);
    final paid = (map['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final bal = (map['balance_due'] as num?)?.toDouble() ?? (grand - paid).clamp(0.0, double.infinity);

    final storedPayStatus = map['payment_status'] as String?;
    final pStatus = (storedPayStatus != null && storedPayStatus.isNotEmpty)
        ? storedPayStatus
        : calculatePaymentStatus(paid, grand);

    return PurchaseModel(
      id: map['id'],
      businessId: (map['business_id'] as num?)?.toInt() ?? 0,
      billNo: map['bill_no'] ?? '',
      supplierId: map['supplier_id'],
      supplierName: map['supplier_name'],
      subtotal: sub,
      discount: disc,
      taxableAmount: taxAmt,
      gstAmount: gst,
      grandTotal: grand,
      paidAmount: paid,
      balanceDue: bal,
      paymentMode: map['payment_mode'] ?? 'Cash',
      paymentStatus: pStatus,
      accountId: map['account_id'],
      accountName: map['account_name'],
      notes: map['notes'],
      status: map['status'] ?? 'completed',
      date: map['date'] != null ? DateTime.tryParse(map['date']) ?? DateTime.now() : DateTime.now(),
      items: items,
    );
  }

  PurchaseModel copyWith({
    int? id,
    int? businessId,
    String? billNo,
    int? supplierId,
    String? supplierName,
    double? subtotal,
    double? discount,
    double? taxableAmount,
    double? gstAmount,
    double? grandTotal,
    double? paidAmount,
    double? balanceDue,
    String? paymentMode,
    String? paymentStatus,
    int? accountId,
    String? accountName,
    String? notes,
    String? status,
    DateTime? date,
    List<PurchaseItemModel>? items,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      billNo: billNo ?? this.billNo,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      gstAmount: gstAmount ?? this.gstAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceDue: balanceDue ?? this.balanceDue,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      date: date ?? this.date,
      items: items ?? this.items,
    );
  }
}

class PurchaseItemModel {
  final int? id;
  final int? purchaseId;
  final int productId;
  final String productName;
  final double quantity;
  final double purchasePrice; // Stored as 'price' in DB
  final double discount; // Line-level discount
  final double taxableAmount; // (quantity * purchasePrice) - discount
  final double gstPercent;
  final double gstAmount; // taxableAmount * (gstPercent / 100)
  final double total; // Line gross total: quantity * purchasePrice

  PurchaseItemModel({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
    this.discount = 0.0,
    double? taxableAmount,
    this.gstPercent = 0.0,
    double? gstAmount,
    required this.total,
  })  : taxableAmount = taxableAmount ?? ((quantity * purchasePrice) - discount).clamp(0.0, double.infinity),
        gstAmount = gstAmount ?? (((taxableAmount ?? ((quantity * purchasePrice) - discount).clamp(0.0, double.infinity))) * (gstPercent / 100));

  double get lineGross => quantity * purchasePrice;
  double get effectiveUnitCost => quantity > 0 ? (taxableAmount / quantity) : purchasePrice;

  Map<String, dynamic> toMap(int pId) {
    return {
      'id': id,
      'purchase_id': pId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': purchasePrice,
      'discount': discount,
      'taxable_amount': taxableAmount,
      'gst_percent': gstPercent,
      'gst_amount': gstAmount,
      'total': total,
    };
  }

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    final qty = (map['quantity'] as num?)?.toDouble() ?? 1.0;
    final price = (map['price'] as num?)?.toDouble() ?? 0.0;
    final disc = (map['discount'] as num?)?.toDouble() ?? 0.0;
    final gstP = (map['gst_percent'] as num?)?.toDouble() ?? 0.0;
    final gross = qty * price;
    final taxAmt = (map['taxable_amount'] as num?)?.toDouble() ?? (gross - disc).clamp(0.0, double.infinity);
    final calculatedGst = taxAmt * (gstP / 100);
    final gstAmt = (map['gst_amount'] as num?)?.toDouble() ?? calculatedGst;

    return PurchaseItemModel(
      id: map['id'],
      purchaseId: map['purchase_id'],
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      productName: map['product_name'] ?? '',
      quantity: qty,
      purchasePrice: price,
      discount: disc,
      taxableAmount: taxAmt,
      gstPercent: gstP,
      gstAmount: gstAmt,
      total: (map['total'] as num?)?.toDouble() ?? gross,
    );
  }

  PurchaseItemModel copyWith({
    int? id,
    int? purchaseId,
    int? productId,
    String? productName,
    double? quantity,
    double? purchasePrice,
    double? discount,
    double? taxableAmount,
    double? gstPercent,
    double? gstAmount,
    double? total,
  }) {
    return PurchaseItemModel(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      discount: discount ?? this.discount,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      gstPercent: gstPercent ?? this.gstPercent,
      gstAmount: gstAmount ?? this.gstAmount,
      total: total ?? this.total,
    );
  }
}
