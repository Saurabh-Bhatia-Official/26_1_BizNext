import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

class CustomerApiException implements Exception {
  final String message;
  final int? statusCode;

  const CustomerApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class CustomerApiService {
  static final CustomerRepository _repository = CustomerRepository();

  static String normalizePhone(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static Future<void> validateCustomer(
    CustomerModel customer, {
    required int businessId,
    int? ignoreId,
  }) async {
    final name = customer.name.trim();
    if (name.isEmpty) {
      throw const CustomerApiException('Customer name is required.');
    }

    final phone = normalizePhone(customer.phone);
    if (phone.isEmpty) {
      throw const CustomerApiException('Mobile number is required.');
    }

    if (phone.length < 10 || phone.length > 15) {
      throw const CustomerApiException('Please enter a valid mobile number.');
    }

    // Duplicate checks are authoritative on the backend/database. This avoids
    // loading the full customer list to validate one form submission.
  }

  static Future<List<CustomerModel>> getCustomers(int businessId) async {
    return _repository.getCustomers(businessId);
  }

  static Future<CustomerModel?> getCustomerById(int id, {required int businessId}) async {
    return _repository.getCustomerById(id, businessId: businessId);
  }

  static Future<List<CustomerModel>> searchCustomers(String query, int businessId) async {
    return _repository.searchCustomers(query, businessId);
  }

  static Future<List<CustomerModel>> filterCustomers(
    int businessId, {
    String? name,
    String? phone,
    String? email,
    int? customerTypeId,
  }) async {
    return _repository.filterCustomers(
      businessId,
      name: name,
      phone: phone,
      email: email,
      customerTypeId: customerTypeId,
    );
  }

  static Future<CustomerModel> createCustomer(CustomerModel customer) async {
    final payload = customer.copyWith(
      businessId: customer.businessId == 0 ? 1 : customer.businessId,
      name: customer.name.trim(),
      phone: customer.phone?.trim(),
      email: customer.email?.trim(),
      address: customer.address?.trim(),
      gstNumber: customer.gstNumber?.trim(),
    );

    await validateCustomer(payload, businessId: payload.businessId);
    final createdId = await _repository.insertCustomer(payload);
    return payload.copyWith(id: createdId);
  }

  static Future<CustomerModel> updateCustomer(CustomerModel customer) async {
    if (customer.id == null) {
      throw const CustomerApiException('A valid customer ID is required to update the record.');
    }

    final payload = customer.copyWith(
      businessId: customer.businessId == 0 ? 1 : customer.businessId,
      name: customer.name.trim(),
      phone: customer.phone?.trim(),
      email: customer.email?.trim(),
      address: customer.address?.trim(),
      gstNumber: customer.gstNumber?.trim(),
    );

    await validateCustomer(payload, businessId: payload.businessId, ignoreId: payload.id);
    await _repository.updateCustomer(payload);
    return payload;
  }

  static Future<void> deleteCustomer(int customerId, {required int businessId}) async {
    await _repository.deleteCustomer(customerId, businessId: businessId);
  }

  static Future<bool> existsInBusiness(int businessId, int customerId) async {
    final row = await _repository.getCustomerById(customerId, businessId: businessId);
    if (row == null) return false;
    return row.businessId == businessId;
  }
}
