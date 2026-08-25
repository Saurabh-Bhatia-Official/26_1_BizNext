// lib/core/services/subscription_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../providers/theme_provider.dart';

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
  static const String _baseUrl = "http://localhost:8000/api/v1";

  SubscriptionService(this._prefs, this._ref);

  String get tier {
    return 'pro';
  }

  bool get isPro => true;

  Future<void> setTier(String newTier) async {
    await _prefs.setString('subscription_tier', newTier);
    _ref.read(subscriptionTierProvider.notifier).state = newTier;
  }

  Future<bool> checkOnlineSubscription(String username, String token) async {
    return true;
  }

  Future<Map<String, dynamic>?> initiateProSubscription(String token) async {
    return {
      "id": "sub_mock_${DateTime.now().millisecondsSinceEpoch}",
      "status": "created",
      "payment_url": "https://rzp.io/l/mock_checkout_biznext",
      "is_mock": true
    };
  }

  Future<bool> forceUpgradeLocalTier(String username, String token) async {
    await setTier('pro');
    return true;
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory(String token) async {
    return [
      {
        "id": "mock_txn_${DateTime.now().millisecondsSinceEpoch}",
        "date": DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        "amount": "₹499",
        "status": "Success",
        "plan": "Pro Plan"
      }
    ];
  }
}
