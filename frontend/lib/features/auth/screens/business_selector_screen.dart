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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back to Sign In',
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              size: 20,
            ),
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              _showBackDialog(context, ref);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPhone ? 'Workspaces' : 'Enterprise Workspace Directory',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: isPhone ? 16 : 18,
                letterSpacing: -0.5,
              ),
            ),
            if (!isPhone)
              Text(
                'Select an active workspace or register a new business entity',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
        actions: [
          _ProfileSummary(user: user, ref: ref, isPhone: isPhone),
          SizedBox(width: isPhone ? 8 : 16),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0F0F1A), Color(0xFF13132B)]
                : const [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Subheader ──
              _SelectorHeader(user: user, isDark: isDark, isPhone: isPhone),

              SizedBox(height: isPhone ? 8 : 12),

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

  void _showBackDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            const SizedBox(width: 10),
            Text(
              'Return to Sign In?',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Returning will sign you out of your current session. Do you want to continue?',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay on Hub'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Return to Sign In'),
          ),
        ],
      ),
    );
  }
}

class _SelectorHeader extends StatelessWidget {
  final dynamic user;
  final bool isDark;
  final bool isPhone;
  const _SelectorHeader({required this.user, required this.isDark, this.isPhone = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isPhone ? 16 : 40, isPhone ? 16 : 24, isPhone ? 16 : 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'BIZNEXT ENTERPRISE CLOUD',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: isPhone ? 10 : 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isPhone ? 10 : 16),
          Text(
            'Welcome back, ${user?.fullName ?? 'User'}',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: isPhone ? 22 : 32,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: isPhone ? -0.5 : -1.2,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 6),
          Text(
            'Select an active workspace to resume enterprise operations or register a new business entity.',
            style: TextStyle(
              color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
              fontSize: isPhone ? 13 : 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final dynamic user;
  final WidgetRef ref;
  final bool isPhone;
  const _ProfileSummary({required this.user, required this.ref, this.isPhone = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isPhone) {
      return IconButton(
        tooltip: 'Sign Out (${user?.fullName ?? 'User'})',
        onPressed: () => _showLogoutDialog(context, ref),
        icon: CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary,
          child: Text(
            user?.initials ?? 'U',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showLogoutDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primary,
              child: Text(
                user?.initials ?? 'U',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              user?.fullName ?? 'User',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.logout_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black54),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Sign Out of Session?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You will return to the sign-in screen.',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
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
        final isMobile = constraints.maxWidth < 600;
        final crossCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1));
        final all = [...businesses, null];

        return GridView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: isMobile ? 12 : 20,
          ),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: isMobile ? 14 : 24,
            mainAxisSpacing: isMobile ? 14 : 24,
            childAspectRatio: isMobile ? 1.45 : 1.2,
          ),
          itemCount: all.length,
          itemBuilder: (ctx, i) {
            final item = all[i];
            if (item == null) return _AddCard(ref: ref, isMobile: isMobile);
            return _BizCard(business: item, index: i, ref: ref, isMobile: isMobile);
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
  final bool isMobile;
  const _BizCard({required this.business, required this.index, required this.ref, this.isMobile = false});

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
          padding: EdgeInsets.all(widget.isMobile ? 18 : 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(widget.isMobile ? 22 : 32),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: _isHovered ? 0.5 : 0.25),
                blurRadius: _isHovered ? 28 : 14,
                offset: Offset(0, _isHovered ? 12 : 6),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: widget.isMobile ? 44 : 52,
                height: widget.isMobile ? 44 : 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(widget.isMobile ? 12 : 16),
                ),
                child: Center(
                  child: Text(
                    widget.business.initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.isMobile ? 15 : 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.business.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.isMobile ? 17 : 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.work_outline_rounded, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.business.type,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: widget.isMobile ? 12 : 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateBusinessScreen(initialBusiness: widget.business),
                          ),
                        );
                      } else if (value == 'delete') {
                        _confirmDelete(context, widget.ref, widget.business);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 12), Text('Edit')]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete Business Workspace?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${biz.name}"? This will hide it from your workspace list.',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
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
            child: const Text('Delete Workspace'),
          ),
        ],
      ),
    );
  }
}

class _AddCard extends StatefulWidget {
  final WidgetRef ref;
  final bool isMobile;
  const _AddCard({required this.ref, this.isMobile = false});
  @override
  State<_AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<_AddCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateBusinessScreen())),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.all(widget.isMobile ? 18 : 24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(widget.isMobile ? 22 : 32),
            border: Border.all(
              color: _isHovered ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1)),
              width: 2,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: widget.isMobile ? 44 : 56,
                height: widget.isMobile ? 44 : 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(widget.isMobile ? 12 : 18),
                ),
                child: Icon(Icons.add_business_rounded, color: AppColors.primary, size: widget.isMobile ? 24 : 30),
              ),
              SizedBox(height: widget.isMobile ? 10 : 16),
              Text(
                'Register Business',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: widget.isMobile ? 14 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Add new enterprise workspace',
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  fontSize: widget.isMobile ? 11 : 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).scale();
  }
}
