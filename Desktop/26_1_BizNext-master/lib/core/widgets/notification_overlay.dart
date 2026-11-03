// lib/core/widgets/notification_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';

class NotificationOverlay extends ConsumerWidget {
  const NotificationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    if (notifications.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 24,
      right: 24,
      child: SizedBox(
        width: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: notifications.reversed
              .map((n) => _NotificationCard(notification: n, key: ValueKey(n.id)))
              .toList(),
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationCard({required this.notification, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    IconData icon;
    switch (notification.type) {
      case NotificationType.success:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case NotificationType.error:
        color = AppColors.error;
        icon = Icons.error_rounded;
        break;
      case NotificationType.warning:
        color = AppColors.warning;
        icon = Icons.warning_rounded;
        break;
      case NotificationType.info:
        color = AppColors.info;
        icon = Icons.info_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: notification.onUndo == null
            ? () => ref.read(notificationProvider.notifier).remove(notification.id)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (notification.title != null)
                      Text(
                        notification.title!,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: isDark ? AppColors.textMuted : Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Undo button (only shown when onUndo is provided)
              if (notification.onUndo != null) ...[
                TextButton(
                  onPressed: () async {
                    ref.read(notificationProvider.notifier).remove(notification.id);
                    await notification.onUndo!();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: color.withValues(alpha: 0.4)),
                    ),
                  ),
                  child: const Text('Undo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                onPressed: () => ref.read(notificationProvider.notifier).remove(notification.id),
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideX(begin: 1, end: 0, curve: Curves.easeOutCubic, duration: 400.ms).fadeIn();
  }
}
