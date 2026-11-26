// lib/features/accounts/models/account_model.dart

import '../../../core/security/token_service.dart';

class AccountModel {
  final int? id;
  final int businessId;
  final String name;
  final String type; // 'Cash', 'Bank', 'Wallet', etc.
  final double openingBalance;
  final double balance;
  final String? accountNumber;
  final String? accountToken;
  final bool isDefault;

  AccountModel({
    this.id,
    required this.businessId,
    required this.name,
    this.type = 'Cash',
    this.openingBalance = 0.0,
    this.balance = 0.0,
    this.accountNumber,
    this.accountToken,
    this.isDefault = false,
  });

  /// Formatted masked account representation, e.g. `•••• •••• 4589`
  String get maskedAccountNumber => AccountTokenManager.maskAccountNumber(accountNumber);

  /// Safe tokenized identifier, e.g. `TKN-ACC-8A1F-9C3D`
  String get displayToken {
    if (accountToken != null && accountToken!.isNotEmpty) return accountToken!;
    if (accountNumber != null && accountNumber!.isNotEmpty) {
      return AccountTokenManager.tokenizeAccount(accountNumber!, businessId: businessId);
    }
    return '';
  }

  AccountModel copyWith({
    int? id,
    int? businessId,
    String? name,
    String? type,
    double? openingBalance,
    double? balance,
    String? accountNumber,
    String? accountToken,
    bool? isDefault,
  }) {
    return AccountModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      balance: balance ?? this.balance,
      accountNumber: accountNumber ?? this.accountNumber,
      accountToken: accountToken ?? this.accountToken,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    final effectiveToken = accountToken ?? 
      (accountNumber != null && accountNumber!.trim().isNotEmpty 
          ? AccountTokenManager.tokenizeAccount(accountNumber!, businessId: businessId) 
          : null);

    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'type': type,
      'opening_balance': openingBalance,
      'balance': balance,
      'account_number': accountNumber != null && accountNumber!.isNotEmpty
          ? AccountEncryptionService.encrypt(accountNumber!)
          : null,
      'account_token': effectiveToken,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    final bId = (map['business_id'] as num?)?.toInt() ?? 1;
    final rawAccNum = map['account_number'] as String?;
    final accNum = rawAccNum != null ? AccountEncryptionService.decrypt(rawAccNum) : null;
    final explicitToken = map['account_token'] as String?;
    final effectiveToken = explicitToken ??
        (accNum != null && accNum.trim().isNotEmpty
            ? AccountTokenManager.tokenizeAccount(accNum, businessId: bId)
            : null);

    return AccountModel(
      id: (map['id'] as num?)?.toInt(),
      businessId: bId,
      name: map['name'] ?? '',
      type: map['type'] ?? 'Cash',
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      accountNumber: accNum,
      accountToken: effectiveToken,
      isDefault: (map['is_default'] as int?) == 1,
    );
  }
}
