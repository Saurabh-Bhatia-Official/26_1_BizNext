// lib/features/auth/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_seen_installation_onboarding') ?? false;
      if (!hasSeen) {
        ref.read(showOnboardingProvider.notifier).state = true;
      } else {
        ref.read(splashCompleteProvider.notifier).state = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C17) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── Background Glow ──
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.15, 1.15), duration: 2.seconds, curve: Curves.easeInOut),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Brand Logo ──
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.18),
                        blurRadius: 32,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.storefront_rounded, size: 48, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fade(duration: 800.ms)
                    .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),

                const SizedBox(height: 24),

                // ── Platform Title ──
                Text(
                  'BIZNEXT',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.15, end: 0),

                const SizedBox(height: 8),

                Text(
                  'Enterprise Business Platform v1.0.0',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ).animate().fadeIn(delay: 700.ms),

                const SizedBox(height: 52),

                // ── Loading Bar ──
                SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 4,
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms),
              ],
            ),
          ),

          // ── Bottom Telemetry Info ──
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Securing your business workspace & accounts...',
                style: TextStyle(
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ).animate().fadeIn(delay: 1100.ms),
          ),
        ],
      ),
    );
  }
}
