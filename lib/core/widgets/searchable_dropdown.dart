// lib/core/widgets/searchable_dropdown.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppSearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<SearchableDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String labelText;
  final IconData? prefixIcon;
  final bool isDark;
  final String searchHint;
  final String? Function(T?)? validator;
  final Function(String)? onAdd;
  final String? addLabel;

  const AppSearchableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelText,
    this.prefixIcon,
    required this.isDark,
    this.searchHint = 'Search...',
    this.validator,
    this.onAdd,
    this.addLabel,
  });

  @override
  State<AppSearchableDropdown<T>> createState() => _AppSearchableDropdownState<T>();
}

class _AppSearchableDropdownState<T> extends State<AppSearchableDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.items.where((i) => i.value == widget.value).firstOrNull;

    return FormField<T>(
      validator: widget.validator,
      initialValue: widget.value,
      builder: (FormFieldState<T> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _showSearchDialog(context, state),
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: AppTheme.inputDecoration(
                  labelText: widget.labelText,
                  prefixIcon: widget.prefixIcon,
                  isDark: widget.isDark,
                ).copyWith(
                  errorText: state.errorText,
                  fillColor: widget.isDark ? AppColors.darkSurface : Colors.white,
                ),
                isEmpty: selectedItem == null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        selectedItem?.label ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          color: widget.isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: widget.isDark ? Colors.white54 : Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSearchDialog(BuildContext context, FormFieldState<T> state) {
    showDialog(
      context: context,
      builder: (context) => _SearchDialog<T>(
        items: widget.items,
        initialValue: widget.value,
        searchHint: widget.searchHint,
        isDark: widget.isDark,
        onAdd: widget.onAdd,
        addLabel: widget.addLabel,
        onSelected: (val) {
          widget.onChanged(val);
          state.didChange(val);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class SearchableDropdownItem<T> {
  final T value;
  final String label;

  SearchableDropdownItem({required this.value, required this.label});
}

class _SearchDialog<T> extends StatefulWidget {
  final List<SearchableDropdownItem<T>> items;
  final T? initialValue;
  final String searchHint;
  final bool isDark;
  final ValueChanged<T?> onSelected;
  final Function(String)? onAdd;
  final String? addLabel;

  const _SearchDialog({
    required this.items,
    required this.initialValue,
    required this.searchHint,
    required this.isDark,
    required this.onSelected,
    this.onAdd,
    this.addLabel,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  late List<SearchableDropdownItem<T>> _filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = widget.items
          .where((item) => item.label.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkBg : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: AppTheme.inputDecoration(
                  labelText: widget.searchHint,
                  prefixIcon: Icons.search_rounded,
                  isDark: widget.isDark,
                ),
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
              ),
            ),
            const Divider(height: 1),
            if (_filteredItems.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final isSelected = item.value == widget.initialValue;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: widget.isDark ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                          : null,
                      onTap: () => widget.onSelected(item.value),
                      hoverColor: AppColors.primary.withValues(alpha: 0.05),
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No results for "${_searchController.text}"',
                      style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (widget.onAdd != null && _searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextButton.icon(
                  onPressed: () {
                    final text = _searchController.text;
                    Navigator.pop(context);
                    widget.onAdd!(text);
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                  label: Text(widget.addLabel ?? 'Add "${_searchController.text}"', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
