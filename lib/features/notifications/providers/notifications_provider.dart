// lib/features/notifications/providers/notifications_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item_model.dart';
import '../repositories/notification_repository.dart';

final notificationFilterTypeProvider = StateProvider<String>((ref) => 'all');
final notificationSearchQueryProvider = StateProvider<String>((ref) => '');

class NotificationsNotifier extends StateNotifier<AsyncValue<List<NotificationItemModel>>> {
  final Ref _ref;
  final NotificationRepository _repository;

  NotificationsNotifier(this._ref, this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  int get _businessId => _ref.read(authProvider).activeBusiness?.id ?? _ref.read(activeBusinessIdProvider);

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final businessId = _businessId;
      // Run automatic smart alert detection on refresh
      await _repository.generateSmartAlerts(businessId);
      final items = await _repository.getNotifications(businessId: businessId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n).toList(),
      );
    } catch (e) {
      // Re-fetch in case of inconsistency
      refresh();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final businessId = _businessId;
      await _repository.markAllAsRead(businessId);
      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((n) => n.copyWith(isRead: true)).toList(),
      );
    } catch (e) {
      refresh();
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);
      final current = state.value ?? [];
      state = AsyncValue.data(
        current.where((n) => n.id != notificationId).toList(),
      );
    } catch (e) {
      refresh();
    }
  }

  Future<void> clearAll() async {
    try {
      final businessId = _businessId;
      await _repository.clearAll(businessId);
      state = const AsyncValue.data([]);
    } catch (e) {
      refresh();
    }
  }

  Future<int> scanAndGenerateAlerts() async {
    try {
      final businessId = _businessId;
      final generated = await _repository.generateSmartAlerts(businessId);
      final items = await _repository.getNotifications(businessId: businessId);
      state = AsyncValue.data(items);
      return generated;
    } catch (_) {
      return 0;
    }
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, AsyncValue<List<NotificationItemModel>>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return NotificationsNotifier(ref, repo);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(notificationsProvider);
  return notifsAsync.maybeWhen(
    data: (items) => items.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

final filteredNotificationsProvider = Provider<List<NotificationItemModel>>((ref) {
  final notifsAsync = ref.watch(notificationsProvider);
  final filterType = ref.watch(notificationFilterTypeProvider);
  final searchQuery = ref.watch(notificationSearchQueryProvider).toLowerCase().trim();

  return notifsAsync.maybeWhen(
    data: (items) {
      return items.where((n) {
        final matchesType = filterType == 'all' ||
            (filterType == 'unread' && !n.isRead) ||
            n.type.value == filterType;

        final matchesSearch = searchQuery.isEmpty ||
            n.title.toLowerCase().contains(searchQuery) ||
            n.message.toLowerCase().contains(searchQuery) ||
            n.type.displayName.toLowerCase().contains(searchQuery);

        return matchesType && matchesSearch;
      }).toList();
    },
    orElse: () => [],
  );
});
