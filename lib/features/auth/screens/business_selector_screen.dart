// lib/features/auth/screens/business_selector_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/business_model.dart';
import '../providers/auth_provider.dart';
import 'create_business_screen.dart';

const _cardGradients = [
  [Color(0xFF6366F1), Color(0xFF4F46E5)], // Indigo
  [Color(0xFF0EA5E9), Color(0xFF0284C7)], // Sky
  [Color(0xFF10B981), Color(0xFF059669)], // Emerald
  [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber
  [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // Violet
  [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal
];

List<Color> _gradientFor(int index) => _cardGradients[index % _cardGradients.length];

class BusinessSelectorScreen extends ConsumerWidget {
  const BusinessSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final businessesAsync = ref.watch(userBusinessesProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F1A), Color(0xFF13132B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              _SelectorHeader(user: user, ref: ref),

              const SizedBox(height: 20),

              // ── Main Grid ──
              Expanded(
                child: businessesAsync.when(
                  data: (businesses) => _BusinessGrid(businesses: businesses, ref: ref),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorHeader extends StatelessWidget {
  final dynamic user;
  final WidgetRef ref;
  const _SelectorHeader({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('✦ BizNext', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome back,\n${user?.fullName ?? 'User'}',
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1.5),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),
                const Text('Select a workspace to continue your progress', style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          _ProfileSummary(user: user, ref: ref),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final dynamic user;
  final WidgetRef ref;
  const _ProfileSummary({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLogoutDialog(context, ref),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Center(
              child: Text(user?.initials ?? 'U', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Logout', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ).animate().fadeIn(duration: 600.ms, delay: 200.ms).scale(),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sign Out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _BusinessGrid extends StatelessWidget {
  final List<BusinessModel> businesses;
  final WidgetRef ref;
  const _BusinessGrid({required this.businesses, required this.ref});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : 2);
        final all = [...businesses, null];

        return GridView.builder(
          padding: const EdgeInsets.all(40),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.1,
          ),
          itemCount: all.length,
          itemBuilder: (ctx, i) {
            final item = all[i];
            if (item == null) return _AddCard(ref: ref);
            return _BizCard(business: item, index: i, ref: ref);
          },
        );
      },
    );
  }
}

class _BizCard extends StatefulWidget {
  final BusinessModel business;
  final int index;
  final WidgetRef ref;
  const _BizCard({required this.business, required this.index, required this.ref});

  @override
  State<_BizCard> createState() => _BizCardState();
}

class _BizCardState extends State<_BizCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _gradientFor(widget.index);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.ref.read(authProvider.notifier).selectBusiness(widget.business),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: _isHovered ? 0.6 : 0.3),
                blurRadius: _isHovered ? 30 : 15,
                offset: Offset(0, _isHovered ? 12 : 8),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                child: Center(child: Text(widget.business.initials, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.business.name,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.work_outline_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 6),
                          Text(widget.business.type, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CreateBusinessScreen(initialBusiness: widget.business)));
                      } else if (value == 'delete') {
                        _confirmDelete(context, widget.ref, widget.business);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 12), Text('Edit')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 12), Text('Delete', style: TextStyle(color: AppColors.error))])),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: (widget.index * 50).ms).scale(begin: const Offset(0.95, 0.95));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BusinessModel biz) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Business?'),
        content: Text('Are you sure you want to delete "${biz.name}"? This will hide it from your list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(authProvider.notifier).deleteBusiness(biz.id!);
              if (success && ctx.mounted) {
                ref.invalidate(userBusinessesProvider);
                Navigator.pop(ctx);
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

class _AddCard extends StatefulWidget {
  final WidgetRef ref;
  const _AddCard({required this.ref});
  @override
  State<_AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<_AddCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateBusinessScreen())),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: _isHovered ? AppColors.primary : Colors.white.withValues(alpha: 0.1), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Add Business', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const Text('Create new workspace', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).scale();
  }
}
