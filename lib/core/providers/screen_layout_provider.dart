// lib/core/providers/screen_layout_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/layout_toggle.dart';
import 'theme_provider.dart';

/// Provider for per-screen persistent LayoutMode (grid vs table)
final screenLayoutProvider = StateNotifierProvider.family<ScreenLayoutNotifier, LayoutMode, String>((ref, screenKey) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ScreenLayoutNotifier(prefs, screenKey);
});

class ScreenLayoutNotifier extends StateNotifier<LayoutMode> {
  final SharedPreferences _prefs;
  final String _screenKey;

  ScreenLayoutNotifier(this._prefs, this._screenKey)
      : super(_loadLayout(_prefs, _screenKey));

  static LayoutMode _loadLayout(SharedPreferences prefs, String key) {
    final stored = prefs.getString('screen_layout_$key');
    if (stored == 'table') return LayoutMode.table;
    if (stored == 'grid') return LayoutMode.grid;
    // Default fallback based on screen key
    if (key == 'purchases' || key == 'sales') return LayoutMode.table;
    return LayoutMode.grid;
  }

  void setLayout(LayoutMode mode) {
    _prefs.setString('screen_layout_$_screenKey', mode == LayoutMode.table ? 'table' : 'grid');
    state = mode;
  }
}
