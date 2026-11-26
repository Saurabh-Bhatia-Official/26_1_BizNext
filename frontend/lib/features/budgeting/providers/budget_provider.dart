// lib/features/budgeting/providers/budget_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/budget_model.dart';
import '../../../core/database/database_providers.dart';

class BudgetRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<BudgetModel>> getBudgets(int businessId) async {
    final result = await _db.queryAll(
      AppConstants.tblBudgets,
      where: 'business_id = ?',
      whereArgs: [businessId],
    );

    List<BudgetModel> budgets = [];
    for (var row in result) {
      final budget = BudgetModel.fromMap(row);
      final spent = await getSpentForBudget(budget);
      budgets.add(budget.copyWith(spent: spent));
    }
    return budgets;
  }

  Future<double> getSpentForBudget(BudgetModel budget) async {
    double spent = 0.0;
    final startStr = budget.startDate.toIso8601String();
    final endStr = budget.endDate.toIso8601String();

    if (budget.targetType == 'category') {
      if (budget.categoryId != null) {
        final res = await _db.rawQuery('''
          SELECT SUM(amount) as total 
          FROM ${AppConstants.tblTransactions} 
          WHERE category_id = ? AND type = 'debit' AND business_id = ? AND date >= ? AND date <= ?
        ''', [budget.categoryId, budget.businessId, startStr, endStr]);
        spent += (res.first['total'] as num?)?.toDouble() ?? 0.0;
      }
    } else if (budget.targetType == 'account') {
      if (budget.accountId != null) {
        final res = await _db.rawQuery('''
          SELECT SUM(amount) as total 
          FROM ${AppConstants.tblTransactions} 
          WHERE account_id = ? AND type = 'debit' AND business_id = ? AND date >= ? AND date <= ?
        ''', [budget.accountId, budget.businessId, startStr, endStr]);
        spent += (res.first['total'] as num?)?.toDouble() ?? 0.0;
      }
    } else if (budget.targetType == 'project' || budget.targetType == 'department') {
      if (budget.targetName != null && budget.targetName!.isNotEmpty) {
        final term = '%${budget.targetName}%';
        final res = await _db.rawQuery('''
          SELECT SUM(amount) as total 
          FROM ${AppConstants.tblTransactions} 
          WHERE description LIKE ? AND type = 'debit' AND business_id = ? AND date >= ? AND date <= ?
        ''', [term, budget.businessId, startStr, endStr]);
        spent += (res.first['total'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return spent;
  }

  Future<int> addBudget(BudgetModel budget) async {
    final id = await _db.insert(AppConstants.tblBudgets, budget.toMap());
    return id;
  }

  Future<int> updateBudget(BudgetModel budget) async {
    final rows = await _db.update(
      AppConstants.tblBudgets,
      budget.toMap(),
      budget.id!,
    );
    return rows;
  }

  Future<int> deleteBudget(int id) async {
    final rows = await _db.delete(
      AppConstants.tblBudgets,
      id,
    );
    return rows;
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => BudgetRepository());

final budgetsProvider = FutureProvider.autoDispose<List<BudgetModel>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(budgetRepositoryProvider).getBudgets(businessId);
});
