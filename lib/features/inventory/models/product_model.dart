// lib/features/inventory/models/product_model.dart

class Product {
  final int? id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final int? categoryId;
  final String? categoryName;
  final int? subcategoryId;
  final String? subcategoryName;
  final String? brand;
  final String? hsnSac;
  final double purchasePrice;
  final double mrp;
  final double sellingPrice;
  final double minSellingPrice;
  final double wholesalePrice;
  final double dealerPrice;
  final double stock;
  final double minStock;
  final String unit;
  final double gstPercent;
  final int? defaultSupplierId;
  final String? defaultSupplierName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? imagePath;

  const Product({
    this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.categoryId,
    this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    this.brand,
    this.hsnSac,
    this.purchasePrice = 0,
    this.mrp = 0,
    this.sellingPrice = 0,
    this.minSellingPrice = 0,
    this.wholesalePrice = 0,
    this.dealerPrice = 0,
    this.stock = 0,
    this.minStock = 5,
    this.unit = 'pcs',
    this.gstPercent = 0,
    this.defaultSupplierId,
    this.defaultSupplierName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.imagePath,
  });

  bool get isLowStock => stock <= minStock;
  bool get isOutOfStock => stock <= 0;

  double get profit => sellingPrice - purchasePrice;
  double get profitPercent =>
      purchasePrice > 0 ? (profit / purchasePrice) * 100 : 0;

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        sku: map['sku'] as String?,
        barcode: map['barcode'] as String?,
        description: map['description'] as String?,
        categoryId: map['category_id'] as int?,
        categoryName: map['category_name'] as String?,
        subcategoryId: map['subcategory_id'] as int?,
        subcategoryName: map['subcategory_name'] as String?,
        brand: map['brand'] as String?,
        hsnSac: map['hsn_sac'] as String?,
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
        mrp: (map['mrp'] as num?)?.toDouble() ?? 0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
        minSellingPrice: (map['min_selling_price'] as num?)?.toDouble() ?? 0,
        wholesalePrice: (map['wholesale_price'] as num?)?.toDouble() ?? 0,
        dealerPrice: (map['dealer_price'] as num?)?.toDouble() ?? 0,
        stock: (map['stock'] as num?)?.toDouble() ?? 0,
        minStock: (map['min_stock'] as num?)?.toDouble() ?? 5,
        unit: map['unit'] as String? ?? 'pcs',
        gstPercent: (map['gst_percent'] as num?)?.toDouble() ?? 0,
        defaultSupplierId: map['default_supplier_id'] as int?,
        defaultSupplierName: map['default_supplier_name'] as String?,
        isActive: (map['is_active'] as int?) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
        imagePath: map['image_path'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'description': description,
        'category_id': categoryId,
        'subcategory_id': subcategoryId,
        'brand': brand,
        'hsn_sac': hsnSac,
        'purchase_price': purchasePrice,
        'mrp': mrp,
        'selling_price': sellingPrice,
        'min_selling_price': minSellingPrice,
        'wholesale_price': wholesalePrice,
        'dealer_price': dealerPrice,
        'stock': stock,
        'min_stock': minStock,
        'unit': unit,
        'gst_percent': gstPercent,
        'default_supplier_id': defaultSupplierId,
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'image_path': imagePath,
      };

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    String? description,
    int? categoryId,
    String? categoryName,
    int? subcategoryId,
    String? subcategoryName,
    String? brand,
    String? hsnSac,
    double? purchasePrice,
    double? mrp,
    double? sellingPrice,
    double? minSellingPrice,
    double? wholesalePrice,
    double? dealerPrice,
    double? stock,
    double? minStock,
    String? unit,
    double? gstPercent,
    int? defaultSupplierId,
    String? defaultSupplierName,
    bool? isActive,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      brand: brand ?? this.brand,
      hsnSac: hsnSac ?? this.hsnSac,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      minSellingPrice: minSellingPrice ?? this.minSellingPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      dealerPrice: dealerPrice ?? this.dealerPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      gstPercent: gstPercent ?? this.gstPercent,
      defaultSupplierId: defaultSupplierId ?? this.defaultSupplierId,
      defaultSupplierName: defaultSupplierName ?? this.defaultSupplierName,
      isActive: isActive ?? this.isActive,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

// ── Customer Type Model ───────────────────────────────────────────────────
class CustomerType {
  final int? id;
  final String name;
  final String? code;
  final String? description;
  final bool isActive;

  const CustomerType({
    this.id,
    required this.name,
    this.code,
    this.description,
    this.isActive = true,
  });

  factory CustomerType.fromMap(Map<String, dynamic> map) => CustomerType(
        id: map['id'] as int?,
        name: map['name'] as String,
        code: map['code'] as String?,
        description: map['description'] as String?,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'code': code,
        'description': description,
        'is_active': isActive ? 1 : 0,
      };
}

// ── Price Category Model (Legacy Alias) ────────────────────────────────────
class PriceCategory {
  final int? id;
  final String name;

  const PriceCategory({this.id, required this.name});

  factory PriceCategory.fromMap(Map<String, dynamic> map) => PriceCategory(
        id: map['id'] as int?,
        name: map['name'] as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
      };
}

// ── Product Tiered Price Model ─────────────────────────────────────────────
class ProductTierPrice {
  final int? id;
  final int productId;
  final int categoryId;
  final String? categoryName;
  final double minQty;
  final double maxQty;
  final double price;
  final double discountPercent;

  const ProductTierPrice({
    this.id,
    required this.productId,
    required this.categoryId,
    this.categoryName,
    this.minQty = 1,
    this.maxQty = 999999,
    required this.price,
    this.discountPercent = 0,
  });

  factory ProductTierPrice.fromMap(Map<String, dynamic> map) => ProductTierPrice(
        id: (map['id'] as num?)?.toInt(),
        productId: (map['product_id'] as num?)?.toInt() ?? 0,
        categoryId: (map['category_id'] as num?)?.toInt() ?? 0,
        categoryName: map['category_name'] as String?,
        minQty: (map['min_qty'] as num?)?.toDouble() ?? 1.0,
        maxQty: (map['max_qty'] as num?)?.toDouble() ?? 999999.0,
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'category_id': categoryId,
        'min_qty': minQty,
        'max_qty': maxQty,
        'price': price,
        'discount_percent': discountPercent,
      };
}

// ── Category Model ────────────────────────────────────────────────────────────
class Category {
  final int? id;
  final String name;
  final String? code;
  final String? description;
  final String? imagePath;
  final int displayOrder;
  final bool isActive;

  const Category({
    this.id,
    required this.name,
    this.code,
    this.description,
    this.imagePath,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        code: map['code'] as String?,
        description: map['description'] as String?,
        imagePath: map['image_path'] as String?,
        displayOrder: map['display_order'] as int? ?? 0,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'code': code,
        'description': description,
        'image_path': imagePath,
        'display_order': displayOrder,
        'is_active': isActive ? 1 : 0,
      };
}

// ── Subcategory Model ─────────────────────────────────────────────────────────
class Subcategory {
  final int? id;
  final int categoryId;
  final String name;
  final String? code;
  final String? description;
  final bool isActive;

  const Subcategory({
    this.id,
    required this.categoryId,
    required this.name,
    this.code,
    this.description,
    this.isActive = true,
  });

  factory Subcategory.fromMap(Map<String, dynamic> map) => Subcategory(
        id: map['id'] as int?,
        categoryId: map['category_id'] as int,
        name: map['name'] as String,
        code: map['code'] as String?,
        description: map['description'] as String?,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category_id': categoryId,
        'name': name,
        'code': code,
        'description': description,
        'is_active': isActive ? 1 : 0,
      };
}

// ── Supplier Product Mapping Model ──────────────────────────────────────────
class SupplierProduct {
  final int? id;
  final int supplierId;
  final int productId;
  final String? supplierSku;
  final String? supplierBarcode;
  final double lastPurchasePrice;
  final DateTime? lastPurchaseDate;
  final double lastPurchaseQty;

  const SupplierProduct({
    this.id,
    required this.supplierId,
    required this.productId,
    this.supplierSku,
    this.supplierBarcode,
    this.lastPurchasePrice = 0,
    this.lastPurchaseDate,
    this.lastPurchaseQty = 0,
  });

  factory SupplierProduct.fromMap(Map<String, dynamic> map) => SupplierProduct(
        id: map['id'] as int?,
        supplierId: map['supplier_id'] as int,
        productId: map['product_id'] as int,
        supplierSku: map['supplier_sku'] as String?,
        supplierBarcode: map['supplier_barcode'] as String?,
        lastPurchasePrice: (map['last_purchase_price'] as num?)?.toDouble() ?? 0,
        lastPurchaseDate: map['last_purchase_date'] != null
            ? DateTime.tryParse(map['last_purchase_date'] as String)
            : null,
        lastPurchaseQty: (map['last_purchase_qty'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'supplier_id': supplierId,
        'product_id': productId,
        'supplier_sku': supplierSku,
        'supplier_barcode': supplierBarcode,
        'last_purchase_price': lastPurchasePrice,
        'last_purchase_date': lastPurchaseDate?.toIso8601String(),
        'last_purchase_qty': lastPurchaseQty,
      };
}

// ── Product Batch Model ──────────────────────────────────────────────────────
class ProductBatch {
  final int? id;
  final int productId;
  final String batchNumber;
  final DateTime? mfgDate;
  final DateTime? expiryDate;
  final double purchaseRate;
  final double quantity;
  final int? supplierId;
  final int? warehouseId;

  const ProductBatch({
    this.id,
    required this.productId,
    required this.batchNumber,
    this.mfgDate,
    this.expiryDate,
    this.purchaseRate = 0,
    this.quantity = 0,
    this.supplierId,
    this.warehouseId,
  });

  bool get isExpired => isExpiredAt(DateTime.now());

  /// Deterministically checks if batch has expired at given timestamp
  bool isExpiredAt([DateTime? now]) =>
      expiryDate != null && expiryDate!.isBefore(now ?? DateTime.now());

  factory ProductBatch.fromMap(Map<String, dynamic> map) => ProductBatch(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        batchNumber: map['batch_number'] as String,
        mfgDate: map['mfg_date'] != null
            ? DateTime.tryParse(map['mfg_date'] as String)
            : null,
        expiryDate: map['expiry_date'] != null
            ? DateTime.tryParse(map['expiry_date'] as String)
            : null,
        purchaseRate: (map['purchase_rate'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        supplierId: map['supplier_id'] as int?,
        warehouseId: map['warehouse_id'] as int?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'batch_number': batchNumber,
        'mfg_date': mfgDate?.toIso8601String(),
        'expiry_date': expiryDate?.toIso8601String(),
        'purchase_rate': purchaseRate,
        'quantity': quantity,
        'supplier_id': supplierId,
        'warehouse_id': warehouseId,
      };
}
