// lib/features/settings/screens/shortcut_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/shortcut_service.dart';
import '../../../core/theme/app_theme.dart';

class ShortcutSettingsScreen extends ConsumerWidget {
  const ShortcutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shortcuts = ref.watch(shortcutSettingsProvider);

    // Group defaults by category
    final groupedDefs = <String, List<AppShortcutDef>>{};
    for (var def in ShortcutNotifier.defaults.values) {
      groupedDefs.putIfAbsent(def.category, () => []).add(def);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Keyboard Shortcuts',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : AppColors.textLight,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textLight),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _confirmReset(context, ref),
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Reset Defaults'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Customize your keyboard shortcuts below. Click on any shortcut tile and press the new key combination to rebind it.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...groupedDefs.entries.map((entry) {
              final category = entry.key;
              final list = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Text(
                      category,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      itemBuilder: (context, index) {
                        final def = list[index];
                        final customShortcut = shortcuts[def.actionId];
                        final isCustom = customShortcut != null;
                        final displayShortcut = customShortcut ?? def.defaultShortcut;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          title: Text(
                            def.label,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          subtitle: isCustom
                              ? const Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 12, color: AppColors.success),
                                    SizedBox(width: 4),
                                    Text('Customized', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold)),
                                  ],
                                )
                              : Text('Default: ${def.defaultShortcut}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              displayShortcut.isEmpty ? 'None' : displayShortcut,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: displayShortcut.isEmpty 
                                    ? AppColors.error 
                                    : (isDark ? Colors.white : AppColors.textLight),
                              ),
                            ),
                          ),
                          onTap: () => _recordNewShortcut(context, ref, def),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _recordNewShortcut(BuildContext context, WidgetRef ref, AppShortcutDef def) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ShortcutRecorderDialog(
        def: def,
        onSave: (newKey) {
          ref.read(shortcutSettingsProvider.notifier).updateShortcut(def.actionId, newKey);
        },
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset All Shortcuts?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will clear all customized keys and revert to default shortcuts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(shortcutSettingsProvider.notifier).resetAll();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRecorderDialog extends StatefulWidget {
  final AppShortcutDef def;
  final Function(String) onSave;

  const _ShortcutRecorderDialog({
    required this.def,
    required this.onSave,
  });

  @override
  State<_ShortcutRecorderDialog> createState() => _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<_ShortcutRecorderDialog> {
  String _currentKeys = '';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
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
      // Skip if key itself is a modifier
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
        setState(() {
          _currentKeys = modifiers.join('+');
        });
        return;
      }

      String keyLabel = key.keyLabel;
      if (key == LogicalKeyboardKey.escape) keyLabel = 'Esc';
      if (key == LogicalKeyboardKey.enter) keyLabel = 'Enter';
      if (key == LogicalKeyboardKey.delete) keyLabel = 'Delete';
      if (key == LogicalKeyboardKey.backspace) keyLabel = 'Backspace';
      if (key == LogicalKeyboardKey.space) keyLabel = 'Space';
      if (key == LogicalKeyboardKey.tab) keyLabel = 'Tab';

      setState(() {
        if (modifiers.isEmpty) {
          _currentKeys = keyLabel;
        } else {
          _currentKeys = '${modifiers.join('+')}+$keyLabel';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Rebind: ${widget.def.label}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Press any combination of keys (e.g. Ctrl + Shift + P) on your keyboard to set the new shortcut.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  _currentKeys.isEmpty ? 'Waiting for key press...' : _currentKeys,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _currentKeys.isEmpty 
                        ? AppColors.textMuted 
                        : (isDark ? Colors.white : AppColors.textLight),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onSave('');
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear Shortcut'),
          ),
          ElevatedButton(
            onPressed: _currentKeys.isEmpty
                ? null
                : () {
                    widget.onSave(_currentKeys);
                    Navigator.pop(context);
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
