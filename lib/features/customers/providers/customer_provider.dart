// lib/features/customers/providers/customer_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';
import '../../loyalty/providers/loyalty_provider.dart';
import '../../../core/database/database_providers.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) => CustomerRepository());

final customersProvider = FutureProvider.autoDispose<List<CustomerModel>>((ref) async {
  ref.watch(databaseVersionProvider); // Global auto-refresh
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(customerRepositoryProvider).getCustomers(businessId);
});

final customerSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredCustomersProvider = Provider.autoDispose<AsyncValue<List<CustomerModel>>>((ref) {
  final customersAsync = ref.watch(customersProvider);
  final query = ref.watch(customerSearchQueryProvider).toLowerCase();

  return customersAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((c) => 
      c.name.toLowerCase().contains(query) || 
      (c.phone?.contains(query) ?? false)
    ).toList();
  });
});

class CustomerFormNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerRepository _repo;
  final Ref _ref;

  CustomerFormNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> saveCustomer(CustomerModel customer) async {
    state = const AsyncValue.loading();
    try {
      if (customer.id == null) {
        final lSettings = _ref.read(loyaltySettingsProvider);
        final initialPoints = (lSettings != null && lSettings.isActive) ? lSettings.welcomePoints : 0.0;
        await _repo.insertCustomer(customer.copyWith(loyaltyPoints: initialPoints));
      } else {
        await _repo.updateCustomer(customer);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteCustomer(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteCustomer(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final customerFormProvider = StateNotifierProvider.autoDispose<CustomerFormNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return CustomerFormNotifier(repo, ref);
});
