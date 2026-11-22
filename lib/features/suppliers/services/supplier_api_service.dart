import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/security/token_service.dart';
import '../models/supplier_model.dart';

class SupplierApiException implements Exception {
  final String message;
  final int statusCode;

  const SupplierApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class SupplierApiService {
  static const String _defaultBaseUrl = 'http://localhost:8080';

  static Uri get root {
    final configured = const String.fromEnvironment(
      'BIZNEXT_API_BASE_URL',
      defaultValue: _defaultBaseUrl,
    );
    final uri = Uri.parse(configured);
    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.endsWith('/api/suppliers')) {
      path = path.substring(0, path.length - '/suppliers'.length);
    } else if (!path.endsWith('/api')) {
      path = '$path/api';
    }
    return uri.replace(path: path);
  }

  static Uri _uri([String path = '', Map<String, String>? query]) =>
      root.replace(path: '${root.path}/suppliers$path', queryParameters: query);

  static Future<Map<String, String>> _headers() async {
    final token = await TokenService.instance.getActiveToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<SupplierModel>> getSuppliers({
    required int businessId,
    bool includeInactive = false,
  }) async {
    final response = await http.get(
      _uri('', {
        'businessId': '$businessId',
        'includeInactive': '$includeInactive',
      }),
      headers: await _headers(),
    );
    _throwIfError(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Unexpected supplier response.');
    }
    return decoded
        .map((item) => _fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<SupplierModel?> getSupplierById({
    required int id,
    required int businessId,
  }) async {
    final response = await http.get(
      _uri('/$id', {'businessId': '$businessId'}),
      headers: await _headers(),
    );
    if (response.statusCode == 404) return null;
    _throwIfError(response);
    return _fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<SupplierModel> create(SupplierModel supplier) async {
    final response = await http.post(
      _uri(),
      headers: await _headers(),
      body: jsonEncode(_toJson(supplier)),
    );
    _throwIfError(response);
    return _fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<SupplierModel> update(SupplierModel supplier) async {
    final response = await http.put(
      _uri('/${supplier.id}', {'businessId': '${supplier.businessId}'}),
      headers: await _headers(),
      body: jsonEncode(_toJson(supplier)),
    );
    _throwIfError(response);
    return _fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> delete({
    required int id,
    required int businessId,
  }) async {
    final response = await http.delete(
      _uri('/$id', {'businessId': '$businessId'}),
      headers: await _headers(),
    );
    _throwIfError(response);
  }

  static Map<String, dynamic> _toJson(SupplierModel supplier) => {
        'businessId': supplier.businessId,
        'name': supplier.name,
        'phone': supplier.phone,
        'email': supplier.email,
        'address': supplier.address,
        'gstNumber': supplier.gstNumber,
        'balance': supplier.balance,
        'active': supplier.isActive,
      };

  static SupplierModel _fromJson(Map<String, dynamic> json) => SupplierModel(
        id: (json['id'] as num?)?.toInt(),
        businessId: (json['businessId'] as num?)?.toInt() ?? 1,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        gstNumber: json['gstNumber'] as String?,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        isActive: json['active'] != false,
        createdAt: json['createdAt'] == null
            ? DateTime.now()
            : DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
      );

  static void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = 'Supplier API request failed.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } catch (_) {}
    throw SupplierApiException(message, response.statusCode);
  }
}
