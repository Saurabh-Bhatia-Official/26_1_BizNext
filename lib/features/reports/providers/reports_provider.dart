// lib/features/reports/providers/reports_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../../billing/models/sale_history_model.dart';
import '../models/report_model.dart';
import '../../../core/database/database_providers.dart';

class ReportsRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<ProfitLossReport> getProfitLoss(int businessId, ReportFilter filter) async {
    final salesRes = await _db.rawQuery('''
      SELECT COALESCE(SUM(grand_total - gst_amount), 0) as total 
      FROM ${AppConstants.tblSales} 
      WHERE business_id = ? AND date BETWEEN ? AND ? AND status = 'completed'
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    final cogsRes = await _db.rawQuery('''
      SELECT COALESCE(SUM(si.quantity * CASE WHEN si.purchase_price > 0 THEN si.purchase_price ELSE p.purchase_price END), 0) as total
      FROM ${AppConstants.tblSaleItems} si
      JOIN ${AppConstants.tblSales} s ON si.sale_id = s.id
      JOIN ${AppConstants.tblProducts} p ON si.product_id = p.id
      WHERE s.business_id = ? AND s.date BETWEEN ? AND ? AND s.status = 'completed'
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    // Include both manual expenses AND manual income in P&L
    final manualExpRes = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total 
      FROM ${AppConstants.tblTransactions} 
      WHERE business_id = ? AND date BETWEEN ? AND ? AND type = 'debit'
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    final manualIncRes = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total 
      FROM ${AppConstants.tblTransactions} 
      WHERE business_id = ? AND date BETWEEN ? AND ? AND type = 'credit'
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    final revenue = (salesRes.first['total'] as num).toDouble() + (manualIncRes.first['total'] as num).toDouble();
    final cost = (cogsRes.first['total'] as num).toDouble();
    final expenses = (manualExpRes.first['total'] as num).toDouble();
    final profit = revenue - cost - expenses;

    return ProfitLossReport(
      totalRevenue: revenue,
      totalCost: cost,
      totalExpenses: expenses,
      netProfit: profit,
      margin: revenue > 0 ? (profit / revenue) * 100 : 0.0,
    );
  }

  Future<SalesReport> getSalesReport(int businessId, ReportFilter filter) async {
    final salesRes = await _db.rawQuery('''
      SELECT s.*, c.name as customer_name 
      FROM ${AppConstants.tblSales} s
      LEFT JOIN ${AppConstants.tblCustomers} c ON s.customer_id = c.id
      WHERE s.business_id = ? AND s.date BETWEEN ? AND ? AND s.status = 'completed'
      ORDER BY s.date DESC
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    final stats = await _db.rawQuery('''
      SELECT COALESCE(SUM(grand_total - gst_amount), 0) as net_sales,
             COALESCE(SUM(grand_total), 0) as total, 
             COALESCE(SUM(gst_amount), 0) as gst,
             COALESCE(SUM(discount), 0) as discount,
             COUNT(*) as count
      FROM ${AppConstants.tblSales}
      WHERE business_id = ? AND date BETWEEN ? AND ? AND status = 'completed'
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    final sales = salesRes.map((m) => SaleHistoryModel.fromMap(m)).toList();
    final s = stats.first;

    final Map<String, double> paymentBreakdown = {};
    for (final sale in sales) {
      paymentBreakdown[sale.paymentMode] = (paymentBreakdown[sale.paymentMode] ?? 0) + sale.grandTotal;
    }

    return SalesReport(
      sales: sales,
      totalAmount: (s['total'] as num).toDouble(),
      netSales: (s['net_sales'] as num).toDouble(),
      totalGst: (s['gst'] as num).toDouble(),
      totalDiscount: (s['discount'] as num).toDouble(),
      transactionCount: s['count'] as int,
      paymentModeBreakdown: paymentBreakdown,
    );
  }

  Future<StockReport> getStockReport(int businessId) async {
    final itemsRes = await _db.rawQuery('''
      SELECT id, name, stock, purchase_price, selling_price, min_stock
      FROM ${AppConstants.tblProducts}
      WHERE business_id = ?
    ''', [businessId]);

    double totalValue = 0;
    int lowStock = 0;
    
    final items = itemsRes.map((m) {
      final stock = (m['stock'] as num).toDouble();
      final pPrice = (m['purchase_price'] as num).toDouble();
      final minLevel = (m['min_stock'] as num?)?.toDouble() ?? 5.0;
      
      if (stock <= minLevel) lowStock++;
      totalValue += stock * pPrice;
      
      return StockItemDetail(
        productId: m['id'] as int,
        productName: m['name'] as String,
        currentStock: stock,
        purchasePrice: pPrice,
        salePrice: (m['selling_price'] as num).toDouble(),
        value: stock * pPrice,
      );
    }).toList();

    return StockReport(
      items: items,
      totalInventoryValue: totalValue,
      lowStockCount: lowStock,
    );
  }

  Future<TaxReport> getTaxReport(int businessId, ReportFilter filter) async {
    final collected = await _db.rawQuery('''
      SELECT COALESCE(SUM(gst_amount), 0) as total 
      FROM ${AppConstants.tblSales} 
      WHERE business_id = ? AND date BETWEEN ? AND ? AND status = 'completed'
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    final paid = await _db.rawQuery('''
      SELECT COALESCE(SUM(gst_amount), 0) as total 
      FROM ${AppConstants.tblPurchases} 
      WHERE business_id = ? AND date BETWEEN ? AND ? AND status = 'completed'
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    final coll = (collected.first['total'] as num).toDouble();
    final pd = (paid.first['total'] as num).toDouble();

    return TaxReport(
      gstCollected: coll,
      gstPaid: pd,
      netGstPayable: coll - pd,
    );
  }

  Future<List<Map<String, dynamic>>> getCustomerSalesSummary(int businessId) async {
    return await _db.rawQuery('''
      SELECT c.id, c.name as customer_name, COUNT(s.id) as transaction_count, COALESCE(SUM(s.grand_total), 0) as total_amount
      FROM ${AppConstants.tblCustomers} c
      JOIN ${AppConstants.tblSales} s ON c.id = s.customer_id
      WHERE c.business_id = ? AND s.status = 'completed'
      GROUP BY c.id
      ORDER BY total_amount DESC
    ''', [businessId]);
  }

  Future<Map<String, dynamic>> getDiscountAnalysis(int businessId, ReportFilter filter) async {
    final res = await _db.rawQuery('''
      SELECT 
        COALESCE(SUM(discount), 0) as total_discount,
        COUNT(CASE WHEN discount > 0 THEN 1 END) as discounted_transactions,
        COALESCE(SUM(grand_total), 0) as total_revenue
      FROM ${AppConstants.tblSales}
      WHERE business_id = ? AND date BETWEEN ? AND ? AND status = 'completed'
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);
    return res.first;
  }

  Future<SalesVsPurchasesReport> getSalesVsPurchasesReport(int businessId, ReportFilter filter) async {
    final salesRes = await _db.rawQuery('''
      SELECT date, grand_total 
      FROM ${AppConstants.tblSales} 
      WHERE business_id = ? AND date BETWEEN ? AND ? AND status = 'completed'
      ORDER BY date ASC
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    final purchasesRes = await _db.rawQuery('''
      SELECT date, grand_total 
      FROM ${AppConstants.tblPurchases} 
      WHERE business_id = ? AND date BETWEEN ? AND ? AND status = 'completed'
      ORDER BY date ASC
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);

    double totalSales = 0;
    double totalPurchases = 0;

    final Map<String, double> salesByDay = {};
    for (var r in salesRes) {
      final amt = (r['grand_total'] as num).toDouble();
      totalSales += amt;
      final dtStr = r['date'] as String;
      final dt = DateTime.parse(dtStr);
      final label = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
      salesByDay[label] = (salesByDay[label] ?? 0) + amt;
    }

    final Map<String, double> purchasesByDay = {};
    for (var r in purchasesRes) {
      final amt = (r['grand_total'] as num).toDouble();
      totalPurchases += amt;
      final dtStr = r['date'] as String;
      final dt = DateTime.parse(dtStr);
      final label = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
      purchasesByDay[label] = (purchasesByDay[label] ?? 0) + amt;
    }

    // Combine labels
    final allLabels = {...salesByDay.keys, ...purchasesByDay.keys}.toList()..sort();
    
    final List<SalesVsPurchasesDataPoint> points = [];
    for (var label in allLabels) {
      points.add(SalesVsPurchasesDataPoint(
        label: label,
        salesAmount: salesByDay[label] ?? 0.0,
        purchasesAmount: purchasesByDay[label] ?? 0.0,
      ));
    }

    return SalesVsPurchasesReport(
      totalSales: totalSales,
      totalPurchases: totalPurchases,
      salesCount: salesRes.length,
      purchasesCount: purchasesRes.length,
      dataPoints: points,
    );
  }
}



final reportsRepositoryProvider = Provider<ReportsRepository>((ref) => ReportsRepository());

final reportFilterProvider = StateProvider<ReportFilter>((ref) => ReportFilter.thisMonth());

final profitLossProvider = FutureProvider.autoDispose<ProfitLossReport>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).getProfitLoss(businessId, filter);
});

final salesReportProvider = FutureProvider.autoDispose<SalesReport>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).getSalesReport(businessId, filter);
});

final stockReportProvider = FutureProvider.autoDispose<StockReport>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(reportsRepositoryProvider).getStockReport(businessId);
});

final taxReportProvider = FutureProvider.autoDispose<TaxReport>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).getTaxReport(businessId, filter);
});

final customerSalesSummaryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(reportsRepositoryProvider).getCustomerSalesSummary(businessId);
});

final discountAnalysisProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).getDiscountAnalysis(businessId, filter);
});

final salesVsPurchasesReportProvider = FutureProvider.autoDispose<SalesVsPurchasesReport>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).getSalesVsPurchasesReport(businessId, filter);
});
