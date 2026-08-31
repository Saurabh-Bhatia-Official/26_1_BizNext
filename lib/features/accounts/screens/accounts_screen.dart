// lib/features/accounts/screens/accounts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/accounts_provider.dart';
import '../models/transaction_model.dart';
import '../models/ledger_model.dart';
import '../models/account_model.dart';
import '../../../core/widgets/category_manager_screen.dart';
import '../../billing/screens/sale_detail_screen.dart';
import '../../purchases/screens/purchase_detail_screen.dart';
import '../../purchases/screens/add_purchase_screen.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../../billing/providers/billing_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../../core/widgets/searchable_dropdown.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _filterType = 'All';

  final List<String> _filters = ['All', 'Purchase', 'Invoice', 'Transfer', 'Income', 'Expense'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(170),
        child: Column(
          children: [
            _AccountsHeader(isDark: isDark),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'ACCOUNTS'),
                Tab(text: 'INCOME CATS'),
                Tab(text: 'EXPENSE CATS'),
              ],
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Overview & Ledger ──
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(child: _BalanceOverview(isDark: isDark)),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showTransactionDialog(context, ref, AppConstants.ledgerCredit),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Record Income / Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                sliver: SliverToBoxAdapter(
                  child: _ConsolidatedLedger(
                    isDark: isDark, 
                    searchQuery: _searchQuery,
                    onSearch: (v) => setState(() => _searchQuery = v),
                    filterType: _filterType,
                    onFilter: (v) => setState(() => _filterType = v),
                    filters: _filters,
                  ),
                ),
              ),
            ],
          ),

          // ── Tab 2: Accounts ──
          _AccountsListTab(isDark: isDark),

          // ── Tab 3: Income Categories ──
          _CategoryListTab(type: 'income', isDark: isDark),

          // ── Tab 4: Expense Categories ──
          _CategoryListTab(type: 'expense', isDark: isDark),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index == 0) {
            return const SizedBox.shrink(); // No FAB since it is merged and placed above
          } else if (_tabController.index == 1) {
            return FloatingActionButton.extended(
              onPressed: () => _showAddAccountDialog(context, ref),
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('Add Account'),
              backgroundColor: AppColors.primary,
            );
          }
          
          return FloatingActionButton.extended(
            onPressed: () => _showAddCategoryDialog(context, ref, _tabController.index == 2 ? AppConstants.ledgerCredit : AppConstants.ledgerDebit),
            icon: const Icon(Icons.add_rounded),
            label: Text('Add ${_tabController.index == 2 ? 'Income' : 'Expense'} Category'),
            backgroundColor: AppColors.primary,
          );
        }
      ),
    );
  }
}

class _CategoryListTab extends ConsumerWidget {
  final String type;
  final bool isDark;
  const _CategoryListTab({required this.type, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(transactionCategoriesProvider(type));

    return categoriesAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No $type categories found', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final cat = list[i];
            return Material(
              color: isDark ? AppColors.darkCard : Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  cat.name, 
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
                      onPressed: () => _showAddCategoryDialog(context, ref, type == 'income' ? AppConstants.ledgerCredit : AppConstants.ledgerDebit, initialCategory: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                      onPressed: () => _confirmDeleteCategory(context, ref, cat),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _confirmDeleteCategory(BuildContext context, WidgetRef ref, dynamic cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Delete "${cat.name}"? This will fail if transactions are using it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(accountsRepositoryProvider).deleteTransactionCategory(cat.id!);
                ref.invalidate(transactionCategoriesProvider(type));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                AppAlert.error(ref, 'Cannot delete: Category is in use');
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

class _AccountsListTab extends ConsumerWidget {
  final bool isDark;
  const _AccountsListTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return accountsAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                const Text('No accounts found', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 20),
          itemBuilder: (ctx, i) {
            final acc = list[i];
            final isBank = acc.type == 'Bank';
            
            return Container(
              height: 210,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: isDark 
                    ? [AppColors.darkCard, AppColors.darkCard.withValues(alpha: 0.8)]
                    : [Colors.white, Colors.white.withValues(alpha: 0.9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // Decorative circle
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isBank ? Icons.account_balance_rounded : Icons.account_balance_wallet_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        acc.name,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (acc.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'DEFAULT',
                                    style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Opening',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(acc.openingBalance),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Current Balance',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        CurrencyFormatter.format(acc.balance),
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: -1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                                onPressed: () => _showAddAccountDialog(context, ref, initialAccount: acc),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                              if (!acc.isDefault) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                  onPressed: () => _confirmDeleteAccount(context, ref, acc),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.error.withValues(alpha: 0.05),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref, dynamic acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text('Delete "${acc.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(accountsRepositoryProvider).deleteAccount(acc.id!);
                ref.invalidate(accountsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                AppAlert.error(ref, 'Cannot delete account');
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

void _showAddAccountDialog(BuildContext context, WidgetRef ref, {dynamic initialAccount}) {
  final nameCtrl = TextEditingController(text: initialAccount?.name);
  String type = initialAccount?.type ?? 'Cash';
  final balanceCtrl = TextEditingController(text: initialAccount?.openingBalance.toString() ?? '0.0');

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(initialAccount == null ? 'Add Account' : 'Edit Account', style: const TextStyle(fontWeight: FontWeight.w900)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Account Name', prefixIcon: Icon(Icons.account_balance_wallet)),
                  ),
                  const SizedBox(height: 16),
                  AppSearchableDropdown<String>(
                    value: type,
                    labelText: 'Type',
                    prefixIcon: Icons.category,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    items: ['Cash', 'Bank', 'Wallet'].map((t) => SearchableDropdownItem(value: t, label: t)).toList(),
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: balanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Opening Balance', prefixIcon: Icon(Icons.currency_rupee)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final bal = double.tryParse(balanceCtrl.text) ?? 0.0;
                  
                  final businessId = ref.read(activeBusinessIdProvider);
                  
                  if (initialAccount == null) {
                    await ref.read(accountsRepositoryProvider).addAccount(
                      AccountModel(
                        businessId: businessId,
                        name: nameCtrl.text.trim(),
                        type: type,
                        openingBalance: bal,
                        balance: bal,
                      )
                    );
                  } else {
                    await ref.read(accountsRepositoryProvider).updateAccount(
                      AccountModel(
                        id: initialAccount.id,
                        businessId: businessId,
                        name: nameCtrl.text.trim(),
                        type: type,
                        openingBalance: bal,
                        isDefault: initialAccount.isDefault,
                      )
                    );
                  }
                  
                  ref.invalidate(accountsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

void _viewTransaction(BuildContext context, WidgetRef ref, LedgerModel ledger) async {
  if (ledger.referenceId == null) return;
  
  // Sale details
  if ((ledger.description?.toLowerCase().contains('sale') ?? false) || 
      (ledger.description?.toLowerCase().contains('invoice') ?? false)) {
     Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: ledger.referenceId!)));
     return;
  }
  
  // Purchase details
  if ((ledger.description?.toLowerCase().contains('purchase') ?? false) || 
      (ledger.description?.toLowerCase().contains('bill') ?? false)) {
    final purchase = await ref.read(purchaseRepositoryProvider).getPurchaseById(ledger.referenceId!);
    if (purchase != null && context.mounted) {
       Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseDetailScreen(purchase: purchase)));
    }
    return;
  }

  // Generic Transaction Detail
  if (ledger.entityType == AppConstants.entityBusiness) {
    final transaction = await ref.read(accountsRepositoryProvider).getTransactionById(ledger.referenceId!);
    if (transaction != null && context.mounted) {
      _showTransactionDetailDialog(context, transaction);
    }
  }
}

void _showTransactionDetailDialog(BuildContext context, TransactionModel t) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isIncome = t.type == AppConstants.ledgerCredit;
  final color = isIncome ? AppColors.success : AppColors.error;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with color
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(isIncome ? Icons.south_west_rounded : Icons.north_east_rounded, color: color, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isIncome ? 'Income Details' : 'Expense Details',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(t.amount),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                ],
              ),
            ),
            // Details List
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  _DetailRow(label: 'DATE', value: DateFormatter.toDisplay(t.date), icon: Icons.calendar_today_rounded),
                  const Divider(height: 32),
                  _DetailRow(label: 'ACCOUNT', value: t.accountName ?? 'Main Account', icon: Icons.account_balance_wallet_rounded),
                  const Divider(height: 32),
                  _DetailRow(label: 'CATEGORY', value: t.categoryName ?? 'General', icon: Icons.category_rounded),
                  if (t.description != null && t.description!.isNotEmpty) ...[
                    const Divider(height: 32),
                    _DetailRow(label: 'NOTES', value: t.description!, icon: Icons.notes_rounded),
                  ],
                ],
              ),
            ),
            // Footer Action
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

void _editTransaction(BuildContext context, WidgetRef ref, LedgerModel ledger) async {
  if (ledger.entityType == AppConstants.entityCustomer && ledger.referenceId != null) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: ledger.referenceId!)));
    return;
  }
  
  if (ledger.entityType == AppConstants.entitySupplier && ledger.referenceId != null) {
    final purchase = await ref.read(purchaseRepositoryProvider).getPurchaseById(ledger.referenceId!);
    if (purchase != null && context.mounted) {
       Navigator.push(context, MaterialPageRoute(builder: (_) => AddPurchaseScreen(initialPurchase: purchase)));
    }
    return;
  }

  if (ledger.description == 'Opening Balance' && ledger.accountId != null) {
    final accounts = await ref.read(accountsRepositoryProvider).getAccounts(ref.read(activeBusinessIdProvider));
    final acc = accounts.firstWhere((a) => a.id == ledger.accountId);
    if (context.mounted) {
      _showAddAccountDialog(context, ref, initialAccount: acc);
    }
    return;
  }

  if (ledger.referenceId == null) return;
  
  final transaction = await ref.read(accountsRepositoryProvider).getTransactionById(ledger.referenceId!);
  if (transaction != null && context.mounted) {
    _showTransactionDialog(context, ref, transaction.type, initialTransaction: transaction);
  }
}

void _showTransactionDialog(BuildContext context, WidgetRef ref, String initialType, {TransactionModel? initialTransaction}) {
  var type = initialType;
  final amountCtrl = TextEditingController(text: initialTransaction?.amount.toString());
  final descCtrl = TextEditingController(text: initialTransaction?.description);
  int? selectedCategoryId = initialTransaction?.categoryId;
  int? selectedAccountId = initialTransaction?.accountId;
  DateTime selectedDate = initialTransaction?.date ?? DateTime.now();

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final isIncome = type == AppConstants.ledgerCredit;
          final catType = isIncome ? 'income' : 'expense';
          final categoriesAsync = ref.watch(transactionCategoriesProvider(catType));
          final accountsAsync = ref.watch(accountsProvider);
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(initialTransaction == null ? 'Record Transaction' : 'Edit Record', style: const TextStyle(fontWeight: FontWeight.w800)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (!isIncome) {
                                setState(() {
                                  type = AppConstants.ledgerCredit;
                                  selectedCategoryId = null;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isIncome ? AppColors.success : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isIncome ? AppColors.success : AppColors.textMuted.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  'Income',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIncome ? Colors.white : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (isIncome) {
                                setState(() {
                                  type = AppConstants.ledgerDebit;
                                  selectedCategoryId = null;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isIncome ? AppColors.error : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: !isIncome ? AppColors.error : AppColors.textMuted.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  'Expense',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !isIncome ? Colors.white : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Amount', 
                              prefixText: '₹ ',
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isIncome ? AppColors.success : AppColors.error),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _DatePickerButton(
                          selectedDate: selectedDate,
                          onDateSelected: (date) => setState(() => selectedDate = date),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: categoriesAsync.when(
                            data: (cats) => AppSearchableDropdown<int>(
                              value: selectedCategoryId,
                              labelText: 'Category',
                              isDark: Theme.of(context).brightness == Brightness.dark,
                              addLabel: 'Add New Category',
                              onAdd: (name) async {
                                final newCatId = await _quickAddTransactionCategory(context, ref, type, name);
                                if (newCatId != null) {
                                  setState(() => selectedCategoryId = newCatId);
                                }
                              },
                              items: cats.map((c) => SearchableDropdownItem<int>(value: c.id!, label: c.name)).toList(),
                              onChanged: (v) => setState(() => selectedCategoryId = v),
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => const Text('Error loading categories'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded, color: isIncome ? AppColors.success : AppColors.error),
                          onPressed: () async {
                            final newCatId = await _showAddCategoryDialog(context, ref, type);
                            if (newCatId != null) {
                              setState(() => selectedCategoryId = newCatId);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: isIncome ? 'e.g. Services, Sales' : 'e.g. Rent, Electricity',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    accountsAsync.when(
                      data: (accounts) {
                        // Set default account if none selected
                        if (selectedAccountId == null && accounts.isNotEmpty) {
                          final defAcc = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
                          selectedAccountId = defAcc.id;
                        }
                        return AppSearchableDropdown<int?>(
                          value: selectedAccountId,
                          labelText: 'Account / Wallet',
                          prefixIcon: Icons.account_balance_wallet_rounded,
                          isDark: Theme.of(context).brightness == Brightness.dark,
                          items: accounts.map((a) => SearchableDropdownItem(value: a.id, label: a.name)).toList(),
                          onChanged: (v) => setState(() => selectedAccountId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => const Text('Error loading accounts'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (amount <= 0) {
                    AppAlert.error(ref, 'Please enter a valid amount');
                    return;
                  }
                  if (selectedCategoryId == null) {
                    AppAlert.error(ref, 'Please select a category');
                    return;
                  }
                  
                  if (selectedAccountId == null) {
                    AppAlert.error(ref, 'Please select an account');
                    return;
                  }
                  
                  final businessId = ref.read(activeBusinessIdProvider);
                  final transaction = TransactionModel(
                    id: initialTransaction?.id,
                    businessId: businessId,
                    categoryId: selectedCategoryId!,
                    type: type,
                    amount: amount,
                    description: descCtrl.text,
                    accountId: selectedAccountId,
                    date: selectedDate,
                  );

                  if (initialTransaction == null) {
                    await ref.read(accountsRepositoryProvider).addTransaction(transaction);
                  } else {
                    await ref.read(accountsRepositoryProvider).updateTransaction(transaction);
                  }

                  ref.invalidate(balanceSummaryProvider);
                  ref.invalidate(ledgerEntriesProvider);
                  ref.invalidate(transactionsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  AppAlert.success(ref, initialTransaction == null ? 'Transaction recorded!' : 'Transaction updated!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isIncome ? AppColors.success : AppColors.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(initialTransaction == null ? 'Save ${isIncome ? 'Income' : 'Expense'}' : 'Update Record'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<int?> _showAddCategoryDialog(BuildContext context, WidgetRef ref, String type, {TransactionCategoryModel? initialCategory, String? name}) async {
  final ctrl = TextEditingController(text: initialCategory?.name ?? name);
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(initialCategory == null ? 'New ${type == AppConstants.ledgerCredit ? 'Income' : 'Expense'} Category' : 'Edit Category', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: TextField(
        controller: ctrl, 
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (ctrl.text.isEmpty) return;
            final businessId = ref.read(activeBusinessIdProvider);
            final category = TransactionCategoryModel(
              id: initialCategory?.id,
              businessId: businessId, 
              name: ctrl.text.trim(), 
              type: type == AppConstants.ledgerCredit ? 'income' : 'expense'
            );

            int id;
            if (initialCategory == null) {
              id = await ref.read(accountsRepositoryProvider).addTransactionCategory(category);
            } else {
              await ref.read(accountsRepositoryProvider).updateTransactionCategory(category);
              id = initialCategory.id!;
            }
            
            final catType = type == AppConstants.ledgerCredit ? 'income' : 'expense';
            ref.invalidate(transactionCategoriesProvider(catType));
            if (ctx.mounted) Navigator.pop(ctx, id);
          },
          child: Text(initialCategory == null ? 'Add Category' : 'Update'),
        ),
      ],
    ),
  );
}

Future<int?> _quickAddTransactionCategory(BuildContext context, WidgetRef ref, String type, String name) async {
  if (name.isEmpty) return null;
  final businessId = ref.read(activeBusinessIdProvider);
  final category = TransactionCategoryModel(
    businessId: businessId, 
    name: name.trim(), 
    type: type == AppConstants.ledgerCredit ? 'income' : 'expense'
  );
  final id = await ref.read(accountsRepositoryProvider).addTransactionCategory(category);
  final catType = type == AppConstants.ledgerCredit ? 'income' : 'expense';
  ref.invalidate(transactionCategoriesProvider(catType));
  return id;
}

class _PremiumFAB extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _PremiumFAB({required this.label, required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: label,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _AccountsHeader extends ConsumerWidget {
  final bool isDark;
  const _AccountsHeader({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallets & Accounts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Financial Assets',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.compare_arrows_rounded, color: AppColors.primary),
                    tooltip: 'Transfer Funds',
                    onPressed: () => _showTransferDialog(context, ref),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.category_rounded, color: AppColors.primary),
                    onPressed: () => _showAccountCategories(context),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAccountCategories(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Manage Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.south_west_rounded, color: AppColors.success),
              title: const Text('Income Categories', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _openCategoryManager(context, 'income');
              },
            ),
            ListTile(
              leading: const Icon(Icons.north_east_rounded, color: AppColors.error),
              title: const Text('Expense Categories', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _openCategoryManager(context, 'expense');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openCategoryManager(BuildContext context, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Consumer(
          builder: (context, ref, child) => CategoryManagerScreen(
            title: '${type[0].toUpperCase()}${type.substring(1)} Categories',
            categoriesProvider: transactionCategoriesProvider(type),
            nameExtractor: (cat) => (cat as TransactionCategoryModel).name,
            onSave: (name, id) async {
              final businessId = ref.read(activeBusinessIdProvider);
              final category = TransactionCategoryModel(id: id, businessId: businessId, name: name, type: type);
              if (id == null) {
                await ref.read(accountsRepositoryProvider).addTransactionCategory(category);
              } else {
                await ref.read(accountsRepositoryProvider).updateTransactionCategory(category);
              }
              ref.invalidate(transactionCategoriesProvider(type));
              return true;
            },
            onDelete: (id) async {
              await ref.read(accountsRepositoryProvider).deleteTransactionCategory(id);
              ref.invalidate(transactionCategoriesProvider(type));
              return true;
            },
          ),
        ),
      ),
    );
  }
}

class _BalanceOverview extends ConsumerWidget {
  final bool isDark;
  const _BalanceOverview({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceSummaryProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Column(
      children: [
        balanceAsync.when(
          data: (data) => Column(
            children: [
              accountsAsync.when(
                data: (accounts) {
                  final totalBalance = accounts.fold(0.0, (sum, item) => sum + item.balance);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark 
                          ? [AppColors.primary, const Color(0xFF4F46E5)]
                          : [const Color(0xFF6366F1), const Color(0xFF818CF8)],
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Available Balance',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(totalBalance),
                            style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -2),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(child: _MiniStat(label: 'Total Income', value: data.totalIncome, isIncrease: true)),
                            Container(width: 1, height: 30, color: Colors.white24),
                            const SizedBox(width: 24),
                            Expanded(child: _MiniStat(label: 'Total Expense', value: data.totalExpenses, isIncrease: false)),
                          ],
                        ),
                      ],
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
                },
                loading: () => Container(height: 180, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(32))),
                error: (_, _) => const SizedBox(),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 450) {
                    return Column(
                      children: [
                        _OverviewCard(
                          label: 'Receivable',
                          value: data.totalReceivable,
                          color: AppColors.success,
                          icon: Icons.call_received_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _OverviewCard(
                          label: 'Payable',
                          value: data.totalPayable,
                          color: AppColors.error,
                          icon: Icons.call_made_rounded,
                          isDark: isDark,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: _OverviewCard(
                          label: 'Receivable',
                          value: data.totalReceivable,
                          color: AppColors.success,
                          icon: Icons.call_received_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _OverviewCard(
                          label: 'Payable',
                          value: data.totalPayable,
                          color: AppColors.error,
                          icon: Icons.call_made_rounded,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  );
                }
              ),
            ],
          ),
          loading: () => const _OverviewSkeleton(),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final bool isIncrease;

  const _MiniStat({required this.label, required this.value, required this.isIncrease});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              CurrencyFormatter.format(value),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _OverviewCard({required this.label, required this.value, required this.color, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: color, size: 24),
                ),
                Icon(Icons.trending_up_rounded, color: color.withValues(alpha: 0.3), size: 32),
              ],
            ),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyFormatter.format(value),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
          ],
        ),
      );
  }
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(2, (i) => Expanded(
        child: Container(
          height: 160,
          margin: EdgeInsets.only(right: i == 0 ? 20 : 0),
          decoration: BoxDecoration(color: AppColors.darkBorder, borderRadius: BorderRadius.circular(32)),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
      )),
    );
  }
}

class _ConsolidatedLedger extends ConsumerWidget {
  final bool isDark;
  final String searchQuery;
  final Function(String) onSearch;
  final String filterType;
  final Function(String) onFilter;
  final List<String> filters;

  const _ConsolidatedLedger({
    required this.isDark, 
    required this.searchQuery, 
    required this.onSearch,
    required this.filterType,
    required this.onFilter,
    required this.filters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(ledgerEntriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Financial Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            SizedBox(
              width: 300,
              child: TextField(
                onChanged: onSearch,
                decoration: InputDecoration(
                  hintText: 'Search ledger...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final isSelected = filterType == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textLight), fontWeight: FontWeight.w700)),
                  selected: isSelected,
                  onSelected: (val) => onFilter(f),
                  selectedColor: AppColors.primary,
                  backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), 
                    side: BorderSide(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        ledgerAsync.when(
          data: (list) {
            final filtered = list.where((t) {
              final query = searchQuery.toLowerCase().trim();
              final matchesSearch = query.isEmpty || 
                                     (t.description?.toLowerCase().contains(query) ?? false) ||
                                     (t.entityName?.toLowerCase().contains(query) ?? false) ||
                                     (t.categoryName?.toLowerCase().contains(query) ?? false);
              
              if (!matchesSearch) return false;
              if (filterType == 'All') return true;
              
              final desc = t.description?.toLowerCase() ?? '';
              final isInvoice = desc.contains('invoice') || desc.contains('sale');
              final isPurchase = desc.contains('purchase') || desc.contains('bill');
              final isTransfer = desc.contains('transfer');

              if (filterType == 'Transfer') return isTransfer;
              if (filterType == 'Purchase') return isPurchase;
              if (filterType == 'Invoice') return isInvoice;
              if (filterType == 'Income') return t.type == AppConstants.ledgerCredit && !isInvoice && !isTransfer;
              if (filterType == 'Expense') return t.type == AppConstants.ledgerDebit && !isPurchase && !isTransfer;
              
              return true;
            }).toList();

            if (filtered.isEmpty) return _EmptyTransactions(isDark: isDark);

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final t = filtered[i];
                final isCredit = t.type == AppConstants.ledgerCredit;
                final color = isCredit ? AppColors.success : AppColors.error;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                        child: Icon(isCredit ? Icons.south_west_rounded : Icons.north_east_rounded, color: color, size: 18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.description?.isNotEmpty == true ? t.description! : (isCredit ? 'Income' : 'Expense'), 
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t.accountName ?? "Main"} • ${t.categoryName ?? t.entityName ?? "Business"}', 
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${isCredit ? '+' : '-'} ${CurrencyFormatter.format(t.amount)}', 
                                style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16, letterSpacing: -0.5)
                              ),
                            ),
                            Text(DateFormatter.toDisplay(t.date), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      if (t.referenceId != null || t.description == 'Opening Balance') ...[
                         const SizedBox(width: 12),
                         _TransactionActionGroup(
                           onView: () => _viewTransaction(context, ref, t),
                           onEdit: () => _editTransaction(context, ref, t),
                           onDelete: t.description == 'Opening Balance' ? null : () => _confirmDelete(context, ref, t),
                           isDark: isDark,
                         ),
                      ],
                    ],
                  ),
                ).animate(delay: (i * 50).ms).fadeIn().slideX(begin: 0.05);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, LedgerModel ledger) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Text('Are you sure you want to delete this transaction? All associated stock and balance updates will be reverted. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final desc = ledger.description?.toLowerCase() ?? '';
              
              if (desc.contains('transfer') && ledger.referenceId != null) {
                await ref.read(accountsRepositoryProvider).deleteTransfer(ledger.referenceId!);
              } else if ((desc.contains('purchase') || desc.contains('bill')) && ledger.referenceId != null) {
                await ref.read(purchaseRepositoryProvider).deletePurchase(ledger.referenceId!);
              } else if ((desc.contains('invoice') || desc.contains('sale')) && ledger.referenceId != null) {
                await ref.read(billingRepositoryProvider).voidSale(ledger.referenceId!);
              } else if (ledger.entityType == AppConstants.entityBusiness && ledger.referenceId != null) {
                await ref.read(accountsRepositoryProvider).deleteTransaction(ledger.referenceId!);
              } else if (ledger.description == 'Opening Balance') {
                AppAlert.info(ref, 'Opening balance cannot be deleted directly. Edit the account instead.');
                return;
              }

              ref.invalidate(ledgerEntriesProvider);
              ref.invalidate(accountsProvider);
              ref.invalidate(balanceSummaryProvider);
              ref.invalidate(purchasesProvider);
              ref.invalidate(productsProvider);
              
              AppAlert.success(ref, 'Transaction deleted successfully');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Action Group (Professional UI) ──────────────────────────
class _TransactionActionGroup extends StatelessWidget {
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final bool isDark;

  const _TransactionActionGroup({
    required this.onView,
    required this.onEdit,
    this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.visibility_outlined,
            tooltip: 'View Details',
            color: AppColors.textMuted,
            onTap: onView,
            isDark: isDark,
          ),
          _ActionButton(
            icon: Icons.edit_note_rounded,
            tooltip: 'Edit Record',
            color: AppColors.primary,
            onTap: onEdit,
            isDark: isDark,
          ),
          if (onDelete != null)
            _ActionButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete Record',
              color: AppColors.error,
              onTap: onDelete!,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  final bool isDark;
  const _EmptyTransactions({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 80, color: AppColors.primary.withValues(alpha: 0.1)),
            const SizedBox(height: 20),
            const Text('No records found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            const Text('Your transaction history will be displayed here.', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _DatePickerButton({required this.selectedDate, required this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) onDateSelected(date);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              DateFormatter.toDisplay(selectedDate),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}


void _showTransferDialog(BuildContext context, WidgetRef ref) {
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  int? fromId;
  int? toId;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final accountsAsync = ref.watch(accountsProvider);
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Transfer Funds', style: TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    accountsAsync.when(
                      data: (accounts) => Column(
                        children: [
                          AppSearchableDropdown<int?>(
                            value: fromId,
                            labelText: 'From Account',
                            isDark: Theme.of(context).brightness == Brightness.dark,
                            items: accounts.map((a) => SearchableDropdownItem(value: a.id, label: "${a.name} (${CurrencyFormatter.format(a.balance)})")).toList(),
                            onChanged: (v) => setState(() => fromId = v),
                          ),
                          const SizedBox(height: 16),
                          AppSearchableDropdown<int?>(
                            value: toId,
                            labelText: 'To Account',
                            isDark: Theme.of(context).brightness == Brightness.dark,
                            items: accounts.map((a) => SearchableDropdownItem(value: a.id, label: a.name)).toList(),
                            onChanged: (v) => setState(() => toId = v),
                          ),
                        ],
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Error loading accounts'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountCtrl.text) ?? 0;
                  if (fromId == null || toId == null || amt <= 0 || fromId == toId) return;

                  final businessId = ref.read(activeBusinessIdProvider);
                  await ref.read(accountsRepositoryProvider).addTransfer(
                    businessId: businessId,
                    fromAccountId: fromId!,
                    toAccountId: toId!,
                    amount: amt,
                    description: descCtrl.text.trim(),
                  );
                  
                  ref.invalidate(accountsProvider);
                  ref.invalidate(ledgerEntriesProvider);
                  ref.invalidate(balanceSummaryProvider);
                  
                  if (ctx.mounted) Navigator.pop(ctx);
                  AppAlert.success(ref, 'Transfer completed');
                },
                child: const Text('Transfer'),
              ),
            ],
          );
        },
      );
    },
  );
}
