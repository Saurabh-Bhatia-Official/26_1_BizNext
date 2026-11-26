// lib/features/loyalty/providers/loyalty_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/loyalty_model.dart';
import '../../../core/database/database_providers.dart';

final loyaltySettingsProvider = StateNotifierProvider<LoyaltyNotifier, LoyaltySettings?>((ref) {
  final business = ref.watch(currentBusinessProvider);
  return LoyaltyNotifier(business?.id, ref);
});

class LoyaltyNotifier extends StateNotifier<LoyaltySettings?> {
  final int? businessId;
  final Ref _ref;

  LoyaltyNotifier(this.businessId, this._ref) : super(null) {
    if (businessId != null) {
      loadSettings();
      // Listen to global database version for auto-refresh
      _ref.listen(databaseVersionProvider, (prev, next) {
        loadSettings();
      });
    }
  }

  final _db = DatabaseHelper.instance;

  Future<void> loadSettings() async {
    if (businessId == null) return;

    final results = await _db.queryAll(
      AppConstants.tblLoyaltySettings, 
      where: 'business_id = ?', 
      whereArgs: [businessId]
    );

    if (results.isNotEmpty) {
      state = LoyaltySettings.fromMap(results.first);
    } else {
      // Create default if not exists
      final settings = LoyaltySettings(businessId: businessId!);
      final id = await _db.insert(AppConstants.tblLoyaltySettings, settings.toMap());
      state = settings.copyWith(id: id);
    }
  }

  Future<void> updateSettings(LoyaltySettings settings) async {
    await _db.update(AppConstants.tblLoyaltySettings, settings.toMap(), settings.id!);
    state = settings;
  }
}
