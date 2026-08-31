// lib/features/reports/models/report_model.dart

import '../../billing/models/sale_history_model.dart';
import '../../accounts/models/transaction_model.dart';

class ReportFilter {
  final DateTime startDate;
  final DateTime endDate;
  final String type; // 'today', 'yesterday', 'thisWeek', 'thisMonth', 'lastMonth', 'thisQuarter', 'thisYear', 'custom'
  final int? categoryId;
  final int? entityId;

  ReportFilter({
    required this.startDate,
    required this.endDate,
    this.type = 'custom',
    this.categoryId,
    this.entityId,
  });

  factory ReportFilter.today({DateTime? now}) {
    final n = now ?? DateTime.now();
    return ReportFilter(
      startDate: DateTime(n.year, n.month, n.day),
      endDate: DateTime(n.year, n.month, n.day, 23, 59, 59, 999),
      type: 'today',
    );
  }

  factory ReportFilter.yesterday({DateTime? now}) {
    final n = now ?? DateTime.now();
    final yest = n.subtract(const Duration(days: 1));
    return ReportFilter(
      startDate: DateTime(yest.year, yest.month, yest.day),
      endDate: DateTime(yest.year, yest.month, yest.day, 23, 59, 59, 999),
      type: 'yesterday',
    );
  }

  factory ReportFilter.thisWeek({DateTime? now}) {
    final n = now ?? DateTime.now();
    final firstDayOfWeek = n.subtract(Duration(days: n.weekday - 1));
    return ReportFilter(
      startDate: DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day),
      endDate: DateTime(n.year, n.month, n.day, 23, 59, 59, 999),
      type: 'thisWeek',
    );
  }

  factory ReportFilter.thisMonth({DateTime? now}) {
    final n = now ?? DateTime.now();
    return ReportFilter(
      startDate: DateTime(n.year, n.month, 1),
      endDate: DateTime(n.year, n.month + 1, 0, 23, 59, 59, 999),
      type: 'thisMonth',
    );
  }

  factory ReportFilter.lastMonth({DateTime? now}) {
    final n = now ?? DateTime.now();
    return ReportFilter(
      startDate: DateTime(n.year, n.month - 1, 1),
      endDate: DateTime(n.year, n.month, 0, 23, 59, 59, 999),
      type: 'lastMonth',
    );
  }

  factory ReportFilter.thisQuarter({DateTime? now}) {
    final n = now ?? DateTime.now();
    final quarterMonth = ((n.month - 1) ~/ 3) * 3 + 1;
    return ReportFilter(
      startDate: DateTime(n.year, quarterMonth, 1),
      endDate: DateTime(n.year, quarterMonth + 3, 0, 23, 59, 59, 999),
      type: 'thisQuarter',
    );
  }

  factory ReportFilter.thisYear({DateTime? now}) {
    final n = now ?? DateTime.now();
    return ReportFilter(
      startDate: DateTime(n.year, 1, 1),
      endDate: DateTime(n.year, 12, 31, 23, 59, 59, 999),
      type: 'thisYear',
    );
  }

  factory ReportFilter.custom(DateTime start, DateTime end) {
    return ReportFilter(
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
      type: 'custom',
    );
  }
}

class SalesTrendPoint {
  final DateTime date;
  final String label;
  final double amount;
  final int count;

  SalesTrendPoint({
    required this.date,
    required this.label,
    required this.amount,
    required this.count,
  });
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

  /// Safe calculation of margin percentage protecting against zero revenue
  double get marginPercent => totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;
}

class SalesReport {
  final List<SaleHistoryModel> sales;
  final double totalAmount;
  final double netSales;
  final double totalGst;
  final double totalDiscount;
  final int transactionCount;
  final Map<String, double> paymentModeBreakdown;
  final List<SalesTrendPoint> trendPoints;

  SalesReport({
    required this.sales,
    required this.totalAmount,
    required this.netSales,
    required this.totalGst,
    required this.totalDiscount,
    required this.transactionCount,
    required this.paymentModeBreakdown,
    this.trendPoints = const [],
  });

  double get averageOrderValue => transactionCount > 0 ? totalAmount / transactionCount : 0.0;
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

  double get netCashFlow => totalIncome - totalExpense;
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
