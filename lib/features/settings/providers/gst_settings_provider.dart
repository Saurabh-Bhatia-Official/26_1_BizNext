// lib/features/settings/providers/gst_settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

final gstRatesProvider = StateNotifierProvider<GstRatesNotifier, List<double>>((ref) {
  return GstRatesNotifier();
});

class GstRatesNotifier extends StateNotifier<List<double>> {
  GstRatesNotifier() : super(AppConstants.gstRates) {
    loadRates();
  }

  static const String _key = 'custom_gst_rates';

  Future<void> loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList(_key);
    if (saved != null) {
      state = saved.map((e) => double.tryParse(e) ?? 0.0).toList()..sort();
    }
  }

  Future<void> addRate(double rate) async {
    if (state.contains(rate)) return;
    final newState = [...state, rate]..sort();
    state = newState;
    await _save();
  }

  Future<void> removeRate(double rate) async {
    // Prevent removing all rates? Maybe not.
    final newState = state.where((r) => r != rate).toList();
    state = newState;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.map((e) => e.toString()).toList());
  }
}
