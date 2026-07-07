// lib/features/loyalty/models/loyalty_model.dart

class LoyaltySettings {
  final int? id;
  final int businessId;
  final double earnRate; // Points per amount spent
  final double earnSpendAmount; // Amount spent to earn points
  final double redeemValue; // ₹ value per 1 point
  final double minRedeemPoints;
  final int expiryDays;
  final String pointName;
  final double maxRedeemLimit; // 0 = no limit
  final double welcomePoints;
  final bool isActive;

  LoyaltySettings({
    this.id,
    required this.businessId,
    this.earnRate = 1.0,
    this.earnSpendAmount = 100.0,
    this.redeemValue = 1.0,
    this.minRedeemPoints = 100,
    this.expiryDays = 365,
    this.pointName = 'Points',
    this.maxRedeemLimit = 0,
    this.welcomePoints = 0,
    this.isActive = true,
  });

  factory LoyaltySettings.fromMap(Map<String, dynamic> map) {
    return LoyaltySettings(
      id: map['id'],
      businessId: map['business_id'],
      earnRate: (map['earn_rate'] as num).toDouble(),
      earnSpendAmount: (map['earn_spend_amount'] as num?)?.toDouble() ?? 100.0,
      redeemValue: (map['redeem_value'] as num).toDouble(),
      minRedeemPoints: (map['min_redeem_pts'] as num).toDouble(),
      expiryDays: map['expiry_days'] ?? 365,
      pointName: map['point_name'] ?? 'Points',
      maxRedeemLimit: (map['max_redeem_limit'] as num?)?.toDouble() ?? 0,
      welcomePoints: (map['welcome_points'] as num?)?.toDouble() ?? 0,
      isActive: map['is_active'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'business_id': businessId,
      'earn_rate': earnRate,
      'earn_spend_amount': earnSpendAmount,
      'redeem_value': redeemValue,
      'min_redeem_pts': minRedeemPoints,
      'expiry_days': expiryDays,
      'point_name': pointName,
      'max_redeem_limit': maxRedeemLimit,
      'welcome_points': welcomePoints,
      'is_active': isActive ? 1 : 0,
    };
  }

  LoyaltySettings copyWith({
    int? id,
    int? businessId,
    double? earnRate,
    double? earnSpendAmount,
    double? redeemValue,
    double? minRedeemPoints,
    int? expiryDays,
    String? pointName,
    double? maxRedeemLimit,
    double? welcomePoints,
    bool? isActive,
  }) {
    return LoyaltySettings(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      earnRate: earnRate ?? this.earnRate,
      earnSpendAmount: earnSpendAmount ?? this.earnSpendAmount,
      redeemValue: redeemValue ?? this.redeemValue,
      minRedeemPoints: minRedeemPoints ?? this.minRedeemPoints,
      expiryDays: expiryDays ?? this.expiryDays,
      pointName: pointName ?? this.pointName,
      maxRedeemLimit: maxRedeemLimit ?? this.maxRedeemLimit,
      welcomePoints: welcomePoints ?? this.welcomePoints,
      isActive: isActive ?? this.isActive,
    );
  }
}
