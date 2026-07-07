// lib/features/billing/providers/sales_stats_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/sale_history_model.dart';
import '../../../core/database/database_providers.dart';

class SalesStats {
  final double todaySales;
  final int todayTransactions;
  final double weekSales;
  final double monthSales;
  final List<double> last7DaysSales;
  final List<Map<String, dynamic>> recentSales;

  const SalesStats({
    this.todaySales = 0,
    this.todayTransactions = 0,
    this.weekSales = 0,
    this.monthSales = 0,
    this.last7DaysSales = const [0, 0, 0, 0, 0, 0, 0],
    this.recentSales = const [],
  });
}

class SalesStatsRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<SalesStats> getStats(int businessId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final weekStart = DateTime(now.year, now.month, now.day - 6).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

    // Today's stats
    final todayResult = await _db.rawQuery(
      "SELECT COALESCE(SUM(grand_total), 0) as total, COUNT(*) as count FROM ${AppConstants.tblSales} WHERE business_id = ? AND date >= ? AND status = 'completed'",
      [businessId, todayStart],
    );

    // This week
    final weekResult = await _db.rawQuery(
      "SELECT COALESCE(SUM(grand_total), 0) as total FROM ${AppConstants.tblSales} WHERE business_id = ? AND date >= ? AND status = 'completed'",
      [businessId, weekStart],
    );

    // This month
    final monthResult = await _db.rawQuery(
      "SELECT COALESCE(SUM(grand_total), 0) as total FROM ${AppConstants.tblSales} WHERE business_id = ? AND date >= ? AND status = 'completed'",
      [businessId, monthStart],
    );

    // Last 7 days breakdown
    final last7Days = <double>[];
    for (int i = 6; i >= 0; i--) {
      final dayStart = DateTime(now.year, now.month, now.day - i).toIso8601String();
      final dayEnd = DateTime(now.year, now.month, now.day - i + 1).toIso8601String();
      final dayResult = await _db.rawQuery(
        "SELECT COALESCE(SUM(grand_total), 0) as total FROM ${AppConstants.tblSales} WHERE business_id = ? AND date >= ? AND date < ? AND status = 'completed'",
        [businessId, dayStart, dayEnd],
      );
      last7Days.add((dayResult.first['total'] as num?)?.toDouble() ?? 0);
    }

    // Recent 5 sales
    final recentSales = await _db.rawQuery(
      "SELECT s.*, c.name as customer_name FROM ${AppConstants.tblSales} s LEFT JOIN ${AppConstants.tblCustomers} c ON s.customer_id = c.id WHERE s.business_id = ? AND s.status = 'completed' ORDER BY s.date DESC LIMIT 5",
      [businessId],
    );

    return SalesStats(
      todaySales: (todayResult.first['total'] as num?)?.toDouble() ?? 0,
      todayTransactions: (todayResult.first['count'] as int?) ?? 0,
      weekSales: (weekResult.first['total'] as num?)?.toDouble() ?? 0,
      monthSales: (monthResult.first['total'] as num?)?.toDouble() ?? 0,
      last7DaysSales: last7Days,
      recentSales: recentSales,
    );
  }

  Future<List<Map<String, dynamic>>> getSaleHistory(int businessId, {int limit = 50, int offset = 0}) async {
    return await _db.rawQuery(
      "SELECT s.*, c.name as customer_name FROM ${AppConstants.tblSales} s LEFT JOIN ${AppConstants.tblCustomers} c ON s.customer_id = c.id WHERE s.business_id = ? ORDER BY s.date DESC LIMIT ? OFFSET ?",
      [businessId, limit, offset],
    );
  }

  Future<List<Map<String, dynamic>>> getSaleHistoryByCustomer(int customerId) async {
    return await _db.rawQuery(
      "SELECT s.*, c.name as customer_name FROM ${AppConstants.tblSales} s LEFT JOIN ${AppConstants.tblCustomers} c ON s.customer_id = c.id WHERE s.customer_id = ? ORDER BY s.date DESC",
      [customerId],
    );
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    return await _db.rawQuery(
      "SELECT * FROM ${AppConstants.tblSaleItems} WHERE sale_id = ?",
      [saleId],
    );
  }

  Future<SaleHistoryModel?> getSaleById(int id) async {
    final saleResult = await _db.rawQuery(
      "SELECT s.*, c.name as customer_name, c.phone as customer_phone, c.address as customer_address, a.name as account_name FROM ${AppConstants.tblSales} s LEFT JOIN ${AppConstants.tblCustomers} c ON s.customer_id = c.id LEFT JOIN ${AppConstants.tblAccounts} a ON s.account_id = a.id WHERE s.id = ?",
      [id],
    );
    if (saleResult.isEmpty) return null;

    final itemResults = await getSaleItems(id);
    final items = itemResults.map((m) => SaleHistoryItemModel.fromMap(m)).toList();
    return SaleHistoryModel.fromMap(saleResult.first, items);
  }
}

final salesStatsRepositoryProvider = Provider<SalesStatsRepository>((ref) => SalesStatsRepository());

final salesStatsProvider = FutureProvider.autoDispose<SalesStats>((ref) async {
  ref.watch(databaseVersionProvider); // Global auto-refresh
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(salesStatsRepositoryProvider).getStats(businessId);
});

final saleHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(databaseVersionProvider); // Global auto-refresh
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(salesStatsRepositoryProvider).getSaleHistory(businessId);
});

final customerSaleHistoryProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, customerId) async {
  return ref.watch(salesStatsRepositoryProvider).getSaleHistoryByCustomer(customerId);
});

final saleDetailProvider = FutureProvider.autoDispose.family<SaleHistoryModel?, int>((ref, saleId) async {
  return ref.watch(salesStatsRepositoryProvider).getSaleById(saleId);
});
