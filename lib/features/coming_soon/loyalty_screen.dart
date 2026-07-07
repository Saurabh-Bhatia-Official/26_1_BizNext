// lib/features/coming_soon/loyalty_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/app_constants.dart';
import '../loyalty/providers/loyalty_provider.dart';
import '../customers/providers/customer_provider.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(loyaltySettingsProvider);

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.stars_rounded, color: AppColors.primary, size: 32),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loyalty & Rewards',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const Text(
                      'Configure earning rules, redemption limits and reward branding',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      settings.isActive ? 'PROGRAM ACTIVE' : 'PROGRAM INACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: settings.isActive ? AppColors.success : AppColors.error,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Switch(
                      value: settings.isActive,
                      activeThumbColor: AppColors.success,
                      onChanged: (v) {
                        ref.read(loyaltySettingsProvider.notifier).updateSettings(settings.copyWith(isActive: v));
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.4,
                      ),
                      children: [
                        _buildSettingCard(
                          context,
                          'Reward Branding',
                          'Custom name for your points',
                          Icons.label_important_rounded,
                          settings.pointName,
                          (val) => ref.read(loyaltySettingsProvider.notifier).updateSettings(
                            settings.copyWith(pointName: val)
                          ),
                          isText: true,
                        ),
                        _buildSettingCard(
                          context,
                          'Points Earning Rate',
                          'Points earned per ₹100 spent',
                          Icons.add_chart_rounded,
                          settings.earnRate.toString(),
                          (val) => ref.read(loyaltySettingsProvider.notifier).updateSettings(
                            settings.copyWith(earnRate: double.tryParse(val) ?? 1.0)
                          ),
                        ),
                        _buildSettingCard(
                          context,
                          'Redemption Value',
                          '₹ value of each ${settings.pointName.toLowerCase()}',
                          Icons.monetization_on_rounded,
                          settings.redeemValue.toString(),
                          (val) => ref.read(loyaltySettingsProvider.notifier).updateSettings(
                            settings.copyWith(redeemValue: double.tryParse(val) ?? 1.0)
                          ),
                        ),
                        _buildSettingCard(
                          context,
                          'Minimum to Redeem',
                          'Minimum ${settings.pointName.toLowerCase()} needed',
                          Icons.lock_clock_rounded,
                          settings.minRedeemPoints.toString(),
                          (val) => ref.read(loyaltySettingsProvider.notifier).updateSettings(
                            settings.copyWith(minRedeemPoints: double.tryParse(val) ?? 100.0)
                          ),
                        ),
                        _buildSettingCard(
                          context,
                          'Max Limit / Bill',
                          'Max ${settings.pointName.toLowerCase()} per invoice',
                          Icons.do_not_disturb_on_rounded,
                          settings.maxRedeemLimit == 0 ? 'No Limit' : settings.maxRedeemLimit.toString(),
                          (val) => ref.read(loyaltySettingsProvider.notifier).updateSettings(
                            settings.copyWith(maxRedeemLimit: double.tryParse(val) ?? 0)
                          ),
                        ),
                        _buildSettingCard(
                          context,
                          'Welcome Reward',
                          'Points for new customers',
                          Icons.card_giftcard_rounded,
                          settings.welcomePoints.toString(),
                          (val) => ref.read(loyaltySettingsProvider.notifier).updateSettings(
                            settings.copyWith(welcomePoints: double.tryParse(val) ?? 0)
                          ),
                        ),
                        _buildSettingCard(
                          context,
                          'Points Expiry',
                          'Days before points expire',
                          Icons.history_toggle_off_rounded,
                          settings.expiryDays.toString(),
                          (val) => ref.read(loyaltySettingsProvider.notifier).updateSettings(
                            settings.copyWith(expiryDays: int.tryParse(val) ?? 365)
                          ),
                        ),
                        _buildActionCard(
                          context,
                          'Customer Balances',
                          'Adjust or reset point balances',
                          Icons.manage_accounts_rounded,
                          'MANAGE DATABASE',
                          () => _showCustomerPointsManager(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, 
    String title, 
    String subtitle, 
    IconData icon, 
    String value, 
    Function(String) onSave,
    {bool isText = false}
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppConstants.sidebarBreakpoint > 1000 ? AppColors.darkBorder : AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Spacer(),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                onPressed: () => _showEditDialog(context, title, value, onSave, isText: isText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, 
    String title, 
    String subtitle, 
    IconData icon, 
    String actionLabel, 
    VoidCallback onTap
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerPointsManager(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerPointsDialog(),
    );
  }

  void _showEditDialog(BuildContext context, String title, String current, Function(String) onSave, {bool isText = false}) {
    final controller = TextEditingController(text: isText ? current : current.replaceAll(RegExp(r'[^0-9.]'), ''));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $title'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: controller,
          keyboardType: isText ? TextInputType.text : TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter new value',
            prefixIcon: Icon(isText ? Icons.edit_note_rounded : Icons.numbers_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _CustomerPointsDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CustomerPointsDialog> createState() => _CustomerPointsDialogState();
}

class _CustomerPointsDialogState extends ConsumerState<_CustomerPointsDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Manage Customer Points', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: customersAsync.when(
                data: (customers) {
                  final filtered = customers.where((c) => 
                    c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (c.phone ?? '').contains(_searchQuery)
                  ).toList();

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final c = filtered[i];
                      return ListTile(
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(c.phone ?? 'No Phone'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                c.loyaltyPoints.toInt().toString(),
                                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 20),
                              onPressed: () => _adjustPoints(context, ref, c),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _adjustPoints(BuildContext context, WidgetRef ref, dynamic customer) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Points: ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Points: ${customer.loyaltyPoints.toInt()}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Adjustment Amount (+/-)',
                hintText: 'e.g., 50 or -20',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final adj = double.tryParse(controller.text) ?? 0.0;
              await DatabaseHelper.instance.update(
                AppConstants.tblCustomers, 
                {'loyalty_points': customer.loyaltyPoints + adj}, 
                customer.id
              );
              ref.refresh(customersProvider);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
