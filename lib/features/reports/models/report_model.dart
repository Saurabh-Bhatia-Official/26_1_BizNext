// lib/features/reports/models/report_model.dart

import '../../billing/models/sale_history_model.dart';
import '../../accounts/models/transaction_model.dart';

class ReportFilter {
  final DateTime startDate;
  final DateTime endDate;
  final String type; // 'today', 'thisWeek', 'thisMonth', 'custom'
  final int? categoryId;
  final int? entityId;

  ReportFilter({
    required this.startDate,
    required this.endDate,
    this.type = 'custom',
    this.categoryId,
    this.entityId,
  });

  factory ReportFilter.today() {
    final now = DateTime.now();
    return ReportFilter(
      startDate: DateTime(now.year, now.month, now.day),
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
      type: 'today',
    );
  }

  factory ReportFilter.yesterday() {
    final now = DateTime.now();
    final yest = now.subtract(const Duration(days: 1));
    return ReportFilter(
      startDate: DateTime(yest.year, yest.month, yest.day),
      endDate: DateTime(yest.year, yest.month, yest.day, 23, 59, 59, 999),
      type: 'yesterday',
    );
  }

  factory ReportFilter.thisWeek() {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return ReportFilter(
      startDate: DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day),
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
      type: 'thisWeek',
    );
  }

  factory ReportFilter.thisMonth() {
    final now = DateTime.now();
    return ReportFilter(
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
      type: 'thisMonth',
    );
  }

  factory ReportFilter.lastMonth() {
    final now = DateTime.now();
    return ReportFilter(
      startDate: DateTime(now.year, now.month - 1, 1),
      endDate: DateTime(now.year, now.month, 0, 23, 59, 59, 999),
      type: 'lastMonth',
    );
  }

  factory ReportFilter.thisYear() {
    final now = DateTime.now();
    return ReportFilter(
      startDate: DateTime(now.year, 1, 1),
      endDate: DateTime(now.year, 12, 31, 23, 59, 59, 999),
      type: 'thisYear',
    );
  }
}

class ProfitLossReport {
  final double totalRevenue;
  final double totalCost;
  final double totalExpenses;
  final double netProfit;
  final double margin;

  ProfitLossReport({
    required this.totalRevenue,
    required this.totalCost,
    required this.totalExpenses,
    required this.netProfit,
    required this.margin,
  });
}

class SalesReport {
  final List<SaleHistoryModel> sales;
  final double totalAmount;
  final double netSales;
  final double totalGst;
  final double totalDiscount;
  final int transactionCount;

  final Map<String, double> paymentModeBreakdown;

  SalesReport({
    required this.sales,
    required this.totalAmount,
    required this.netSales,
    required this.totalGst,
    required this.totalDiscount,
    required this.transactionCount,
    required this.paymentModeBreakdown,
  });
}

class StockReport {
  final List<StockItemDetail> items;
  final double totalInventoryValue;
  final int lowStockCount;

  StockReport({
    required this.items,
    required this.totalInventoryValue,
    required this.lowStockCount,
  });
}

class StockItemDetail {
  final int productId;
  final String productName;
  final double currentStock;
  final double purchasePrice;
  final double salePrice;
  final double value;

  StockItemDetail({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.purchasePrice,
    required this.salePrice,
    required this.value,
  });
}

class TransactionReport {
  final List<TransactionModel> transactions;
  final Map<String, double> categoryBreakdown;
  final double totalIncome;
  final double totalExpense;

  TransactionReport({
    required this.transactions,
    required this.categoryBreakdown,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class TaxReport {
  final double gstCollected; // From Sales
  final double gstPaid;      // From Purchases
  final double netGstPayable;

  TaxReport({
    required this.gstCollected,
    required this.gstPaid,
    required this.netGstPayable,
  });
}

class SalesVsPurchasesReport {
  final double totalSales;
  final double totalPurchases;
  final int salesCount;
  final int purchasesCount;
  final List<SalesVsPurchasesDataPoint> dataPoints;

  SalesVsPurchasesReport({
    required this.totalSales,
    required this.totalPurchases,
    required this.salesCount,
    required this.purchasesCount,
    required this.dataPoints,
  });
}

class SalesVsPurchasesDataPoint {
  final String label;
  final double salesAmount;
  final double purchasesAmount;

  SalesVsPurchasesDataPoint({
    required this.label,
    required this.salesAmount,
    required this.purchasesAmount,
  });
}
