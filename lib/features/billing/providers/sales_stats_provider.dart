import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/backend_api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/sale_history_model.dart';

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
  Future<List<Map<String, dynamic>>> _sales(int businessId) async {
    final response = await BackendApiService.get(
      'sales',
      {'businessId': '$businessId'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<SalesStats> getStats(int businessId) async {
    final sales = await _sales(businessId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = today.subtract(const Duration(days: 6));
    final month = DateTime(now.year, now.month, 1);

    double sumFor(DateTime from, [DateTime? before]) {
      return sales.where((sale) {
        if (sale['status']?.toString() != 'completed') return false;
        final date = DateTime.tryParse(sale['date']?.toString() ?? '');
        if (date == null) return false;
        return !date.isBefore(from) && (before == null || date.isBefore(before));
      }).fold<double>(
        0,
        (sum, sale) =>
            sum + ((sale['grand_total'] as num?)?.toDouble() ?? 0),
      );
    }

    final last7Days = List<double>.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      return sumFor(day, day.add(const Duration(days: 1)));
    });
    final todaySales = sumFor(today);
    final todayTransactions = sales.where((sale) {
      if (sale['status']?.toString() != 'completed') return false;
      final date = DateTime.tryParse(sale['date']?.toString() ?? '');
      return date != null && !date.isBefore(today);
    }).length;

    return SalesStats(
      todaySales: todaySales,
      todayTransactions: todayTransactions,
      weekSales: sumFor(week),
      monthSales: sumFor(month),
      last7DaysSales: last7Days,
      recentSales: sales.take(5).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> getSaleHistory(
    int businessId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final sales = await _sales(businessId);
    return sales.skip(offset).take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getSaleHistoryByCustomer(
      int customerId) async {
    final response =
        await BackendApiService.get('sales', {'businessId': '1'});
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded
        .where((item) =>
            item is Map &&
            ((item['customer_id'] ?? item['customerId']) as num?)?.toInt() ==
                customerId)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final response = await BackendApiService.get(
      'sales/$saleId',
      {'businessId': '1'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! Map) return const [];
    final items = decoded['items'];
    if (items is! List) return const [];
    return items
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<SaleHistoryModel?> getSaleById(int id) async {
    final response = await BackendApiService.get(
      'sales/$id',
      {'businessId': '1'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! Map<String, dynamic>) return null;
    final items = await getSaleItems(id);
    return SaleHistoryModel.fromMap(
      decoded,
      items.map(SaleHistoryItemModel.fromMap).toList(),
    );
  }
}

final salesStatsRepositoryProvider =
    Provider<SalesStatsRepository>((ref) => SalesStatsRepository());

final salesStatsProvider =
    FutureProvider.autoDispose<SalesStats>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(salesStatsRepositoryProvider).getStats(businessId);
});

final saleHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(salesStatsRepositoryProvider).getSaleHistory(businessId);
});

final customerSaleHistoryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>(
        (ref, customerId) async {
  return ref
      .watch(salesStatsRepositoryProvider)
      .getSaleHistoryByCustomer(customerId);
});

final saleDetailProvider =
    FutureProvider.autoDispose.family<SaleHistoryModel?, int>(
        (ref, saleId) async {
  return ref.watch(salesStatsRepositoryProvider).getSaleById(saleId);
});
