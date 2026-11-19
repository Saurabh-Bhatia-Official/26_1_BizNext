// lib/features/customers/providers/customer_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';
import '../services/customer_api_service.dart';
import '../../loyalty/providers/loyalty_provider.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) => CustomerRepository());

final customersProvider = FutureProvider.autoDispose<List<CustomerModel>>((ref) async {
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
    if (mounted) state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      final hydratedCustomer = customer.businessId == 0
          ? customer.copyWith(businessId: businessId)
          : customer.copyWith(businessId: businessId);

      if (hydratedCustomer.id == null) {
        final lSettings = _ref.read(loyaltySettingsProvider);
        final initialPoints = (lSettings != null && lSettings.isActive) ? lSettings.welcomePoints : 0.0;
        await CustomerApiService.createCustomer(
          hydratedCustomer.copyWith(loyaltyPoints: initialPoints),
        );
      } else {
        await CustomerApiService.updateCustomer(hydratedCustomer);
      }
      _ref.invalidate(customersProvider);
      if (mounted) state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteCustomer(int id) async {
    if (mounted) state = const AsyncValue.loading();
    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      await CustomerApiService.deleteCustomer(id, businessId: businessId);
      _ref.invalidate(customersProvider);
      if (mounted) state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final customerFormProvider = StateNotifierProvider<CustomerFormNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return CustomerFormNotifier(repo, ref);
});
