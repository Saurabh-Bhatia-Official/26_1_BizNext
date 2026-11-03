// lib/features/accounts/models/transaction_model.dart

import '../../../core/constants/app_constants.dart';

class TransactionModel {
  final int? id;
  final int businessId;
  final int? categoryId;
  final String? categoryName;
  final String type; // 'credit' (income) or 'debit' (expense)
  final double amount;
  final String? description;
  final String paymentMode;
  final int? accountId;
  final String? accountName;
  final DateTime date;

  TransactionModel({
    this.id,
    required this.businessId,
    this.categoryId,
    this.categoryName,
    required this.type,
    required this.amount,
    this.description,
    this.paymentMode = 'Cash',
    this.accountId,
    this.accountName,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  bool get isIncome => type == AppConstants.ledgerCredit;
  bool get isExpense => type == AppConstants.ledgerDebit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'description': description,
      'payment_mode': paymentMode,
      'account_id': accountId,
      'date': date.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: (map['id'] as num?)?.toInt(),
      businessId: (map['business_id'] as num?)?.toInt() ?? 0,
      categoryId: (map['category_id'] as num?)?.toInt(),
      categoryName: map['category_name'],
      type: map['type'] ?? 'debit',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'],
      paymentMode: map['payment_mode'] ?? 'Cash',
      accountId: (map['account_id'] as num?)?.toInt(),
      accountName: map['account_name'],
      date: map['date'] != null ? DateTime.tryParse(map['date']) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class TransactionCategoryModel {
  final int? id;
  final int businessId;
  final String name;
  final String type; // 'income' or 'expense'

  TransactionCategoryModel({
    this.id, 
    required this.businessId, 
    required this.name,
    required this.type,
  });

  factory TransactionCategoryModel.fromMap(Map<String, dynamic> map) {
    return TransactionCategoryModel(
      id: map['id'],
      businessId: map['business_id'],
      name: map['name'],
      type: map['type'] ?? 'expense',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'type': type,
    };
  }
}
