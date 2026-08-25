import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../accounts/models/account_summary_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../inventory/models/product_model.dart';
import '../../billing/providers/sales_stats_provider.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../../reports/providers/reports_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesStatsProvider);
          ref.invalidate(inventoryStatsProvider);
          ref.invalidate(productsProvider);
          ref.invalidate(purchaseStatsProvider);
          ref.invalidate(balanceSummaryProvider);
          ref.invalidate(salesReportProvider);
          ref.invalidate(profitLossProvider);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _DashboardBanner(isDark: isDark)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(child: _KpiSection(isDark: isDark)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              sliver: SliverToBoxAdapter(child: _DashboardMainContent(isDark: isDark)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner ──────────────────────────────────────────────────────────────────
class _DashboardBanner extends ConsumerWidget {
  final bool isDark;
  const _DashboardBanner({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final business = ref.watch(currentBusinessProvider);
    final firstName = user?.fullName.split(' ').first ?? 'Admin';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.primary, AppColors.primaryDark]
              : [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -30,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'OVERVIEW',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormatter.today(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Hello, $firstName 👋',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${business?.name ?? 'Your Business'} is performing well today.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              _QuickActionMenu(isDark: isDark),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
}

class _QuickActionMenu extends ConsumerWidget {
  final bool isDark;
  const _QuickActionMenu({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.add_shopping_cart_rounded,
            label: 'New Sale',
            onTap: () => ref.read(selectedNavIndexProvider.notifier).state = 1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.inventory_2_rounded,
            label: 'Inventory',
            onTap: () => ref.read(selectedNavIndexProvider.notifier).state = 5,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── KPI Section ─────────────────────────────────────────────────────────────
class _KpiSection extends ConsumerWidget {
  final bool isDark;
  const _KpiSection({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesStatsProvider);
    final statsAsync = ref.watch(inventoryStatsProvider);
    final purchaseAsync = ref.watch(purchaseStatsProvider);
    final balanceAsync = ref.watch(balanceSummaryProvider);

    if (salesAsync.hasError) return _ErrorCard(message: 'Sales: ${salesAsync.error}');
    if (statsAsync.hasError) return _ErrorCard(message: 'Inventory: ${statsAsync.error}');
    if (purchaseAsync.hasError) return _ErrorCard(message: 'Purchases: ${purchaseAsync.error}');
    if (balanceAsync.hasError) return _ErrorCard(message: 'Accounts: ${balanceAsync.error}');

    if (!salesAsync.hasValue || !statsAsync.hasValue || !purchaseAsync.hasValue || !balanceAsync.hasValue) {
      return const _KpiRowSkeleton();
    }

    return _KpiGrid(
      sales: salesAsync.value!,
      stats: statsAsync.value!,
      purchaseStats: purchaseAsync.value!,
      balance: balanceAsync.value!,
      isDark: isDark,
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final SalesStats sales;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> purchaseStats;
  final AccountSummaryModel balance;
  final bool isDark;

  const _KpiGrid({
    required this.sales,
    required this.stats,
    required this.purchaseStats,
    required this.balance,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final kpis = [
      _KpiData(
        title: "Today's Sales",
        value: CurrencyFormatter.format(sales.todaySales),
        subtitle: '${sales.todayTransactions} transactions',
        icon: Icons.payments_rounded,
        color: AppColors.success,
      ),
      _KpiData(
        title: 'Monthly Sales',
        value: CurrencyFormatter.format(sales.monthSales),
        subtitle: 'Current month revenue',
        icon: Icons.calendar_month_rounded,
        color: AppColors.primary,
      ),
      _KpiData(
        title: 'Total Purchases',
        value: CurrencyFormatter.format((purchaseStats['total_purchases'] as num?)?.toDouble() ?? 0),
        subtitle: '${purchaseStats['count'] ?? 0} orders placed',
        icon: Icons.shopping_cart_rounded,
        color: AppColors.accent,
      ),
      _KpiData(
        title: 'Inventory Value',
        value: CurrencyFormatter.format((stats['inventory_value'] as num?)?.toDouble() ?? 0),
        subtitle: 'Total stock asset',
        icon: Icons.inventory_2_rounded,
        color: AppColors.info,
      ),
      _KpiData(
        title: 'Stock Alerts',
        value: '${stats['low_stock_count'] ?? 0}',
        subtitle: 'Items low or out of stock',
        icon: Icons.warning_rounded,
        color: AppColors.warning,
      ),
      _KpiData(
        title: 'Cash in Hand',
        value: CurrencyFormatter.format(balance.cashInHand),
        subtitle: 'Total account balance',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200 ? 3 : (constraints.maxWidth > 650 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            mainAxisExtent: 100,
          ),
          itemCount: kpis.length,
          itemBuilder: (ctx, i) => _KpiCard(kpi: kpis[i], isDark: isDark)
              .animate(delay: (i * 80).ms)
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 400.ms, curve: Curves.easeOutBack)
              .fadeIn(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final _KpiData kpi;
  final bool isDark;
  const _KpiCard({required this.kpi, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kpi.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(kpi.icon, color: kpi.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  kpi.title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    kpi.value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                ),
                Text(
                  kpi.subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: kpi.color.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Main Content Grid ────────────────────────────────────────────────────────
class _DashboardMainContent extends StatelessWidget {
  final bool isDark;
  const _DashboardMainContent({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1100) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _SalesChartPanel(isDark: isDark)),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: _PaymentDonutPanel(isDark: isDark)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _RecentTransactionsPanel(isDark: isDark),
                    const SizedBox(height: 24),
                    _ProfitSummaryPanel(isDark: isDark),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _LowStockPanel(isDark: isDark)),
            ],
          );
        }
        return Column(
          children: [
            _SalesChartPanel(isDark: isDark),
            const SizedBox(height: 24),
            _PaymentDonutPanel(isDark: isDark),
            const SizedBox(height: 24),
            _RecentTransactionsPanel(isDark: isDark),
            const SizedBox(height: 24),
            _LowStockPanel(isDark: isDark),
            const SizedBox(height: 24),
            _ProfitSummaryPanel(isDark: isDark),
          ],
        );
      },
    );
  }
}

// ── Sales Chart ──────────────────────────────────────────────────────────────
class _SalesChartPanel extends ConsumerWidget {
  final bool isDark;
  const _SalesChartPanel({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesStatsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.2),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revenue Insight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      'Last 7 days performance',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ChartToggle(),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: salesAsync.when(
              data: (sales) {
                if (sales.last7DaysSales.every((e) => e == 0)) {
                  return _EmptyChartState(
                    icon: Icons.stacked_line_chart_rounded,
                    message: 'Not enough data for chart',
                  );
                }
                return _buildLineChart(sales.last7DaysSales, isDark);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Analytics Error: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<double> data, bool isDark) {
    final spots = List.generate(7, (i) => FlSpot(i.toDouble(), data[i]));
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 1000.0 : maxVal * 1.25;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final now = DateTime.now();
                final date = now.subtract(Duration(days: 6 - val.toInt()));
                final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    days[date.weekday - 1],
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => isDark ? AppColors.darkSurface : Colors.white,
            tooltipRoundedRadius: 12,
            tooltipBorder: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              CurrencyFormatter.format(s.y),
              TextStyle(color: isDark ? Colors.white : AppColors.textLight, fontWeight: FontWeight.w900, fontSize: 12),
            )).toList(),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.4,
            color: AppColors.primary,
            barWidth: 5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3.5,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: AppColors.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleItem(label: 'Daily', isActive: true),
          _ToggleItem(label: 'Weekly', isActive: false),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final bool isActive;
  const _ToggleItem({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textMuted,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ── Payment Donut Chart ──────────────────────────────────────────────────────
class _PaymentDonutPanel extends ConsumerWidget {
  final bool isDark;
  const _PaymentDonutPanel({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(salesReportProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.2),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Modes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      'This month distribution',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.pie_chart_rounded, size: 20, color: AppColors.textMuted.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: reportAsync.when(
              data: (report) {
                if (report.paymentModeBreakdown.isEmpty) {
                  return _EmptyChartState(
                    icon: Icons.pie_chart_rounded,
                    message: 'No payment data this month',
                  );
                }
                return _DonutChart(data: report.paymentModeBreakdown, isDark: isDark);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  final Map<String, double> data;
  final bool isDark;
  const _DonutChart({required this.data, required this.isDark});

  static const _modeColors = {
    'Cash': AppColors.success,
    'Card': AppColors.info,
    'UPI': AppColors.primary,
    'Credit': AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0.0, (a, b) => a + b);
    if (total == 0) {
      return _EmptyChartState(
        icon: Icons.pie_chart_rounded,
        message: 'No payment data',
      );
    }

    final sections = data.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      return PieChartSectionData(
        value: entry.value,
        color: _modeColors[entry.key] ?? AppColors.textMuted,
        radius: 45,
        title: '${percentage.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      );
    }).toList();

    final legend = data.entries.map((entry) {
      final color = _modeColors[entry.key] ?? AppColors.textMuted;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              CurrencyFormatter.format(entry.value),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textLight,
              ),
            ),
          ],
        ),
      );
    }).toList();

    return Row(
      children: [
        Flexible(
          flex: 2,
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 2,
                startDegreeOffset: -90,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: legend,
          ),
        ),
      ],
    );
  }
}

// ── Recent Transactions ──────────────────────────────────────────────────────
class _RecentTransactionsPanel extends ConsumerWidget {
  final bool isDark;
  const _RecentTransactionsPanel({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesStatsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.2),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      'Latest transactions',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.history_rounded, color: AppColors.textMuted.withValues(alpha: 0.5), size: 20),
            ],
          ),
          const SizedBox(height: 20),
          salesAsync.when(
            data: (sales) {
              if (sales.recentSales.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No transactions yet', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: sales.recentSales.asMap().entries.map((entry) {
                  return _TransactionItem(
                    sale: entry.value,
                    isDark: isDark,
                    isLast: entry.key == sales.recentSales.length - 1,
                  ).animate(delay: (entry.key * 50).ms).fadeIn().slideX(begin: 0.1, end: 0);
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.error)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 2,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBg,
                foregroundColor: AppColors.primary,
                elevation: 0,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Text('View All Transactions', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Map<String, dynamic> sale;
  final bool isDark;
  final bool isLast;
  const _TransactionItem({required this.sale, required this.isDark, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final amount = (sale['grand_total'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : AppColors.lightBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale['customer_name'] ?? 'Walk-in Customer',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${sale['invoice_no'] ?? 'INV-000'} • ${DateFormatter.formatRelative(sale['date'])}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PAID',
                  style: TextStyle(color: AppColors.success, fontSize: 8, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Inventory Alerts ─────────────────────────────────────────────────────────
class _LowStockPanel extends ConsumerWidget {
  final bool isDark;
  const _LowStockPanel({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.2),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inventory Critical', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text(
                      'Low stock & out of stock',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 5,
                icon: const Icon(Icons.arrow_forward_rounded),
                color: AppColors.primary,
                tooltip: 'Manage Inventory',
              ),
            ],
          ),
          const SizedBox(height: 20),
          productsAsync.when(
            data: (products) {
              final lowStock = products.where((p) => p.isLowStock).take(4).toList();
              if (lowStock.isEmpty) return _EmptyAlerts();
              return Column(
                children: lowStock.map((p) => _AlertItem(product: p, isDark: isDark)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final Product product;
  final bool isDark;
  const _AlertItem({required this.product, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isOut = product.isOutOfStock;
    final color = isOut ? AppColors.error : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(isOut ? Icons.dangerous_rounded : Icons.warning_rounded, color: color, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  isOut ? 'Out of stock' : 'Low stock',
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${product.stock} ${product.unit}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profit Summary ───────────────────────────────────────────────────────────
class _ProfitSummaryPanel extends ConsumerWidget {
  final bool isDark;
  const _ProfitSummaryPanel({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profitAsync = ref.watch(profitLossProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.2),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: profitAsync.when(
        data: (report) {
          final maxVal = [report.totalRevenue, report.totalCost, report.totalExpenses, report.netProfit]
              .fold(0.0, (a, b) => a > b ? a : b);
          final scale = maxVal > 0 ? 1.0 / maxVal : 1.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Financial Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          'This month performance',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: report.netProfit >= 0
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          report.netProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          size: 16,
                          color: report.netProfit >= 0 ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${report.margin.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: report.netProfit >= 0 ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProfitBar(
                label: 'Revenue',
                value: report.totalRevenue,
                fraction: report.totalRevenue * scale,
                color: AppColors.success,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _ProfitBar(
                label: 'COGS',
                value: report.totalCost,
                fraction: report.totalCost * scale,
                color: AppColors.warning,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _ProfitBar(
                label: 'Expenses',
                value: report.totalExpenses,
                fraction: report.totalExpenses * scale,
                color: AppColors.error,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _ProfitBar(
                label: 'Net Profit',
                value: report.netProfit,
                fraction: report.netProfit > 0 ? report.netProfit * scale : 0,
                color: AppColors.info,
                isDark: isDark,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}

class _ProfitBar extends StatelessWidget {
  final String label;
  final double value;
  final double fraction;
  final Color color;
  final bool isDark;

  const _ProfitBar({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            CurrencyFormatter.format(value),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textLight,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
class _KpiData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  _KpiData({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});
}

class _KpiRowSkeleton extends StatelessWidget {
  const _KpiRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200 ? 3 : (constraints.maxWidth > 650 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 100,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightBorder.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
        );
      },
    );
  }
}

class _EmptyChartState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyChartState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12))),
        ],
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 14),
            const Text('All Stock Levels Healthy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('No immediate action required', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
