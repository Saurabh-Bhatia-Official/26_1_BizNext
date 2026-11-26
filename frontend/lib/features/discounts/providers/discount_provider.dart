// lib/features/discounts/providers/discount_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/offer.dart';
import '../repositories/discount_repository.dart';
import '../../customers/models/customer_discount.dart';
import '../../inventory/models/product_discount.dart';
import '../../../core/database/database_providers.dart';

final discountRepositoryProvider = Provider((ref) => DiscountRepository());

final offersProvider = StateNotifierProvider<OffersNotifier, List<Offer>>((ref) {
  final repo = ref.watch(discountRepositoryProvider);
  final business = ref.watch(currentBusinessProvider);
  return OffersNotifier(repo, business?.id, ref);
});

class OffersNotifier extends StateNotifier<List<Offer>> {
  final DiscountRepository _repo;
  final int? _businessId;
  final Ref _ref;

  OffersNotifier(this._repo, this._businessId, this._ref) : super([]) {
    loadOffers();
    // Global auto-refresh
    _ref.listen(databaseVersionProvider, (prev, next) {
      loadOffers();
    });
  }

  Future<void> loadOffers() async {
    if (_businessId == null) return;
    state = await _repo.getAllOffers(_businessId);
  }

  Future<void> addOffer(Offer offer) async {
    await _repo.addOffer(offer);
    await loadOffers();
  }

  Future<void> updateOffer(Offer offer) async {
    await _repo.updateOffer(offer);
    await loadOffers();
  }

  Future<void> deleteOffer(int id) async {
    await _repo.deleteOffer(id);
    await loadOffers();
  }

  List<Offer> getValidOffers() {
    return state.where((o) => o.isCurrentlyValid).toList();
  }
}

final customerDiscountProvider = FutureProvider.family<CustomerDiscount?, int>((ref, customerId) async {
  ref.watch(databaseVersionProvider);
  final repo = ref.watch(discountRepositoryProvider);
  final business = ref.watch(currentBusinessProvider);
  if (business == null) return null;
  return await repo.getCustomerDiscount(customerId, business.id!);
});

final productDiscountProvider = FutureProvider.family<ProductDiscount?, int>((ref, productId) async {
  ref.watch(databaseVersionProvider);
  final repo = ref.watch(discountRepositoryProvider);
  final business = ref.watch(currentBusinessProvider);
  if (business == null) return null;
  return await repo.getProductDiscount(productId, business.id!);
});
