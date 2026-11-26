// lib/features/budgeting/models/budget_model.dart

class BudgetModel {
  final int? id;
  final int businessId;
  final int? categoryId;
  final int? accountId;
  final String targetType; // 'category', 'account', 'project', 'department'
  final String? targetName; // e.g. for custom projects/departments
  final double amount;
  final String period; // 'monthly', 'quarterly', 'yearly'
  final DateTime startDate;
  final DateTime endDate;

  // UI Helper fields (not stored in budgets table directly, but calculated)
  final double spent;

  BudgetModel({
    this.id,
    required this.businessId,
    this.categoryId,
    this.accountId,
    required this.targetType,
    this.targetName,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.spent = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'category_id': categoryId,
      'account_id': accountId,
      'target_type': targetType,
      'target_name': targetName,
      'amount': amount,
      'period': period,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map, {double spent = 0.0}) {
    return BudgetModel(
      id: map['id'],
      businessId: map['business_id'],
      categoryId: map['category_id'],
      accountId: map['account_id'],
      targetType: map['target_type'] ?? 'category',
      targetName: map['target_name'],
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      period: map['period'] ?? 'monthly',
      startDate: DateTime.tryParse(map['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(map['end_date'] ?? '') ?? DateTime.now(),
      spent: spent,
    );
  }

  BudgetModel copyWith({
    int? id,
    int? businessId,
    int? categoryId,
    int? accountId,
    String? targetType,
    String? targetName,
    double? amount,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    double? spent,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      targetType: targetType ?? this.targetType,
      targetName: targetName ?? this.targetName,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      spent: spent ?? this.spent,
    );
  }
}
