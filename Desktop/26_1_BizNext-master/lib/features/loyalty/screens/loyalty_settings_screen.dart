// lib/features/loyalty/screens/loyalty_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/notification_provider.dart';
import '../providers/loyalty_provider.dart';
import '../models/loyalty_model.dart';

class LoyaltySettingsScreen extends ConsumerStatefulWidget {
  const LoyaltySettingsScreen({super.key});

  @override
  ConsumerState<LoyaltySettingsScreen> createState() => _LoyaltySettingsScreenState();
}

class _LoyaltySettingsScreenState extends ConsumerState<LoyaltySettingsScreen> {
  late TextEditingController _earnRateCtrl;
  late TextEditingController _earnSpendCtrl;
  late TextEditingController _redeemValueCtrl;
  late TextEditingController _minRedeemCtrl;
  late TextEditingController _pointNameCtrl;
  late TextEditingController _welcomePtsCtrl;
  late TextEditingController _expiryCtrl;

  @override
  void initState() {
    super.initState();
    _earnRateCtrl = TextEditingController();
    _earnSpendCtrl = TextEditingController();
    _redeemValueCtrl = TextEditingController();
    _minRedeemCtrl = TextEditingController();
    _pointNameCtrl = TextEditingController();
    _welcomePtsCtrl = TextEditingController();
    _expiryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _earnRateCtrl.dispose();
    _earnSpendCtrl.dispose();
    _redeemValueCtrl.dispose();
    _minRedeemCtrl.dispose();
    _pointNameCtrl.dispose();
    _welcomePtsCtrl.dispose();
    _expiryCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(LoyaltySettings settings) {
    _earnRateCtrl.text = settings.earnRate.toString();
    _earnSpendCtrl.text = settings.earnSpendAmount.toString();
    _redeemValueCtrl.text = settings.redeemValue.toString();
    _minRedeemCtrl.text = settings.minRedeemPoints.toString();
    _pointNameCtrl.text = settings.pointName;
    _welcomePtsCtrl.text = settings.welcomePoints.toString();
    _expiryCtrl.text = settings.expiryDays.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(loyaltySettingsProvider);

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Only sync once or when state changes externally
    if (_pointNameCtrl.text.isEmpty) {
      _syncControllers(settings);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textLight),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Loyalty Program Settings',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.textLight),
                  ),
                ),
              ],
            ),
            const Text('Configure how your customers earn and redeem points', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 40),

            _Section(
              title: 'Program Status',
              isDark: isDark,
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Enable Loyalty Program', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: const Text('Allow customers to earn points on purchases', style: TextStyle(fontSize: 12)),
                  value: settings.isActive,
                  onChanged: (v) {
                    ref.read(loyaltySettingsProvider.notifier).updateSettings(settings.copyWith(isActive: v));
                  },
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),

            const SizedBox(height: 32),

            _Section(
              title: 'Earning Rules',
              isDark: isDark,
              children: [
                _InputTile(
                  label: 'Point Name',
                  hint: 'e.g. Points, Stars, Coins',
                  controller: _pointNameCtrl,
                  icon: Icons.label_important_rounded,
                ),
                _InputTile(
                  label: 'Points Earned',
                  hint: '1.0',
                  controller: _earnRateCtrl,
                  icon: Icons.add_circle_outline_rounded,
                  keyboardType: TextInputType.number,
                ),
                _InputTile(
                  label: 'Amount Spent to Earn (₹)',
                  hint: '100.0',
                  controller: _earnSpendCtrl,
                  icon: Icons.currency_rupee_rounded,
                  keyboardType: TextInputType.number,
                ),
                _InputTile(
                  label: 'Welcome Points',
                  hint: 'Points for new registration',
                  controller: _welcomePtsCtrl,
                  icon: Icons.card_giftcard_rounded,
                  keyboardType: TextInputType.number,
                ),
                _InputTile(
                  label: 'Points Expiry (Days)',
                  hint: '365',
                  controller: _expiryCtrl,
                  icon: Icons.timer_rounded,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),

            const SizedBox(height: 32),

            _Section(
              title: 'Redemption Rules',
              isDark: isDark,
              children: [
                _InputTile(
                  label: 'Redeem Value (₹ per 1 point)',
                  hint: '1.0',
                  controller: _redeemValueCtrl,
                  icon: Icons.monetization_on_rounded,
                  keyboardType: TextInputType.number,
                ),
                _InputTile(
                  label: 'Minimum Points to Redeem',
                  hint: '100',
                  controller: _minRedeemCtrl,
                  icon: Icons.shopping_basket_rounded,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),

            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  final newSettings = settings.copyWith(
                    pointName: _pointNameCtrl.text.trim(),
                    earnRate: double.tryParse(_earnRateCtrl.text) ?? 1.0,
                    earnSpendAmount: double.tryParse(_earnSpendCtrl.text) ?? 100.0,
                    redeemValue: double.tryParse(_redeemValueCtrl.text) ?? 1.0,
                    minRedeemPoints: double.tryParse(_minRedeemCtrl.text) ?? 100.0,
                    welcomePoints: double.tryParse(_welcomePtsCtrl.text) ?? 0.0,
                    expiryDays: int.tryParse(_expiryCtrl.text) ?? 365,
                  );
                  
                  await ref.read(loyaltySettingsProvider.notifier).updateSettings(newSettings);
                  if (context.mounted) {
                    AppAlert.success(ref, 'Loyalty settings saved successfully!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('SAVE CONFIGURATION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;
  const _Section({required this.title, required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InputTile extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;

  const _InputTile({
    required this.label, 
    required this.hint, 
    required this.controller, 
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
