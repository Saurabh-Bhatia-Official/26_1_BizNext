// lib/features/suppliers/providers/supplier_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/supplier_model.dart';
import '../repositories/supplier_repository.dart';
import '../../../core/database/database_providers.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) => SupplierRepository());

final suppliersProvider = FutureProvider.autoDispose<List<SupplierModel>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(supplierRepositoryProvider).getSuppliers(businessId);
});

final supplierSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredSuppliersProvider = Provider.autoDispose<AsyncValue<List<SupplierModel>>>((ref) {
  final suppliersAsync = ref.watch(suppliersProvider);
  final query = ref.watch(supplierSearchQueryProvider).toLowerCase();

  return suppliersAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((s) => 
      s.name.toLowerCase().contains(query) || 
      (s.phone?.contains(query) ?? false)
    ).toList();
  });
});

class SupplierFormNotifier extends StateNotifier<AsyncValue<void>> {
  final SupplierRepository _repo;
  final Ref _ref;

  SupplierFormNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> saveSupplier(SupplierModel supplier) async {
    if (mounted) state = const AsyncValue.loading();
    try {
      if (supplier.id == null) {
        await _repo.insertSupplier(supplier);
      } else {
        await _repo.updateSupplier(supplier);
      }
      if (mounted) state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteSupplier(int id) async {
    if (mounted) state = const AsyncValue.loading();
    try {
      await _repo.deleteSupplier(id);
      if (mounted) state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final supplierFormProvider = StateNotifierProvider.autoDispose<SupplierFormNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  return SupplierFormNotifier(repo, ref);
});
