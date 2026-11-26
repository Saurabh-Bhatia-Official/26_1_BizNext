// lib/features/customers/models/customer_model.dart

class CustomerModel {
  final int? id;
  final int businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstNumber;
  final int? customerTypeId;
  final String? customerTypeName;
  final double balance;
  final double loyaltyPoints;
  final DateTime createdAt;

  CustomerModel({
    this.id,
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.gstNumber,
    this.customerTypeId,
    this.customerTypeName,
    this.balance = 0,
    this.loyaltyPoints = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gst_number': gstNumber,
      'customer_type_id': customerTypeId,
      'balance': balance,
      'loyalty_points': loyaltyPoints,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'],
      businessId: map['business_id'] ?? 1,
      name: map['name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      gstNumber: map['gst_number'],
      customerTypeId: map['customer_type_id'] as int?,
      customerTypeName: map['customer_type_name'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      loyaltyPoints: (map['loyalty_points'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  CustomerModel copyWith({
    int? id,
    int? businessId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstNumber,
    int? customerTypeId,
    String? customerTypeName,
    double? balance,
    double? loyaltyPoints,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      customerTypeId: customerTypeId ?? this.customerTypeId,
      customerTypeName: customerTypeName ?? this.customerTypeName,
      balance: balance ?? this.balance,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
