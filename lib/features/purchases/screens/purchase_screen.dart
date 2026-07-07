// lib/features/purchases/screens/purchase_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/layout_toggle.dart';
import '../models/purchase_model.dart';
import '../providers/purchase_provider.dart';
import 'purchase_detail_screen.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../../core/widgets/searchable_dropdown.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  LayoutMode _layoutMode = LayoutMode.table;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _PurchaseHeader(isDark: isDark, layoutMode: _layoutMode, onLayoutChanged: (m) => setState(() => _layoutMode = m)),
          _PurchaseSummaryBar(isDark: isDark),
          Expanded(child: _PurchaseHistoryList(isDark: isDark, layoutMode: _layoutMode)),
        ],
      ),
    );
  }
}

class _PurchaseHeader extends StatelessWidget {
  final bool isDark;
  final LayoutMode layoutMode;
  final ValueChanged<LayoutMode> onLayoutChanged;
  const _PurchaseHeader({required this.isDark, required this.layoutMode, required this.onLayoutChanged});

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
                  'Purchases',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.textLight),
                ),
                const Text('Track stock-in and supplier payments', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              ],
            ),
          ),
          LayoutToggle(current: layoutMode, onChanged: onLayoutChanged, isDark: isDark),
        ],
      ),
    );
  }
}

// C5 FIX: Real data from DB
class _PurchaseSummaryBar extends ConsumerWidget {
  final bool isDark;
  const _PurchaseSummaryBar({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(purchaseStatsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: statsAsync.when(
        data: (stats) => Row(
          children: [
            _SummaryItem(
              label: 'Total Purchases',
              value: (stats['total_purchases'] as num?)?.toDouble() ?? 0,
              icon: Icons.shopping_bag_rounded,
              color: AppColors.primary,
              isDark: isDark,
            ),
            const SizedBox(width: 16),
            _SummaryItem(
              label: 'Amt Payable',
              value: (stats['total_payable'] as num?)?.toDouble() ?? 0,
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.error,
              isDark: isDark,
            ),
          ],
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _SummaryItem({required this.label, required this.value, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CurrencyFormatter.format(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// C5 FIX: Shows real purchase history from DB
class _PurchaseHistoryList extends ConsumerWidget {
  final bool isDark;
  final LayoutMode layoutMode;
  const _PurchaseHistoryList({required this.isDark, required this.layoutMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesProvider);

    return purchasesAsync.when(
      data: (purchases) {
        if (purchases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                const Text('No Purchases Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Text('Your purchase history will appear here.', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          );
        }
        if (layoutMode == LayoutMode.grid) {
          return _PurchaseGrid(purchases: purchases, isDark: isDark, ref: ref);
        }
        return _PurchaseListView(purchases: purchases, isDark: isDark, ref: ref);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── List / Table View (original) ───────────────────────────────────────────────
class _PurchaseListView extends StatelessWidget {
  final List<PurchaseModel> purchases;
  final bool isDark;
  final WidgetRef ref;
  const _PurchaseListView({required this.purchases, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: purchases.length,
      itemBuilder: (ctx, i) {
        final p = purchases[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PurchaseDetailScreen(purchase: p))),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.billNo ?? 'Purchase #${p.id}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(p.supplierName ?? 'Unknown Supplier', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyFormatter.format(p.grandTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    if (p.balanceDue > 0)
                      Text('Pending: ${CurrencyFormatter.format(p.balanceDue)}', style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
                    Text(DateFormatter.toDisplay(p.date), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(width: 12),
                if (p.balanceDue > 0) ...[
                  IconButton(
                    icon: const Icon(Icons.payments_outlined, color: AppColors.success, size: 22),
                    tooltip: 'Pay Pending',
                    onPressed: () => _showPaymentDialog(context, ref, p),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  onPressed: () => _confirmDeletePurchase(context, ref, p.id!, p.billNo ?? '#${p.id}'),
                ),
              ],
            ),
          ),
        ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.05, end: 0);
      },
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, PurchaseModel purchase) {
    _showPurchasePaymentDialog(context, ref, purchase);
  }

  void _confirmDeletePurchase(BuildContext context, WidgetRef ref, int id, String billNo) {
    _confirmPurchaseDelete(context, ref, id, billNo);
  }
}

// ── Grid / Card View ───────────────────────────────────────────────────────────
class _PurchaseGrid extends StatelessWidget {
  final List<PurchaseModel> purchases;
  final bool isDark;
  final WidgetRef ref;
  const _PurchaseGrid({required this.purchases, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1));
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.6,
          ),
          itemCount: purchases.length,
          itemBuilder: (_, i) {
            final p = purchases[i];
            return _PurchaseCard(purchase: p, isDark: isDark, ref: ref)
                .animate(delay: (i * 40).ms).fadeIn().slideY(begin: 0.05, end: 0);
          },
        );
      },
    );
  }
}

class _PurchaseCard extends StatefulWidget {
  final PurchaseModel purchase;
  final bool isDark;
  final WidgetRef ref;
  const _PurchaseCard({required this.purchase, required this.isDark, required this.ref});

  @override
  State<_PurchaseCard> createState() => _PurchaseCardState();
}

class _PurchaseCardState extends State<_PurchaseCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final hasPending = p.balanceDue > 0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseDetailScreen(purchase: p))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? AppColors.primary : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.5,
            ),
            boxShadow: _hovered ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 18),
                  ),
                  const Spacer(),
                  if (hasPending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Pending', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                p.billNo ?? 'Purchase #${p.id}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                p.supplierName ?? 'Unknown Supplier',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    CurrencyFormatter.format(p.grandTotal),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                  Row(
                    children: [
                      if (hasPending)
                        IconButton(
                          icon: const Icon(Icons.payments_outlined, color: AppColors.success, size: 18),
                          tooltip: 'Pay',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showPurchasePaymentDialog(context, widget.ref, p),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmPurchaseDelete(context, widget.ref, p.id!, p.billNo ?? '#${p.id}'),
                      ),
                    ],
                  ),
                ],
              ),
              Text(DateFormatter.toDisplay(p.date), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
void _showPurchasePaymentDialog(BuildContext context, WidgetRef ref, PurchaseModel purchase) {
    final amountCtrl = TextEditingController(text: purchase.balanceDue.toString());
    String mode = 'Cash';
    int? selectedAccountId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Outstanding: ${CurrencyFormatter.format(purchase.balanceDue)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
                const SizedBox(height: 20),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount to Pay', prefixText: '₹ '),
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
                          labelText: 'Account / Fund Source',
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (amt <= 0 || amt > purchase.balanceDue) {
                  AppAlert.error(ref, 'Invalid amount');
                  return;
                }
                if (selectedAccountId == null) {
                  AppAlert.error(ref, 'Please select an account');
                  return;
                }
                await ref.read(purchaseRepositoryProvider).addPurchasePayment(purchase.id!, amt, mode, accountId: selectedAccountId);
                ref.invalidate(purchasesProvider);
                ref.invalidate(purchaseStatsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                AppAlert.success(ref, 'Payment recorded successfully');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
}

void _confirmPurchaseDelete(BuildContext context, WidgetRef ref, int id, String billNo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Purchase?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete purchase $billNo? This will reduce product stock levels accordingly.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(purchaseRepositoryProvider).deletePurchase(id);
              ref.invalidate(purchasesProvider);
              ref.invalidate(purchaseStatsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              AppAlert.success(ref, 'Purchase $billNo deleted successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
}
