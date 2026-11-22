import '../models/supplier_model.dart';
import '../services/supplier_api_service.dart';

class SupplierRepository {
  Future<List<SupplierModel>> getSuppliers(int businessId, {bool includeInactive = false}) async {
    return SupplierApiService.getSuppliers(
      businessId: businessId,
      includeInactive: includeInactive,
    );
  }

  Future<SupplierModel?> getSupplierById(int id, int businessId) async {
    return SupplierApiService.getSupplierById(id: id, businessId: businessId);
  }

  Future<int> insertSupplier(SupplierModel supplier) async {
    final created = await SupplierApiService.create(supplier);
    return created.id ?? 0;
  }

  Future<int> updateSupplier(SupplierModel supplier) async {
    final updated = await SupplierApiService.update(supplier);
    return updated.id ?? supplier.id ?? 0;
  }

  Future<int> deleteSupplier(int id) async {
    throw UnimplementedError(
      'Call deleteSupplierByBusiness(id, businessId) instead.',
    );
  }

  Future<List<Map<String, dynamic>>> getSupplierPurchases(int supplierId, int businessId) async {
    return const [];
  }

  Future<void> deleteSupplierByBusiness({
    required int id,
    required int businessId,
  }) async {
    await SupplierApiService.delete(id: id, businessId: businessId);
  }
}
