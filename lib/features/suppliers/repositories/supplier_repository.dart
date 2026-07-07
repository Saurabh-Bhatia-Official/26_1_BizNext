// lib/features/suppliers/repositories/supplier_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<SupplierModel>> getSuppliers(int businessId) async {
    final maps = await _db.queryAll(
      AppConstants.tblSuppliers,
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => SupplierModel.fromMap(m)).toList();
  }

  Future<int> insertSupplier(SupplierModel supplier) async {
    return await _db.insert(AppConstants.tblSuppliers, supplier.toMap());
  }

  Future<int> updateSupplier(SupplierModel supplier) async {
    return await _db.update(AppConstants.tblSuppliers, supplier.toMap(), supplier.id!);
  }

  Future<int> deleteSupplier(int id) async {
    return await _db.delete(AppConstants.tblSuppliers, id);
  }
}
