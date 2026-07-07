import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class SyncModeNotifier extends StateNotifier<String?> {
  SyncModeNotifier(String? mode) : super(mode);
  void setMode(String mode) => state = mode;
}

final syncModeProvider = StateNotifierProvider<SyncModeNotifier, String?>((ref) {
  throw UnimplementedError('SyncModeNotifier must be overridden in ProviderScope');
});

class SyncModeScreen extends ConsumerWidget {
  const SyncModeScreen({super.key});

  Future<void> _selectMode(BuildContext context, WidgetRef ref, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefSyncMode, mode);
    ref.read(syncModeProvider.notifier).setMode(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF0F0F1A)),
          Positioned(top: -120, left: -120, child: _GlowOrb(color: AppColors.primary, size: 400)),
          Positioned(bottom: -120, right: -120, child: _GlowOrb(color: AppColors.accent, size: 400)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', width: 100, height: 100, fit: BoxFit.contain),
                  const SizedBox(height: 24),
                  const Text(
                    'BizNext ERP',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose your preferred mode to get started',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  _ModeCard(
                    icon: Icons.cloud_done_rounded,
                    title: 'Go Online',
                    subtitle: 'Store data in the cloud via Firebase.\nSync across devices. Requires internet.',
                    color: AppColors.primary,
                    onTap: () => _selectMode(context, ref, 'online'),
                  ),
                  const SizedBox(height: 20),
                  _ModeCard(
                    icon: Icons.storage_rounded,
                    title: 'Stay Offline',
                    subtitle: 'Store all data locally on this device.\nNo internet required. Fully private.',
                    color: Colors.amber,
                    onTap: () => _selectMode(context, ref, 'offline'),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'You can change this later in Settings',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: 0.12), Colors.transparent])),
    );
  }
}
