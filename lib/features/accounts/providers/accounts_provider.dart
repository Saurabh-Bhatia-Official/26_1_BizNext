import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/backend_api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/account_model.dart';
import '../models/account_summary_model.dart';
import '../models/ledger_model.dart';
import '../models/transaction_model.dart';

class AccountsRepository {
  Future<AccountSummaryModel> getBalanceSummary(int businessId) async {
    final accountsResponse =
        await BackendApiService.get('accounts', {'businessId': '$businessId'});
    final ledgerResponse =
        await BackendApiService.get('journal/ledger', {'businessId': '$businessId'});
    final accounts = BackendApiService.decode(accountsResponse);
    final ledger = BackendApiService.decode(ledgerResponse);

    var cash = 0.0;
    if (accounts is List) {
      for (final item in accounts) {
        if (item is Map) {
          cash += (item['balance'] as num?)?.toDouble() ?? 0;
        }
      }
    }

    var income = 0.0;
    var expenses = 0.0;
    if (ledger is List) {
      for (final item in ledger) {
        if (item is! Map) continue;
        final entryType = (item['entryType'] ?? item['entry_type'])
            ?.toString()
            .toLowerCase();
        final amount = (item['amount'] as num?)?.toDouble() ?? 0;
        if (entryType == 'credit') {
          income += amount;
        } else if (entryType == 'debit') {
          expenses += amount;
        }
      }
    }

    return AccountSummaryModel(
      cashInHand: cash,
      totalReceivable: 0,
      totalPayable: 0,
      totalExpenses: expenses,
      totalIncome: income,
    );
  }

  Future<List<LedgerModel>> getRecentLedgerEntries(
    int businessId, {
    int limit = 50,
  }) async {
    final response =
        await BackendApiService.get('journal/ledger', {'businessId': '$businessId'});
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded.take(limit).map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return LedgerModel.fromMap({
        'id': map['id'],
        'business_id': map['businessId'] ?? map['business_id'],
        'entity_type': map['entityType'] ?? map['entity_type'] ?? '',
        'entity_id': map['entityId'] ?? map['entity_id'] ?? 0,
        'type': map['entryType'] ?? map['entry_type'] ?? '',
        'amount': map['amount'],
        'balance': map['balance'],
        'reference_id': map['referenceId'] ?? map['reference_id'],
        'account_id': map['accountId'] ?? map['account_id'],
        'description': map['description'],
        'date': map['createdAt'] ?? map['created_at'] ?? map['date'],
      });
    }).toList();
  }

  Future<List<TransactionModel>> getTransactions(int businessId) async {
    return const [];
  }

  Future<List<TransactionCategoryModel>> getTransactionCategories(
      int businessId, String type) async {
    return const [];
  }

  Future<TransactionModel?> getTransactionById(int id) async => null;

  Future<int> addTransaction(TransactionModel transaction) async {
    final response = await BackendApiService.post('journal/entries', {
      'businessId': transaction.businessId,
      'description': transaction.description,
      'referenceType': 'TRANSACTION',
      'lines': [
        {
          'accountId': transaction.accountId,
          'description': transaction.description,
          'debit': transaction.type == 'debit' ? transaction.amount : 0,
          'credit': transaction.type == 'credit' ? transaction.amount : 0,
        },
      ],
    });
    final decoded = BackendApiService.decode(response);
    return decoded is Map ? (decoded['id'] as num?)?.toInt() ?? 0 : 0;
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await addTransaction(transaction);
  }

  Future<void> deleteTransaction(int id) async {}

  Future<void> deleteLedgerEntry(int id) async {}

  Future<int> addTransactionCategory(
      TransactionCategoryModel category) async {
    return 0;
  }

  Future<void> updateTransactionCategory(
      TransactionCategoryModel category) async {}

  Future<void> deleteTransactionCategory(int id) async {}

  Future<List<AccountModel>> getAccounts(int businessId) async {
    final response =
        await BackendApiService.get('accounts', {'businessId': '$businessId'});
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return AccountModel(
        id: (map['id'] as num?)?.toInt(),
        businessId: (map['businessId'] as num?)?.toInt() ?? businessId,
        name: map['name'] as String? ?? '',
        type: map['type'] as String? ?? 'Cash',
        balance: 0,
        isDefault: false,
      );
    }).toList();
  }

  Future<int> addAccount(AccountModel account) async {
    final response = await BackendApiService.post('accounts', {
      'businessId': account.businessId,
      'code': 'ACC-${account.name.hashCode.abs()}',
      'name': account.name,
      'type': account.type,
      'active': true,
    });
    final decoded = BackendApiService.decode(response);
    return decoded is Map ? (decoded['id'] as num?)?.toInt() ?? 0 : 0;
  }

  Future<void> updateAccount(AccountModel account) async {
    await BackendApiService.put(
      'accounts/${account.id}',
      {
        'businessId': account.businessId,
        'code': 'ACC-${account.name.hashCode.abs()}',
        'name': account.name,
        'type': account.type,
        'active': true,
      },
      {'businessId': '${account.businessId}'},
    );
  }

  Future<void> deleteAccount(int id) async {
    await BackendApiService.delete(
      'accounts/$id',
      {'businessId': '1'},
    );
  }

  Future<void> addTransfer({
    required int businessId,
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? description,
  }) async {
    await BackendApiService.post('journal/entries', {
      'businessId': businessId,
      'description': description ?? 'Account transfer',
      'referenceType': 'TRANSFER',
      'lines': [
        {'accountId': fromAccountId, 'description': 'Transfer out', 'debit': 0, 'credit': amount},
        {'accountId': toAccountId, 'description': 'Transfer in', 'debit': amount, 'credit': 0},
      ],
    });
  }

  Future<void> deleteTransfer(int refId) async {}

  Future<List<LedgerModel>> getAccountLedger(
    int accountId, {
    int limit = 100,
  }) async {
    final response =
        await BackendApiService.get('journal/ledger', {'businessId': '1'});
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded
        .where((item) => item is Map &&
            ((item['accountId'] ?? item['account_id']) as num?)?.toInt() ==
                accountId)
        .take(limit)
        .map((item) => LedgerModel.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }
}

final accountsRepositoryProvider =
    Provider<AccountsRepository>((ref) => AccountsRepository());

final balanceSummaryProvider =
    FutureProvider.autoDispose<AccountSummaryModel>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(accountsRepositoryProvider).getBalanceSummary(businessId);
});

final ledgerEntriesProvider =
    FutureProvider.autoDispose<List<LedgerModel>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(accountsRepositoryProvider).getRecentLedgerEntries(businessId);
});

final transactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(accountsRepositoryProvider).getTransactions(businessId);
});

final transactionCategoriesProvider =
    FutureProvider.family<List<TransactionCategoryModel>, String>((ref, type) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref
      .watch(accountsRepositoryProvider)
      .getTransactionCategories(businessId, type);
});

final accountsProvider =
    FutureProvider.autoDispose<List<AccountModel>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(accountsRepositoryProvider).getAccounts(businessId);
});

final accountLedgerProvider =
    FutureProvider.family<List<LedgerModel>, int>((ref, accountId) async {
  return ref.watch(accountsRepositoryProvider).getAccountLedger(accountId);
});
