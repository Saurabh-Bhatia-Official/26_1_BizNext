// lib/features/customers/screens/customer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/layout_toggle.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import 'add_edit_customer_screen.dart';
import 'customer_sales_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../discounts/providers/discount_provider.dart';
import '../models/customer_discount.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/services/subscription_service.dart';

class CustomerScreen extends ConsumerStatefulWidget {
  const CustomerScreen({super.key});

  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen> {
  LayoutMode _layoutMode = LayoutMode.grid;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customersAsync = ref.watch(filteredCustomersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _CustomerHeader(
            isDark: isDark,
            layoutMode: _layoutMode,
            onLayoutChanged: (m) => setState(() => _layoutMode = m),
          ),
          Expanded(
            child: customersAsync.when(
              data: (list) => list.isEmpty
                  ? _EmptyState(isDark: isDark)
                  : (_layoutMode == LayoutMode.grid
                      ? _CustomerGrid(customers: list, isDark: isDark)
                      : _CustomerTable(customers: list, isDark: isDark)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditCustomerScreen())),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.w700)),
      ).animate().scale(delay: 400.ms),
    );
  }
}

class _CustomerHeader extends ConsumerWidget {
  final bool isDark;
  final LayoutMode layoutMode;
  final ValueChanged<LayoutMode> onLayoutChanged;

  const _CustomerHeader({
    required this.isDark,
    required this.layoutMode,
    required this.onLayoutChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customers',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textLight,
                  ),
                ),
                const Text('Manage your client base and balances', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              ],
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              onChanged: (v) => ref.read(customerSearchQueryProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          LayoutToggle(current: layoutMode, onChanged: onLayoutChanged, isDark: isDark),
        ],
      ),
    );
  }
}

// ── Grid Layout ────────────────────────────────────────────────────────────────
class _CustomerGrid extends StatelessWidget {
  final List<CustomerModel> customers;
  final bool isDark;
  const _CustomerGrid({required this.customers, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : 2);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.4,
          ),
          itemCount: customers.length,
          itemBuilder: (_, i) => _CustomerCard(customer: customers[i], isDark: isDark)
              .animate(delay: (i * 50).ms)
              .fadeIn()
              .slideX(begin: 0.05, end: 0),
        );
      },
    );
  }
}

// ── Table Layout ───────────────────────────────────────────────────────────────
class _CustomerTable extends StatefulWidget {
  final List<CustomerModel> customers;
  final bool isDark;
  const _CustomerTable({required this.customers, required this.isDark});

  @override
  State<_CustomerTable> createState() => _CustomerTableState();
}

class _CustomerTableState extends State<_CustomerTable> {
  int _sortColumn = 0;
  bool _sortAscending = true;
  late List<CustomerModel> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = List.from(widget.customers);
  }

  @override
  void didUpdateWidget(_CustomerTable old) {
    super.didUpdateWidget(old);
    if (old.customers != widget.customers) _applySort(widget.customers);
  }

  void _applySort(List<CustomerModel> src) {
    final list = List<CustomerModel>.from(src);
    list.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 0: cmp = a.name.compareTo(b.name); break;
        case 1: cmp = (a.phone ?? '').compareTo(b.phone ?? ''); break;
        case 2: cmp = a.balance.compareTo(b.balance); break;
        case 3: cmp = a.loyaltyPoints.compareTo(b.loyaltyPoints); break;
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    setState(() => _sorted = list);
  }

  void _onSort(int col, bool asc) {
    _sortColumn = col;
    _sortAscending = asc;
    _applySort(widget.customers);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColumn,
            sortAscending: _sortAscending,
            headingRowColor: WidgetStateProperty.all(
              isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.lightBg,
            ),
            headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3),
            dataTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            dividerThickness: 1,
            columnSpacing: 28,
            columns: [
              DataColumn(label: const Text('Customer'), onSort: _onSort),
              DataColumn(label: const Text('Phone'), onSort: _onSort),
              DataColumn(label: const Text('Balance'), numeric: true, onSort: _onSort),
              DataColumn(label: const Text('Loyalty Pts'), numeric: true, onSort: _onSort),
              const DataColumn(label: Text('Actions')),
            ],
            rows: _sorted.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              final balanceColor = c.balance > 0 ? AppColors.success : (c.balance < 0 ? AppColors.error : AppColors.textMuted);

              return DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) return AppColors.primary.withValues(alpha: 0.04);
                  return i.isOdd
                      ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.02))
                      : null;
                }),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(c.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                        const SizedBox(width: 12),
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCustomerScreen(customer: c))),
                  ),
                  DataCell(Text(c.phone ?? '—', style: const TextStyle(color: AppColors.textMuted))),
                  DataCell(Text(
                    CurrencyFormatter.format(c.balance),
                    style: TextStyle(color: balanceColor, fontWeight: FontWeight.w700),
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(c.loyaltyPoints.toInt().toString()),
                    ],
                  )),
                  DataCell(_CustomerTableActions(customer: c)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CustomerTableActions extends ConsumerWidget {
  final CustomerModel customer;
  const _CustomerTableActions({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCustomerScreen(customer: customer))),
        ),
        IconButton(
          icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.textMuted),
          tooltip: 'Sale History',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSalesScreen(customer: customer))),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
          tooltip: 'Delete',
          visualDensity: VisualDensity.compact,
          onPressed: () => _confirmDelete(context, ref),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Customer?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(customerFormProvider.notifier).deleteCustomer(customer.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted && success) AppAlert.success(ref, 'Customer deleted successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatefulWidget {
  final CustomerModel customer;
  final bool isDark;
  const _CustomerCard({required this.customer, required this.isDark});

  @override
  State<_CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<_CustomerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final balance = widget.customer.balance;
    final balanceColor = balance > 0 ? AppColors.success : (balance < 0 ? AppColors.error : AppColors.textMuted);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCustomerScreen(customer: widget.customer))),
        child: Consumer(
          builder: (context, ref, child) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hovered ? AppColors.primary : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: 1.5,
              ),
              boxShadow: _hovered ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))] : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(widget.customer.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, color: AppColors.textMuted.withValues(alpha: 0.5), size: 18),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'history') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSalesScreen(customer: widget.customer)));
                        } else if (val == 'edit') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCustomerScreen(customer: widget.customer)));
                        } else if (val == 'discount') {
                          _showDiscountDialog(context, ref);
                        } else if (val == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'history', child: ListTile(leading: Icon(Icons.history_rounded, size: 18), title: Text('Sale History'), dense: true)),
                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded, size: 18), title: Text('Edit'), dense: true)),
                        if (ref.watch(featureSettingsProvider).customerDiscountEnabled)
                          const PopupMenuItem(value: 'discount', child: ListTile(leading: Icon(Icons.local_offer_rounded, size: 18), title: Text('Manage Discount'), dense: true)),
                        PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), title: const Text('Delete', style: TextStyle(color: AppColors.error)), dense: true)),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.customer.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.customer.phone ?? 'No phone',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Balance', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.format(balance),
                        style: TextStyle(color: balanceColor, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (ref.watch(subscriptionServiceProvider).isPro && ref.watch(featureSettingsProvider).loyaltyEnabled) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Loyalty Points', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.customer.loyaltyPoints.toInt().toString(),
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Customer?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete ${widget.customer.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(customerFormProvider.notifier).deleteCustomer(widget.customer.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted && success) {
                AppAlert.success(ref, 'Customer deleted successfully');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerDiscountDialog(customer: widget.customer),
    );
  }
}

class _CustomerDiscountDialog extends ConsumerStatefulWidget {
  final CustomerModel customer;
  const _CustomerDiscountDialog({required this.customer});

  @override
  ConsumerState<_CustomerDiscountDialog> createState() => _CustomerDiscountDialogState();
}

class _CustomerDiscountDialogState extends ConsumerState<_CustomerDiscountDialog> {
  late TextEditingController _valueCtrl;
  String _discountType = 'percentage';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _valueCtrl = TextEditingController(text: '0');
    _loadCurrentDiscount();
  }

  Future<void> _loadCurrentDiscount() async {
    final discount = await ref.read(customerDiscountProvider(widget.customer.id!).future);
    if (discount != null) {
      setState(() {
        _valueCtrl.text = discount.discountValue.toString();
        _discountType = discount.discountType;
        _isActive = discount.isActive;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Discount for ${widget.customer.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('%'),
                  value: 'percentage',
                  groupValue: _discountType,
                  onChanged: (v) => setState(() => _discountType = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Flat'),
                  value: 'fixed',
                  groupValue: _discountType,
                  onChanged: (v) => setState(() => _discountType = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _valueCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _discountType == 'percentage' ? 'Percentage' : 'Fixed Amount',
              prefixIcon: Icon(_discountType == 'percentage' ? Icons.percent_rounded : Icons.currency_rupee_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            title: const Text('Active'),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final businessId = ref.read(activeBusinessIdProvider);
            final discount = CustomerDiscount(
              businessId: businessId,
              customerId: widget.customer.id!,
              discountType: _discountType,
              discountValue: double.tryParse(_valueCtrl.text) ?? 0,
              isActive: _isActive,
              createdAt: DateTime.now(),
            );
            await ref.read(discountRepositoryProvider).upsertCustomerDiscount(discount);
            ref.invalidate(customerDiscountProvider(widget.customer.id!));
            if (context.mounted) {
              Navigator.pop(context);
              AppAlert.success(ref, 'Discount updated for ${widget.customer.name}');
            }
          },
          child: const Text('Save Discount'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 80, color: AppColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          const Text('No Customers Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Text('Start by adding your first customer contact.', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
