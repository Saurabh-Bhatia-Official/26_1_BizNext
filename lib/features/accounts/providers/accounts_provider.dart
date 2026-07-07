// lib/features/accounts/providers/accounts_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/account_model.dart';
import '../models/account_summary_model.dart';
import '../models/ledger_model.dart';
import '../models/transaction_model.dart';
import '../../../core/database/database_providers.dart';

class AccountsRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<AccountSummaryModel> getBalanceSummary(int businessId) async {
    // 1. Total Expenses (All modes, for stats)
    final allExpenses = await _db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM ${AppConstants.tblTransactions} WHERE business_id = ? AND type = 'debit'",
      [businessId],
    );
    final allIncome = await _db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM ${AppConstants.tblTransactions} WHERE business_id = ? AND type = 'credit'",
      [businessId],
    );

    // 4. Receivables & Payables
    final receivable = await _db.rawQuery(
      "SELECT COALESCE(SUM(balance), 0) as total FROM ${AppConstants.tblCustomers} WHERE business_id = ?",
      [businessId],
    );
    final payable = await _db.rawQuery(
      "SELECT COALESCE(SUM(balance), 0) as total FROM ${AppConstants.tblSuppliers} WHERE business_id = ?",
      [businessId],
    );

    // 5. Total Balance from Accounts
    final accountsBalance = await _db.rawQuery(
      "SELECT COALESCE(SUM(balance), 0) as total FROM ${AppConstants.tblAccounts} WHERE business_id = ?",
      [businessId],
    );

    return AccountSummaryModel(
      cashInHand: (accountsBalance.first['total'] as num?)?.toDouble() ?? 0,
      totalReceivable: (receivable.first['total'] as num?)?.toDouble() ?? 0,
      totalPayable: (payable.first['total'] as num?)?.toDouble() ?? 0,
      totalExpenses: (allExpenses.first['total'] as num?)?.toDouble() ?? 0,
      totalIncome: (allIncome.first['total'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<LedgerModel>> getRecentLedgerEntries(int businessId, {int limit = 50}) async {
    final result = await _db.rawQuery('''
      SELECT l.*, 
             CASE 
               WHEN l.entity_type = '${AppConstants.entityCustomer}' THEN c.name 
               WHEN l.entity_type = '${AppConstants.entitySupplier}' THEN s.name 
             END as entity_name,
             tc.name as category_name,
             a.name as account_name
      FROM ${AppConstants.tblLedger} l
      LEFT JOIN ${AppConstants.tblCustomers} c ON l.entity_type = '${AppConstants.entityCustomer}' AND l.entity_id = c.id
      LEFT JOIN ${AppConstants.tblSuppliers} s ON l.entity_type = '${AppConstants.entitySupplier}' AND l.entity_id = s.id
      LEFT JOIN ${AppConstants.tblTransactions} t ON l.entity_type = '${AppConstants.entityBusiness}' AND l.reference_id = t.id
      LEFT JOIN ${AppConstants.tblTransactionCategories} tc ON t.category_id = tc.id
      LEFT JOIN ${AppConstants.tblAccounts} a ON l.account_id = a.id
      WHERE l.business_id = ?
      ORDER BY l.date DESC
      LIMIT ?
    ''', [businessId, limit]);

    return result.map((m) => LedgerModel.fromMap(m)).toList();
  }

  Future<List<TransactionModel>> getTransactions(int businessId) async {
    final result = await _db.rawQuery('''
      SELECT t.*, tc.name as category_name, a.name as account_name
      FROM ${AppConstants.tblTransactions} t 
      LEFT JOIN ${AppConstants.tblTransactionCategories} tc ON t.category_id = tc.id 
      LEFT JOIN ${AppConstants.tblAccounts} a ON t.account_id = a.id
      WHERE t.business_id = ? 
      ORDER BY t.date DESC
    ''', [businessId]);
    return result.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<List<TransactionCategoryModel>> getTransactionCategories(int businessId, String type) async {
    final result = await _db.rawQuery(
      "SELECT * FROM ${AppConstants.tblTransactionCategories} WHERE business_id = ? AND type = ?",
      [businessId, type],
    );
    return result.map((m) => TransactionCategoryModel.fromMap(m)).toList();
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final result = await _db.rawQuery('''
      SELECT t.*, tc.name as category_name, a.name as account_name
      FROM ${AppConstants.tblTransactions} t 
      LEFT JOIN ${AppConstants.tblTransactionCategories} tc ON t.category_id = tc.id 
      LEFT JOIN ${AppConstants.tblAccounts} a ON t.account_id = a.id
      WHERE t.id = ?
    ''', [id]);
    if (result.isEmpty) return null;
    return TransactionModel.fromMap(result.first);
  }

  Future<int> addTransaction(TransactionModel transaction) async {
    return await _db.transaction((txn) async {
      final id = await txn.insert(AppConstants.tblTransactions, transaction.toMap());
      
      // Update Account Balance
      if (transaction.accountId != null) {
        final double adjustment = transaction.type == AppConstants.ledgerCredit ? transaction.amount : -transaction.amount;
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?",
          [adjustment, transaction.accountId],
        );
      }

      // Also record in main Ledger for a consolidated view
      await txn.insert(AppConstants.tblLedger, {
        'business_id': transaction.businessId,
        'entity_type': AppConstants.entityBusiness,
        'entity_id': 0,
        'type': transaction.type,
        'amount': transaction.amount,
        'reference_id': id,
        'account_id': transaction.accountId,
        'description': transaction.description ?? (transaction.isIncome ? 'General Income' : 'General Expense'),
        'date': transaction.date.toIso8601String(),
      });
      
      return id;
    });
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await _db.transaction((txn) async {
      // Get old transaction to reverse balance
      final oldData = await txn.query(AppConstants.tblTransactions, where: 'id = ?', whereArgs: [transaction.id]);
      if (oldData.isNotEmpty) {
        final old = TransactionModel.fromMap(oldData.first);
        if (old.accountId != null) {
          final double reverseAdjustment = old.type == AppConstants.ledgerCredit ? -old.amount : old.amount;
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?",
            [reverseAdjustment, old.accountId],
          );
        }
      }

      await txn.update(AppConstants.tblTransactions, transaction.toMap(), where: 'id = ?', whereArgs: [transaction.id]);
      
      // Apply new balance
      if (transaction.accountId != null) {
        final double adjustment = transaction.type == AppConstants.ledgerCredit ? transaction.amount : -transaction.amount;
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?",
          [adjustment, transaction.accountId],
        );
      }

      // Update consolidated ledger entry
      await txn.update(AppConstants.tblLedger, {
        'type': transaction.type,
        'amount': transaction.amount,
        'account_id': transaction.accountId,
        'description': transaction.description ?? (transaction.isIncome ? 'General Income' : 'General Expense'),
        'date': transaction.date.toIso8601String(),
      }, where: 'reference_id = ? AND entity_type = ?', whereArgs: [transaction.id, AppConstants.entityBusiness]);
    });
  }

  Future<void> deleteTransaction(int id) async {
    await _db.transaction((txn) async {
      // Reverse balance before deleting
      final oldData = await txn.query(AppConstants.tblTransactions, where: 'id = ?', whereArgs: [id]);
      if (oldData.isNotEmpty) {
        final old = TransactionModel.fromMap(oldData.first);
        if (old.accountId != null) {
          final double reverseAdjustment = old.type == AppConstants.ledgerCredit ? -old.amount : old.amount;
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?",
            [reverseAdjustment, old.accountId],
          );
        }
      }

      await txn.delete(AppConstants.tblTransactions, where: 'id = ?', whereArgs: [id]);
      // Clean up consolidated ledger entry too
      await txn.delete(AppConstants.tblLedger, where: 'reference_id = ? AND entity_type = ?', whereArgs: [id, AppConstants.entityBusiness]);
    });
  }

  Future<void> deleteLedgerEntry(int id) async {
    await _db.delete(AppConstants.tblLedger, id);
  }

  Future<int> addTransactionCategory(TransactionCategoryModel category) async {
    return await _db.insert(AppConstants.tblTransactionCategories, category.toMap());
  }

  Future<void> updateTransactionCategory(TransactionCategoryModel category) async {
    await _db.update(AppConstants.tblTransactionCategories, category.toMap(), category.id!);
  }

  Future<void> deleteTransactionCategory(int id) async {
    // Check if any transactions use this category
    final count = await _db.rawQuery("SELECT COUNT(*) as total FROM ${AppConstants.tblTransactions} WHERE category_id = ?", [id]);
    if ((count.first['total'] as int) > 0) {
      throw Exception('Category in use by transactions');
    }
    await _db.delete(AppConstants.tblTransactionCategories, id);
  }

  // ── Account Management (Cash/Bank) ──
  Future<List<AccountModel>> getAccounts(int businessId) async {
    final result = await _db.rawQuery(
      "SELECT * FROM ${AppConstants.tblAccounts} WHERE business_id = ? ORDER BY is_default DESC, name ASC",
      [businessId],
    );
    return result.map((m) => AccountModel.fromMap(m)).toList();
  }

  Future<int> addAccount(AccountModel account) async {
    return await _db.transaction((txn) async {
      final id = await txn.insert(AppConstants.tblAccounts, account.toMap());
      
      // Record Opening Balance in Ledger if > 0
      if (account.openingBalance != 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': account.businessId,
          'entity_type': AppConstants.entityBusiness,
          'entity_id': 0,
          'type': account.openingBalance > 0 ? AppConstants.ledgerCredit : AppConstants.ledgerDebit,
          'amount': account.openingBalance.abs(),
          'account_id': id,
          'description': 'Opening Balance',
          'date': DateTime.now().toIso8601String(),
        });
        
        // Update balance to match opening
        await txn.rawUpdate("UPDATE ${AppConstants.tblAccounts} SET balance = ? WHERE id = ?", [account.openingBalance, id]);
      }
      
      return id;
    });
  }

  Future<void> updateAccount(AccountModel account) async {
    await _db.transaction((txn) async {
      // 1. Get old account to calculate balance difference
      final oldData = await txn.query(AppConstants.tblAccounts, where: 'id = ?', whereArgs: [account.id]);
      if (oldData.isNotEmpty) {
        final old = AccountModel.fromMap(oldData.first);
        final openingDelta = account.openingBalance - old.openingBalance;
        
        // 2. Calculate new current balance
        final newBalance = old.balance + openingDelta;
        
        // 3. Update Account
        await txn.update(AppConstants.tblAccounts, {
          'name': account.name,
          'type': account.type,
          'opening_balance': account.openingBalance,
          'balance': newBalance,
          'account_number': account.accountNumber,
          'is_default': account.isDefault ? 1 : 0,
        }, where: 'id = ?', whereArgs: [account.id]);

        // 4. Update Opening Balance Ledger Entry if it exists
        await txn.update(AppConstants.tblLedger, {
          'amount': account.openingBalance.abs(),
          'type': account.openingBalance >= 0 ? AppConstants.ledgerCredit : AppConstants.ledgerDebit,
        }, where: 'account_id = ? AND description = ?', whereArgs: [account.id, 'Opening Balance']);
      }
    });
  }

  Future<void> deleteAccount(int id) async {
    await _db.delete(AppConstants.tblAccounts, id);
  }

  Future<void> addTransfer({
    required int businessId,
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? description,
  }) async {
    await _db.transaction((txn) async {
      final date = DateTime.now();
      final dateStr = date.toIso8601String();
      // Use timestamp as reference_id to link both sides
      final refId = date.millisecondsSinceEpoch ~/ 1000;
      
      // 1. Debit from Source
      await txn.rawUpdate("UPDATE ${AppConstants.tblAccounts} SET balance = balance - ? WHERE id = ?", [amount, fromAccountId]);
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': AppConstants.entityBusiness,
        'entity_id': 0,
        'type': AppConstants.ledgerDebit,
        'amount': amount,
        'reference_id': refId,
        'account_id': fromAccountId,
        'description': 'Transfer to Account ID: $toAccountId ${description?.isNotEmpty == true ? "($description)" : ""}',
        'date': dateStr,
      });

      // 2. Credit to Destination
      await txn.rawUpdate("UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?", [amount, toAccountId]);
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': AppConstants.entityBusiness,
        'entity_id': 0,
        'type': AppConstants.ledgerCredit,
        'amount': amount,
        'reference_id': refId,
        'account_id': toAccountId,
        'description': 'Transfer from Account ID: $fromAccountId ${description?.isNotEmpty == true ? "($description)" : ""}',
        'date': dateStr,
      });
    });
  }

  Future<void> deleteTransfer(int refId) async {
    await _db.transaction((txn) async {
      final entries = await txn.query(AppConstants.tblLedger, where: 'reference_id = ?', whereArgs: [refId]);
      for (final entry in entries) {
        final double amt = (entry['amount'] as num).toDouble();
        final int? accId = entry['account_id'] as int?;
        final isDebit = entry['type'] == AppConstants.ledgerDebit;
        
        if (accId != null) {
          // Revert: add back to debit side, subtract from credit side
          final double adjustment = isDebit ? amt : -amt;
          await txn.rawUpdate("UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?", [adjustment, accId]);
        }
      }
      await txn.delete(AppConstants.tblLedger, where: 'reference_id = ?', whereArgs: [refId]);
    });
  }

  Future<List<LedgerModel>> getAccountLedger(int accountId, {int limit = 100}) async {
    final result = await _db.rawQuery('''
      SELECT l.*, 
             CASE 
               WHEN l.entity_type = '${AppConstants.entityCustomer}' THEN c.name 
               WHEN l.entity_type = '${AppConstants.entitySupplier}' THEN s.name 
             END as entity_name,
             tc.name as category_name,
             a.name as account_name
      FROM ${AppConstants.tblLedger} l
      LEFT JOIN ${AppConstants.tblCustomers} c ON l.entity_type = '${AppConstants.entityCustomer}' AND l.entity_id = c.id
      LEFT JOIN ${AppConstants.tblSuppliers} s ON l.entity_type = '${AppConstants.entitySupplier}' AND l.entity_id = s.id
      LEFT JOIN ${AppConstants.tblTransactions} t ON l.entity_type = '${AppConstants.entityBusiness}' AND l.reference_id = t.id
      LEFT JOIN ${AppConstants.tblTransactionCategories} tc ON t.category_id = tc.id
      LEFT JOIN ${AppConstants.tblAccounts} a ON l.account_id = a.id
      WHERE l.account_id = ?
      ORDER BY l.date DESC
      LIMIT ?
    ''', [accountId, limit]);
    return result.map((m) => LedgerModel.fromMap(m)).toList();
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) => AccountsRepository());

final balanceSummaryProvider = FutureProvider.autoDispose<AccountSummaryModel>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(accountsRepositoryProvider).getBalanceSummary(businessId);
});

final ledgerEntriesProvider = FutureProvider.autoDispose<List<LedgerModel>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(accountsRepositoryProvider).getRecentLedgerEntries(businessId);
});

final transactionsProvider = FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(accountsRepositoryProvider).getTransactions(businessId);
});

final transactionCategoriesProvider = FutureProvider.family<List<TransactionCategoryModel>, String>((ref, type) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(accountsRepositoryProvider).getTransactionCategories(businessId, type);
});

final accountsProvider = FutureProvider.autoDispose<List<AccountModel>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(accountsRepositoryProvider).getAccounts(businessId);
});

final accountLedgerProvider = FutureProvider.family<List<LedgerModel>, int>((ref, accountId) async {
  return ref.watch(accountsRepositoryProvider).getAccountLedger(accountId);
});
