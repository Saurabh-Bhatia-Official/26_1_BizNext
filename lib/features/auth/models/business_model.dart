// lib/features/auth/models/business_model.dart

class BusinessModel {
  final int? id;
  final String name;
  final String type;
  final String? address;
  final String? phone;
  final String? email;
  final String? gstNumber;
  final String currency;
  final String currencySymbol;
  final int? ownerId;
  final bool isActive;
  final DateTime? createdAt;
  // Role of the logged-in user in this business (from user_businesses join)
  final String? userRole;

  const BusinessModel({
    this.id,
    required this.name,
    this.type = 'Retail Shop',
    this.address,
    this.phone,
    this.email,
    this.gstNumber,
    this.currency = 'INR',
    this.currencySymbol = '₹',
    this.ownerId,
    this.isActive = true,
    this.createdAt,
    this.userRole,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : 'B';
  }

  factory BusinessModel.fromMap(Map<String, dynamic> map) => BusinessModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String? ?? 'Retail Shop',
        address: map['address'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        gstNumber: map['gst_number'] as String?,
        currency: map['currency'] as String? ?? 'INR',
        currencySymbol: map['currency_symbol'] as String? ?? '₹',
        ownerId: map['owner_id'] as int?,
        isActive: (map['is_active'] as int?) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        userRole: map['user_role'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'address': address,
        'phone': phone,
        'email': email,
        'gst_number': gstNumber,
        'currency': currency,
        'currency_symbol': currencySymbol,
        'owner_id': ownerId,
        'is_active': isActive ? 1 : 0,
      };

  BusinessModel copyWith({
    int? id,
    String? name,
    String? type,
    String? address,
    String? phone,
    String? email,
    String? gstNumber,
    String? currency,
    String? currencySymbol,
    int? ownerId,
    bool? isActive,
    String? userRole,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      ownerId: ownerId ?? this.ownerId,
      isActive: isActive ?? this.isActive,
      userRole: userRole ?? this.userRole,
    );
  }
}
