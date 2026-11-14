// lib/features/customers/models/customer_discount.dart

class CustomerDiscount {
  final int? id;
  final int businessId;
  final int customerId;
  final String discountType; // 'percentage', 'fixed'
  final double discountValue;
  final bool isActive;
  final DateTime createdAt;

  CustomerDiscount({
    this.id,
    required this.businessId,
    required this.customerId,
    required this.discountType,
    required this.discountValue,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'customer_id': customerId,
      'discount_type': discountType,
      'discount_value': discountValue,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CustomerDiscount.fromMap(Map<String, dynamic> map) {
    return CustomerDiscount(
      id: map['id'],
      businessId: map['business_id'],
      customerId: map['customer_id'],
      discountType: map['discount_type'],
      discountValue: map['discount_value'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  CustomerDiscount copyWith({
    int? id,
    int? businessId,
    int? customerId,
    String? discountType,
    double? discountValue,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CustomerDiscount(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerId: customerId ?? this.customerId,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
