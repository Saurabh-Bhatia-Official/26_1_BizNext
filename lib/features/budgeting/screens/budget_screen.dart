// lib/features/budgeting/screens/budget_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/budget_model.dart';
import '../providers/budget_provider.dart';
import '../../../core/widgets/searchable_dropdown.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Budgeting & Goals', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(budgetsProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return _EmptyBudgetsState(isDark: isDark);
          }

          final totalLimit = budgets.fold<double>(0, (sum, item) => sum + item.amount);
          final totalSpent = budgets.fold<double>(0, (sum, item) => sum + item.spent);
          final remaining = totalLimit - totalSpent;
          final overspentCount = budgets.where((b) => b.spent > b.amount).length;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── KPI Summary Cards ──
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: _BudgetSummaryPanel(
                    isDark: isDark,
                    totalLimit: totalLimit,
                    totalSpent: totalSpent,
                    remaining: remaining,
                    overspentCount: overspentCount,
                  ).animate().fadeIn().slideY(begin: 0.05),
                ),
              ),

              // ── Alerts Banner ──
              if (overspentCount > 0)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Overspending Alert: $overspentCount budget(s) have exceeded their limits! Take necessary actions to reduce costs.',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake(),
                  ),
                ),

              // ── Active Budgets List ──
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final budget = budgets[index];
                      return _BudgetCard(budget: budget, isDark: isDark)
                          .animate(delay: (index * 50).ms)
                          .fadeIn()
                          .slideX(begin: 0.05);
                    },
                    childCount: budgets.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading budgets: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBudgetDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Budget', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context, {BudgetModel? editBudget}) {
    showDialog(
      context: context,
      builder: (ctx) => _AddEditBudgetDialog(editBudget: editBudget),
    );
  }
}

class _BudgetSummaryPanel extends StatelessWidget {
  final bool isDark;
  final double totalLimit;
  final double totalSpent;
  final double remaining;
  final int overspentCount;

  const _BudgetSummaryPanel({
    required this.isDark,
    required this.totalLimit,
    required this.totalSpent,
    required this.remaining,
    required this.overspentCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Budget Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Limit', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(totalLimit),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total Spent', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(totalSpent),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: totalSpent > totalLimit ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              color: totalSpent > totalLimit ? AppColors.error : AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% utilized',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                remaining >= 0
                    ? '₹${CurrencyFormatter.format(remaining)} remaining'
                    : '₹${CurrencyFormatter.format(-remaining)} over budget',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: remaining >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  final BudgetModel budget;
  final bool isDark;

  const _BudgetCard({required this.budget, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = budget.amount > 0 ? (budget.spent / budget.amount).clamp(0.0, 1.0) : 0.0;
    final isOverspent = budget.spent > budget.amount;
    final remaining = budget.amount - budget.spent;

    // Calculate Forecasting
    final daysPassed = DateTime.now().difference(budget.startDate).inDays + 1;
    final totalDays = budget.endDate.difference(budget.startDate).inDays + 1;
    final dailyAvg = daysPassed > 0 ? budget.spent / daysPassed : budget.spent;
    final forecastedTotal = dailyAvg * totalDays;
    final isForecastOver = forecastedTotal > budget.amount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverspent 
              ? AppColors.error.withValues(alpha: 0.3) 
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTargetTitle(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Period: ${budget.period.toUpperCase()} (${DateFormatter.toDisplay(budget.startDate)} - ${DateFormatter.toDisplay(budget.endDate)})',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => _AddEditBudgetDialog(editBudget: budget),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Limit', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(budget.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Actual Spent', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(budget.spent),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isOverspent ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              color: isOverspent ? AppColors.error : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% utilized',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isOverspent ? AppColors.error : AppColors.textMuted,
                ),
              ),
              Text(
                remaining >= 0
                    ? '₹${CurrencyFormatter.format(remaining)} left'
                    : 'Over by ₹${CurrencyFormatter.format(-remaining)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: remaining >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Forecasting & Variance Panel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isForecastOver ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 16,
                      color: isForecastOver ? AppColors.error : AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Forecast: ₹${CurrencyFormatter.format(forecastedTotal)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isForecastOver ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Variance: ${remaining >= 0 ? "+" : ""}${CurrencyFormatter.format(remaining)} (${((remaining / (budget.amount > 0 ? budget.amount : 1)) * 100).toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: remaining >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTargetTitle() {
    switch (budget.targetType) {
      case 'category':
        return 'Category Budget';
      case 'account':
        return 'Account/Wallet Budget';
      case 'project':
        return 'Project: ${budget.targetName}';
      case 'department':
        return 'Department: ${budget.targetName}';
      default:
        return 'Budget Constraint';
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget?'),
        content: const Text('Are you sure you want to remove this budget restriction?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(budgetRepositoryProvider).deleteBudget(budget.id!);
              ref.invalidate(budgetsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _EmptyBudgetsState extends StatelessWidget {
  final bool isDark;
  const _EmptyBudgetsState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pie_chart_outline_rounded, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Budgets Defined',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create category-wise, account-wise, project-wise, or department-wise budgets to monitor your spending and enforce variance analysis constraints.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditBudgetDialog extends ConsumerStatefulWidget {
  final BudgetModel? editBudget;
  const _AddEditBudgetDialog({this.editBudget});

  @override
  ConsumerState<_AddEditBudgetDialog> createState() => _AddEditBudgetDialogState();
}

class _AddEditBudgetDialogState extends ConsumerState<_AddEditBudgetDialog> {
  final _amountCtrl = TextEditingController();
  final _targetNameCtrl = TextEditingController();
  String _targetType = 'category';
  String _period = 'monthly';
  int? _selectedCategoryId;
  int? _selectedAccountId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    if (widget.editBudget != null) {
      final b = widget.editBudget!;
      _amountCtrl.text = b.amount.toString();
      _targetNameCtrl.text = b.targetName ?? '';
      _targetType = b.targetType;
      _period = b.period;
      _selectedCategoryId = b.categoryId;
      _selectedAccountId = b.accountId;
      _startDate = b.startDate;
      _endDate = b.endDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(transactionCategoriesProvider('expense'));
    final accountsAsync = ref.watch(accountsProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.editBudget == null ? 'New Budget Goal' : 'Edit Budget Goal', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Target Type Selector
              DropdownButtonFormField<String>(
                value: _targetType,
                decoration: const InputDecoration(labelText: 'Budget Target Type'),
                items: const [
                  DropdownMenuItem(value: 'category', child: Text('Category')),
                  DropdownMenuItem(value: 'account', child: Text('Account / Wallet')),
                  DropdownMenuItem(value: 'project', child: Text('Project')),
                  DropdownMenuItem(value: 'department', child: Text('Department')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _targetType = val);
                },
              ),
              const SizedBox(height: 16),

              // Dynamic Target Value Fields
              if (_targetType == 'category')
                categoriesAsync.when(
                  data: (cats) => AppSearchableDropdown<int>(
                    value: _selectedCategoryId,
                    labelText: 'Expense Category',
                    isDark: isDark,
                    items: cats.map((c) => SearchableDropdownItem(value: c.id!, label: c.name)).toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error loading categories'),
                )
              else if (_targetType == 'account')
                accountsAsync.when(
                  data: (accounts) => AppSearchableDropdown<int>(
                    value: _selectedAccountId,
                    labelText: 'Account / Wallet',
                    isDark: isDark,
                    items: accounts.map((a) => SearchableDropdownItem(value: a.id!, label: a.name)).toList(),
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error loading accounts'),
                )
              else
                TextField(
                  controller: _targetNameCtrl,
                  decoration: InputDecoration(
                    labelText: _targetType == 'project' ? 'Project Name' : 'Department Name',
                    border: const OutlineInputBorder(),
                  ),
                ),

              const SizedBox(height: 16),
              // Budget Limit Amount
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Budget Spending Limit',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),
              // Period Dropdown
              DropdownButtonFormField<String>(
                value: _period,
                decoration: const InputDecoration(labelText: 'Budget Cycle'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _period = val;
                      final now = DateTime.now();
                      if (_period == 'monthly') {
                        _startDate = DateTime(now.year, now.month, 1);
                        _endDate = DateTime(now.year, now.month + 1, 0);
                      } else if (_period == 'quarterly') {
                        _startDate = now;
                        _endDate = now.add(const Duration(days: 90));
                      } else if (_period == 'yearly') {
                        _startDate = DateTime(now.year, 1, 1);
                        _endDate = DateTime(now.year, 12, 31);
                      }
                    });
                  }
                },
              ),

              const SizedBox(height: 16),
              // Start & End Date row
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text('Start: ${DateFormatter.toDisplay(_startDate)}'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _endDate = picked);
                      },
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text('End: ${DateFormatter.toDisplay(_endDate)}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saveBudget,
          child: Text(widget.editBudget == null ? 'Create Budget' : 'Save Changes'),
        ),
      ],
    );
  }

  void _saveBudget() async {
    final amt = double.tryParse(_amountCtrl.text);
    if (amt == null || amt <= 0) return;

    final businessId = ref.read(activeBusinessIdProvider);

    final budget = BudgetModel(
      id: widget.editBudget?.id,
      businessId: businessId,
      targetType: _targetType,
      targetName: _targetType == 'project' || _targetType == 'department' ? _targetNameCtrl.text.trim() : null,
      categoryId: _targetType == 'category' ? _selectedCategoryId : null,
      accountId: _targetType == 'account' ? _selectedAccountId : null,
      amount: amt,
      period: _period,
      startDate: _startDate,
      endDate: _endDate,
    );

    if (widget.editBudget == null) {
      await ref.read(budgetRepositoryProvider).addBudget(budget);
    } else {
      await ref.read(budgetRepositoryProvider).updateBudget(budget);
    }

    ref.invalidate(budgetsProvider);
    if (mounted) Navigator.pop(context);
  }
}
