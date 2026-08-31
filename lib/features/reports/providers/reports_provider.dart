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

    final revenue = ((salesRes.first['total'] as num?)?.toDouble() ?? 0.0) + ((manualIncRes.first['total'] as num?)?.toDouble() ?? 0.0);
    final cost = (cogsRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final expenses = (manualExpRes.first['total'] as num?)?.toDouble() ?? 0.0;
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
    final Map<String, ({double amount, int count, DateTime date})> dailyMap = {};

    for (final sale in sales) {
      paymentBreakdown[sale.paymentMode] = (paymentBreakdown[sale.paymentMode] ?? 0) + sale.grandTotal;
      
      final dt = sale.date;
      final label = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
      final existing = dailyMap[label];
      if (existing != null) {
        dailyMap[label] = (
          amount: existing.amount + sale.grandTotal,
          count: existing.count + 1,
          date: dt,
        );
      } else {
        dailyMap[label] = (
          amount: sale.grandTotal,
          count: 1,
          date: dt,
        );
      }
    }

    final sortedKeys = dailyMap.keys.toList()
      ..sort((a, b) => dailyMap[a]!.date.compareTo(dailyMap[b]!.date));

    final trendPoints = sortedKeys.map((k) {
      final item = dailyMap[k]!;
      return SalesTrendPoint(
        date: item.date,
        label: k,
        amount: item.amount,
        count: item.count,
      );
    }).toList();

    return SalesReport(
      sales: sales,
      totalAmount: (s['total'] as num?)?.toDouble() ?? 0.0,
      netSales: (s['net_sales'] as num?)?.toDouble() ?? 0.0,
      totalGst: (s['gst'] as num?)?.toDouble() ?? 0.0,
      totalDiscount: (s['discount'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (s['count'] as num?)?.toInt() ?? 0,
      paymentModeBreakdown: paymentBreakdown,
      trendPoints: trendPoints,
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
      final stock = (m['stock'] as num?)?.toDouble() ?? 0.0;
      final pPrice = (m['purchase_price'] as num?)?.toDouble() ?? 0.0;
      final minLevel = (m['min_stock'] as num?)?.toDouble() ?? 5.0;
      
      if (stock <= minLevel) lowStock++;
      totalValue += stock * pPrice;
      
      return StockItemDetail(
        productId: (m['id'] as num?)?.toInt() ?? 0,
        productName: m['name'] as String? ?? 'Product',
        currentStock: stock,
        purchasePrice: pPrice,
        salePrice: (m['selling_price'] as num?)?.toDouble() ?? 0.0,
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

    final coll = (collected.first['total'] as num?)?.toDouble() ?? 0.0;
    final pd = (paid.first['total'] as num?)?.toDouble() ?? 0.0;

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
      final amt = (r['grand_total'] as num?)?.toDouble() ?? 0.0;
      totalSales += amt;
      final dtStr = r['date'] as String?;
      final dt = dtStr != null ? DateTime.tryParse(dtStr) ?? DateTime.now() : DateTime.now();
      final label = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
      salesByDay[label] = (salesByDay[label] ?? 0) + amt;
    }

    final Map<String, double> purchasesByDay = {};
    for (var r in purchasesRes) {
      final amt = (r['grand_total'] as num?)?.toDouble() ?? 0.0;
      totalPurchases += amt;
      final dtStr = r['date'] as String?;
      final dt = dtStr != null ? DateTime.tryParse(dtStr) ?? DateTime.now() : DateTime.now();
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

  Future<List<Map<String, dynamic>>> getCategorySales(int businessId, ReportFilter filter) async {
    return await _db.rawQuery('''
      SELECT 
        COALESCE(c.name, 'Uncategorized') as category_name,
        SUM(si.quantity) as total_quantity,
        SUM(si.total) as total_sales,
        COUNT(DISTINCT s.id) as order_count
      FROM ${AppConstants.tblSaleItems} si
      JOIN ${AppConstants.tblSales} s ON si.sale_id = s.id
      JOIN ${AppConstants.tblProducts} p ON si.product_id = p.id
      LEFT JOIN ${AppConstants.tblCategories} c ON p.category_id = c.id
      WHERE s.business_id = ? AND s.date BETWEEN ? AND ? AND s.status = 'completed'
      GROUP BY c.id
      ORDER BY total_sales DESC
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getCustomerTypeSales(int businessId, ReportFilter filter) async {
    return await _db.rawQuery('''
      SELECT 
        COALESCE(ct.name, 'Direct Retail / Walk-in') as customer_type_name,
        COUNT(DISTINCT s.id) as transaction_count,
        SUM(s.grand_total) as total_sales,
        SUM(s.discount) as total_discount
      FROM ${AppConstants.tblSales} s
      LEFT JOIN ${AppConstants.tblCustomers} c ON s.customer_id = c.id
      LEFT JOIN ${AppConstants.tblCustomerTypes} ct ON c.customer_type_id = ct.id
      WHERE s.business_id = ? AND s.date BETWEEN ? AND ? AND s.status = 'completed'
      GROUP BY ct.id
      ORDER BY total_sales DESC
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getSupplierPurchaseSummary(int businessId, ReportFilter filter) async {
    return await _db.rawQuery('''
      SELECT 
        COALESCE(sup.name, 'Unknown Supplier') as supplier_name,
        sup.phone as supplier_phone,
        COUNT(p.id) as purchase_count,
        SUM(p.grand_total) as total_purchases,
        SUM(p.paid_amount) as total_paid,
        SUM(p.balance_due) as total_balance_due
      FROM ${AppConstants.tblPurchases} p
      LEFT JOIN ${AppConstants.tblSuppliers} sup ON p.supplier_id = sup.id
      WHERE p.business_id = ? AND p.date BETWEEN ? AND ? AND p.status = 'completed'
      GROUP BY p.supplier_id
      ORDER BY total_purchases DESC
    ''', [businessId, filter.startDate.toIso8601String(), filter.endDate.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getProductMovementAnalysis(int businessId, ReportFilter filter) async {
    return await _db.rawQuery('''
      SELECT 
        p.id as product_id,
        p.name as product_name,
        p.sku,
        p.unit,
        p.purchase_price,
        p.selling_price,
        p.stock as current_stock,
        (p.stock * p.purchase_price) as inventory_value,
        COALESCE(SUM(CASE WHEN it.transaction_type = 'PURCHASE' THEN it.quantity ELSE 0 END), 0) as purchased_qty,
        COALESCE(SUM(CASE WHEN it.transaction_type = 'SALE' THEN it.quantity ELSE 0 END), 0) as sold_qty,
        COALESCE(SUM(CASE WHEN it.transaction_type = 'STOCK_ADJUSTMENT' OR it.transaction_type = 'DAMAGE_WASTAGE' THEN it.quantity ELSE 0 END), 0) as adjusted_qty
      FROM ${AppConstants.tblProducts} p
      LEFT JOIN ${AppConstants.tblInventoryTransactions} it ON p.id = it.product_id AND it.created_date BETWEEN ? AND ?
      WHERE p.business_id = ? AND p.is_active = 1
      GROUP BY p.id
      ORDER BY p.name ASC
    ''', [filter.startDate.toIso8601String(), filter.endDate.toIso8601String(), businessId]);
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

final categorySalesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).getCategorySales(businessId, filter);
});

final customerTypeSalesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).getCustomerTypeSales(businessId, filter);
});

final supplierPurchaseSummaryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).getSupplierPurchaseSummary(businessId, filter);
});

final productMovementAnalysisProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).getProductMovementAnalysis(businessId, filter);
});
