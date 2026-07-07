// lib/features/customers/repositories/customer_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<CustomerModel>> getCustomers(int businessId) async {
    final maps = await _db.queryAll(
      AppConstants.tblCustomers,
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => CustomerModel.fromMap(m)).toList();
  }

  Future<int> insertCustomer(CustomerModel customer) async {
    return await _db.insert(AppConstants.tblCustomers, customer.toMap());
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    return await _db.update(AppConstants.tblCustomers, customer.toMap(), customer.id!);
  }

  Future<int> deleteCustomer(int id) async {
    return await _db.delete(AppConstants.tblCustomers, id);
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    final map = await _db.queryById(AppConstants.tblCustomers, id);
    return map != null ? CustomerModel.fromMap(map) : null;
  }
}
