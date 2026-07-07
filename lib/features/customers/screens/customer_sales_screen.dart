// lib/features/customers/screens/customer_sales_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../billing/providers/sales_stats_provider.dart';
import '../../billing/screens/sale_detail_screen.dart';
import '../models/customer_model.dart';
import '../../../core/constants/app_constants.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CustomerSalesScreen extends ConsumerWidget {
  final CustomerModel customer;
  const CustomerSalesScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final salesAsync = ref.watch(customerSaleHistoryProvider(customer.id!));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sale History', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(customer.name, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _CustomerSummaryHeader(customer: customer, isDark: isDark),
          Expanded(
            child: salesAsync.when(
              data: (list) => list.isEmpty
                  ? _EmptyCustomerSales(isDark: isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final s = list[index];
                        return _SaleItemCard(sale: s, isDark: isDark);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSummaryHeader extends StatelessWidget {
  final CustomerModel customer;
  final bool isDark;
  const _CustomerSummaryHeader({required this.customer, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [AppColors.darkCard, AppColors.darkCard.withValues(alpha: 0.8)]
            : [AppColors.primary.withValues(alpha: 0.05), AppColors.primary.withValues(alpha: 0.02)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              customer.name[0].toUpperCase(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  customer.phone ?? 'No phone number',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Outstanding Balance', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              Text(
                CurrencyFormatter.format(customer.balance),
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.w900, 
                  color: customer.balance > 0 ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SaleItemCard extends StatelessWidget {
  final Map<String, dynamic> sale;
  final bool isDark;
  const _SaleItemCard({required this.sale, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isCredit = sale['payment_mode'] == AppConstants.paymentCredit;
    final statusColor = isCredit ? AppColors.warning : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: sale['id']))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isCredit ? Icons.timer_outlined : Icons.check_circle_outline_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(sale['invoice_no'] ?? 'INV-000', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sale['payment_mode']?.toString().toUpperCase() ?? 'CASH',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatter.toDisplay(DateTime.parse(sale['date'])),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format((sale['grand_total'] as num).toDouble()),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
                    ),
                    if (isCredit)
                       Text(
                        'Due: ${CurrencyFormatter.format((sale['balance_due'] as num).toDouble())}',
                        style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }
}

class _EmptyCustomerSales extends StatelessWidget {
  final bool isDark;
  const _EmptyCustomerSales({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 80, color: AppColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          const Text('No Sales Record', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const Text('This customer has no purchase history yet.', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
