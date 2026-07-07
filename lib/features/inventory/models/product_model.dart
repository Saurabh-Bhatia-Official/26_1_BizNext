// lib/features/inventory/models/product_model.dart

class Product {
  final int? id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final int? categoryId;
  final String? categoryName;
  final double purchasePrice;
  final double sellingPrice;
  final double wholesalePrice;
  final double dealerPrice;
  final double stock;
  final double minStock;
  final String unit;
  final double gstPercent;
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
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.wholesalePrice = 0,
    this.dealerPrice = 0,
    this.stock = 0,
    this.minStock = 5,
    this.unit = 'pcs',
    this.gstPercent = 0,
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
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
        wholesalePrice: (map['wholesale_price'] as num?)?.toDouble() ?? 0,
        dealerPrice: (map['dealer_price'] as num?)?.toDouble() ?? 0,
        stock: (map['stock'] as num?)?.toDouble() ?? 0,
        minStock: (map['min_stock'] as num?)?.toDouble() ?? 5,
        unit: map['unit'] as String? ?? 'pcs',
        gstPercent: (map['gst_percent'] as num?)?.toDouble() ?? 0,
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
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'wholesale_price': wholesalePrice,
        'dealer_price': dealerPrice,
        'stock': stock,
        'min_stock': minStock,
        'unit': unit,
        'gst_percent': gstPercent,
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
    double? purchasePrice,
    double? sellingPrice,
    double? wholesalePrice,
    double? dealerPrice,
    double? stock,
    double? minStock,
    String? unit,
    double? gstPercent,
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
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      dealerPrice: dealerPrice ?? this.dealerPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      gstPercent: gstPercent ?? this.gstPercent,
      isActive: isActive ?? this.isActive,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

// ── Price Category Model ───────────────────────────────────────────────────
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
  final double price;

  const ProductTierPrice({
    this.id,
    required this.productId,
    required this.categoryId,
    this.categoryName,
    required this.price,
  });

  factory ProductTierPrice.fromMap(Map<String, dynamic> map) => ProductTierPrice(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        categoryId: map['category_id'] as int,
        categoryName: map['category_name'] as String?,
        price: (map['price'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'category_id': categoryId,
        'price': price,
      };
}

// ── Category Model ────────────────────────────────────────────────────────────
class Category {
  final int? id;
  final String name;
  final String? description;

  const Category({this.id, required this.name, this.description});

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
      };
}
