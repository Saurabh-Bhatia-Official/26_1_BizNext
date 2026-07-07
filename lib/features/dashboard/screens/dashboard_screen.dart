import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../inventory/models/product_model.dart';
import '../../billing/providers/sales_stats_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final statsAsync = ref.watch(inventoryStatsProvider);
    final salesAsync = ref.watch(salesStatsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inventoryStatsProvider);
          ref.invalidate(salesStatsProvider);
          ref.invalidate(productsProvider);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Premium Banner with Gradient Decoration ──
            SliverToBoxAdapter(
              child: _DashboardBanner(isDark: isDark),
            ),

            // ── KPI Overview ──
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: _CombinedStatsRow(
                  statsAsync: statsAsync,
                  salesAsync: salesAsync,
                  isDark: isDark,
                ),
              ),
            ),

            // ── Main Content Grid ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              sliver: SliverToBoxAdapter(
                child: _DashboardMainContent(
                  isDark: isDark,
                  salesAsync: salesAsync,
                ),
              ),
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
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
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
            onTap: () => ref.read(selectedNavIndexProvider.notifier).state = 1, // POS Billing
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.inventory_2_rounded,
            label: 'Inventory',
            onTap: () => ref.read(selectedNavIndexProvider.notifier).state = 5, // Inventory
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

// ── Main Content Grid ────────────────────────────────────────────────────────
class _DashboardMainContent extends StatelessWidget {
  final bool isDark;
  final AsyncValue<SalesStats> salesAsync;

  const _DashboardMainContent({required this.isDark, required this.salesAsync});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1100) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _SalesChartPanel(isDark: isDark, salesAsync: salesAsync),
                    const SizedBox(height: 24),
                    _LowStockPanel(isDark: isDark),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: _RecentTransactionsPanel(isDark: isDark, salesAsync: salesAsync),
              ),
            ],
          );
        }
        return Column(
          children: [
            _SalesChartPanel(isDark: isDark, salesAsync: salesAsync),
            const SizedBox(height: 24),
            _RecentTransactionsPanel(isDark: isDark, salesAsync: salesAsync),
            const SizedBox(height: 24),
            _LowStockPanel(isDark: isDark),
          ],
        );
      },
    );
  }
}

// ── KPI Section ──────────────────────────────────────────────────────────────
class _CombinedStatsRow extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> statsAsync;
  final AsyncValue<SalesStats> salesAsync;
  final bool isDark;

  const _CombinedStatsRow({required this.statsAsync, required this.salesAsync, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return salesAsync.when(
      data: (sales) => statsAsync.when(
        data: (stats) => _KpiGrid(stats: stats, sales: sales, isDark: isDark),
        loading: () => const _KpiRowSkeleton(),
        error: (e, _) => _ErrorCard(message: 'Stats Error: $e'),
      ),
      loading: () => const _KpiRowSkeleton(),
      error: (e, _) => _ErrorCard(message: 'Sales Error: $e'),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  final SalesStats sales;
  final bool isDark;

  const _KpiGrid({required this.stats, required this.sales, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final kpis = [
      _KpiData(
        title: "Today's Sales",
        value: CurrencyFormatter.format(sales.todaySales),
        subtitle: 'From ${sales.todayTransactions} deals', 
        icon: Icons.payments_rounded,
        color: AppColors.primary,
      ),
      _KpiData(
        title: 'Weekly Volume',
        value: CurrencyFormatter.compact(sales.weekSales),
        subtitle: 'Last 7 days revenue',
        icon: Icons.auto_graph_rounded,
        color: AppColors.accent,
      ),
      _KpiData(
        title: 'Inventory Value',
        value: CurrencyFormatter.compact((stats['inventory_value'] as num?)?.toDouble() ?? 0),
        subtitle: 'Total stock asset',
        icon: Icons.inventory_2_rounded,
        color: AppColors.success,
      ),
      _KpiData(
        title: 'Stock Alerts',
        value: '${stats['low_stock_count'] ?? 0}',
        subtitle: 'Items low or out',
        icon: Icons.notification_important_rounded,
        color: AppColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 650 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            mainAxisExtent: 110,
          ),
          itemCount: kpis.length,
          itemBuilder: (ctx, i) => _ModernKpiCard(kpi: kpis[i], isDark: isDark)
              .animate(delay: (i * 100).ms)
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 400.ms, curve: Curves.easeOutBack)
              .fadeIn(),
        );
      },
    );
  }
}

class _ModernKpiCard extends StatelessWidget {
  final _KpiData kpi;
  final bool isDark;
  const _ModernKpiCard({required this.kpi, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kpi.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(kpi.icon, color: kpi.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  kpi.title,
                  style: const TextStyle(
                    fontSize: 11, 
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
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                ),
                Text(
                  kpi.subtitle,
                  style: TextStyle(
                    fontSize: 10,
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

// ── Sales Chart ──────────────────────────────────────────────────────────────
class _SalesChartPanel extends StatelessWidget {
  final bool isDark;
  final AsyncValue<SalesStats> salesAsync;

  const _SalesChartPanel({required this.isDark, required this.salesAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Revenue Insight', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(
                    'Last 7 days performance', 
                    style: TextStyle(
                      fontSize: 12, 
                      color: AppColors.textMuted, 
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              _ChartToggle(),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 260,
            child: salesAsync.when(
              data: (sales) {
                if (sales.last7DaysSales.every((e) => e == 0)) {
                  return const _EmptyChartState();
                }
                
                final spots = List.generate(7, (i) => FlSpot(i.toDouble(), sales.last7DaysSales[i]));
                final maxVal = sales.last7DaysSales.reduce((a, b) => a > b ? a : b);
                final maxY = maxVal == 0 ? 1000.0 : maxVal * 1.2;
                
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
                            final dayName = days[date.weekday - 1];
                            return Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: Text(
                                dayName, 
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
                        barWidth: 6,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: AppColors.primary,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.25), 
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
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Analytics Error: $e')),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textMuted,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Recent Transactions ──────────────────────────────────────────────────────
class _RecentTransactionsPanel extends ConsumerWidget {
  final bool isDark;
  final AsyncValue<SalesStats> salesAsync;

  const _RecentTransactionsPanel({required this.isDark, required this.salesAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Sales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Icon(Icons.history_rounded, color: AppColors.textMuted.withValues(alpha: 0.5), size: 20),
            ],
          ),
          const SizedBox(height: 24),
          salesAsync.when(
            data: (sales) {
              if (sales.recentSales.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 16),
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
            error: (e, _) => Text('Error loading history: $e'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 2, // Sales History
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
    final amount = (sale['grand_total'] as num).toDouble();
    
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : AppColors.lightBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale['customer_name'] ?? 'Walk-in Customer',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
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
                  fontSize: 15,
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
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
              const Text('Inventory Critical', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 5, // Inventory
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Manage Stock', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          productsAsync.when(
            data: (products) {
              final lowStock = products.where((p) => p.isLowStock).take(4).toList();
              if (lowStock.isEmpty) return _EmptyAlerts();
              return Column(
                children: lowStock.map((p) => _AlertItem(product: p, isDark: isDark)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(isOut ? Icons.dangerous_rounded : Icons.warning_rounded, color: color, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(
                  isOut ? 'Out of stock' : 'Low stock warning',
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${product.stock} ${product.unit}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
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
        final crossCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 650 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 110,
          ),
          itemCount: 4,
          itemBuilder: (_, _) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightBorder.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
        );
      },
    );
  }
}

class _EmptyChartState extends StatelessWidget {
  const _EmptyChartState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stacked_line_chart_rounded, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Not enough data for chart', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
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
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('All Stock Levels Healthy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('No immediate action required', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
