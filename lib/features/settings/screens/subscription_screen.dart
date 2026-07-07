// lib/features/settings/screens/subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/app_theme.dart';
import 'razorpay_gateway_screen.dart';
import 'payment_history_screen.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final subService = ref.watch(subscriptionServiceProvider);
    final isPro = subService.isPro;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, size: 80, color: Colors.amber),
            const SizedBox(height: 12),
            Text(
              isPro ? 'You are a PRO Member!' : 'Upgrade to BizNext PRO',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isPro ? 'Enjoy unlimited sync and advanced cloud features.' : 'Unlock full potential, online backups, and cloud storage.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _PlanCard(
                    title: 'Free Plan',
                    price: '₹0',
                    features: const [
                      'Offline-Only operations',
                      'Max 10 products',
                      'Max 10 invoices',
                      'Max 10 customers',
                      'No Cloud Sync/Backups',
                    ],
                    isActive: !isPro,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PlanCard(
                    title: 'Pro Plan',
                    price: '₹499/mo',
                    features: const [
                      'Automatic background cloud sync',
                      'Unlimited products & invoices',
                      'Unlimited business profiles',
                      'Cloudinary media storage',
                      '24/7 dedicated support',
                    ],
                    isActive: isPro,
                    isProColor: true,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            if (!isPro)
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () => _handleUpgrade(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                      ),
                      child: const Text('Upgrade via Razorpay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
            else ...[
              const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 50),
              const SizedBox(height: 12),
              const Text('Active via Razorpay Subscriptions', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _handleChangePlan(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Change Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () => _handleCancelSubscription(context, subService),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Cancel Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('View Payment History'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpgrade(BuildContext context) async {
    setState(() => _isLoading = true);
    final subService = ref.read(subscriptionServiceProvider);
    
    // Simulate/Initiate subscription via backend api
    final res = await subService.initiateProSubscription("dummy_token_12345");
    setState(() => _isLoading = false);

    if (res != null && context.mounted) {
      // Open the Razorpay payment gateway options directly inside the software (in-app view)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RazorpayGatewayScreen(subId: res["id"]),
        ),
      );
    }
  }

  void _handleChangePlan(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Subscription Plan'),
        content: const Text(
          'You are currently on the Pro Monthly Plan (₹499/mo). If you would like to switch to a different cycle (e.g. Annual Plan at discount, or custom corporate plans), please contact support or initiate a change order session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Plan change request submitted to Razorpay Billing...')),
              );
            },
            child: const Text('Contact Billing'),
          )
        ],
      ),
    );
  }

  void _handleCancelSubscription(BuildContext context, SubscriptionService subService) {
    final expiryDate = DateTime.now().add(const Duration(days: 15));
    final expiryStr = "${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirm Cancellation'),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel your subscription?\n\n'
          '• Your premium features will remain active until the expiry date: $expiryStr.\n'
          '• After $expiryStr, the following features will NO LONGER be accessible:\n'
          '  - Automatic cloud data sync & background backups\n'
          '  - Adding unlimited products, customers, and invoices (reverts to free limits)\n'
          '  - Media storage on Cloudinary\n'
          '  - Premium custom invoice templates',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep My Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              await subService.setTier('free');
              setState(() => _isLoading = false);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Subscription Cancelled. Premium features expire on $expiryStr.'),
                    duration: const Duration(seconds: 5),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final bool isActive;
  final bool isProColor;
  final bool isDark;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.isActive,
    this.isProColor = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isActive
        ? (isProColor ? Colors.amber : AppColors.primary)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isActive ? 2.5 : 1),
        boxShadow: isActive
            ? [BoxShadow(color: borderColor.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 2)]
            : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isActive)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isProColor ? Colors.amber : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(price, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isProColor ? Colors.amber : null)),
          const Divider(height: 24),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
