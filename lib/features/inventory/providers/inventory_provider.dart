// lib/features/inventory/providers/inventory_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';
import '../../../core/database/database_providers.dart';

/// Thrown when a product name already exists for the same business.
class DuplicateProductNameException implements Exception {
  final String name;
  const DuplicateProductNameException(this.name);
  @override
  String toString() => 'A product named "$name" already exists.';
}

// ── Repository ─────────────────────────────────────────────────────────────────
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

// ── Filter State ───────────────────────────────────────────────────────────────
class InventoryFilter {
  final String searchQuery;
  final int? categoryId;
  final bool lowStockOnly;

  const InventoryFilter({
    this.searchQuery = '',
    this.categoryId,
    this.lowStockOnly = false,
  });

  InventoryFilter copyWith({
    String? searchQuery,
    int? categoryId,
    bool? lowStockOnly,
    bool clearCategory = false,
  }) {
    return InventoryFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    );
  }
}

final inventoryFilterProvider = StateProvider<InventoryFilter>((ref) => const InventoryFilter());

// ── Products List ──────────────────────────────────────────────────────────────
final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  ref.watch(databaseVersionProvider);
  final repo = ref.watch(productRepositoryProvider);
  final filter = ref.watch(inventoryFilterProvider);
  final businessId = ref.watch(activeBusinessIdProvider);

  return repo.getAllProducts(
    businessId: businessId,
    searchQuery: filter.searchQuery,
    categoryId: filter.categoryId,
    lowStockOnly: filter.lowStockOnly,
  );
});

// ── Categories ─────────────────────────────────────────────────────────────────
final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  ref.watch(databaseVersionProvider);
  final repo = ref.watch(productRepositoryProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return repo.getAllCategories(businessId);
});

// ── Price Categories ───────────────────────────────────────────────────────────
final priceCategoriesProvider = FutureProvider.autoDispose<List<PriceCategory>>((ref) async {
  ref.watch(databaseVersionProvider);
  final repo = ref.watch(productRepositoryProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return repo.getPriceCategories(businessId);
});

// ── Tiered Prices State (for form) ─────────────────────────────────────────────
final productTieredPricesProvider = StateProvider.autoDispose<List<ProductTierPrice>>((ref) => []);

final tieredPricesForProductProvider = FutureProvider.family<List<ProductTierPrice>, int>((ref, productId) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProductPrices(productId);
});

// ── Inventory Stats ────────────────────────────────────────────────────────────
final inventoryStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(databaseVersionProvider);
  final repo = ref.watch(productRepositoryProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return repo.getInventoryStats(businessId);
});

// ── Selected Product ───────────────────────────────────────────────────────────
final selectedProductProvider = StateProvider<Product?>((ref) => null);

// ── Product Form Notifier ──────────────────────────────────────────────────────
class ProductFormNotifier extends StateNotifier<AsyncValue<void>> {
  final ProductRepository _repo;
  final Ref _ref;

  ProductFormNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> saveProduct(Product product) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);

      // ── Unique name check ──────────────────────────────────────────────────
      final nameTaken = await _repo.isProductNameTaken(
        product.name,
        businessId,
        excludeId: product.id, // null when creating → checks all
      );
      if (nameTaken) {
        throw DuplicateProductNameException(product.name);
      }
      // ──────────────────────────────────────────────────────────────────────

      if (product.id == null) {
        final id = await _repo.addProduct(product, businessId);
        final tieredPrices = _ref.read(productTieredPricesProvider);
        if (tieredPrices.isNotEmpty) {
          await _repo.updateProductPrices(id, tieredPrices);
        }
      } else {
        await _repo.updateProduct(product);
        final tieredPrices = _ref.read(productTieredPricesProvider);
        await _repo.updateProductPrices(product.id!, tieredPrices);
      }
      if (mounted) {
        state = const AsyncValue.data(null);
      }
      return true;
    } on DuplicateProductNameException {
      rethrow; // Let the UI handle it
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteProduct(id);
      if (mounted) {
        state = const AsyncValue.data(null);
      }
      return true;
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
      return false;
    }
  }

  Future<bool> duplicateProduct(Product product) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      final duplicated = product.copyWith(
        id: null,
        name: '${product.name} (Copy)',
        sku: product.sku != null ? '${product.sku}-COPY' : null,
        barcode: null,
      );
      await _repo.addProduct(duplicated, businessId);
      if (mounted) {
        state = const AsyncValue.data(null);
      }
      return true;
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
      return false;
    }
  }

  Future<bool> saveCategory(Category category) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      if (category.id == null) {
        await _repo.addCategory(category, businessId);
      } else {
        await _repo.updateCategory(category);
      }
      if (mounted) {
        state = const AsyncValue.data(null);
      }
      return true;
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteCategory(id);
      if (mounted) {
        state = const AsyncValue.data(null);
      }
      return true;
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
      return false;
    }
  }

  Future<bool> savePriceCategory(PriceCategory category) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      await _repo.addPriceCategory(category, businessId);
      if (mounted) {
        state = const AsyncValue.data(null);
      }
      return true;
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
      return false;
    }
  }

  Future<bool> deletePriceCategory(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deletePriceCategory(id);
      if (mounted) {
        state = const AsyncValue.data(null);
      }
      return true;
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
      return false;
    }
  }
}

final productFormProvider = StateNotifierProvider.autoDispose<ProductFormNotifier, AsyncValue<void>>(
  (ref) => ProductFormNotifier(ref.watch(productRepositoryProvider), ref),
);
