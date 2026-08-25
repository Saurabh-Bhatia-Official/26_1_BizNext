// lib/core/services/shortcut_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../providers/theme_provider.dart';

class AppShortcutDef {
  final String actionId;
  final String label;
  final String category;
  final String defaultShortcut;

  const AppShortcutDef({
    required this.actionId,
    required this.label,
    required this.category,
    required this.defaultShortcut,
  });
}

class ShortcutNotifier extends StateNotifier<Map<String, String>> {
  final Ref _ref;
  static const String _prefsKey = 'custom_keyboard_shortcuts';

  static const Map<String, AppShortcutDef> defaults = {
    'nav_dashboard': AppShortcutDef(actionId: 'nav_dashboard', label: 'Go to Dashboard', category: 'Navigation', defaultShortcut: 'Ctrl+Shift+D'),
    'nav_pos': AppShortcutDef(actionId: 'nav_pos', label: 'Go to POS Billing', category: 'Navigation', defaultShortcut: 'Ctrl+Shift+P'),
    'nav_sales': AppShortcutDef(actionId: 'nav_sales', label: 'Go to Sales Screen', category: 'Navigation', defaultShortcut: 'Ctrl+Shift+S'),
    'nav_inventory': AppShortcutDef(actionId: 'nav_inventory', label: 'Go to Inventory/Stock', category: 'Navigation', defaultShortcut: 'Ctrl+Shift+I'),
    'nav_settings': AppShortcutDef(actionId: 'nav_settings', label: 'Go to Settings', category: 'Navigation', defaultShortcut: 'Ctrl+Shift+T'),
    'save': AppShortcutDef(actionId: 'save', label: 'Save / Submit Form', category: 'Forms', defaultShortcut: 'Ctrl+S'),
    'cancel': AppShortcutDef(actionId: 'cancel', label: 'Cancel / Go Back', category: 'Forms', defaultShortcut: 'Esc'),
    'pos_pay': AppShortcutDef(actionId: 'pos_pay', label: 'POS: Checkout / Pay', category: 'POS', defaultShortcut: 'F12'),
    'pos_clear': AppShortcutDef(actionId: 'pos_clear', label: 'POS: Clear Cart', category: 'POS', defaultShortcut: 'Ctrl+Delete'),
    'pos_search': AppShortcutDef(actionId: 'pos_search', label: 'POS: Focus Search', category: 'POS', defaultShortcut: 'Ctrl+F'),
    'pos_scan': AppShortcutDef(actionId: 'pos_scan', label: 'POS: Open Barcode Scanner', category: 'POS', defaultShortcut: 'Ctrl+Shift+K'),
    'sync_data': AppShortcutDef(actionId: 'sync_data', label: 'Sync Business Data', category: 'General', defaultShortcut: 'Ctrl+Shift+R'),
  };

  ShortcutNotifier(this._ref) : super({}) {
    _loadShortcuts();
  }

  void _loadShortcuts() {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final decoded = Map<String, dynamic>.from(json.decode(jsonStr));
        state = decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      debugPrint("Error loading custom shortcuts: $e");
    }
  }

  Future<void> updateShortcut(String actionId, String keyCombination) async {
    final updated = Map<String, String>.from(state);
    if (keyCombination.isEmpty) {
      updated.remove(actionId);
    } else {
      updated[actionId] = keyCombination;
    }
    state = updated;
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setString(_prefsKey, json.encode(updated));
    } catch (e) {
      debugPrint("Error saving custom shortcuts: $e");
    }
  }

  Future<void> resetAll() async {
    state = {};
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint("Error resetting shortcuts: $e");
    }
  }
}

final shortcutSettingsProvider = StateNotifierProvider<ShortcutNotifier, Map<String, String>>((ref) {
  return ShortcutNotifier(ref);
});

class ShortcutRegistry {
  final Map<String, VoidCallback> _actions = {};

  void register(String actionId, VoidCallback callback) {
    _actions[actionId] = callback;
  }

  void unregister(String actionId) {
    _actions.remove(actionId);
  }

  VoidCallback? get(String actionId) => _actions[actionId];
}

final shortcutRegistryProvider = Provider((ref) => ShortcutRegistry());

class AppShortcut extends ConsumerStatefulWidget {
  final String actionId;
  final VoidCallback? onPressed;
  final Widget child;

  const AppShortcut({
    super.key,
    required this.actionId,
    required this.onPressed,
    required this.child,
  });

  @override
  ConsumerState<AppShortcut> createState() => _AppShortcutState();
}

class _AppShortcutState extends ConsumerState<AppShortcut> {
  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(AppShortcut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed != oldWidget.onPressed) {
      ref.read(shortcutRegistryProvider).unregister(widget.actionId);
      _register();
    }
  }

  @override
  void dispose() {
    ref.read(shortcutRegistryProvider).unregister(widget.actionId);
    super.dispose();
  }

  void _register() {
    if (widget.onPressed != null) {
      ref.read(shortcutRegistryProvider).register(widget.actionId, widget.onPressed!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class ShortcutListener extends ConsumerWidget {
  final Widget child;
  const ShortcutListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final shortcutString = _getShortcutString(event);
          if (shortcutString.isNotEmpty) {
            final registry = ref.read(shortcutRegistryProvider);
            final shortcuts = ref.read(shortcutSettingsProvider);

            String? matchedActionId;
            // Check user mappings
            shortcuts.forEach((actionId, shortcut) {
              if (shortcut.toLowerCase() == shortcutString.toLowerCase()) {
                matchedActionId = actionId;
              }
            });

            // If not overridden, check default mappings
            if (matchedActionId == null) {
              ShortcutNotifier.defaults.forEach((actionId, def) {
                if (!shortcuts.containsKey(actionId)) {
                  if (def.defaultShortcut.toLowerCase() == shortcutString.toLowerCase()) {
                    matchedActionId = actionId;
                  }
                }
              });
            }

            if (matchedActionId != null) {
              final callback = registry.get(matchedActionId!);
              if (callback != null) {
                callback();
                return KeyEventResult.handled;
              }
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }

  String _getShortcutString(KeyEvent event) {
    final modifiers = <String>[];
    if (HardwareKeyboard.instance.isControlPressed) {
      modifiers.add('Ctrl');
    }
    if (HardwareKeyboard.instance.isAltPressed) {
      modifiers.add('Alt');
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      modifiers.add('Shift');
    }
    if (HardwareKeyboard.instance.isMetaPressed) {
      modifiers.add('Meta');
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.meta) {
      return '';
    }

    String keyLabel = key.keyLabel;
    if (key == LogicalKeyboardKey.escape) keyLabel = 'Esc';
    if (key == LogicalKeyboardKey.enter) keyLabel = 'Enter';
    if (key == LogicalKeyboardKey.delete) keyLabel = 'Delete';
    if (key == LogicalKeyboardKey.backspace) keyLabel = 'Backspace';
    if (key == LogicalKeyboardKey.space) keyLabel = 'Space';
    if (key == LogicalKeyboardKey.tab) keyLabel = 'Tab';

    if (modifiers.isEmpty) {
      return keyLabel;
    } else {
      return '${modifiers.join('+')}+$keyLabel';
    }
  }
}
