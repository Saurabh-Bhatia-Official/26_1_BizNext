import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/security/token_service.dart';
import '../models/customer_model.dart';

class CustomerHttpException implements Exception {
  final String message;
  final int statusCode;

  const CustomerHttpException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class CustomerHttpService {
  static const String _defaultBaseUrl = 'http://localhost:8080/api/customers';

  static String get baseUrl {
    return const String.fromEnvironment(
      'BIZNEXT_API_BASE_URL',
      defaultValue: _defaultBaseUrl,
    );
  }

  static Future<Map<String, String>> _headers() async {
    final token = await TokenService.instance.getActiveToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<CustomerModel>> getCustomers({required int businessId}) async {
    final customers = await _getPaged(Uri.parse(baseUrl).replace(queryParameters: {
      'businessId': '$businessId',
      'size': '200',
    }));
    return _listFromJson(customers, businessId: businessId);
  }

  static Future<CustomerModel?> getCustomerById({required int customerId, required int businessId}) async {
    final uri = Uri.parse('$baseUrl/$customerId').replace(queryParameters: {'businessId': '$businessId'});
    final response = await http.get(uri, headers: await _headers());
    _throwIfError(response);

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return CustomerModel(
        id: decoded['id'] as int?,
        businessId: (decoded['businessId'] as num?)?.toInt() ?? 1,
        name: decoded['name'] as String? ?? '',
        phone: decoded['phone'] as String?,
        email: decoded['email'] as String?,
        address: decoded['address'] as String?,
        gstNumber: decoded['gstNumber'] as String?,
        customerTypeId: (decoded['customerTypeId'] as num?)?.toInt(),
        balance: (decoded['balance'] as num?)?.toDouble() ?? 0.0,
        loyaltyPoints: (decoded['loyaltyPoints'] as num?)?.toDouble() ?? 0.0,
        createdAt: decoded['createdAt'] != null ? DateTime.tryParse(decoded['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
      );
    }
    return null;
  }

  static Future<List<CustomerModel>> searchCustomers({required int businessId, required String query}) async {
    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {
      'businessId': '$businessId',
      'q': query,
      'size': '200',
    });
    return _listFromJson(await _getPaged(uri), businessId: businessId);
  }

  static Future<List<CustomerModel>> filterCustomers({
    required int businessId,
    String? name,
    String? phone,
    String? email,
    int? customerTypeId,
  }) async {
    final params = <String, String>{'businessId': businessId.toString()};
    if (name != null && name.trim().isNotEmpty) params['name'] = name.trim();
    if (phone != null && phone.trim().isNotEmpty) params['phone'] = phone.trim();
    if (email != null && email.trim().isNotEmpty) params['email'] = email.trim();
    if (customerTypeId != null) params['customerTypeId'] = customerTypeId.toString();
    params['size'] = '200';

    final uri = Uri.parse('$baseUrl/filter').replace(queryParameters: params);
    return _listFromJson(await _getPaged(uri), businessId: businessId);
  }

  static Future<CustomerModel> createCustomer(CustomerModel customer) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({
      'businessId': customer.businessId,
      'name': customer.name,
      'phone': customer.phone ?? '',
      'email': customer.email ?? '',
      'address': customer.address ?? '',
      'gstNumber': customer.gstNumber ?? '',
      'customerTypeId': customer.customerTypeId,
      'balance': customer.balance,
      'loyaltyPoints': customer.loyaltyPoints,
    });

    final response = await http.post(uri, headers: await _headers(), body: body);
    _throwIfError(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return CustomerModel(
      id: decoded['id'] as int?,
      businessId: (decoded['businessId'] as num?)?.toInt() ?? customer.businessId,
      name: decoded['name'] as String? ?? customer.name,
      phone: decoded['phone'] as String?,
      email: decoded['email'] as String?,
      address: decoded['address'] as String?,
      gstNumber: decoded['gstNumber'] as String?,
      customerTypeId: (decoded['customerTypeId'] as num?)?.toInt(),
      balance: (decoded['balance'] as num?)?.toDouble() ?? customer.balance,
      loyaltyPoints: (decoded['loyaltyPoints'] as num?)?.toDouble() ?? customer.loyaltyPoints,
      createdAt: decoded['createdAt'] != null ? DateTime.tryParse(decoded['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }

  static Future<CustomerModel> updateCustomer(CustomerModel customer) async {
    final uri = Uri.parse('$baseUrl/${customer.id}');
    final body = jsonEncode({
      'businessId': customer.businessId,
      'name': customer.name,
      'phone': customer.phone ?? '',
      'email': customer.email ?? '',
      'address': customer.address ?? '',
      'gstNumber': customer.gstNumber ?? '',
      'customerTypeId': customer.customerTypeId,
      'balance': customer.balance,
      'loyaltyPoints': customer.loyaltyPoints,
    });

    final response = await http.put(uri, headers: await _headers(), body: body);
    _throwIfError(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return CustomerModel(
      id: decoded['id'] as int?,
      businessId: (decoded['businessId'] as num?)?.toInt() ?? customer.businessId,
      name: decoded['name'] as String? ?? customer.name,
      phone: decoded['phone'] as String?,
      email: decoded['email'] as String?,
      address: decoded['address'] as String?,
      gstNumber: decoded['gstNumber'] as String?,
      customerTypeId: (decoded['customerTypeId'] as num?)?.toInt(),
      balance: (decoded['balance'] as num?)?.toDouble() ?? customer.balance,
      loyaltyPoints: (decoded['loyaltyPoints'] as num?)?.toDouble() ?? customer.loyaltyPoints,
      createdAt: decoded['createdAt'] != null ? DateTime.tryParse(decoded['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }

  static Future<void> deleteCustomer({required int customerId, required int businessId}) async {
    final uri = Uri.parse('$baseUrl/$customerId').replace(queryParameters: {'businessId': '$businessId'});
    final response = await http.delete(uri, headers: await _headers());
    _throwIfError(response);
  }

  static List<CustomerModel> _listFromJson(List<dynamic> decoded, {required int businessId}) {
    return decoded
        .map((item) => _customerFromJson(item as Map<String, dynamic>, businessId: businessId))
        .toList();
  }

  static CustomerModel _customerFromJson(Map<String, dynamic> map, {required int businessId}) {
    return CustomerModel(
      id: map['id'] as int?,
      businessId: (map['businessId'] as num?)?.toInt() ?? businessId,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      gstNumber: map['gstNumber'] as String?,
      customerTypeId: (map['customerTypeId'] as num?)?.toInt(),
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      loyaltyPoints: (map['loyaltyPoints'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static Future<List<dynamic>> _getPaged(Uri firstPageUri) async {
    final items = <dynamic>[];
    var page = 0;
    while (true) {
      final uri = firstPageUri.replace(queryParameters: {
        ...firstPageUri.queryParameters,
        'page': '$page',
      });
      final response = await http.get(uri, headers: await _headers());
      _throwIfError(response);
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is! Map<String, dynamic> || decoded['content'] is! List) {
        throw const FormatException('Unexpected paginated customer response.');
      }
      items.addAll(decoded['content'] as List<dynamic>);
      if (decoded['last'] == true || (decoded['totalPages'] as int? ?? 0) <= page + 1) {
        return items;
      }
      page++;
    }
  }

  static void _throwIfError(http.Response response) {
    if (response.statusCode >= 400) {
      var message = 'Customer request failed.';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) message = decoded['error'].toString();
        if (decoded is Map && decoded['message'] != null) message = decoded['message'].toString();
      } catch (_) {}
      throw CustomerHttpException(message, response.statusCode);
    }
  }
}
