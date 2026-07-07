// lib/features/settings/providers/settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';
import '../../../core/database/database_providers.dart';

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

final featureSettingsProvider = StateNotifierProvider<FeatureSettingsNotifier, AppFeatureSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  final business = ref.watch(currentBusinessProvider);
  return FeatureSettingsNotifier(repo, business?.id, ref);
});

class FeatureSettingsNotifier extends StateNotifier<AppFeatureSettings> {
  final SettingsRepository _repo;
  final int? _businessId;
  final Ref _ref;

  FeatureSettingsNotifier(this._repo, this._businessId, this._ref) : super(AppFeatureSettings()) {
    loadSettings();
    // Global auto-refresh
    _ref.listen(databaseVersionProvider, (prev, next) {
      loadSettings();
    });
  }

  Future<void> loadSettings() async {
    if (_businessId == null) return;
    final settings = await _repo.getSettings(_businessId);
    state = settings;
  }

  Future<void> updateSetting(String key, bool value) async {
    if (_businessId == null) return;
    await _repo.updateSetting(_businessId, key, value ? '1' : '0');
    await loadSettings();
  }

  Future<void> toggleCustomerDiscount(bool value) => updateSetting('customer_discount_enabled', value);
  Future<void> toggleProductDiscount(bool value) => updateSetting('product_discount_enabled', value);
  Future<void> toggleOffers(bool value) => updateSetting('offers_enabled', value);
  Future<void> toggleLoyalty(bool value) => updateSetting('loyalty_enabled', value);
  Future<void> toggleGst(bool value) => updateSetting('gst_enabled', value);
  Future<void> toggleInventoryTracking(bool value) => updateSetting('inventory_tracking_enabled', value);
  Future<void> toggleNotifications(bool value) => updateSetting('notifications_enabled', value);
  Future<void> toggleAutoSync(bool value) => updateSetting('auto_sync_enabled', value);

  Future<void> setScannerDevice(String value) async {
    if (_businessId == null) return;
    await _repo.updateSetting(_businessId, 'scanner_device', value);
    await loadSettings();
  }

  Future<void> setCameraIndex(int value) async {
    if (_businessId == null) return;
    await _repo.updateSetting(_businessId, 'selected_camera_index', value.toString());
    await loadSettings();
  }
}
