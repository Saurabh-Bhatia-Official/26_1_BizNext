// lib/features/discounts/models/offer.dart

class Offer {
  final int? id;
  final int businessId;
  final String name;
  final String offerType; // 'buy_x_get_y', 'festival', 'loyalty', 'bulk', 'first_purchase', 'bill_amount'
  final String discountType; // 'percentage', 'fixed', 'free_product'
  final double discountValue;
  final double minQty;
  final double minAmount;
  final String applyTo; // 'all', 'category', 'product'
  final int? targetId; // category_id or product_id
  final double buyQty;
  final double getQty;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final String? posterPath;

  Offer({
    this.id,
    required this.businessId,
    required this.name,
    required this.offerType,
    required this.discountType,
    required this.discountValue,
    this.minQty = 0,
    this.minAmount = 0,
    this.applyTo = 'all',
    this.targetId,
    this.buyQty = 0,
    this.getQty = 0,
    this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    this.posterPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'offer_type': offerType,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_qty': minQty,
      'min_amount': minAmount,
      'apply_to': applyTo,
      'target_id': targetId,
      'buy_qty': buyQty,
      'get_qty': getQty,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'poster_path': posterPath,
    };
  }

  factory Offer.fromMap(Map<String, dynamic> map) {
    return Offer(
      id: map['id'],
      businessId: (map['business_id'] as num?)?.toInt() ?? 0,
      name: map['name'] ?? '',
      offerType: map['offer_type'] ?? '',
      discountType: map['discount_type'] ?? '',
      discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0.0,
      minQty: (map['min_qty'] as num?)?.toDouble() ?? 0.0,
      minAmount: (map['min_amount'] as num?)?.toDouble() ?? 0.0,
      applyTo: map['apply_to'] ?? '',
      targetId: map['target_id'],
      buyQty: (map['buy_qty'] as num?)?.toDouble() ?? 0.0,
      getQty: (map['get_qty'] as num?)?.toDouble() ?? 0.0,
      startDate: map['start_date'] != null ? DateTime.tryParse(map['start_date']) : null,
      endDate: map['end_date'] != null ? DateTime.tryParse(map['end_date']) : null,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
      posterPath: map['poster_path'],
    );
  }

  String getOfferDescription(String? targetProductName) {
    String suffix = '';
    if (applyTo == 'product') {
      suffix = targetProductName != null ? ' on $targetProductName' : ' on specific product';
    }

    switch (offerType) {
      case 'buy_x_get_y':
        return 'Buy ${buyQty.toInt()} get ${getQty.toInt()} free$suffix';
      case 'bill_amount':
        return '$discountValue${discountType == 'percentage' ? '%' : ' off'} on bills above ₹$minAmount$suffix';
      case 'product_discount':
        return '$discountValue${discountType == 'percentage' ? '%' : ' off'} on selected products';
      default:
        return '$discountValue${discountType == 'percentage' ? '%' : ' off'} discount$suffix';
    }
  }

  bool get isCurrentlyValid => isCurrentlyValidAt(DateTime.now());

  /// Deterministically checks if offer is valid at given timestamp
  bool isCurrentlyValidAt([DateTime? now]) {
    if (!isActive) return false;
    final current = now ?? DateTime.now();
    if (startDate != null && current.isBefore(startDate!)) return false;
    if (endDate != null && current.isAfter(endDate!)) return false;
    return true;
  }

  Offer copyWith({
    int? id,
    int? businessId,
    String? name,
    String? offerType,
    String? discountType,
    double? discountValue,
    double? minQty,
    double? minAmount,
    String? applyTo,
    int? targetId,
    double? buyQty,
    double? getQty,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
    bool? isActive,
    DateTime? createdAt,
    String? posterPath,
  }) {
    return Offer(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      offerType: offerType ?? this.offerType,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      minQty: minQty ?? this.minQty,
      minAmount: minAmount ?? this.minAmount,
      applyTo: applyTo ?? this.applyTo,
      targetId: targetId ?? this.targetId,
      buyQty: buyQty ?? this.buyQty,
      getQty: getQty ?? this.getQty,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      posterPath: posterPath ?? this.posterPath,
    );
  }
}
