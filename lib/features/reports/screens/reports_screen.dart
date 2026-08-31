// lib/features/reports/screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../providers/reports_provider.dart';
import '../models/report_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/rbac_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedReportType = 'sales';
  String _chartViewMode = 'line'; // 'line', 'bar', 'pie'

  @override
  Widget build(BuildContext context) {
    final rbac = ref.watch(rbacProvider);
    if (!rbac.hasPermission(AppPermission.viewReports)) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to view reports.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(reportFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Analytics & Intelligence Hub',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton.filledTonal(
            icon: const Icon(Icons.file_download_rounded, color: AppColors.primary, size: 20),
            onPressed: () => _exportData(context),
            tooltip: 'Export Report as CSV',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 16),
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

          // ── Report Type Choice Chips Ribbon ──
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  _ReportTypeChip(label: 'Sales & Revenue', value: 'sales', selectedValue: _selectedReportType, icon: Icons.insights_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Sales vs Purchases', value: 'sales_vs_purchases', selectedValue: _selectedReportType, icon: Icons.compare_arrows_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Sales by Category', value: 'category_sales', selectedValue: _selectedReportType, icon: Icons.category_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Customer Types', value: 'customer_type_sales', selectedValue: _selectedReportType, icon: Icons.groups_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Product Movement & Stock', value: 'inventory_movement', selectedValue: _selectedReportType, icon: Icons.inventory_2_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Supplier Purchases', value: 'supplier_purchases', selectedValue: _selectedReportType, icon: Icons.local_shipping_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Expenses Breakdown', value: 'expenses', selectedValue: _selectedReportType, icon: Icons.receipt_long_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Profit & Loss', value: 'pnl', selectedValue: _selectedReportType, icon: Icons.account_balance_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Cash Flow', value: 'cash_flow', selectedValue: _selectedReportType, icon: Icons.swap_horiz_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Balance Sheet', value: 'balance_sheet', selectedValue: _selectedReportType, icon: Icons.balance_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                  _ReportTypeChip(label: 'Tax & GST', value: 'tax', selectedValue: _selectedReportType, icon: Icons.gavel_rounded, isDark: isDark, onChanged: (v) => setState(() => _selectedReportType = v)),
                ],
              ),
            ),
          ),

          // ── Professional Interactive Chart Dashboard Panel ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            sliver: SliverToBoxAdapter(
              child: _InteractiveChartPanel(
                isDark: isDark,
                reportType: _selectedReportType,
                chartMode: _chartViewMode,
                onChartModeChanged: (mode) => setState(() => _chartViewMode = mode),
              ),
            ),
          ),

          // ── Detailed Report List / Data Grid ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
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
        fileName: '${_selectedReportType}_report_${DateTime.now().millisecondsSinceEpoch}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        final filter = ref.read(reportFilterProvider);
        final businessId = ref.read(activeBusinessIdProvider);
        String csvContent = "Export Type: $_selectedReportType\nGenerated: ${DateTime.now()}\n";
        
        if (_selectedReportType == 'sales') {
          final report = await ref.read(reportsRepositoryProvider).getSalesReport(businessId, filter);
          csvContent += "Invoice No,Date,Customer,Payment Mode,Subtotal,GST,Discount,Total\n";
          for (var s in report.sales) {
            csvContent += "${s.invoiceNo},${s.date},${s.customerName ?? 'Walk-in'},${s.paymentMode},${s.subtotal},${s.gstAmount},${s.discount},${s.grandTotal}\n";
          }
        } else if (_selectedReportType == 'supplier_purchases') {
          final list = await ref.read(reportsRepositoryProvider).getSupplierPurchaseSummary(businessId, filter);
          csvContent += "Supplier Name,Phone,Bills Count,Total Purchases,Total Paid,Balance Due\n";
          for (var r in list) {
            csvContent += "${r['supplier_name']},${r['supplier_phone'] ?? ''},${r['purchase_count']},${r['total_purchases']},${r['total_paid']},${r['total_balance_due']}\n";
          }
        } else if (_selectedReportType == 'inventory_movement') {
          final list = await ref.read(reportsRepositoryProvider).getProductMovementAnalysis(businessId, filter);
          csvContent += "Product Name,SKU,Unit,Cost,Selling Price,Purchased Qty,Sold Qty,Adjusted Qty,Current Stock,Valuation\n";
          for (var r in list) {
            csvContent += "${r['product_name']},${r['sku'] ?? ''},${r['unit']},${r['purchase_price']},${r['selling_price']},${r['purchased_qty']},${r['sold_qty']},${r['adjusted_qty']},${r['current_stock']},${r['inventory_value']}\n";
          }
        } else {
          csvContent += "Export completed for period: ${filter.startDate} to ${filter.endDate}\n";
        }

        await file.writeAsString(csvContent);
        if (context.mounted) {
          AppAlert.success(ref, 'Report exported successfully to CSV');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppAlert.error(ref, 'Failed to export report: $e');
      }
    }
  }
}

// ── Report Type Chip ─────────────────────────────────────────────────────────
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
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Interactive Chart Panel ───────────────────────────────────────────────────
class _InteractiveChartPanel extends ConsumerWidget {
  final bool isDark;
  final String reportType;
  final String chartMode;
  final ValueChanged<String> onChartModeChanged;

  const _InteractiveChartPanel({
    required this.isDark,
    required this.reportType,
    required this.chartMode,
    required this.onChartModeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Mode Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getChartTitle(),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getChartSubtitle(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              _buildModeButtons(),
            ],
          ),
          const SizedBox(height: 24),
          // Chart Canvas
          SizedBox(
            height: 240,
            child: _buildChartContent(ref),
          ),
        ],
      ),
    );
  }

  String _getChartTitle() {
    switch (reportType) {
      case 'sales':
        return 'Sales & Revenue Trajectory';
      case 'sales_vs_purchases':
        return 'Sales vs Purchases Comparative Dynamics';
      case 'category_sales':
        return 'Category Revenue Distribution';
      case 'customer_type_sales':
        return 'Customer Tier Performance';
      case 'inventory_movement':
        return 'Top Moving Inventory (Volume)';
      case 'supplier_purchases':
        return 'Supplier Outflows & Balances';
      case 'expenses':
        return 'Expense Categories & Outflows';
      case 'pnl':
        return 'Income Statement & Profitability Flow';
      case 'cash_flow':
        return 'Cash Inflow vs Outflow';
      case 'balance_sheet':
        return 'Assets vs Liabilities Position';
      case 'tax':
        return 'GST Output vs Input Tax Credit';
      default:
        return 'Financial Performance';
    }
  }

  String _getChartSubtitle() {
    switch (reportType) {
      case 'sales':
        return 'Interactive revenue trend over the selected period';
      case 'sales_vs_purchases':
        return 'Comparison of revenue generation against procurement cost';
      case 'category_sales':
        return 'Share of total revenue by product categories';
      case 'customer_type_sales':
        return 'Volume and revenue breakdown by customer category';
      case 'inventory_movement':
        return 'Fastest selling products during this timeframe';
      case 'supplier_purchases':
        return 'Purchases, paid sums, and pending liabilities';
      case 'expenses':
        return 'Operating overhead and expense breakdown';
      case 'pnl':
        return 'Revenue, COGS, operating costs, and net margin';
      case 'cash_flow':
        return 'Net operational liquidity and cash movements';
      case 'balance_sheet':
        return 'Current liquidity assets vs outstanding obligations';
      case 'tax':
        return 'GST collected vs GST paid to calculate liability';
      default:
        return 'Overview analytics';
    }
  }

  Widget _buildModeButtons() {
    if (reportType == 'sales' || reportType == 'sales_vs_purchases') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChartTypeBtn(icon: Icons.show_chart_rounded, type: 'line', current: chartMode, onTap: onChartModeChanged),
            _ChartTypeBtn(icon: Icons.bar_chart_rounded, type: 'bar', current: chartMode, onTap: onChartModeChanged),
            if (reportType == 'sales')
              _ChartTypeBtn(icon: Icons.pie_chart_rounded, type: 'pie', current: chartMode, onTap: onChartModeChanged),
          ],
        ),
      );
    } else if (reportType == 'category_sales' || reportType == 'expenses') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChartTypeBtn(icon: Icons.pie_chart_rounded, type: 'pie', current: chartMode == 'bar' ? 'bar' : 'pie', onTap: onChartModeChanged),
            _ChartTypeBtn(icon: Icons.bar_chart_rounded, type: 'bar', current: chartMode == 'bar' ? 'bar' : 'pie', onTap: onChartModeChanged),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildChartContent(WidgetRef ref) {
    switch (reportType) {
      case 'sales':
        return _buildSalesChart(ref);
      case 'sales_vs_purchases':
        return _buildSalesVsPurchasesChart(ref);
      case 'category_sales':
        return _buildCategorySalesChart(ref);
      case 'customer_type_sales':
        return _buildCustomerTypeChart(ref);
      case 'inventory_movement':
        return _buildProductMovementChart(ref);
      case 'supplier_purchases':
        return _buildSupplierPurchasesChart(ref);
      case 'expenses':
        return _buildExpensesChart(ref);
      case 'pnl':
        return _buildPnlChart(ref);
      case 'cash_flow':
        return _buildCashFlowChart(ref);
      case 'balance_sheet':
        return _buildBalanceSheetChart(ref);
      case 'tax':
        return _buildTaxChart(ref);
      default:
        return _buildPnlChart(ref);
    }
  }

  // 1. Sales & Revenue Chart
  Widget _buildSalesChart(WidgetRef ref) {
    final salesAsync = ref.watch(salesReportProvider);
    return salesAsync.when(
      data: (report) {
        if (chartMode == 'pie' && report.paymentModeBreakdown.isNotEmpty) {
          return _buildPaymentModePieChart(report.paymentModeBreakdown);
        }

        if (report.trendPoints.isEmpty) {
          if (report.totalAmount == 0) return const _EmptyChart();
          // Fallback single bar
          return BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: report.totalAmount,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 36,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        if (chartMode == 'bar') {
          return BarChart(
            BarChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (val) => FlLine(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx >= 0 && idx < report.trendPoints.length) {
                        if (report.trendPoints.length > 7 && idx % (report.trendPoints.length ~/ 6) != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            report.trendPoints[idx].label,
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              barGroups: report.trendPoints.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.amount,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: report.trendPoints.length > 15 ? 8 : 16,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        }

        // Line Chart default
        final spots = report.trendPoints.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value.amount);
        }).toList();

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (val) => FlLine(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1, dashArray: [5, 5]),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx >= 0 && idx < report.trendPoints.length) {
                      if (report.trendPoints.length > 7 && idx % (report.trendPoints.length ~/ 5 + 1) != 0 && idx != report.trendPoints.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          report.trendPoints[idx].label,
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => isDark ? AppColors.darkSurface : Colors.black87,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final idx = spot.x.toInt();
                    final point = idx >= 0 && idx < report.trendPoints.length ? report.trendPoints[idx] : null;
                    return LineTooltipItem(
                      '${point?.label ?? ""}\n${CurrencyFormatter.format(spot.y)}\n(${point?.count ?? 0} orders)',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppColors.primary,
                barWidth: 3.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: spots.length <= 12,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2.5,
                    strokeColor: AppColors.primary,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.35),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // Payment Mode Donut Chart
  Widget _buildPaymentModePieChart(Map<String, double> breakdown) {
    final colors = [AppColors.primary, AppColors.success, AppColors.accent, Colors.amber, Colors.purple];
    final total = breakdown.values.fold(0.0, (s, v) => s + v);
    if (total == 0) return const _EmptyChart();

    int colorIdx = 0;
    final sections = breakdown.entries.map((e) {
      final color = colors[colorIdx % colors.length];
      colorIdx++;
      final pct = (e.value / total) * 100;
      return PieChartSectionData(
        value: e.value,
        color: color,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 45,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 3,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: breakdown.entries.map((e) {
              final color = colors[breakdown.keys.toList().indexOf(e.key) % colors.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(e.value),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 2. Sales vs Purchases Dual Chart
  Widget _buildSalesVsPurchasesChart(WidgetRef ref) {
    final vsAsync = ref.watch(salesVsPurchasesReportProvider);
    return vsAsync.when(
      data: (report) {
        if (report.dataPoints.isEmpty) return const _EmptyChart();
        final salesSpots = report.dataPoints.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.salesAmount)).toList();
        final purchaseSpots = report.dataPoints.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.purchasesAmount)).toList();

        if (chartMode == 'bar') {
          return BarChart(
            BarChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx >= 0 && idx < report.dataPoints.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            report.dataPoints[idx].label,
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              barGroups: report.dataPoints.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(toY: e.value.salesAmount, color: AppColors.primary, width: 14, borderRadius: BorderRadius.circular(4)),
                    BarChartRodData(toY: e.value.purchasesAmount, color: Colors.amber, width: 14, borderRadius: BorderRadius.circular(4)),
                  ],
                );
              }).toList(),
            ),
          );
        }

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx >= 0 && idx < report.dataPoints.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          report.dataPoints[idx].label,
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.darkCard,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final isSales = spot.barIndex == 0;
                    return LineTooltipItem(
                      '${isSales ? "Sales" : "Purchases"}: ${CurrencyFormatter.format(spot.y)}',
                      TextStyle(color: isSales ? AppColors.primary : Colors.amber, fontWeight: FontWeight.w800, fontSize: 12),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: salesSpots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: purchaseSpots,
                isCurved: true,
                color: Colors.amber,
                barWidth: 3,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // 3. Category Sales Share Chart
  Widget _buildCategorySalesChart(WidgetRef ref) {
    final catAsync = ref.watch(categorySalesProvider);
    return catAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const _EmptyChart();
        final colors = [AppColors.primary, AppColors.success, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.blue];
        double total = categories.fold(0.0, (acc, c) => acc + ((c['total_sales'] as num?)?.toDouble() ?? 0.0));

        return Row(
          children: [
            Expanded(
              flex: 5,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: categories.asMap().entries.map((e) {
                    final color = colors[e.key % colors.length];
                    final amt = (e.value['total_sales'] as num?)?.toDouble() ?? 0.0;
                    final pct = total > 0 ? (amt / total) * 100 : 0.0;
                    return PieChartSectionData(
                      value: amt > 0 ? amt : 1,
                      color: color,
                      radius: 35,
                      title: '${pct.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: ListView(
                shrinkWrap: true,
                children: categories.asMap().entries.map((e) {
                  final color = colors[e.key % colors.length];
                  final amt = (e.value['total_sales'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.value['category_name'] as String? ?? 'Uncategorized',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(amt),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // 4. Customer Type Performance Chart
  Widget _buildCustomerTypeChart(WidgetRef ref) {
    final custAsync = ref.watch(customerTypeSalesProvider);
    return custAsync.when(
      data: (types) {
        if (types.isEmpty) return const _EmptyChart();
        final colors = [AppColors.primary, AppColors.success, Colors.amber, Colors.purple];

        return BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx >= 0 && idx < types.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          types[idx]['customer_type_name'] as String? ?? 'Tier',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            barGroups: types.asMap().entries.map((e) {
              final amt = (e.value['total_sales'] as num?)?.toDouble() ?? 0.0;
              final color = colors[e.key % colors.length];
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: amt,
                    color: color,
                    width: 28,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // 5. Product Movement (Fast Moving) Chart
  Widget _buildProductMovementChart(WidgetRef ref) {
    final movementAsync = ref.watch(productMovementAnalysisProvider);
    return movementAsync.when(
      data: (list) {
        if (list.isEmpty) return const _EmptyChart();
        final sortedBySold = [...list]..sort((a, b) => ((b['sold_qty'] as num?) ?? 0).compareTo((a['sold_qty'] as num?) ?? 0));
        final topItems = sortedBySold.take(5).toList();

        return BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx >= 0 && idx < topItems.length) {
                      final name = topItems[idx]['product_name'] as String? ?? '';
                      final shortName = name.length > 8 ? '${name.substring(0, 7)}…' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(shortName, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            barGroups: topItems.asMap().entries.map((e) {
              final qty = (e.value['sold_qty'] as num?)?.toDouble() ?? 0.0;
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: qty,
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.primary],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // 6. Supplier Purchases Chart
  Widget _buildSupplierPurchasesChart(WidgetRef ref) {
    final supAsync = ref.watch(supplierPurchaseSummaryProvider);
    return supAsync.when(
      data: (list) {
        if (list.isEmpty) return const _EmptyChart();
        final topSuppliers = list.take(5).toList();

        return BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx >= 0 && idx < topSuppliers.length) {
                      final name = topSuppliers[idx]['supplier_name'] as String? ?? 'Supplier';
                      final shortName = name.length > 9 ? '${name.substring(0, 8)}…' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(shortName, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            barGroups: topSuppliers.asMap().entries.map((e) {
              final total = (e.value['total_purchases'] as num?)?.toDouble() ?? 0.0;
              final paid = (e.value['total_paid'] as num?)?.toDouble() ?? 0.0;
              final due = (e.value['total_balance_due'] as num?)?.toDouble() ?? 0.0;
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(toY: total, color: Colors.amber, width: 10, borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: paid, color: AppColors.success, width: 10, borderRadius: BorderRadius.circular(4)),
                  if (due > 0)
                    BarChartRodData(toY: due, color: AppColors.error, width: 10, borderRadius: BorderRadius.circular(4)),
                ],
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // 7. Expenses Breakdown Chart
  Widget _buildExpensesChart(WidgetRef ref) {
    final txAsync = ref.watch(transactionsProvider);
    return txAsync.when(
      data: (list) {
        final expenses = list.where((t) => t.type == 'debit').toList();
        if (expenses.isEmpty) return const _EmptyChart();

        final Map<String, double> categoryMap = {};
        for (var e in expenses) {
          final cat = e.categoryName ?? 'Other Expense';
          categoryMap[cat] = (categoryMap[cat] ?? 0) + e.amount;
        }

        final colors = [AppColors.error, Colors.deepOrange, Colors.amber, Colors.purple, Colors.pink, Colors.blueGrey];
        final total = categoryMap.values.fold(0.0, (s, v) => s + v);

        int cIdx = 0;
        final sections = categoryMap.entries.map((e) {
          final color = colors[cIdx % colors.length];
          cIdx++;
          final pct = (e.value / total) * 100;
          return PieChartSectionData(
            value: e.value,
            color: color,
            title: pct > 8 ? '${pct.toStringAsFixed(0)}%' : '',
            radius: 46,
            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
          );
        }).toList();

        return Row(
          children: [
            Expanded(
              flex: 5,
              child: PieChart(
                PieChartData(sections: sections, centerSpaceRadius: 42, sectionsSpace: 3),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categoryMap.entries.take(5).map((e) {
                  final idx = categoryMap.keys.toList().indexOf(e.key);
                  final color = colors[idx % colors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                        Text('₹${CurrencyFormatter.format(e.value)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // 8. Profit & Loss Flow Chart
  Widget _buildPnlChart(WidgetRef ref) {
    final pnlAsync = ref.watch(profitLossProvider);
    return pnlAsync.when(
      data: (report) {
        return BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    switch (val.toInt()) {
                      case 0:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      case 1:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('COGS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      case 2:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Expenses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      case 3:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Net Profit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      default:
                        return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: report.totalRevenue, color: AppColors.primary, width: 28, borderRadius: BorderRadius.circular(8))]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: report.totalCost, color: Colors.orange, width: 28, borderRadius: BorderRadius.circular(8))]),
              BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: report.totalExpenses, color: AppColors.error, width: 28, borderRadius: BorderRadius.circular(8))]),
              BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: report.netProfit > 0 ? report.netProfit : 0, color: AppColors.success, width: 28, borderRadius: BorderRadius.circular(8))]),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // 9. Cash Flow Chart
  Widget _buildCashFlowChart(WidgetRef ref) {
    final pnlAsync = ref.watch(profitLossProvider);
    return pnlAsync.when(
      data: (report) {
        final outflow = report.totalCost + report.totalExpenses;
        return BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    switch (val.toInt()) {
                      case 0:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Inflow (Sales)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      case 1:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Outflow (Cost/Exp)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      default:
                        return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ),
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: report.totalRevenue, color: AppColors.success, width: 36, borderRadius: BorderRadius.circular(10))]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: outflow, color: AppColors.error, width: 36, borderRadius: BorderRadius.circular(10))]),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // 10. Balance Sheet Chart
  Widget _buildBalanceSheetChart(WidgetRef ref) {
    final summaryAsync = ref.watch(balanceSummaryProvider);
    return summaryAsync.when(
      data: (summary) {
        final assets = summary.cashInHand + summary.totalReceivable;
        final liabilities = summary.totalPayable;
        return BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    switch (val.toInt()) {
                      case 0:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Total Assets', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      case 1:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Total Liabilities', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      default:
                        return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ),
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: assets, color: AppColors.primary, width: 36, borderRadius: BorderRadius.circular(10))]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: liabilities, color: AppColors.error, width: 36, borderRadius: BorderRadius.circular(10))]),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }

  // 11. Tax & GST Chart
  Widget _buildTaxChart(WidgetRef ref) {
    final taxAsync = ref.watch(taxReportProvider);
    return taxAsync.when(
      data: (report) {
        return BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    switch (val.toInt()) {
                      case 0:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('GST Collected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      case 1:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('GST Paid (ITC)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      case 2:
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Net Payable', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
                      default:
                        return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ),
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: report.gstCollected, color: AppColors.success, width: 32, borderRadius: BorderRadius.circular(8))]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: report.gstPaid, color: Colors.orange, width: 32, borderRadius: BorderRadius.circular(8))]),
              BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: report.netGstPayable > 0 ? report.netGstPayable : 0, color: Colors.indigo, width: 32, borderRadius: BorderRadius.circular(8))]),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EmptyChart(),
    );
  }
}

class _ChartTypeBtn extends StatelessWidget {
  final IconData icon;
  final String type;
  final String current;
  final ValueChanged<String> onTap;

  const _ChartTypeBtn({required this.icon, required this.type, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = type == current;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: isSelected ? Colors.white : AppColors.textMuted, size: 18),
        onPressed: () => onTap(type),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
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
          Text('No data available to plot chart for this period', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Detailed Report List / Data Grid Section ──────────────────────────────────
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
            Text('Sales Key Indicators', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(label: 'Total Orders', value: '${report.transactionCount}', icon: Icons.receipt_rounded, color: Colors.blue),
                _StatCard(label: 'Net Revenue', value: CurrencyFormatter.format(report.netSales), icon: Icons.attach_money_rounded, color: Colors.green),
                _StatCard(label: 'Avg Order Value', value: CurrencyFormatter.format(report.averageOrderValue), icon: Icons.shopping_basket_rounded, color: Colors.teal),
                _StatCard(label: 'GST Collected', value: CurrencyFormatter.format(report.totalGst), icon: Icons.gavel_rounded, color: Colors.purple),
                _StatCard(label: 'Total Discounts', value: CurrencyFormatter.format(report.totalDiscount), icon: Icons.local_offer_rounded, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Transactions (${report.sales.length})', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            ...report.sales.map((s) => _ReportListTile(
              title: s.invoiceNo,
              subtitle: '${s.customerName ?? 'Walk-in'} • ${s.paymentMode.toUpperCase()} • ${DateFormatter.toDisplay(s.date)}',
              trailing: CurrencyFormatter.format(s.grandTotal),
              tag: s.paymentMode,
            )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else if (reportType == 'inventory_movement') {
      final movementAsync = ref.watch(productMovementAnalysisProvider);
      return movementAsync.when(
        data: (list) {
          final totalValuation = list.fold(0.0, (sum, i) => sum + ((i['inventory_value'] as num?)?.toDouble() ?? 0.0));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory Valuation & Movement', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(label: 'Total Valuation', value: CurrencyFormatter.format(totalValuation), icon: Icons.account_balance_wallet_rounded, color: AppColors.primary),
                  _StatCard(label: 'Tracked Items', value: '${list.length}', icon: Icons.inventory_rounded, color: Colors.indigo),
                ],
              ),
              const SizedBox(height: 24),
              Text('Product Velocity & Stock Movement', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...list.map((i) => _ReportListTile(
                title: i['name'] as String? ?? 'Product',
                subtitle: '${i['total_qty_sold'] ?? 0} sold in period • Current Stock: ${i['stock'] ?? 0}',
                trailing: CurrencyFormatter.format((i['total_revenue'] as num?)?.toDouble() ?? 0.0),
                tag: ((i['total_qty_sold'] as num?) ?? 0) > 10 ? 'High Velocity' : 'Standard',
              )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else if (reportType == 'category_sales') {
      final catAsync = ref.watch(categorySalesProvider);
      return catAsync.when(
        data: (categories) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Category Contribution', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            ...categories.map((c) => _ReportListTile(
              title: c['category_name'] as String? ?? 'Uncategorized',
              subtitle: '${c['order_count'] ?? 0} unique orders • ${c['total_quantity'] ?? 0} total items sold',
              trailing: CurrencyFormatter.format((c['total_sales'] as num?)?.toDouble() ?? 0.0),
            )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else if (reportType == 'customer_type_sales') {
      final custTypeAsync = ref.watch(customerTypeSalesProvider);
      return custTypeAsync.when(
        data: (types) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales Breakdown by Customer Tier', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            ...types.map((t) => _ReportListTile(
              title: t['customer_type_name'] as String? ?? 'Direct Retail',
              subtitle: '${t['transaction_count'] ?? 0} transactions • Discounts Granted: ${CurrencyFormatter.format((t['total_discount'] as num?)?.toDouble() ?? 0.0)}',
              trailing: CurrencyFormatter.format((t['total_sales'] as num?)?.toDouble() ?? 0.0),
            )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else if (reportType == 'supplier_purchases') {
      final supAsync = ref.watch(supplierPurchaseSummaryProvider);
      return supAsync.when(
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplier Purchases & Liabilities', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            ...list.map((s) => _ReportListTile(
              title: s['supplier_name'] as String? ?? 'Supplier',
              subtitle: '${s['purchase_count'] ?? 0} purchases • Paid: ${CurrencyFormatter.format((s['total_paid'] as num?)?.toDouble() ?? 0.0)} • Due: ${CurrencyFormatter.format((s['total_balance_due'] as num?)?.toDouble() ?? 0.0)}',
              trailing: CurrencyFormatter.format((s['total_purchases'] as num?)?.toDouble() ?? 0.0),
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
              Text('Expenses & Cost Outflows', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(label: 'Total Outflow', value: CurrencyFormatter.format(total), icon: Icons.trending_down_rounded, color: AppColors.error),
                  _StatCard(label: 'Expense Records', value: '${expenses.length}', icon: Icons.receipt_rounded, color: Colors.blueGrey),
                ],
              ),
              const SizedBox(height: 24),
              Text('Operational Expense Records', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...expenses.map((e) => _ReportListTile(
                title: e.description ?? 'Expense Record',
                subtitle: '${e.categoryName} • ${DateFormatter.toDisplay(e.date)}',
                trailing: CurrencyFormatter.format(e.amount),
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
            Text('Profit & Loss Breakdown', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _ReportDetailsRow(label: 'Operating Gross Revenue', value: CurrencyFormatter.format(report.totalRevenue)),
            _ReportDetailsRow(label: 'Cost of Goods Sold (COGS)', value: '- ${CurrencyFormatter.format(report.totalCost)}', color: AppColors.error),
            _ReportDetailsRow(label: 'Operating & Admin Expenses', value: '- ${CurrencyFormatter.format(report.totalExpenses)}', color: AppColors.error),
            const Divider(height: 32),
            _ReportDetailsRow(
              label: 'Net Profit', 
              value: CurrencyFormatter.format(report.netProfit), 
              isBold: true,
              color: report.netProfit >= 0 ? AppColors.success : AppColors.error,
            ),
            _ReportDetailsRow(label: 'Net Profit Margin', value: '${report.marginPercent.toStringAsFixed(2)}%', isBold: true),
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
            Text('Balance Sheet (Assets & Liabilities)', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            const Text('Current Assets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 8),
            _ReportDetailsRow(label: 'Cash & Account Wallets', value: CurrencyFormatter.format(summary.cashInHand)),
            _ReportDetailsRow(label: 'Total Receivables (Customers)', value: CurrencyFormatter.format(summary.totalReceivable)),
            const SizedBox(height: 16),
            const Text('Current Liabilities & Payables', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error)),
            const SizedBox(height: 8),
            _ReportDetailsRow(label: 'Total Payables (Suppliers)', value: CurrencyFormatter.format(summary.totalPayable), color: AppColors.error),
            const Divider(height: 32),
            _ReportDetailsRow(
              label: 'Net Working Capital (Net Assets)',
              value: CurrencyFormatter.format(summary.cashInHand + summary.totalReceivable - summary.totalPayable),
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
            Text('Taxation & GST Liability', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _ReportDetailsRow(label: 'Output Tax (GST Collected on Sales)', value: CurrencyFormatter.format(report.gstCollected), color: AppColors.success),
            _ReportDetailsRow(label: 'Input Tax Credit (GST Paid on Purchases)', value: CurrencyFormatter.format(report.gstPaid), color: AppColors.error),
            const Divider(height: 32),
            _ReportDetailsRow(
              label: 'Net GST Payable', 
              value: CurrencyFormatter.format(report.netGstPayable), 
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
            Text('Sales vs Purchases Comparative Summary', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(label: 'Total Sales', value: CurrencyFormatter.format(report.totalSales), icon: Icons.trending_up_rounded, color: AppColors.primary),
                _StatCard(label: 'Total Purchases', value: CurrencyFormatter.format(report.totalPurchases), icon: Icons.trending_down_rounded, color: Colors.amber),
                _StatCard(
                  label: 'Trade Surplus / Margin', 
                  value: CurrencyFormatter.format(report.totalSales - report.totalPurchases), 
                  icon: Icons.account_balance_wallet_rounded,
                  color: (report.totalSales - report.totalPurchases) >= 0 ? AppColors.success : AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _ReportDetailsRow(label: 'Sales Count', value: '${report.salesCount} invoices'),
            _ReportDetailsRow(label: 'Purchases Count', value: '${report.purchasesCount} bills'),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    } else {
      final pnlAsync = ref.watch(profitLossProvider);
      return pnlAsync.when(
        data: (report) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cash Flow Summary', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _ReportDetailsRow(label: 'Cash Inflow (Sales & Income)', value: CurrencyFormatter.format(report.totalRevenue), color: AppColors.success),
            _ReportDetailsRow(label: 'Cash Outflow (COGS & Expenses)', value: '- ${CurrencyFormatter.format(report.totalCost + report.totalExpenses)}', color: AppColors.error),
            const Divider(height: 32),
            _ReportDetailsRow(
              label: 'Net Operational Cash Flow', 
              value: CurrencyFormatter.format(report.totalRevenue - (report.totalCost + report.totalExpenses)), 
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

// ── Stat KPI Card ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  const _StatCard({required this.label, required this.value, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
        ],
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
            style: GoogleFonts.outfit(
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
  final String? tag;

  const _ReportListTile({required this.title, required this.subtitle, required this.trailing, this.tag});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    if (tag != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag!.toUpperCase(),
                          style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(trailing, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}

// ── Reports Header & Filter Selector ──────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reporting Timeline',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatter.toDisplay(filter.startDate)} – ${DateFormatter.toDisplay(filter.endDate)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: filter.type,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
                items: const [
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
                  DropdownMenuItem(value: 'thisWeek', child: Text('This Week')),
                  DropdownMenuItem(value: 'thisMonth', child: Text('This Month')),
                  DropdownMenuItem(value: 'lastMonth', child: Text('Last Month')),
                  DropdownMenuItem(value: 'thisQuarter', child: Text('This Quarter')),
                  DropdownMenuItem(value: 'thisYear', child: Text('This Year')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Range…')),
                ],
                onChanged: (val) async {
                  if (val == null) return;
                  if (val == 'today') {
                    onFilterChange(ReportFilter.today());
                  } else if (val == 'yesterday') {
                    onFilterChange(ReportFilter.yesterday());
                  } else if (val == 'thisWeek') {
                    onFilterChange(ReportFilter.thisWeek());
                  } else if (val == 'thisMonth') {
                    onFilterChange(ReportFilter.thisMonth());
                  } else if (val == 'lastMonth') {
                    onFilterChange(ReportFilter.lastMonth());
                  } else if (val == 'thisQuarter') {
                    onFilterChange(ReportFilter.thisQuarter());
                  } else if (val == 'thisYear') {
                    onFilterChange(ReportFilter.thisYear());
                  } else if (val == 'custom') {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: DateTimeRange(start: filter.startDate, end: filter.endDate),
                    );
                    if (picked != null) {
                      onFilterChange(ReportFilter.custom(picked.start, picked.end));
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
