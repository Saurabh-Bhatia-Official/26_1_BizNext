// lib/features/suppliers/models/supplier_model.dart

class SupplierModel {
  final int? id;
  final int businessId;
  final String name;
  final String? companyName;
  final String? phone;
  final String? email;
  final String? address;
  final String? state;
  final String? gstNumber;
  final String? pan;
  final String? contactPerson;
  final String? paymentTerms;
  final double creditLimit;
  final double openingBalance;
  final double balance;
  final String? bankDetails;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  SupplierModel({
    this.id,
    required this.businessId,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.address,
    this.state,
    this.gstNumber,
    this.pan,
    this.contactPerson,
    this.paymentTerms,
    this.creditLimit = 0,
    this.openingBalance = 0,
    this.balance = 0,
    this.bankDetails,
    this.notes,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'company_name': companyName,
      'phone': phone,
      'email': email,
      'address': address,
      'state': state,
      'gst_number': gstNumber,
      'pan': pan,
      'contact_person': contactPerson,
      'payment_terms': paymentTerms,
      'credit_limit': creditLimit,
      'opening_balance': openingBalance,
      'balance': balance,
      'bank_details': bankDetails,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'],
      businessId: map['business_id'] ?? 1,
      name: map['name'] ?? '',
      companyName: map['company_name'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      state: map['state'],
      gstNumber: map['gst_number'],
      pan: map['pan'],
      contactPerson: map['contact_person'],
      paymentTerms: map['payment_terms'],
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      bankDetails: map['bank_details'],
      notes: map['notes'],
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  SupplierModel copyWith({
    int? id,
    int? businessId,
    String? name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
    String? state,
    String? gstNumber,
    String? pan,
    String? contactPerson,
    String? paymentTerms,
    double? creditLimit,
    double? openingBalance,
    double? balance,
    String? bankDetails,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      state: state ?? this.state,
      gstNumber: gstNumber ?? this.gstNumber,
      pan: pan ?? this.pan,
      contactPerson: contactPerson ?? this.contactPerson,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      creditLimit: creditLimit ?? this.creditLimit,
      openingBalance: openingBalance ?? this.openingBalance,
      balance: balance ?? this.balance,
      bankDetails: bankDetails ?? this.bankDetails,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
