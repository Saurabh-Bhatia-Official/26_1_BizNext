// lib/features/notifications/models/notification_item_model.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum SystemNotificationType {
  lowStock,
  duePayment,
  salesMilestone,
  system,
  syncBackup,
  customerLoyalty,
  promotional;

  String get value {
    switch (this) {
      case SystemNotificationType.lowStock:
        return 'low_stock';
      case SystemNotificationType.duePayment:
        return 'due_payment';
      case SystemNotificationType.salesMilestone:
        return 'sales_milestone';
      case SystemNotificationType.system:
        return 'system';
      case SystemNotificationType.syncBackup:
        return 'sync_backup';
      case SystemNotificationType.customerLoyalty:
        return 'customer_loyalty';
      case SystemNotificationType.promotional:
        return 'promotional';
    }
  }

  static SystemNotificationType fromString(String? type) {
    switch (type?.toLowerCase().trim()) {
      case 'low_stock':
        return SystemNotificationType.lowStock;
      case 'due_payment':
        return SystemNotificationType.duePayment;
      case 'sales_milestone':
        return SystemNotificationType.salesMilestone;
      case 'sync_backup':
        return SystemNotificationType.syncBackup;
      case 'customer_loyalty':
        return SystemNotificationType.customerLoyalty;
      case 'promotional':
        return SystemNotificationType.promotional;
      case 'system':
      default:
        return SystemNotificationType.system;
    }
  }

  String get displayName {
    switch (this) {
      case SystemNotificationType.lowStock:
        return 'Inventory Alert';
      case SystemNotificationType.duePayment:
        return 'Payment & Dues';
      case SystemNotificationType.salesMilestone:
        return 'Sales Milestone';
      case SystemNotificationType.system:
        return 'System Notification';
      case SystemNotificationType.syncBackup:
        return 'Cloud & Sync';
      case SystemNotificationType.customerLoyalty:
        return 'Loyalty Reward';
      case SystemNotificationType.promotional:
        return 'Promotion';
    }
  }

  IconData get icon {
    switch (this) {
      case SystemNotificationType.lowStock:
        return Icons.inventory_2_rounded;
      case SystemNotificationType.duePayment:
        return Icons.account_balance_wallet_rounded;
      case SystemNotificationType.salesMilestone:
        return Icons.trending_up_rounded;
      case SystemNotificationType.system:
        return Icons.notifications_active_rounded;
      case SystemNotificationType.syncBackup:
        return Icons.cloud_done_rounded;
      case SystemNotificationType.customerLoyalty:
        return Icons.stars_rounded;
      case SystemNotificationType.promotional:
        return Icons.local_offer_rounded;
    }
  }

  Color get color {
    switch (this) {
      case SystemNotificationType.lowStock:
        return Colors.orange;
      case SystemNotificationType.duePayment:
        return AppColors.error;
      case SystemNotificationType.salesMilestone:
        return AppColors.success;
      case SystemNotificationType.system:
        return AppColors.primary;
      case SystemNotificationType.syncBackup:
        return Colors.teal;
      case SystemNotificationType.customerLoyalty:
        return Colors.purple;
      case SystemNotificationType.promotional:
        return Colors.indigo;
    }
  }
}

enum SystemNotificationPriority {
  low,
  medium,
  high,
  urgent;

  String get value => name;

  static SystemNotificationPriority fromString(String? priority) {
    switch (priority?.toLowerCase().trim()) {
      case 'low':
        return SystemNotificationPriority.low;
      case 'high':
        return SystemNotificationPriority.high;
      case 'urgent':
        return SystemNotificationPriority.urgent;
      case 'medium':
      default:
        return SystemNotificationPriority.medium;
    }
  }

  Color get color {
    switch (this) {
      case SystemNotificationPriority.low:
        return Colors.blueGrey;
      case SystemNotificationPriority.medium:
        return AppColors.primary;
      case SystemNotificationPriority.high:
        return Colors.orange;
      case SystemNotificationPriority.urgent:
        return AppColors.error;
    }
  }
}

class NotificationItemModel {
  final int? id;
  final int businessId;
  final String title;
  final String message;
  final SystemNotificationType type;
  final SystemNotificationPriority priority;
  final bool isRead;
  final String? actionType;
  final String? actionData;
  final DateTime timestamp;
  final DateTime createdAt;

  const NotificationItemModel({
    this.id,
    this.businessId = 1,
    required this.title,
    required this.message,
    this.type = SystemNotificationType.system,
    this.priority = SystemNotificationPriority.medium,
    this.isRead = false,
    this.actionType,
    this.actionData,
    required this.timestamp,
    required this.createdAt,
  });

  factory NotificationItemModel.now({
    int? id,
    int businessId = 1,
    required String title,
    required String message,
    SystemNotificationType type = SystemNotificationType.system,
    SystemNotificationPriority priority = SystemNotificationPriority.medium,
    bool isRead = false,
    String? actionType,
    String? actionData,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    return NotificationItemModel(
      id: id,
      businessId: businessId,
      title: title,
      message: message,
      type: type,
      priority: priority,
      isRead: isRead,
      actionType: actionType,
      actionData: actionData,
      timestamp: effectiveNow,
      createdAt: effectiveNow,
    );
  }

  NotificationItemModel copyWith({
    int? id,
    int? businessId,
    String? title,
    String? message,
    SystemNotificationType? type,
    SystemNotificationPriority? priority,
    bool? isRead,
    String? actionType,
    String? actionData,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return NotificationItemModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      actionType: actionType ?? this.actionType,
      actionData: actionData ?? this.actionData,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'business_id': businessId,
      'title': title,
      'message': message,
      'type': type.value,
      'priority': priority.value,
      'is_read': isRead ? 1 : 0,
      'action_type': actionType,
      'action_data': actionData,
      'timestamp': timestamp.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory NotificationItemModel.fromMap(Map<String, dynamic> map) {
    return NotificationItemModel(
      id: (map['id'] as num?)?.toInt(),
      businessId: (map['business_id'] as num?)?.toInt() ?? 1,
      title: map['title'] as String? ?? 'Notification',
      message: map['message'] as String? ?? '',
      type: SystemNotificationType.fromString(map['type'] as String?),
      priority: SystemNotificationPriority.fromString(map['priority'] as String?),
      isRead: (map['is_read'] == 1 || map['is_read'] == true),
      actionType: map['action_type'] as String?,
      actionData: map['action_data'] as String?,
      timestamp: map['timestamp'] != null
          ? (DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  String timeAgo({DateTime? clock}) {
    final current = clock ?? DateTime.now();
    final diff = current.difference(timestamp);

    if (diff.inSeconds < 45) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m min${m == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hr${h == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d day${d == 1 ? '' : 's'} ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationItemModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.title == title &&
        other.message == message &&
        other.type == type &&
        other.priority == priority &&
        other.isRead == isRead &&
        other.actionType == actionType &&
        other.actionData == actionData;
  }

  @override
  int get hashCode => Object.hash(
        id,
        businessId,
        title,
        message,
        type,
        priority,
        isRead,
        actionType,
        actionData,
      );
}
