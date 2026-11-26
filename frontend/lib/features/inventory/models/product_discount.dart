// lib/features/inventory/models/product_discount.dart

class ProductDiscount {
  final int? id;
  final int businessId;
  final int productId;
  final String discountType; // 'percentage', 'fixed'
  final double discountValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;

  ProductDiscount({
    this.id,
    required this.businessId,
    required this.productId,
    required this.discountType,
    required this.discountValue,
    this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'product_id': productId,
      'discount_type': discountType,
      'discount_value': discountValue,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProductDiscount.fromMap(Map<String, dynamic> map) {
    return ProductDiscount(
      id: map['id'],
      businessId: map['business_id'],
      productId: map['product_id'],
      discountType: map['discount_type'],
      discountValue: map['discount_value'],
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date']) : null,
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  bool get isCurrentlyValid => isCurrentlyValidAt(DateTime.now());

  /// Deterministically checks if product discount is valid at given timestamp
  bool isCurrentlyValidAt([DateTime? now]) {
    if (!isActive) return false;
    final current = now ?? DateTime.now();
    if (startDate != null && current.isBefore(startDate!)) return false;
    if (endDate != null && current.isAfter(endDate!)) return false;
    return true;
  }

  ProductDiscount copyWith({
    int? id,
    int? businessId,
    int? productId,
    String? discountType,
    double? discountValue,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ProductDiscount(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      productId: productId ?? this.productId,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
