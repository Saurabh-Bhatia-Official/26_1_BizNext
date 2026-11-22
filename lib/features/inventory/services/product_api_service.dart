import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/security/token_service.dart';
import '../models/product_model.dart';

class ProductApiException implements Exception {
  final String message;
  final int? statusCode;

  const ProductApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ProductApiPage {
  final List<Product> products;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool isLast;

  const ProductApiPage({
    required this.products,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.isLast,
  });

  factory ProductApiPage.fromJson(Map<String, dynamic> json) => ProductApiPage(
    products: (json['content'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              ProductApiService.productFromJson(item as Map<String, dynamic>),
        )
        .toList(),
    page: (json['page'] as num?)?.toInt() ?? 0,
    size: (json['size'] as num?)?.toInt() ?? 0,
    totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    isLast: json['last'] == true,
  );
}

class ProductApiService {
  static const String _configuredApiUrl = String.fromEnvironment(
    'BIZNEXT_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static Uri get _apiRoot {
    final configured = Uri.parse(_configuredApiUrl);
    var path = configured.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.endsWith('/api/customers')) {
      path = path.substring(0, path.length - '/customers'.length);
    } else if (!path.endsWith('/api')) {
      path = '$path/api';
    }
    return configured.replace(path: path);
  }

  static Uri _uri(String path, [Map<String, String>? query]) => _apiRoot
      .replace(path: '${_apiRoot.path}/products$path', queryParameters: query);

  static Future<ProductApiPage> getProducts({
    required int businessId,
    String query = '',
    int? categoryId,
    String? brand,
    String status = 'Active',
    bool lowStockOnly = false,
    int page = 0,
    int size = 50,
    String sortBy = 'name',
    String direction = 'asc',
  }) async {
    final params = <String, String>{
      'businessId': '$businessId',
      'status': status,
      'lowStock': '$lowStockOnly',
      'page': '$page',
      'size': '$size',
      'sortBy': sortBy,
      'direction': direction,
    };
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    if (categoryId != null) params['categoryId'] = '$categoryId';
    if (brand != null && brand.trim().isNotEmpty)
      params['brand'] = brand.trim();
    final response = await http.get(
      _uri('', params),
      headers: await _headers(),
    );
    _throwIfError(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected paginated product response.');
    }
    return ProductApiPage.fromJson(decoded);
  }

  static Future<List<Product>> getAllProducts({
    required int businessId,
    String query = '',
    int? categoryId,
    String? brand,
    String status = 'Active',
    bool lowStockOnly = false,
    String sortBy = 'name',
    String direction = 'asc',
  }) async {
    final products = <Product>[];
    var page = 0;
    while (true) {
      final result = await getProducts(
        businessId: businessId,
        query: query,
        categoryId: categoryId,
        brand: brand,
        status: status,
        lowStockOnly: lowStockOnly,
        page: page,
        size: 200,
        sortBy: sortBy,
        direction: direction,
      );
      products.addAll(result.products);
      if (result.isLast || result.totalPages <= page + 1) return products;
      page++;
    }
  }

  static Future<Product?> getProductById({
    required int id,
    required int businessId,
  }) async {
    final response = await http.get(
      _uri('/$id', {'businessId': '$businessId'}),
      headers: await _headers(),
    );
    if (response.statusCode == 404) return null;
    _throwIfError(response);
    return productFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<List<Category>> getCategories({required int businessId}) async {
    final response = await http.get(
      _uri('/categories', {'businessId': '$businessId'}),
      headers: await _headers(),
    );
    _throwIfError(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Unexpected product category response.');
    }
    return decoded
        .map((item) => productCategoryFromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Category> createCategory({
    required int businessId,
    required String name,
  }) async {
    final response = await http.post(
      _uri('/categories'),
      headers: await _headers(),
      body: jsonEncode({'businessId': businessId, 'name': name.trim()}),
    );
    _throwIfError(response);
    return productCategoryFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<Category> updateCategory({
    required int businessId,
    required int categoryId,
    required String name,
  }) async {
    final response = await http.put(
      _uri('/categories/$categoryId', {'businessId': '$businessId'}),
      headers: await _headers(),
      body: jsonEncode({'businessId': businessId, 'name': name.trim()}),
    );
    _throwIfError(response);
    return productCategoryFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<void> deleteCategory({
    required int businessId,
    required int categoryId,
  }) async {
    final response = await http.delete(
      _uri('/categories/$categoryId', {'businessId': '$businessId'}),
      headers: await _headers(),
    );
    _throwIfError(response);
  }

  static Future<Product> saveProduct({
    required Product product,
    required int businessId,
    String? imagePath,
    bool removeImage = false,
  }) async {
    final isCreate = product.id == null;
    final path = isCreate ? '' : '/${product.id}';
    final request = http.MultipartRequest(
      isCreate ? 'POST' : 'PUT',
      _uri(path, {if (!isCreate && removeImage) 'removeImage': 'true'}),
    );
    request.headers.addAll(await _headers(includeContentType: false));
    request.files.add(
      http.MultipartFile.fromString(
        'product',
        jsonEncode(_toJson(product, businessId)),
        contentType: MediaType('application', 'json'),
      ),
    );

    final selectedPath = imagePath?.trim();
    if (selectedPath != null &&
        selectedPath.isNotEmpty &&
        !isRemoteUrl(selectedPath)) {
      await _validateImage(selectedPath);
      request.files.add(
        await http.MultipartFile.fromPath('image', selectedPath),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    _throwIfError(response);
    return productFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> deleteProduct({
    required int id,
    required int businessId,
  }) async {
    final response = await http.delete(
      _uri('/$id', {'businessId': '$businessId'}),
      headers: await _headers(),
    );
    _throwIfError(response);
  }

  static Future<void> setProductStatus({
    required int id,
    required int businessId,
    required bool isActive,
  }) async {
    final response = await http.patch(
      _uri('/$id/status', {'businessId': '$businessId'}),
      headers: await _headers(),
      body: jsonEncode({'status': isActive ? 'Active' : 'Inactive'}),
    );
    _throwIfError(response);
  }

  static Future<void> adjustProductStock({
    required int id,
    required int businessId,
    required double adjustedQuantity,
    required String adjustmentType,
    required String reason,
  }) async {
    final response = await http.patch(
      _uri('/$id/stock'),
      headers: await _headers(),
      body: jsonEncode({
        'businessId': businessId,
        'adjustedQuantity': adjustedQuantity,
        'adjustmentType': adjustmentType,
        'reason': reason,
      }),
    );
    _throwIfError(response);
  }

  static Product productFromJson(Map<String, dynamic> json) => Product(
    id: (json['id'] as num?)?.toInt(),
    name: json['productName'] as String? ?? '',
    sku: json['sku'] as String?,
    barcode: json['barcode'] as String?,
    description: json['description'] as String?,
    categoryId: (json['categoryId'] as num?)?.toInt(),
    categoryName: json['categoryName'] as String?,
    brand: json['brand'] as String?,
    hsnSac: json['hsnSac'] as String?,
    purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0,
    mrp: (json['mrp'] as num?)?.toDouble() ?? 0,
    sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
    minSellingPrice: (json['minSellingPrice'] as num?)?.toDouble() ?? 0,
    wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble() ?? 0,
    dealerPrice: (json['dealerPrice'] as num?)?.toDouble() ?? 0,
    stock: (json['stockQuantity'] as num?)?.toDouble() ?? 0,
    minStock: (json['minimumStockLevel'] as num?)?.toDouble() ?? 5,
    unit: json['unit'] as String? ?? 'pcs',
    gstPercent: (json['taxPercentage'] as num?)?.toDouble() ?? 0,
    isActive: (json['status'] as String? ?? 'Active') == 'Active',
    createdAt: _dateTime(json['createdAt']),
    updatedAt: _dateTime(json['updatedAt']),
    imagePath: json['productImage'] as String?,
  );

  static Category productCategoryFromJson(Map<String, dynamic> json) =>
      Category(
        id: (json['id'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
      );

  static Map<String, dynamic> _toJson(Product product, int businessId) => {
    'businessId': businessId,
    'productName': product.name.trim(),
    'sku': _emptyToNull(product.sku),
    'categoryId': product.categoryId,
    'brand': _emptyToNull(product.brand),
    'description': _emptyToNull(product.description),
    'purchasePrice': product.purchasePrice,
    'mrp': product.mrp,
    'sellingPrice': product.sellingPrice,
    'minSellingPrice': product.minSellingPrice,
    'wholesalePrice': product.wholesalePrice,
    'dealerPrice': product.dealerPrice,
    'taxPercentage': product.gstPercent,
    'stockQuantity': product.stock,
    'minimumStockLevel': product.minStock,
    'unit': product.unit,
    'barcode': _emptyToNull(product.barcode),
    'hsnSac': _emptyToNull(product.hsnSac),
    'active': product.isActive,
  };

  static Future<void> _validateImage(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const ProductApiException(
        'The selected image file could not be found.',
      );
    }
    final extension = path.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw const ProductApiException(
        'Choose a JPG, JPEG, PNG, or WEBP product image.',
      );
    }
    if (await file.length() > 5 * 1024 * 1024) {
      throw const ProductApiException(
        'Product images must be 5 MB or smaller.',
      );
    }
  }

  static Future<Map<String, String>> _headers({
    bool includeContentType = true,
  }) async {
    final token = await TokenService.instance.getActiveToken();
    return {
      if (includeContentType) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static void _throwIfError(http.Response response) {
    if (response.statusCode < 400) return;
    var message = 'Product request failed.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      } else if (decoded is Map && decoded['error'] != null) {
        message = decoded['error'].toString();
      }
    } on FormatException {
      // Use the status-based message for non-JSON responses.
    }
    throw ProductApiException(message, statusCode: response.statusCode);
  }

  static DateTime? _dateTime(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  static String? _emptyToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  static bool isRemoteUrl(String value) =>
      value.startsWith('https://') || value.startsWith('http://');
}
