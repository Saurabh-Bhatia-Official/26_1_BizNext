// lib/features/billing/screens/sales_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/sales_stats_provider.dart';
import '../utils/invoice_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../accounts/providers/accounts_provider.dart';
import 'pos_billing_screen.dart';
import 'sale_detail_screen.dart';
import '../../../core/widgets/searchable_dropdown.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final salesAsync = ref.watch(saleHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _SalesHeader(isDark: isDark),
          _SalesSummaryBar(isDark: isDark),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ref.invalidate(saleHistoryProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Expanded(
            child: salesAsync.when(
              data: (list) => list.isEmpty 
                ? _EmptySales(isDark: isDark)
                : _SalesList(sales: list, isDark: isDark),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesHeader extends StatelessWidget {
  final bool isDark;
  const _SalesHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales History',
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.w900, 
                    color: isDark ? Colors.white : AppColors.textLight,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 8),
                    const Text('Real-time transaction tracking', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesSummaryBar extends ConsumerWidget {
  final bool isDark;
  const _SalesSummaryBar({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(salesStatsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: statsAsync.when(
        data: (stats) {
          final isMobile = MediaQuery.of(context).size.width < 600;
          final cards = [
            _SummaryCard(
              label: 'Today\'s Sales',
              value: stats.todaySales,
              icon: Icons.auto_graph_rounded,
              colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              isDark: isDark,
            ),
            if (isMobile) const SizedBox(height: 16) else const SizedBox(width: 16),
            _SummaryCard(
              label: 'This Month',
              value: stats.monthSales,
              icon: Icons.calendar_today_rounded,
              colors: [const Color(0xFF10B981), const Color(0xFF059669)],
              isDark: isDark,
            ),
          ];

          return isMobile 
            ? Column(children: cards) 
            : Row(children: cards.map((c) => c is _SummaryCard ? Expanded(child: c) : c).toList());
        },
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final List<Color> colors;
  final bool isDark;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: colors[0].withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(icon, color: Colors.white.withValues(alpha: 0.15), size: 100),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 20),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(value),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                  ),
                ),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }
}

class _SalesList extends ConsumerWidget {
  final List<Map<String, dynamic>> sales;
  final bool isDark;
  const _SalesList({required this.sales, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: sales.length,
      itemBuilder: (ctx, i) {
        final s = sales[i];
        final isCredit = s['payment_mode'] == AppConstants.paymentCredit;
        final isPendingCredit = isCredit && ((s['balance_due'] as num?) ?? 0) > 0;
        final statusColor = isPendingCredit ? AppColors.warning : AppColors.success;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: s['id']))),
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
                        isPendingCredit ? Icons.timer_outlined : Icons.check_circle_outline_rounded,
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
                              Text(s['invoice_no'] ?? 'INV-000', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s['payment_mode']?.toString().toUpperCase() ?? 'CASH',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textMuted),
                                ),
                              ),
                              if (s['discount'] != null && ((s['discount'] as num?) ?? 0) > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'OFFERS APPLIED',
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.success),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s['customer_name'] ?? 'Walk-in Customer',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format((s['grand_total'] as num?)?.toDouble() ?? 0.0),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
                        ),
                        Text(
                          s['date'] != null ? DateFormatter.toDisplay(DateTime.tryParse(s['date']) ?? DateTime.now()) : '',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (val) {
                        if (val == 'print') _printInvoice(context, ref, s['id']);
                        if (val == 'pay') _showPaymentDialog(context, ref, s);
                        if (val == 'duplicate') _duplicateInvoice(context, ref, s['id']);
                        if (val == 'edit') _editInvoice(context, ref, s['id']);
                        if (val == 'delete') _confirmDelete(context, ref, s['id'], s['invoice_no']);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print_rounded, size: 18), SizedBox(width: 12), Text('Print Invoice')])),
                        if (isCredit && ((s['balance_due'] as num?) ?? 0) > 0)
                          const PopupMenuItem(value: 'pay', child: Row(children: [Icon(Icons.payments_outlined, size: 18, color: AppColors.success), SizedBox(width: 12), Text('Collect Payment', style: TextStyle(color: AppColors.success))])),
                        const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 18, color: AppColors.accent), SizedBox(width: 12), Text('Duplicate to POS', style: TextStyle(color: AppColors.accent))])),
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: AppColors.primary), SizedBox(width: 12), Text('Edit Invoice', style: TextStyle(color: AppColors.primary))])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 12), Text('Void Sale', style: TextStyle(color: AppColors.error))])),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }

  void _printInvoice(BuildContext context, WidgetRef ref, int saleId) async {
    try {
      final business = ref.read(currentBusinessProvider);
      if (business == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Preparing Invoice...', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
              ],
            ),
          ),
        ),
      );

      final sale = await ref.read(saleDetailProvider(saleId).future);
      if (context.mounted) Navigator.pop(context);

      if (sale != null) {
        await InvoiceService.generateAndPrintInvoice(business: business, sale: sale);
      } else {
        AppAlert.error(ref, 'Could not load sale details');
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      AppAlert.error(ref, 'Error generating invoice: $e');
    }
  }

  void _duplicateInvoice(BuildContext context, WidgetRef ref, int saleId) async {
    final sale = await ref.read(saleDetailProvider(saleId).future);
    if (sale != null && context.mounted) {
      ref.read(billingProvider.notifier).duplicateSale(sale);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PosBillingScreen()));
    }
  }

  void _editInvoice(BuildContext context, WidgetRef ref, int saleId) async {
    final sale = await ref.read(saleDetailProvider(saleId).future);
    if (sale != null && context.mounted) {
      ref.read(billingProvider.notifier).loadSale(sale);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PosBillingScreen()));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String invoiceNo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Void Transaction?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to void invoice $invoiceNo? This will restore inventory stock levels.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(billingRepositoryProvider).voidSale(id);
              ref.invalidate(saleHistoryProvider);
              ref.invalidate(salesStatsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              AppAlert.success(ref, 'Invoice $invoiceNo voided successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Void Sale'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> sale) {
    final balance = (sale['balance_due'] as num?)?.toDouble() ?? 0.0;
    final amountCtrl = TextEditingController(text: balance.toString());
    String mode = 'Cash';
    int? selectedAccountId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Collect Payment', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Outstanding: ${CurrencyFormatter.format(balance)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount to Collect', prefixText: '₹ '),
              ),
              const SizedBox(height: 16),
              AppSearchableDropdown<String>(
                value: mode,
                labelText: 'Payment Mode',
                isDark: Theme.of(context).brightness == Brightness.dark,
                items: AppConstants.paymentModes.where((m) => m != 'Credit').map((m) => SearchableDropdownItem(value: m, label: m)).toList(),
                onChanged: (v) => setState(() => mode = v ?? 'Cash'),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final accountsAsync = ref.watch(accountsProvider);
                  return accountsAsync.when(
                    data: (accounts) {
                      if (selectedAccountId == null && accounts.isNotEmpty) {
                        final def = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
                        selectedAccountId = def.id;
                      }
                      return AppSearchableDropdown<int?>(
                        value: selectedAccountId,
                        labelText: 'Deposit To Account',
                        isDark: Theme.of(context).brightness == Brightness.dark,
                        items: accounts.map((a) => SearchableDropdownItem(value: a.id, label: a.name)).toList(),
                        onChanged: (v) => setState(() => selectedAccountId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox(),
                  );
                }
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (amt <= 0 || amt > balance) {
                  AppAlert.error(ref, 'Invalid amount');
                  return;
                }
                if (selectedAccountId == null) {
                  AppAlert.error(ref, 'Please select an account');
                  return;
                }
                await ref.read(billingRepositoryProvider).addSalePayment(sale['id'], amt, mode, accountId: selectedAccountId);
                ref.invalidate(saleHistoryProvider);
                ref.invalidate(salesStatsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                AppAlert.success(ref, 'Payment collected successfully');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              child: const Text('Confirm Collection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySales extends StatelessWidget {
  final bool isDark;
  const _EmptySales({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(Icons.history_rounded, size: 80, color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          const Text('No Sales Found', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text('Transactions you make will appear here.', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
