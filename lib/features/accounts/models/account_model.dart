// lib/features/accounts/models/account_model.dart

class AccountModel {
  final int? id;
  final int businessId;
  final String name;
  final String type; // 'Cash', 'Bank', 'Wallet', etc.
  final double openingBalance;
  final double balance;
  final String? accountNumber;
  final bool isDefault;

  AccountModel({
    this.id,
    required this.businessId,
    required this.name,
    this.type = 'Cash',
    this.openingBalance = 0.0,
    this.balance = 0.0,
    this.accountNumber,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'type': type,
      'opening_balance': openingBalance,
      'balance': balance,
      'account_number': accountNumber,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'],
      businessId: map['business_id'],
      name: map['name'],
      type: map['type'] ?? 'Cash',
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      accountNumber: map['account_number'],
      isDefault: (map['is_default'] as int?) == 1,
    );
  }
}
