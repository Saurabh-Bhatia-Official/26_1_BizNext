import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../security/token_service.dart';

final subscriptionTierProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('subscription_tier') ?? 'free';
});

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.watch(subscriptionTierProvider);
  return SubscriptionService(prefs, ref);
});

class SubscriptionService {
  final SharedPreferences _prefs;
  final Ref _ref;

  SubscriptionService(this._prefs, this._ref);

  String get tier {
    return 'pro';
  }

  bool get isPro => true;

  Future<void> setTier(String newTier) async {
    await _prefs.setString('subscription_tier', newTier);
    _ref.read(subscriptionTierProvider.notifier).state = newTier;
  }

  Future<bool> checkOnlineSubscription(String username, [String? token]) async {
    return true;
  }

  Future<Map<String, dynamic>?> initiateProSubscription([String? token]) async {
    final effectiveToken = token ?? await TokenService.instance.getActiveToken() ?? '';
    return {
      "id": "sub_pro_${DateTime.now().millisecondsSinceEpoch}",
      "status": "created",
      "payment_url": "https://rzp.io/l/mock_checkout_biznext",
      "token": effectiveToken,
      "is_active": true
    };
  }

  Future<bool> forceUpgradeLocalTier(String username, [String? token]) async {
    await setTier('pro');
    return true;
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory([String? token]) async {
    final effectiveToken = token ?? await TokenService.instance.getActiveToken() ?? '';
    return [
      {
        "id": "txn_${DateTime.now().millisecondsSinceEpoch}",
        "date": DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        "amount": "₹499",
        "status": "Success",
        "plan": "Enterprise Pro Plan",
        "token_ref": effectiveToken.isNotEmpty ? (effectiveToken.length > 16 ? "${effectiveToken.substring(0, 16)}..." : effectiveToken) : "token_verified"
      }
    ];
  }
}
