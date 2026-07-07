// lib/features/inventory/repositories/product_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/product_model.dart';

class ProductRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ── Products ───────────────────────────────────────────────────────────────

  Future<List<Product>> getAllProducts({
    required int businessId,
    String? searchQuery,
    int? categoryId,
    bool? lowStockOnly,
    bool includeInactive = false,
  }) async {
    final conditions = <String>['p.business_id = ?'];
    final args = <dynamic>[businessId];

    if (!includeInactive) conditions.add('p.is_active = 1');
    if (categoryId != null) {
      conditions.add('p.category_id = ?');
      args.add(categoryId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    if (lowStockOnly == true) conditions.add('p.stock <= p.min_stock');

    final where = 'WHERE ${conditions.join(' AND ')}';

    final result = await _db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM ${AppConstants.tblProducts} p
      LEFT JOIN ${AppConstants.tblCategories} c ON p.category_id = c.id
      $where
      ORDER BY p.name ASC
    ''', args);

    return result.map(Product.fromMap).toList();
  }

  Future<Product?> getProductById(int id) async {
    final result = await _db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM ${AppConstants.tblProducts} p
      LEFT JOIN ${AppConstants.tblCategories} c ON p.category_id = c.id
      WHERE p.id = ?
    ''', [id]);
    return result.isNotEmpty ? Product.fromMap(result.first) : null;
  }

  Future<Product?> getProductByBarcode(String barcode, int businessId) async {
    final result = await _db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM ${AppConstants.tblProducts} p
      LEFT JOIN ${AppConstants.tblCategories} c ON p.category_id = c.id
      WHERE p.barcode = ? AND p.business_id = ?
    ''', [barcode, businessId]);
    return result.isNotEmpty ? Product.fromMap(result.first) : null;
  }

  /// Returns true if another product with [name] already exists in [businessId].
  /// When editing, pass [excludeId] to skip the current product.
  Future<bool> isProductNameTaken(String name, int businessId, {int? excludeId}) async {
    final lowerName = name.trim().toLowerCase();
    String query = '''
      SELECT COUNT(*) AS cnt
      FROM ${AppConstants.tblProducts}
      WHERE LOWER(name) = ? AND business_id = ? AND is_active = 1
    ''';
    final args = <dynamic>[lowerName, businessId];
    if (excludeId != null) {
      query += ' AND id != ?';
      args.add(excludeId);
    }
    final result = await _db.rawQuery(query, args);
    final count = result.isNotEmpty ? (result.first['cnt'] as int? ?? 0) : 0;
    return count > 0;
  }

  Future<int> addProduct(Product product, int businessId) async {
    final data = product.toMap();
    data['business_id'] = businessId;
    return _db.insert(AppConstants.tblProducts, data);
  }

  Future<int> updateProduct(Product product) async {
    if (product.id == null) throw ArgumentError('Product id is required');
    return _db.update(AppConstants.tblProducts, product.toMap(), product.id!);
  }

  Future<int> deleteProduct(int id) async {
    return _db.update(AppConstants.tblProducts, {'is_active': 0}, id);
  }

  /// Restore a soft-deleted product by setting is_active = 1.
  Future<int> restoreProduct(int id) async {
    return _db.update(AppConstants.tblProducts, {'is_active': 1}, id);
  }

  Future<void> adjustStock(int productId, double adjustment) async {
    await _db.rawUpdate(
      "UPDATE ${AppConstants.tblProducts} SET stock = stock + ?, updated_at = datetime('now') WHERE id = ?",
      [adjustment, productId],
    );
  }

  Future<Map<String, dynamic>> getInventoryStats(int businessId) async {
    final result = await _db.rawQuery('''
      SELECT
        COUNT(*) AS total_products,
        SUM(CASE WHEN stock <= min_stock THEN 1 ELSE 0 END) AS low_stock_count,
        SUM(CASE WHEN stock <= 0 THEN 1 ELSE 0 END) AS out_of_stock_count,
        SUM(stock * purchase_price) AS inventory_value
      FROM ${AppConstants.tblProducts}
      WHERE is_active = 1 AND business_id = ?
    ''', [businessId]);
    return result.isNotEmpty ? result.first : {};
  }

  // ── Categories ─────────────────────────────────────────────────────────────

  Future<List<Category>> getAllCategories(int businessId) async {
    final result = await _db.queryAll(
      AppConstants.tblCategories,
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );
    return result.map(Category.fromMap).toList();
  }

  Future<int> addCategory(Category category, int businessId) async {
    final data = category.toMap();
    data['business_id'] = businessId;
    return _db.insert(AppConstants.tblCategories, data);
  }

  Future<int> updateCategory(Category category) async {
    if (category.id == null) throw ArgumentError('Category id is required');
    return _db.update(AppConstants.tblCategories, category.toMap(), category.id!);
  }

  Future<int> deleteCategory(int id) async {
    return _db.delete(AppConstants.tblCategories, id);
  }

  // ── Price Categories ───────────────────────────────────────────────────────

  Future<List<PriceCategory>> getPriceCategories(int businessId) async {
    final result = await _db.queryAll(
      AppConstants.tblPriceCategories,
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );
    return result.map(PriceCategory.fromMap).toList();
  }

  Future<int> addPriceCategory(PriceCategory category, int businessId) async {
    final data = category.toMap();
    data['business_id'] = businessId;
    return _db.insert(AppConstants.tblPriceCategories, data);
  }

  Future<int> deletePriceCategory(int id) async {
    return _db.delete(AppConstants.tblPriceCategories, id);
  }

  // ── Product Tiered Prices ──────────────────────────────────────────────────

  Future<List<ProductTierPrice>> getProductPrices(int productId) async {
    final result = await _db.rawQuery('''
      SELECT tp.*, pc.name as category_name
      FROM ${AppConstants.tblProductPrices} tp
      JOIN ${AppConstants.tblPriceCategories} pc ON tp.category_id = pc.id
      WHERE tp.product_id = ?
    ''', [productId]);
    return result.map(ProductTierPrice.fromMap).toList();
  }

  Future<void> updateProductPrices(int productId, List<ProductTierPrice> prices) async {
    await _db.transaction((txn) async {
      // Clear existing
      await txn.delete(
        AppConstants.tblProductPrices,
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      
      // Insert new
      for (final p in prices) {
        await txn.insert(AppConstants.tblProductPrices, {
          'product_id': productId,
          'category_id': p.categoryId,
          'price': p.price,
        });
      }
    });
  }
}
