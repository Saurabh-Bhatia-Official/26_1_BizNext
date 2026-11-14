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
    int? subcategoryId,
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
    if (subcategoryId != null) {
      conditions.add('p.subcategory_id = ?');
      args.add(subcategoryId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ? OR p.brand LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    if (lowStockOnly == true) conditions.add('p.stock <= p.min_stock');

    final where = 'WHERE ${conditions.join(' AND ')}';

    final result = await _db.rawQuery('''
      SELECT 
        p.*, 
        c.name AS category_name,
        sc.name AS subcategory_name,
        s.name AS default_supplier_name
      FROM ${AppConstants.tblProducts} p
      LEFT JOIN ${AppConstants.tblCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tblSubcategories} sc ON p.subcategory_id = sc.id
      LEFT JOIN ${AppConstants.tblSuppliers} s ON p.default_supplier_id = s.id
      $where
      ORDER BY p.name ASC
    ''', args);

    return result.map(Product.fromMap).toList();
  }

  Future<Product?> getProductById(int id, int businessId) async {
    final result = await _db.rawQuery('''
      SELECT 
        p.*, 
        c.name AS category_name,
        sc.name AS subcategory_name,
        s.name AS default_supplier_name
      FROM ${AppConstants.tblProducts} p
      LEFT JOIN ${AppConstants.tblCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tblSubcategories} sc ON p.subcategory_id = sc.id
      LEFT JOIN ${AppConstants.tblSuppliers} s ON p.default_supplier_id = s.id
      WHERE p.id = ? AND p.business_id = ?
    ''', [id, businessId]);
    return result.isNotEmpty ? Product.fromMap(result.first) : null;
  }

  Future<Product?> getProductByBarcode(String barcode, int businessId) async {
    final result = await _db.rawQuery('''
      SELECT 
        p.*, 
        c.name AS category_name,
        sc.name AS subcategory_name,
        s.name AS default_supplier_name
      FROM ${AppConstants.tblProducts} p
      LEFT JOIN ${AppConstants.tblCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tblSubcategories} sc ON p.subcategory_id = sc.id
      LEFT JOIN ${AppConstants.tblSuppliers} s ON p.default_supplier_id = s.id
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
    final count = result.isNotEmpty ? ((result.first['cnt'] as num?)?.toInt() ?? 0) : 0;
    return count > 0;
  }

  Future<int> addProduct(Product product, int businessId) async {
    // Validations
    if (product.sellingPrice < 0 || product.purchasePrice < 0) {
      throw Exception("Price Error: Prices cannot be negative.");
    }
    if (product.sku != null && product.sku!.trim().isNotEmpty) {
      final skuResult = await _db.rawQuery(
        "SELECT COUNT(*) AS count FROM ${AppConstants.tblProducts} WHERE sku = ? AND business_id = ? AND is_active = 1",
        [product.sku, businessId],
      );
      if (skuResult.isNotEmpty && (((skuResult.first['count'] as num?)?.toInt() ?? 0) > 0)) {
        throw Exception("Duplicate SKU Error: A product with SKU '${product.sku}' already exists.");
      }
    }
    if (product.barcode != null && product.barcode!.trim().isNotEmpty) {
      final barcodeResult = await _db.rawQuery(
        "SELECT COUNT(*) AS count FROM ${AppConstants.tblProducts} WHERE barcode = ? AND business_id = ? AND is_active = 1",
        [product.barcode, businessId],
      );
      if (barcodeResult.isNotEmpty && (((barcodeResult.first['count'] as num?)?.toInt() ?? 0) > 0)) {
        throw Exception("Duplicate Barcode Error: A product with barcode '${product.barcode}' already exists.");
      }
    }

    final data = product.toMap();
    data['business_id'] = businessId;

    return await _db.transaction((txn) async {
      final productId = await txn.insert(AppConstants.tblProducts, data);

      // Get Default Warehouse
      final warehouseResult = await txn.query(
        AppConstants.tblWarehouses,
        columns: ['id'],
        where: 'business_id = ?',
        whereArgs: [businessId],
        limit: 1,
      );
      final warehouseId = warehouseResult.isNotEmpty ? (warehouseResult.first['id'] as int?) ?? 1 : 1;

      // Initialize warehouse stock
      await txn.insert(AppConstants.tblWarehouseStocks, {
        'warehouse_id': warehouseId,
        'product_id': productId,
        'stock': product.stock,
      });

      // If initial opening stock was specified, log an immutable OPENING_STOCK inventory transaction
      if (product.stock > 0) {
        await txn.insert(AppConstants.tblInventoryTransactions, {
          'product_id': productId,
          'warehouse_id': warehouseId,
          'transaction_type': AppConstants.transactionTypeOpeningStock,
          'reference_number': 'OPENING-STOCK',
          'quantity': product.stock,
          'unit_cost': product.purchasePrice,
          'opening_stock': 0,
          'closing_stock': product.stock,
          'remarks': 'Initial product opening stock balance',
        });
      }

      return productId;
    });
  }

  Future<int> updateProduct(Product product) async {
    if (product.id == null) throw ArgumentError('Product id is required');
    
    // Validations
    if (product.sellingPrice < 0 || product.purchasePrice < 0) {
      throw Exception("Price Error: Prices cannot be negative.");
    }
    
    final businessIdResult = await _db.rawQuery("SELECT business_id, stock FROM ${AppConstants.tblProducts} WHERE id = ?", [product.id]);
    final businessId = businessIdResult.isNotEmpty ? (businessIdResult.first['business_id'] as num?)?.toInt() ?? 1 : 1;
    final existingStock = businessIdResult.isNotEmpty ? (businessIdResult.first['stock'] as num?)?.toDouble() ?? 0.0 : 0.0;

    if (product.sku != null && product.sku!.trim().isNotEmpty) {
      final skuResult = await _db.rawQuery(
        "SELECT COUNT(*) AS count FROM ${AppConstants.tblProducts} WHERE sku = ? AND business_id = ? AND id != ? AND is_active = 1",
        [product.sku, businessId, product.id],
      );
      if (skuResult.isNotEmpty && (((skuResult.first['count'] as num?)?.toInt() ?? 0) > 0)) {
        throw Exception("Duplicate SKU Error: Another product with SKU '${product.sku}' already exists.");
      }
    }
    if (product.barcode != null && product.barcode!.trim().isNotEmpty) {
      final barcodeResult = await _db.rawQuery(
        "SELECT COUNT(*) AS count FROM ${AppConstants.tblProducts} WHERE barcode = ? AND business_id = ? AND id != ? AND is_active = 1",
        [product.barcode, businessId, product.id],
      );
      if (barcodeResult.isNotEmpty && (((barcodeResult.first['count'] as num?)?.toInt() ?? 0) > 0)) {
        throw Exception("Duplicate Barcode Error: Another product with barcode '${product.barcode}' already exists.");
      }
    }

    final data = product.toMap();
    // Rule: Never allow overwriting stock from normal product screen
    data['stock'] = existingStock;

    return _db.update(AppConstants.tblProducts, data, product.id!);
  }

  Future<int> deleteProduct(int id) async {
    return _db.update(AppConstants.tblProducts, {'is_active': 0}, id);
  }

  /// Restore a soft-deleted product by setting is_active = 1.
  Future<int> restoreProduct(int id) async {
    return _db.update(AppConstants.tblProducts, {'is_active': 1}, id);
  }

  // ── Stock Adjustments & Stock Movement Ledger ─────────────────────────────

  Future<int> recordStockAdjustment({
    required int businessId,
    required int productId,
    required double adjustedQty, // Positive to increase, negative to decrease
    required String adjustmentType, // 'PHYSICAL_DISCREPANCY', 'DAMAGE', 'WASTAGE', 'EXPIRED', 'RETURN_TO_STOCK'
    required String reason,
    int? userId,
    int? warehouseId,
  }) async {
    return await _db.transaction((txn) async {
      final productRes = await txn.query(
        AppConstants.tblProducts,
        columns: ['stock', 'purchase_price', 'name'],
        where: 'id = ? AND business_id = ?',
        whereArgs: [productId, businessId],
      );
      if (productRes.isEmpty) throw Exception("Product ID $productId not found.");

      final currentStock = (productRes.first['stock'] as num?)?.toDouble() ?? 0.0;
      final unitCost = (productRes.first['purchase_price'] as num?)?.toDouble() ?? 0.0;
      final newStock = currentStock + adjustedQty;

      if (newStock < 0) {
        throw Exception("Stock Error: Stock adjustment would result in negative stock ($newStock).");
      }

      final wId = warehouseId ?? 1;

      // Update product stock
      await txn.rawUpdate(
        "UPDATE ${AppConstants.tblProducts} SET stock = ?, updated_at = datetime('now') WHERE id = ? AND business_id = ?",
        [newStock, productId, businessId],
      );

      // Update warehouse stock
      await txn.rawUpdate(
        "UPDATE ${AppConstants.tblWarehouseStocks} SET stock = stock + ? WHERE warehouse_id = ? AND product_id = ?",
        [adjustedQty, wId, productId],
      );

      // Log Stock Ledger Transaction
      final txType = (adjustmentType == 'DAMAGE' || adjustmentType == 'WASTAGE')
          ? AppConstants.transactionTypeDamageWastage
          : AppConstants.transactionTypeStockAdjustment;

      final txId = await txn.insert(AppConstants.tblInventoryTransactions, {
        'product_id': productId,
        'warehouse_id': wId,
        'transaction_type': txType,
        'reference_number': 'ADJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'quantity': adjustedQty,
        'unit_cost': unitCost,
        'opening_stock': currentStock,
        'closing_stock': newStock,
        'created_by': userId,
        'remarks': '$adjustmentType: $reason',
      });

      // Log Audit Trail
      await txn.insert(AppConstants.tblAuditLogs, {
        'user_id': userId,
        'module': 'INVENTORY',
        'action_type': 'STOCK_ADJUSTMENT',
        'record_id': productId,
        'previous_state': '{"stock": $currentStock}',
        'new_state': '{"stock": $newStock, "adjustment": $adjustedQty, "type": "$adjustmentType"}',
      });

      return txId;
    });
  }

  Future<List<Map<String, dynamic>>> getStockLedger(
    int businessId, {
    int? productId,
    String? transactionType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final conditions = <String>['p.business_id = ?'];
    final args = <dynamic>[businessId];

    if (productId != null) {
      conditions.add('it.product_id = ?');
      args.add(productId);
    }
    if (transactionType != null && transactionType.isNotEmpty) {
      conditions.add('it.transaction_type = ?');
      args.add(transactionType);
    }
    if (startDate != null) {
      conditions.add('it.created_date >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      conditions.add('it.created_date <= ?');
      args.add(endDate.toIso8601String());
    }

    final where = 'WHERE ${conditions.join(' AND ')}';

    return await _db.rawQuery('''
      SELECT 
        it.*,
        p.name AS product_name,
        p.unit AS product_unit,
        p.sku AS product_sku,
        w.name AS warehouse_name
      FROM ${AppConstants.tblInventoryTransactions} it
      JOIN ${AppConstants.tblProducts} p ON it.product_id = p.id
      LEFT JOIN ${AppConstants.tblWarehouses} w ON it.warehouse_id = w.id
      $where
      ORDER BY it.id DESC
    ''', args);
  }

  Future<Map<String, dynamic>> getInventoryStats(int businessId) async {
    final result = await _db.rawQuery('''
      SELECT
        COUNT(*) AS total_products,
        SUM(CASE WHEN stock <= min_stock AND stock > 0 THEN 1 ELSE 0 END) AS low_stock_count,
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
      orderBy: 'display_order ASC, name ASC',
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

  // ── Subcategories ──────────────────────────────────────────────────────────

  Future<List<Subcategory>> getSubcategories(int businessId, {int? categoryId}) async {
    String where = 'business_id = ?';
    List<dynamic> whereArgs = [businessId];
    if (categoryId != null) {
      where += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }
    final result = await _db.queryAll(
      AppConstants.tblSubcategories,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return result.map(Subcategory.fromMap).toList();
  }

  Future<int> addSubcategory(Subcategory subcategory, int businessId) async {
    final data = subcategory.toMap();
    data['business_id'] = businessId;
    return _db.insert(AppConstants.tblSubcategories, data);
  }

  Future<int> updateSubcategory(Subcategory subcategory) async {
    if (subcategory.id == null) throw ArgumentError('Subcategory id is required');
    return _db.update(AppConstants.tblSubcategories, subcategory.toMap(), subcategory.id!);
  }

  Future<int> deleteSubcategory(int id) async {
    return _db.delete(AppConstants.tblSubcategories, id);
  }

  // ── Customer Types (Price Lists) ───────────────────────────────────────────

  Future<List<CustomerType>> getCustomerTypes(int businessId) async {
    final result = await _db.queryAll(
      AppConstants.tblCustomerTypes,
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );
    return result.map(CustomerType.fromMap).toList();
  }

  Future<int> addCustomerType(CustomerType customerType, int businessId) async {
    final data = customerType.toMap();
    data['business_id'] = businessId;
    return _db.insert(AppConstants.tblCustomerTypes, data);
  }

  Future<int> deleteCustomerType(int id) async {
    return _db.delete(AppConstants.tblCustomerTypes, id);
  }

  // ── Price Categories (Legacy Compatibility) ────────────────────────────────

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
      SELECT tp.*, COALESCE(ct.name, pc.name) as category_name
      FROM ${AppConstants.tblProductPrices} tp
      LEFT JOIN ${AppConstants.tblCustomerTypes} ct ON tp.category_id = ct.id
      LEFT JOIN ${AppConstants.tblPriceCategories} pc ON tp.category_id = pc.id
      WHERE tp.product_id = ?
      ORDER BY tp.min_qty ASC
    ''', [productId]);
    return result.map(ProductTierPrice.fromMap).toList();
  }

  Future<Map<int, List<ProductTierPrice>>> getAllProductPrices(int businessId) async {
    final result = await _db.rawQuery('''
      SELECT tp.*, COALESCE(ct.name, pc.name) as category_name
      FROM ${AppConstants.tblProductPrices} tp
      JOIN ${AppConstants.tblProducts} p ON tp.product_id = p.id
      LEFT JOIN ${AppConstants.tblCustomerTypes} ct ON tp.category_id = ct.id
      LEFT JOIN ${AppConstants.tblPriceCategories} pc ON tp.category_id = pc.id
      WHERE p.business_id = ?
      ORDER BY tp.min_qty ASC
    ''', [businessId]);
    final Map<int, List<ProductTierPrice>> map = {};
    for (final row in result) {
      final item = ProductTierPrice.fromMap(row);
      map.putIfAbsent(item.productId, () => []).add(item);
    }
    return map;
  }

  Future<void> updateProductPrices(int productId, List<ProductTierPrice> prices) async {
    await _db.transaction((txn) async {
      await txn.delete(
        AppConstants.tblProductPrices,
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      
      for (final p in prices) {
        await txn.insert(AppConstants.tblProductPrices, {
          'product_id': productId,
          'category_id': p.categoryId,
          'min_qty': p.minQty,
          'max_qty': p.maxQty,
          'price': p.price,
          'discount_percent': p.discountPercent,
        });
      }
      _db.notify(AppConstants.tblProductPrices);
    });
  }

  // ── Product Batches ────────────────────────────────────────────────────────

  Future<List<ProductBatch>> getProductBatches(int productId) async {
    final result = await _db.queryAll(
      AppConstants.tblProductBatches,
      where: 'product_id = ? AND quantity > 0',
      whereArgs: [productId],
      orderBy: 'expiry_date ASC', // FEFO
    );
    return result.map(ProductBatch.fromMap).toList();
  }

  Future<int> addProductBatch(ProductBatch batch, int businessId) async {
    final data = batch.toMap();
    data['business_id'] = businessId;
    return _db.insert(AppConstants.tblProductBatches, data);
  }
}
