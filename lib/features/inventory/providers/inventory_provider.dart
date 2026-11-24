// lib/features/inventory/providers/inventory_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';
import '../../../core/database/database_providers.dart';
import '../services/product_api_service.dart';

// ── Repository ─────────────────────────────────────────────────────────────────
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

// ── Filter State ───────────────────────────────────────────────────────────────
class InventoryFilter {
  final String searchQuery;
  final int? categoryId;
  final int? subcategoryId;
  final String? brand;
  final String status;
  final bool lowStockOnly;
  final int page;
  final int pageSize;
  final String sortBy;
  final String sortDirection;

  const InventoryFilter({
    this.searchQuery = '',
    this.categoryId,
    this.subcategoryId,
    this.brand,
    this.status = 'Active',
    this.lowStockOnly = false,
    this.page = 0,
    this.pageSize = 25,
    this.sortBy = 'name',
    this.sortDirection = 'asc',
  });

  InventoryFilter copyWith({
    String? searchQuery,
    int? categoryId,
    int? subcategoryId,
    String? brand,
    String? status,
    bool? lowStockOnly,
    int? page,
    int? pageSize,
    String? sortBy,
    String? sortDirection,
    bool clearCategory = false,
    bool clearSubcategory = false,
    bool clearBrand = false,
  }) {
    return InventoryFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      subcategoryId: clearSubcategory
          ? null
          : (subcategoryId ?? this.subcategoryId),
      brand: clearBrand ? null : (brand ?? this.brand),
      status: status ?? this.status,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }
}

final inventoryFilterProvider = StateProvider<InventoryFilter>(
  (ref) => const InventoryFilter(),
);

// ── Products List ──────────────────────────────────────────────────────────────
final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);

  return ProductApiService.getAllProducts(
    businessId: businessId,
    status: 'Active',
  );
});

final productPageProvider = FutureProvider.autoDispose<ProductApiPage>((
  ref,
) async {
  final filter = ref.watch(inventoryFilterProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ProductApiService.getProducts(
    businessId: businessId,
    query: filter.searchQuery,
    categoryId: filter.categoryId,
    brand: filter.brand,
    status: filter.status,
    lowStockOnly: filter.lowStockOnly,
    page: filter.page,
    size: filter.pageSize,
    sortBy: filter.sortBy,
    direction: filter.sortDirection,
  );
});

// ── Categories ─────────────────────────────────────────────────────────────────
final categoriesProvider = FutureProvider.autoDispose<List<Category>>((
  ref,
) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  return ProductApiService.getCategories(businessId: businessId);
});

// ── Subcategories ──────────────────────────────────────────────────────────────
final subcategoriesProvider = FutureProvider.family
    .autoDispose<List<Subcategory>, int?>((ref, _) async {
      return const <Subcategory>[];
    });

// ── Customer Types (Price Lists) ───────────────────────────────────────────────
final customerTypesProvider = FutureProvider.autoDispose<List<CustomerType>>((
  ref,
) async {
  ref.watch(databaseVersionProvider);
  final repo = ref.watch(productRepositoryProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return repo.getCustomerTypes(businessId);
});

// ── Price Categories (Legacy Compatibility) ────────────────────────────────────
final priceCategoriesProvider = FutureProvider.autoDispose<List<PriceCategory>>(
  (ref) async {
    ref.watch(databaseVersionProvider);
    final repo = ref.watch(productRepositoryProvider);
    final businessId = ref.watch(activeBusinessIdProvider);
    return repo.getPriceCategories(businessId);
  },
);

// ── Tiered Prices State (for form) ─────────────────────────────────────────────
final productTieredPricesProvider =
    StateProvider.autoDispose<List<ProductTierPrice>>((ref) => []);

final tieredPricesForProductProvider =
    FutureProvider.family<List<ProductTierPrice>, int>((ref, productId) async {
      final repo = ref.watch(productRepositoryProvider);
      return repo.getProductPrices(productId);
    });

final allProductTierPricesProvider =
    FutureProvider.autoDispose<Map<int, List<ProductTierPrice>>>((ref) async {
      ref.watch(databaseVersionProvider);
      final repo = ref.watch(productRepositoryProvider);
      final businessId = ref.watch(activeBusinessIdProvider);
      return repo.getAllProductPrices(businessId);
    });

// ── Inventory Stats ────────────────────────────────────────────────────────────
final inventoryStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final businessId = ref.watch(activeBusinessIdProvider);
    final products = await ProductApiService.getAllProducts(
      businessId: businessId,
      status: 'Active',
    );
    final activeProducts = products
        .where((product) => product.isActive)
        .toList();
    return {
      'total_products': activeProducts.length,
      'low_stock_count': activeProducts
          .where((product) => product.isLowStock && !product.isOutOfStock)
          .length,
      'out_of_stock_count': activeProducts
          .where((product) => product.isOutOfStock)
          .length,
      'inventory_value': activeProducts.fold<double>(
        0,
        (total, product) => total + product.stock * product.purchasePrice,
      ),
    };
  },
);

// ── Stock Movement Ledger ──────────────────────────────────────────────────────
class StockLedgerFilter {
  final int? productId;
  final String? transactionType;
  final DateTime? startDate;
  final DateTime? endDate;

  const StockLedgerFilter({
    this.productId,
    this.transactionType,
    this.startDate,
    this.endDate,
  });

  StockLedgerFilter copyWith({
    int? productId,
    String? transactionType,
    DateTime? startDate,
    DateTime? endDate,
    bool clearProduct = false,
    bool clearType = false,
  }) {
    return StockLedgerFilter(
      productId: clearProduct ? null : (productId ?? this.productId),
      transactionType: clearType
          ? null
          : (transactionType ?? this.transactionType),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

final stockLedgerFilterProvider = StateProvider<StockLedgerFilter>(
  (ref) => const StockLedgerFilter(),
);

final stockLedgerProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      ref.watch(databaseVersionProvider);
      final repo = ref.watch(productRepositoryProvider);
      final businessId = ref.watch(activeBusinessIdProvider);
      final filter = ref.watch(stockLedgerFilterProvider);

      return repo.getStockLedger(
        businessId,
        productId: filter.productId,
        transactionType: filter.transactionType,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
    });

// ── Selected Product ───────────────────────────────────────────────────────────
final selectedProductProvider = StateProvider<Product?>((ref) => null);

// ── Product Form Notifier ──────────────────────────────────────────────────────
class ProductFormNotifier extends StateNotifier<AsyncValue<void>> {
  final ProductRepository _repo;
  final Ref _ref;

  ProductFormNotifier(this._repo, this._ref)
    : super(const AsyncValue.data(null));

  Future<bool> saveProduct(
    Product product, {
    String? imagePath,
    bool removeImage = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      await ProductApiService.saveProduct(
        product: product,
        businessId: businessId,
        imagePath: imagePath,
        removeImage: removeImage,
      );
      _ref.read(inventoryFilterProvider.notifier).state = _ref
          .read(inventoryFilterProvider)
          .copyWith(page: 0);
      _ref.invalidate(productsProvider);
      _ref.invalidate(productPageProvider);
      _ref.invalidate(inventoryStatsProvider);
      _ref.invalidate(categoriesProvider);
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

  Future<bool> deleteProduct(int id) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      await ProductApiService.deleteProduct(id: id, businessId: businessId);
      _ref.read(inventoryFilterProvider.notifier).state = _ref
          .read(inventoryFilterProvider)
          .copyWith(page: 0);
      _ref.invalidate(productsProvider);
      _ref.invalidate(productPageProvider);
      _ref.invalidate(inventoryStatsProvider);
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

  Future<bool> setProductStatus(int id, {required bool isActive}) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      await ProductApiService.setProductStatus(
        id: id,
        businessId: businessId,
        isActive: isActive,
      );
      _ref.invalidate(productsProvider);
      _ref.invalidate(productPageProvider);
      _ref.invalidate(inventoryStatsProvider);
      if (mounted) state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> duplicateProduct(Product product) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      final duplicated = product.copyWith(
        clearId: true,
        name: '${product.name} (Copy)',
        sku: product.sku != null ? '${product.sku}-COPY' : null,
        barcode: null,
      );
      await ProductApiService.saveProduct(
        product: duplicated,
        businessId: businessId,
      );
      _ref.read(inventoryFilterProvider.notifier).state = _ref
          .read(inventoryFilterProvider)
          .copyWith(page: 0);
      _ref.invalidate(productsProvider);
      _ref.invalidate(productPageProvider);
      _ref.invalidate(inventoryStatsProvider);
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

  Future<bool> recordStockAdjustment({
    required int productId,
    required double adjustedQty,
    required String adjustmentType,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      await ProductApiService.adjustProductStock(
        id: productId,
        businessId: businessId,
        adjustedQuantity: adjustedQty,
        adjustmentType: adjustmentType,
        reason: reason,
      );
      _ref.invalidate(productsProvider);
      _ref.invalidate(productPageProvider);
      _ref.invalidate(inventoryStatsProvider);
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
      if (category.id != null) {
        await ProductApiService.updateCategory(
          businessId: businessId,
          categoryId: category.id!,
          name: category.name,
        );
      } else {
        await ProductApiService.createCategory(
          businessId: businessId,
          name: category.name,
        );
      }
      _ref.invalidate(categoriesProvider);
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
      final businessId = _ref.read(activeBusinessIdProvider);
      await ProductApiService.deleteCategory(
        businessId: businessId,
        categoryId: id,
      );
      _ref.invalidate(categoriesProvider);
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

  Future<bool> saveSubcategory(Subcategory subcategory) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      if (subcategory.id == null) {
        await _repo.addSubcategory(subcategory, businessId);
      } else {
        await _repo.updateSubcategory(subcategory);
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

  Future<bool> deleteSubcategory(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteSubcategory(id);
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

  Future<bool> saveCustomerType(CustomerType customerType) async {
    state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      await _repo.addCustomerType(customerType, businessId);
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

  Future<bool> deleteCustomerType(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteCustomerType(id);
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

final productFormProvider =
    StateNotifierProvider.autoDispose<ProductFormNotifier, AsyncValue<void>>(
      (ref) => ProductFormNotifier(ref.watch(productRepositoryProvider), ref),
    );
