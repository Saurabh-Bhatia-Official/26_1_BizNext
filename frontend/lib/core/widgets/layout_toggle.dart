// lib/core/widgets/layout_toggle.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum LayoutMode { grid, table }

class LayoutToggle extends StatelessWidget {
  final LayoutMode current;
  final ValueChanged<LayoutMode> onChanged;
  final bool isDark;

  const LayoutToggle({
    super.key,
    required this.current,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.grid_view_rounded,
            tooltip: 'Grid View',
            isActive: current == LayoutMode.grid,
            isDark: isDark,
            onTap: () => onChanged(LayoutMode.grid),
          ),
          const SizedBox(width: 4),
          _ToggleBtn(
            icon: Icons.table_rows_rounded,
            tooltip: 'Table View',
            isActive: current == LayoutMode.table,
            isDark: isDark,
            onTap: () => onChanged(LayoutMode.table),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white54 : AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
