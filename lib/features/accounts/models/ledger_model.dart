// lib/features/accounts/models/ledger_model.dart

class LedgerModel {
  final int? id;
  final int businessId;
  final String entityType; // customer, supplier
  final int entityId;
  final String? entityName;
  final String? categoryName;
  final String type; // credit, debit
  final double amount;
  final double balance;
  final int? referenceId;
  final int? accountId;
  final String? accountName;
  final String? description;
  final DateTime date;

  LedgerModel({
    this.id,
    required this.businessId,
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.categoryName,
    required this.type,
    required this.amount,
    this.balance = 0,
    this.referenceId,
    this.accountId,
    this.accountName,
    this.description,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'entity_type': entityType,
      'entity_id': entityId,
      'type': type,
      'amount': amount,
      'balance': balance,
      'reference_id': referenceId,
      'account_id': accountId,
      'account_name': accountName,
      'description': description,
      'category_name': categoryName,
      'date': date.toIso8601String(),
    };
  }

  factory LedgerModel.fromMap(Map<String, dynamic> map) {
    return LedgerModel(
      id: map['id'],
      businessId: map['business_id'],
      entityType: map['entity_type'],
      entityId: map['entity_id'],
      entityName: map['entity_name'],
      categoryName: map['category_name'],
      type: map['type'],
      amount: (map['amount'] as num).toDouble(),
      balance: (map['balance'] as num).toDouble(),
      referenceId: map['reference_id'],
      accountId: map['account_id'],
      accountName: map['account_name'],
      description: map['description'],
      date: DateTime.parse(map['date']),
    );
  }
}
