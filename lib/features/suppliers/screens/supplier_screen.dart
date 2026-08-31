// lib/features/suppliers/screens/supplier_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/layout_toggle.dart';
import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'add_edit_supplier_screen.dart';

class SupplierScreen extends ConsumerStatefulWidget {
  const SupplierScreen({super.key});

  @override
  ConsumerState<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends ConsumerState<SupplierScreen> {
  LayoutMode _layoutMode = LayoutMode.grid;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suppliersAsync = ref.watch(filteredSuppliersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _SupplierHeader(
            isDark: isDark,
            layoutMode: _layoutMode,
            onLayoutChanged: (m) => setState(() => _layoutMode = m),
          ),
          Expanded(
            child: suppliersAsync.when(
              data: (list) => list.isEmpty
                  ? _EmptyState(isDark: isDark)
                  : (_layoutMode == LayoutMode.grid
                      ? _SupplierGrid(suppliers: list, isDark: isDark)
                      : _SupplierTable(suppliers: list, isDark: isDark)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditSupplierScreen())),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Supplier', style: TextStyle(fontWeight: FontWeight.w700)),
      ).animate().scale(delay: 400.ms),
    );
  }
}

class _SupplierHeader extends ConsumerWidget {
  final bool isDark;
  final LayoutMode layoutMode;
  final ValueChanged<LayoutMode> onLayoutChanged;

  const _SupplierHeader({
    required this.isDark,
    required this.layoutMode,
    required this.onLayoutChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
      child: isMobile 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supplier Directory',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
              const Text('Vendor masters, purchasing history & payables', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => ref.read(supplierSearchQueryProvider.notifier).state = v,
                      decoration: const InputDecoration(
                        hintText: 'Search vendor or phone...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  LayoutToggle(current: layoutMode, onChanged: onLayoutChanged, isDark: isDark),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supplier Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const Text('Vendor masters, purchasing ledger & accounts payable', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  onChanged: (v) => ref.read(supplierSearchQueryProvider.notifier).state = v,
                  decoration: const InputDecoration(
                    hintText: 'Search vendors...',
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
class _SupplierGrid extends StatelessWidget {
  final List<SupplierModel> suppliers;
  final bool isDark;
  const _SupplierGrid({required this.suppliers, required this.isDark});

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
            childAspectRatio: constraints.maxWidth < 600 ? 0.9 : 1.35,
          ),
          itemCount: suppliers.length,
          itemBuilder: (_, i) => _SupplierCard(supplier: suppliers[i], isDark: isDark)
              .animate(delay: (i * 50).ms)
              .fadeIn()
              .slideX(begin: 0.05, end: 0),
        );
      },
    );
  }
}

// ── Table Layout ───────────────────────────────────────────────────────────────
class _SupplierTable extends StatefulWidget {
  final List<SupplierModel> suppliers;
  final bool isDark;
  const _SupplierTable({required this.suppliers, required this.isDark});

  @override
  State<_SupplierTable> createState() => _SupplierTableState();
}

class _SupplierTableState extends State<_SupplierTable> {
  int _sortColumn = 0;
  bool _sortAscending = true;
  late List<SupplierModel> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = List.from(widget.suppliers);
  }

  @override
  void didUpdateWidget(_SupplierTable old) {
    super.didUpdateWidget(old);
    if (old.suppliers != widget.suppliers) _applySort(widget.suppliers);
  }

  void _applySort(List<SupplierModel> src) {
    final list = List<SupplierModel>.from(src);
    list.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 0: cmp = a.name.compareTo(b.name); break;
        case 1: cmp = (a.phone ?? '').compareTo(b.phone ?? ''); break;
        case 2: cmp = (a.gstNumber ?? '').compareTo(b.gstNumber ?? ''); break;
        case 3: cmp = a.balance.compareTo(b.balance); break;
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    setState(() => _sorted = list);
  }

  void _onSort(int col, bool asc) {
    _sortColumn = col;
    _sortAscending = asc;
    _applySort(widget.suppliers);
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
              DataColumn(label: const Text('Supplier / Company'), onSort: _onSort),
              DataColumn(label: const Text('Contact & Phone'), onSort: _onSort),
              DataColumn(label: const Text('GSTIN / State'), onSort: _onSort),
              DataColumn(label: const Text('Terms'), onSort: _onSort),
              DataColumn(label: const Text('Payable Balance'), numeric: true, onSort: _onSort),
              const DataColumn(label: Text('Actions')),
            ],
            rows: _sorted.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final balanceColor = s.balance > 0 ? AppColors.error : (s.balance < 0 ? AppColors.success : AppColors.textMuted);

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
                          backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                          child: Text(s.name[0].toUpperCase(), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (s.companyName != null && s.companyName!.isNotEmpty)
                              Text(s.companyName!, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditSupplierScreen(supplier: s))),
                  ),
                  DataCell(Text(s.phone ?? (s.contactPerson ?? '—'), style: const TextStyle(color: AppColors.textMuted))),
                  DataCell(Text(s.gstNumber ?? (s.state ?? '—'), style: const TextStyle(color: AppColors.textMuted))),
                  DataCell(Text(s.paymentTerms ?? 'Net 30', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(
                    CurrencyFormatter.format(s.balance),
                    style: TextStyle(color: balanceColor, fontWeight: FontWeight.w800),
                  )),
                  DataCell(_SupplierTableActions(supplier: s)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SupplierTableActions extends ConsumerWidget {
  final SupplierModel supplier;
  const _SupplierTableActions({required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.primary),
          tooltip: 'Purchase Orders',
          visualDensity: VisualDensity.compact,
          onPressed: () => _showSupplierPurchases(context, ref, supplier),
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditSupplierScreen(supplier: supplier))),
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
        title: const Text('Delete Supplier?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete ${supplier.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(supplierFormProvider.notifier).deleteSupplier(supplier.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted && success) AppAlert.success(ref, 'Supplier removed');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SupplierCard extends StatefulWidget {
  final SupplierModel supplier;
  final bool isDark;
  const _SupplierCard({required this.supplier, required this.isDark});

  @override
  State<_SupplierCard> createState() => _SupplierCardState();
}

class _SupplierCardState extends State<_SupplierCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final balance = widget.supplier.balance;
    final balanceColor = balance > 0 ? AppColors.error : (balance < 0 ? AppColors.success : AppColors.textMuted);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditSupplierScreen(supplier: widget.supplier))),
        child: Consumer(
          builder: (context, ref, child) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
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
                      backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                      child: Text(widget.supplier.name[0].toUpperCase(), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      onSelected: (val) {
                        if (val == 'edit') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditSupplierScreen(supplier: widget.supplier)));
                        } else if (val == 'purchases') {
                          _showSupplierPurchases(context, ref, widget.supplier);
                        } else if (val == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 12), Text('Edit Details')],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'purchases',
                          child: Row(
                            children: [Icon(Icons.history_rounded, size: 18, color: AppColors.primary), SizedBox(width: 12), Text('Purchase History')],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 12), Text('Delete', style: TextStyle(color: AppColors.error))],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.supplier.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.supplier.companyName ?? (widget.supplier.phone ?? 'No phone'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.supplier.paymentTerms ?? 'Net 30', style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                    Text(
                      CurrencyFormatter.format(balance),
                      style: TextStyle(color: balanceColor, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ],
                ),
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
        title: const Text('Delete Supplier?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete ${widget.supplier.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(supplierFormProvider.notifier).deleteSupplier(widget.supplier.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted && success) {
                AppAlert.success(ref, 'Supplier deleted successfully');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

void _showSupplierPurchases(BuildContext context, WidgetRef ref, SupplierModel supplier) async {
  final businessId = ref.read(activeBusinessIdProvider);
  final purchases = await ref.read(supplierRepositoryProvider).getSupplierPurchases(supplier.id!, businessId);

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text('Purchase History: ${supplier.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 380,
        child: purchases.isEmpty
            ? const Center(child: Text('No purchase records found for this vendor.', style: TextStyle(color: AppColors.textMuted)))
            : ListView.separated(
                itemCount: purchases.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final p = purchases[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: const CircleAvatar(backgroundColor: Color(0xFFEEF2FF), child: Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20)),
                    title: Text(p['bill_no'] ?? 'PO #${p['id']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text((p['date'] as String? ?? '').substring(0, 10), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(CurrencyFormatter.format((p['grand_total'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        if (((p['balance_due'] as num?)?.toDouble() ?? 0.0) > 0)
                          Text('Due: ${CurrencyFormatter.format((p['balance_due'] as num?)?.toDouble() ?? 0.0)}', style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
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
          Icon(Icons.local_shipping_outlined, size: 80, color: AppColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          const Text('No Suppliers Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Text('Add vendor partners to record incoming goods and stock invoices.', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
