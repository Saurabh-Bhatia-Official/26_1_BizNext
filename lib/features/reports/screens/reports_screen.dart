// lib/features/reports/screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../billing/providers/billing_provider.dart';
import '../../billing/providers/sales_stats_provider.dart';
import '../../billing/screens/pos_billing_screen.dart';
import '../../billing/models/sale_history_model.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../providers/reports_provider.dart';
import '../models/report_model.dart';
import '../../settings/providers/settings_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedReportType = 'sales'; // 'sales', 'expenses', 'pnl', 'cash_flow', 'balance_sheet', 'tax'
  String _chartType = 'line'; // 'line', 'bar', 'pie', 'area', 'trend'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(reportFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Analytics & Financial Reports', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_zip_rounded, color: AppColors.primary),
            onPressed: () => _exportData(context),
            tooltip: 'Export CSV',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Period Selector & Filter Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _ReportsHeader(
                isDark: isDark,
                filter: filter,
                onFilterChange: (newFilter) => ref.read(reportFilterProvider.notifier).state = newFilter,
              ),
            ),
          ),

          // ── Report Type Choice Chips ──
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  _ReportTypeChip(label: 'Sales & Revenue', value: 'sales', selectedValue: _selectedReportType, icon: Icons.insights_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Expenses Breakdown', value: 'expenses', selectedValue: _selectedReportType, icon: Icons.receipt_long_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Sales vs Purchases', value: 'sales_vs_purchases', selectedValue: _selectedReportType, icon: Icons.compare_arrows_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Profit & Loss', value: 'pnl', selectedValue: _selectedReportType, icon: Icons.account_balance_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Cash Flow', value: 'cash_flow', selectedValue: _selectedReportType, icon: Icons.swap_horiz_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Balance Sheet', value: 'balance_sheet', selectedValue: _selectedReportType, icon: Icons.balance_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Tax & GST', value: 'tax', selectedValue: _selectedReportType, icon: Icons.gavel_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                ],
              ),
            ),
          ),

          // ── Interactive Dashboard Chart Panel ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: _InteractiveChartPanel(
                isDark: isDark,
                reportType: _selectedReportType,
                chartType: _chartType,
                onChartTypeChanged: (v) => setState(() => _chartType = v),
              ),
            ),
          ),

          // ── Detailed Report List / Data Grid ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            sliver: SliverToBoxAdapter(
              child: _ReportBreakdownSection(
                isDark: isDark,
                reportType: _selectedReportType,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Report',
        fileName: '${_selectedReportType}_export.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile == null) return;

      final StringBuffer csv = StringBuffer();
      if (_selectedReportType == 'sales') {
        final salesReport = await ref.read(salesReportProvider.future);
        csv.writeln('Invoice No,Date,Customer,Total Amount,GST Amount,Discount,Payment Mode');
        for (final sale in salesReport.sales) {
          csv.writeln('${sale.invoiceNo},${sale.date.toIso8601String()},${sale.customerName ?? 'Walk-in'},${sale.grandTotal},${sale.gstAmount},${sale.discount},${sale.paymentMode}');
        }
      } else {
        csv.writeln('Report Type,Generated Date,Key,Value');
        csv.writeln('${_selectedReportType},${DateTime.now().toIso8601String()},Export,Standard CSV format');
      }

      final File file = File(outputFile);
      await file.writeAsString(csv.toString());
      AppAlert.success(ref, 'Export saved successfully');
    } catch (e) {
      AppAlert.error(ref, 'Failed to export data: $e');
    }
  }
}

class _ReportTypeChip extends StatelessWidget {
  final String label;
  final String value;
  final String selectedValue;
  final IconData icon;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _ReportTypeChip({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.icon,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selectedValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveChartPanel extends ConsumerWidget {
  final bool isDark;
  final String reportType;
  final String chartType;
  final ValueChanged<String> onChartTypeChanged;

  const _InteractiveChartPanel({
    required this.isDark,
    required this.reportType,
    required this.chartType,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Visual Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  _ChartTypeButton(type: 'line', current: chartType, icon: Icons.show_chart_rounded, onTap: onChartTypeChanged),
                  _ChartTypeButton(type: 'bar', current: chartType, icon: Icons.bar_chart_rounded, onTap: onChartTypeChanged),
                  _ChartTypeButton(type: 'pie', current: chartType, icon: Icons.pie_chart_rounded, onTap: onChartTypeChanged),
                  _ChartTypeButton(type: 'area', current: chartType, icon: Icons.area_chart_rounded, onTap: onChartTypeChanged),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _buildChart(ref),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(WidgetRef ref) {
    if (reportType == 'sales') {
      final salesAsync = ref.watch(salesReportProvider);
      return salesAsync.when(
        data: (report) {
          if (report.sales.isEmpty) return const _EmptyChart();
          if (chartType == 'pie') {
            return PieChart(PieChartData(
              sections: report.paymentModeBreakdown.entries.map((e) {
                final double val = e.value;
                return PieChartSectionData(
                  color: e.key == 'Cash' ? Colors.green : Colors.blue,
                  value: val,
                  title: '${e.key}\n₹${val.toStringAsFixed(0)}',
                  radius: 70,
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ));
          }

          // Line/Bar/Area charts
          final List<FlSpot> spots = [];
          for (int i = 0; i < report.sales.length; i++) {
            spots.add(FlSpot(i.toDouble(), report.sales[i].grandTotal));
          }

          if (chartType == 'bar') {
            return BarChart(BarChartData(
              barGroups: spots.map((s) => BarChartGroupData(
                x: s.x.toInt(),
                barRods: [BarChartRodData(toY: s.y, color: AppColors.primary, width: 14)],
              )).toList(),
            ));
          }

          return LineChart(LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 4,
                belowBarData: chartType == 'area' 
                    ? BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.15))
                    : null,
              ),
            ],
          ));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _EmptyChart(),
      );
    } else if (reportType == 'expenses') {
      final txAsync = ref.watch(transactionsProvider);
      return txAsync.when(
        data: (list) {
          final expenses = list.where((t) => t.type == 'debit').toList();
          if (expenses.isEmpty) return const _EmptyChart();

          final categoryTotals = <String, double>{};
          for (var exp in expenses) {
            final cat = exp.categoryName ?? 'Other';
            categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + exp.amount;
          }

          if (chartType == 'pie') {
            return PieChart(PieChartData(
              sections: categoryTotals.entries.map((e) {
                return PieChartSectionData(
                  color: Colors.primaries[categoryTotals.keys.toList().indexOf(e.key) % Colors.primaries.length],
                  value: e.value,
                  title: '${e.key}\n₹${e.value.toStringAsFixed(0)}',
                  radius: 70,
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ));
          }

          final List<FlSpot> spots = [];
          for (int i = 0; i < expenses.length; i++) {
            spots.add(FlSpot(i.toDouble(), expenses[i].amount));
          }

          if (chartType == 'bar') {
            return BarChart(BarChartData(
              barGroups: spots.map((s) => BarChartGroupData(
                x: s.x.toInt(),
                barRods: [BarChartRodData(toY: s.y, color: AppColors.error, width: 14)],
              )).toList(),
            ));
          }

          return LineChart(LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.error,
                barWidth: 4,
                belowBarData: chartType == 'area'
                    ? BarAreaData(show: true, color: AppColors.error.withValues(alpha: 0.15))
                    : null,
              ),
            ],
          ));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _EmptyChart(),
      );
    } else if (reportType == 'sales_vs_purchases') {
      final vsAsync = ref.watch(salesVsPurchasesReportProvider);
      return vsAsync.when(
        data: (report) {
          if (report.dataPoints.isEmpty) return const _EmptyChart();

          if (chartType == 'pie') {
            return PieChart(PieChartData(
              sections: [
                PieChartSectionData(color: AppColors.primary, value: report.totalSales, title: 'Sales\n₹${report.totalSales.toStringAsFixed(0)}', radius: 70, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                PieChartSectionData(color: Colors.amber, value: report.totalPurchases, title: 'Purchases\n₹${report.totalPurchases.toStringAsFixed(0)}', radius: 70, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ));
          }

          final List<FlSpot> salesSpots = [];
          final List<FlSpot> purchasesSpots = [];
          for (int i = 0; i < report.dataPoints.length; i++) {
            salesSpots.add(FlSpot(i.toDouble(), report.dataPoints[i].salesAmount));
            purchasesSpots.add(FlSpot(i.toDouble(), report.dataPoints[i].purchasesAmount));
          }

          if (chartType == 'bar') {
            return BarChart(BarChartData(
              barGroups: List.generate(report.dataPoints.length, (i) {
                final pt = report.dataPoints[i];
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(toY: pt.salesAmount, color: AppColors.primary, width: 6),
                    BarChartRodData(toY: pt.purchasesAmount, color: Colors.amber, width: 6),
                  ],
                );
              }),
            ));
          }

          return LineChart(LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: salesSpots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 4,
                belowBarData: chartType == 'area' 
                    ? BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.15))
                    : null,
              ),
              LineChartBarData(
                spots: purchasesSpots,
                isCurved: true,
                color: Colors.amber,
                barWidth: 4,
                belowBarData: chartType == 'area' 
                    ? BarAreaData(show: true, color: Colors.amber.withValues(alpha: 0.15))
                    : null,
              ),
            ],
          ));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _EmptyChart(),
      );
    } else {
      // Default/Other report visualizations (Profit/Loss, Cash Flow)
      final pnlAsync = ref.watch(profitLossProvider);
      return pnlAsync.when(
        data: (report) {
          final revenue = report.totalRevenue;
          final expenses = report.totalExpenses + report.totalCost;

          if (chartType == 'pie') {
            return PieChart(PieChartData(
              sections: [
                PieChartSectionData(color: AppColors.success, value: revenue, title: 'Revenue\n₹${revenue.toStringAsFixed(0)}', radius: 70, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                PieChartSectionData(color: AppColors.error, value: expenses, title: 'Expenses\n₹${expenses.toStringAsFixed(0)}', radius: 70, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ));
          }

          return BarChart(BarChartData(
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: revenue, color: AppColors.success, width: 24)]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: expenses, color: AppColors.error, width: 24)]),
            ],
          ));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _EmptyChart(),
      );
    }
  }
}

class _ChartTypeButton extends StatelessWidget {
  final String type;
  final String current;
  final IconData icon;
  final ValueChanged<String> onTap;

  const _ChartTypeButton({required this.type, required this.current, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = type == current;
    return IconButton(
      icon: Icon(icon, color: isSelected ? AppColors.primary : AppColors.textMuted),
      onPressed: () => onTap(type),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('No sufficient data to visualize charts', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ReportBreakdownSection extends ConsumerWidget {
  final bool isDark;
  final String reportType;

  const _ReportBreakdownSection({required this.isDark, required this.reportType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reportType == 'sales') {
      final salesAsync = ref.watch(salesReportProvider);
      return salesAsync.when(
        data: (report) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales Operations Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(label: 'Total Orders', value: '${report.transactionCount}', color: Colors.blue),
                _StatCard(label: 'Net Revenue', value: '₹${CurrencyFormatter.format(report.netSales)}', color: Colors.green),
                _StatCard(label: 'GST Collected', value: '₹${CurrencyFormatter.format(report.totalGst)}', color: Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Recent Invoices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...report.sales.map((s) => _ReportListTile(
              title: s.invoiceNo,
              subtitle: '${s.customerName ?? 'Walk-in'} • ${DateFormatter.toDisplay(s.date)}',
              trailing: '₹${CurrencyFormatter.format(s.grandTotal)}',
            )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else if (reportType == 'expenses') {
      final txAsync = ref.watch(transactionsProvider);
      return txAsync.when(
        data: (list) {
          final expenses = list.where((t) => t.type == 'debit').toList();
          final total = expenses.fold(0.0, (sum, t) => sum + t.amount);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Expenses & Cost Outflows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatCard(label: 'Total Outflow', value: '₹${CurrencyFormatter.format(total)}', color: AppColors.error),
                  _StatCard(label: 'Expense Records', value: '${expenses.length}', color: Colors.blueGrey),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Operational Expense Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...expenses.map((e) => _ReportListTile(
                title: e.description ?? 'Expense Record',
                subtitle: '${e.categoryName} • ${DateFormatter.toDisplay(e.date)}',
                trailing: '₹${CurrencyFormatter.format(e.amount)}',
              )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else if (reportType == 'pnl') {
      final pnlAsync = ref.watch(profitLossProvider);
      return pnlAsync.when(
        data: (report) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profit & Loss Statement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ReportDetailsRow(label: 'Operating Gross Revenue', value: '₹${CurrencyFormatter.format(report.totalRevenue)}'),
            _ReportDetailsRow(label: 'Cost of Goods Sold (COGS)', value: '- ₹${CurrencyFormatter.format(report.totalCost)}', color: AppColors.error),
            _ReportDetailsRow(label: 'Operating & Admin Expenses', value: '- ₹${CurrencyFormatter.format(report.totalExpenses)}', color: AppColors.error),
            const Divider(height: 32),
            _ReportDetailsRow(
              label: 'Net Profits', 
              value: '₹${CurrencyFormatter.format(report.netProfit)}', 
              isBold: true,
              color: report.netProfit >= 0 ? AppColors.success : AppColors.error,
            ),
            _ReportDetailsRow(label: 'Profit Margin', value: '${report.margin.toStringAsFixed(2)}%', isBold: true),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else if (reportType == 'balance_sheet') {
      final summaryAsync = ref.watch(balanceSummaryProvider);
      return summaryAsync.when(
        data: (summary) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Balance Sheet (Assets & Liabilities)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Current Assets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 8),
            _ReportDetailsRow(label: 'Cash & Account Wallets', value: '₹${CurrencyFormatter.format(summary.cashInHand)}'),
            _ReportDetailsRow(label: 'Total Receivables (Customers)', value: '₹${CurrencyFormatter.format(summary.totalReceivable)}'),
            const SizedBox(height: 16),
            const Text('Current Liabilities & Payables', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error)),
            const SizedBox(height: 8),
            _ReportDetailsRow(label: 'Total Payables (Suppliers)', value: '₹${CurrencyFormatter.format(summary.totalPayable)}', color: AppColors.error),
            const Divider(height: 32),
            _ReportDetailsRow(
              label: 'Net Working Capital (Net Assets)',
              value: '₹${CurrencyFormatter.format(summary.cashInHand + summary.totalReceivable - summary.totalPayable)}',
              isBold: true,
              color: AppColors.success,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else if (reportType == 'tax') {
      final taxAsync = ref.watch(taxReportProvider);
      return taxAsync.when(
        data: (report) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Taxation & GST Liability', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ReportDetailsRow(label: 'Output Tax (GST Collected on Sales)', value: '₹${CurrencyFormatter.format(report.gstCollected)}', color: AppColors.success),
            _ReportDetailsRow(label: 'Input Tax Credit (GST Paid on Purchases)', value: '₹${CurrencyFormatter.format(report.gstPaid)}', color: AppColors.error),
            const Divider(height: 32),
            _ReportDetailsRow(
              label: 'Net GST Payable', 
              value: '₹${CurrencyFormatter.format(report.netGstPayable)}', 
              isBold: true,
              color: report.netGstPayable >= 0 ? Colors.indigo : AppColors.success,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else if (reportType == 'sales_vs_purchases') {
      final vsAsync = ref.watch(salesVsPurchasesReportProvider);
      return vsAsync.when(
        data: (report) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales vs Purchases Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(label: 'Total Sales', value: '₹${CurrencyFormatter.format(report.totalSales)}', color: AppColors.primary),
                _StatCard(label: 'Total Purchases', value: '₹${CurrencyFormatter.format(report.totalPurchases)}', color: Colors.amber),
              ],
            ),
            const SizedBox(height: 24),
            _ReportDetailsRow(label: 'Sales Count', value: '${report.salesCount} invoices'),
            _ReportDetailsRow(label: 'Purchases Count', value: '${report.purchasesCount} bills'),
            _ReportDetailsRow(
              label: 'Trade Balance', 
              value: '₹${CurrencyFormatter.format(report.totalSales - report.totalPurchases)}', 
              isBold: true,
              color: (report.totalSales - report.totalPurchases) >= 0 ? AppColors.success : AppColors.error,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else {
      // cash_flow
      final pnlAsync = ref.watch(profitLossProvider);
      return pnlAsync.when(
        data: (report) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cash Flow Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ReportDetailsRow(label: 'Cash Inflow (Sales & Manual Income)', value: '₹${CurrencyFormatter.format(report.totalRevenue)}', color: AppColors.success),
            _ReportDetailsRow(label: 'Cash Outflow (COGS & Expenses)', value: '- ₹${CurrencyFormatter.format(report.totalCost + report.totalExpenses)}', color: AppColors.error),
            const Divider(height: 32),
            _ReportDetailsRow(
              label: 'Net Cash Flow', 
              value: '₹${CurrencyFormatter.format(report.totalRevenue - (report.totalCost + report.totalExpenses))}', 
              isBold: true,
              color: (report.totalRevenue - (report.totalCost + report.totalExpenses)) >= 0 ? AppColors.success : AppColors.error,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ReportDetailsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const _ReportDetailsRow({required this.label, required this.value, this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: isBold ? null : AppColors.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _ReportListTile({required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  final bool isDark;
  final ReportFilter filter;
  final ValueChanged<ReportFilter> onFilterChange;

  const _ReportsHeader({
    required this.isDark,
    required this.filter,
    required this.onFilterChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Period: ${DateFormatter.toDisplay(filter.startDate)} - ${DateFormatter.toDisplay(filter.endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: filter.type,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'today', child: Text('Today')),
              DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
              DropdownMenuItem(value: 'thisMonth', child: Text('This Month')),
              DropdownMenuItem(value: 'lastMonth', child: Text('Last Month')),
              DropdownMenuItem(value: 'thisYear', child: Text('This Year')),
            ],
            onChanged: (val) {
              if (val != null) {
                if (val == 'today') {
                  onFilterChange(ReportFilter.today());
                } else if (val == 'yesterday') {
                  onFilterChange(ReportFilter.yesterday());
                } else if (val == 'thisMonth') {
                  onFilterChange(ReportFilter.thisMonth());
                } else if (val == 'lastMonth') {
                  onFilterChange(ReportFilter.lastMonth());
                } else if (val == 'thisYear') {
                  onFilterChange(ReportFilter.thisYear());
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
