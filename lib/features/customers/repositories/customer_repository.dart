// lib/features/customers/repositories/customer_repository.dart

import '../models/customer_model.dart';
import '../services/customer_http_service.dart';

class CustomerRepository {
  Future<List<CustomerModel>> getCustomers(int businessId) async {
    return CustomerHttpService.getCustomers(businessId: businessId);
  }

  Future<List<CustomerModel>> searchCustomers(String query, int businessId) async {
    return CustomerHttpService.searchCustomers(businessId: businessId, query: query);
  }

  Future<List<CustomerModel>> filterCustomers(
    int businessId, {
    String? name,
    String? phone,
    String? email,
    int? customerTypeId,
  }) async {
    return CustomerHttpService.filterCustomers(
      businessId: businessId,
      name: name,
      phone: phone,
      email: email,
      customerTypeId: customerTypeId,
    );
  }

  Future<int> insertCustomer(CustomerModel customer) async {
    final remoteCustomer = await CustomerHttpService.createCustomer(customer);
    final remoteId = remoteCustomer.id;
    if (remoteId == null) {
      throw const FormatException('Customer API response did not contain an ID.');
    }
    return remoteId;
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    if (customer.id == null) {
      throw ArgumentError('Customer ID is required for update.');
    }
    final remoteCustomer = await CustomerHttpService.updateCustomer(customer);
    return remoteCustomer.id ?? customer.id!;
  }

  Future<int> deleteCustomer(int id, {required int businessId}) async {
    await CustomerHttpService.deleteCustomer(customerId: id, businessId: businessId);
    return 1;
  }

  Future<CustomerModel?> getCustomerById(int id, {required int businessId}) async {
    return CustomerHttpService.getCustomerById(customerId: id, businessId: businessId);
  }
}

