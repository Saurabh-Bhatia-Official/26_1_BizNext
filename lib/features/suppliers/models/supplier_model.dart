// lib/features/suppliers/models/supplier_model.dart

class SupplierModel {
  final int? id;
  final int businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstNumber;
  final double balance;
  final DateTime createdAt;

  SupplierModel({
    this.id,
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.gstNumber,
    this.balance = 0,
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
      'balance': balance,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'],
      businessId: map['business_id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      gstNumber: map['gst_number'],
      balance: (map['balance'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  SupplierModel copyWith({
    int? id,
    int? businessId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstNumber,
    double? balance,
    DateTime? createdAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
