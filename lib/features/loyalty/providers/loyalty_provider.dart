// lib/features/loyalty/providers/loyalty_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/backend_api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/loyalty_model.dart';

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
    }
  }

  Future<void> loadSettings() async {
    if (businessId == null) return;

    final response = await BackendApiService.get(
      'settings',
      {'businessId': '$businessId'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! Map) {
      state = LoyaltySettings(businessId: businessId!);
      return;
    }
    state = LoyaltySettings(
      businessId: businessId!,
      earnRate: double.tryParse(decoded['loyalty_earn_rate']?.toString() ?? '') ?? 1,
      earnSpendAmount: double.tryParse(decoded['loyalty_earn_spend_amount']?.toString() ?? '') ?? 100,
      redeemValue: double.tryParse(decoded['loyalty_redeem_value']?.toString() ?? '') ?? 1,
      minRedeemPoints: double.tryParse(decoded['loyalty_min_redeem_points']?.toString() ?? '') ?? 100,
      expiryDays: int.tryParse(decoded['loyalty_expiry_days']?.toString() ?? '365') ?? 365,
      pointName: decoded['loyalty_point_name'] as String? ?? 'Points',
      maxRedeemLimit: double.tryParse(decoded['loyalty_max_redeem_limit']?.toString() ?? '') ?? 0,
      welcomePoints: double.tryParse(decoded['loyalty_welcome_points']?.toString() ?? '') ?? 0,
      isActive: decoded['loyalty_enabled'] == true || decoded['loyalty_enabled'] == '1',
    );
  }

  Future<void> updateSettings(LoyaltySettings settings) async {
    await BackendApiService.put('settings', {
      'loyalty_earn_rate': '${settings.earnRate}',
      'loyalty_earn_spend_amount': '${settings.earnSpendAmount}',
      'loyalty_redeem_value': '${settings.redeemValue}',
      'loyalty_min_redeem_points': '${settings.minRedeemPoints}',
      'loyalty_expiry_days': '${settings.expiryDays}',
      'loyalty_point_name': settings.pointName,
      'loyalty_max_redeem_limit': '${settings.maxRedeemLimit}',
      'loyalty_welcome_points': '${settings.welcomePoints}',
      'loyalty_enabled': settings.isActive ? '1' : '0',
    }, {'businessId': '$businessId'});
    state = settings;
  }
}
