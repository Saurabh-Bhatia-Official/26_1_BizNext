// lib/core/widgets/category_manager_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/notification_provider.dart';

class CategoryItem {
  final int id;
  final String name;
  CategoryItem({required this.id, required this.name});
}

class CategoryManagerScreen extends ConsumerStatefulWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<dynamic>>> categoriesProvider;
  final Future<bool> Function(String name, int? id) onSave;
  final Future<bool> Function(int id) onDelete;
  final String? Function(dynamic)? nameExtractor;

  const CategoryManagerScreen({
    super.key,
    required this.title,
    required this.categoriesProvider,
    required this.onSave,
    required this.onDelete,
    this.nameExtractor,
  });

  @override
  ConsumerState<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends ConsumerState<CategoryManagerScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(widget.categoriesProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search categories...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : Colors.white,
              ),
            ),
          ),
          Expanded(
            child: categoriesAsync.when(
              data: (list) {
                final filtered = list.where((c) {
                  final name = widget.nameExtractor?.call(c) ?? c.name;
                  return name.toLowerCase().contains(_query.toLowerCase());
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('No categories found', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    final name = widget.nameExtractor?.call(item) ?? item.name;
                    final id = item.id;

                    return Material(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: ListTile(
                        title: Text(
                          name, 
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
                              onPressed: () => _showEditDialog(context, name, id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                              onPressed: () => _confirmDelete(context, name, id),
                            ),
                          ],
                        ),
                      ),
                    ).animate(delay: (i * 30).ms).fadeIn().slideX(begin: 0.05);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context, '', null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700)),
      ).animate().scale(delay: 200.ms),
    );
  }

  void _showEditDialog(BuildContext context, String currentName, int? id) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'Add Category' : 'Edit Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final success = await widget.onSave(ctrl.text.trim(), id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) {
                AppAlert.success(ref, id == null ? 'Category added' : 'Category updated');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String name, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "$name"? This cannot be undone if in use.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final success = await widget.onDelete(id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  AppAlert.success(ref, 'Category deleted');
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                AppAlert.error(ref, e.toString());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
