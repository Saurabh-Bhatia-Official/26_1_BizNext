// lib/features/suppliers/repositories/supplier_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<SupplierModel>> getSuppliers(int businessId, {bool includeInactive = false}) async {
    String where = 'business_id = ?';
    if (!includeInactive) {
      where += ' AND is_active = 1';
    }
    final maps = await _db.queryAll(
      AppConstants.tblSuppliers,
      where: where,
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => SupplierModel.fromMap(m)).toList();
  }

  Future<SupplierModel?> getSupplierById(int id, int businessId) async {
    final maps = await _db.queryAll(
      AppConstants.tblSuppliers,
      where: 'id = ? AND business_id = ?',
      whereArgs: [id, businessId],
    );
    return maps.isNotEmpty ? SupplierModel.fromMap(maps.first) : null;
  }

  Future<int> insertSupplier(SupplierModel supplier) async {
    return await _db.insert(AppConstants.tblSuppliers, supplier.toMap());
  }

  Future<int> updateSupplier(SupplierModel supplier) async {
    return await _db.update(AppConstants.tblSuppliers, supplier.toMap(), supplier.id!);
  }

  Future<int> deleteSupplier(int id) async {
    // Soft delete
    return await _db.update(AppConstants.tblSuppliers, {'is_active': 0}, id);
  }

  Future<List<Map<String, dynamic>>> getSupplierPurchases(int supplierId, int businessId) async {
    return await _db.rawQuery('''
      SELECT p.*, COUNT(pi.id) as total_items
      FROM ${AppConstants.tblPurchases} p
      LEFT JOIN ${AppConstants.tblPurchaseItems} pi ON p.id = pi.purchase_id
      WHERE p.supplier_id = ? AND p.business_id = ?
      GROUP BY p.id
      ORDER BY p.date DESC
    ''', [supplierId, businessId]);
  }
}
