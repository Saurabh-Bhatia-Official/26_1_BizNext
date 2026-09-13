// lib/features/onboarding/screens/onboarding_tutorial_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class OnboardingTutorialScreen extends ConsumerStatefulWidget {
  const OnboardingTutorialScreen({super.key});

  @override
  ConsumerState<OnboardingTutorialScreen> createState() => _OnboardingTutorialScreenState();
}

class _OnboardingTutorialScreenState extends ConsumerState<OnboardingTutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      icon: Icons.point_of_sale_rounded,
      badgeText: 'FEATURE 1/5',
      title: 'Smart POS & Express Billing',
      description: 'Lightning-fast checkout, barcode scanner support, custom invoices, offline mode, and instant thermal receipt printing.',
      gradientColors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    ),
    _OnboardingPageData(
      icon: Icons.inventory_2_rounded,
      badgeText: 'FEATURE 2/5',
      title: 'Complete Inventory Control',
      description: 'Real-time stock tracking, low-stock warnings, batch management, price tiers, and barcode generation.',
      gradientColors: [Color(0xFF10B981), Color(0xFF047857)],
    ),
    _OnboardingPageData(
      icon: Icons.people_rounded,
      badgeText: 'FEATURE 3/5',
      title: 'Customers & Supplier Ledgers',
      description: 'Comprehensive party management with credit limit alerts, purchase orders, balance ledgers, and transaction history.',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
    _OnboardingPageData(
      icon: Icons.account_balance_wallet_rounded,
      badgeText: 'FEATURE 4/5',
      title: 'Finance, Budgets & Accounts',
      description: 'Multiple cash and bank accounts tracking, automated profit & loss summaries, expense categories, and monthly targets.',
      gradientColors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    ),
    _OnboardingPageData(
      icon: Icons.insights_rounded,
      badgeText: 'FEATURE 5/5',
      title: 'AI Business Assistant & Reports',
      description: 'Automated revenue insights, executive financial reports, intelligent chatbot advice, and real-time business analytics.',
      gradientColors: [Color(0xFFEC4899), Color(0xFFBE185D)],
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_installation_onboarding', true);
    if (mounted) {
      ref.read(showOnboardingProvider.notifier).state = false;
      ref.read(splashCompleteProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar with Logo & Skip ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'BIZNEXT',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text('SKIP', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),

            // ── Slides ──
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final data = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon Card
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: data.gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: data.gradientColors[0].withValues(alpha: 0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              )
                            ],
                          ),
                          child: Icon(data.icon, size: 70, color: Colors.white),
                        ).animate(key: ValueKey(index)).fade(duration: 500.ms).scale(duration: 500.ms, curve: Curves.elasticOut),

                        const SizedBox(height: 36),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: data.gradientColors[0].withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: data.gradientColors[0].withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            data.badgeText,
                            style: TextStyle(
                              color: data.gradientColors[0],
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Title
                        Text(
                          data.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textLight,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Description
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 450),
                          child: Text(
                            data.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Footer Navigation ──
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: 300.ms,
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == i ? 28 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? AppColors.primary : (isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  // Next / Get Started Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    onPressed: () {
                      if (isLastPage) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    icon: Icon(isLastPage ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 20),
                    label: Text(
                      isLastPage ? 'GET STARTED' : 'NEXT',
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String badgeText;
  final String title;
  final String description;
  final List<Color> gradientColors;

  const _OnboardingPageData({
    required this.icon,
    required this.badgeText,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}
