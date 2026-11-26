// lib/core/providers/notification_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum NotificationType { success, error, warning, info }

class AppNotification {
  final String id;
  final String message;
  final String? title;
  final NotificationType type;
  final DateTime timestamp;
  /// If set, the notification card shows an "Undo" button that calls this.
  final Future<void> Function()? onUndo;

  AppNotification({
    required this.id,
    required this.message,
    this.title,
    this.type = NotificationType.info,
    DateTime? timestamp,
    this.onUndo,
  }) : timestamp = timestamp ?? DateTime.now();
}

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  NotificationNotifier() : super([]);

  final _uuid = const Uuid();

  void show({
    required String message,
    String? title,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final notification = AppNotification(
      id: _uuid.v4(),
      message: message,
      title: title,
      type: type,
    );

    state = [...state, notification];

    Timer(duration, () {
      remove(notification.id);
    });
  }

  /// Shows a notification with an Undo button. The undo callback is called
  /// if the user taps Undo before the notification expires.
  void showWithUndo({
    required String message,
    required Future<void> Function() onUndo,
    String? title,
    Duration duration = const Duration(seconds: 5),
  }) {
    final id = _uuid.v4();
    final notification = AppNotification(
      id: id,
      message: message,
      title: title ?? 'Deleted',
      type: NotificationType.warning,
      onUndo: onUndo,
    );

    state = [...state, notification];

    Timer(duration, () {
      remove(id);
    });
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  return NotificationNotifier();
});

class AppAlert {
  static void success(WidgetRef ref, String message, {String? title}) {
    ref.read(notificationProvider.notifier).show(
      message: message,
      title: title ?? 'Success',
      type: NotificationType.success,
    );
  }

  static void error(WidgetRef ref, String message, {String? title}) {
    ref.read(notificationProvider.notifier).show(
      message: message,
      title: title ?? 'Error',
      type: NotificationType.error,
    );
  }

  static void warning(WidgetRef ref, String message, {String? title}) {
    ref.read(notificationProvider.notifier).show(
      message: message,
      title: title ?? 'Warning',
      type: NotificationType.warning,
    );
  }

  static void info(WidgetRef ref, String message, {String? title}) {
    ref.read(notificationProvider.notifier).show(
      message: message,
      title: title ?? 'Info',
      type: NotificationType.info,
    );
  }
}
