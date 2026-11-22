// lib/features/discounts/repositories/discount_repository.dart

import '../../../core/services/backend_api_service.dart';
import '../../customers/models/customer_discount.dart';
import '../../inventory/models/product_discount.dart';
import '../models/offer.dart';

class DiscountRepository {
  // ── Customer Discounts ─────────────────────────────────────────────────────

  Future<CustomerDiscount?> getCustomerDiscount(int customerId, int businessId) async {
    final response = await BackendApiService.get(
      'customer-discounts',
      {'customerId': '$customerId', 'businessId': '$businessId'},
    );
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? CustomerDiscount.fromMap(decoded)
        : null;
  }

  Future<int> upsertCustomerDiscount(CustomerDiscount discount) async {
    final response = await BackendApiService.put(
      'customer-discounts', discount.toMap());
    final decoded = BackendApiService.decode(response);
    return (decoded is Map<String, dynamic>
            ? (decoded['id'] as num?)?.toInt()
            : null) ??
        0;
  }

  Future<int> deleteCustomerDiscount(int id) async {
    await BackendApiService.delete('customer-discounts/$id');
    return 1;
  }

  // ── Product Discounts ──────────────────────────────────────────────────────

  Future<ProductDiscount?> getProductDiscount(int productId, int businessId) async {
    final response = await BackendApiService.get(
      'product-discounts',
      {'productId': '$productId', 'businessId': '$businessId'},
    );
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? ProductDiscount.fromMap(decoded)
        : null;
  }

  Future<int> upsertProductDiscount(ProductDiscount discount) async {
    final response = await BackendApiService.put(
      'product-discounts', discount.toMap());
    final decoded = BackendApiService.decode(response);
    return (decoded is Map<String, dynamic>
            ? (decoded['id'] as num?)?.toInt()
            : null) ??
        0;
  }

  Future<int> deleteProductDiscount(int id) async {
    await BackendApiService.delete('product-discounts/$id');
    return 1;
  }

  // ── Offers ─────────────────────────────────────────────────────────────────

  Future<List<Offer>> getAllOffers(int businessId) async {
    final response =
        await BackendApiService.get('offers', {'businessId': '$businessId'});
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded
        .map((item) => _offerFromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> addOffer(Offer offer) async {
    final response =
        await BackendApiService.post('offers', _offerToApi(offer));
    final decoded = BackendApiService.decode(response);
    return (decoded is Map<String, dynamic>
            ? (decoded['id'] as num?)?.toInt()
            : null) ??
        0;
  }

  Future<int> updateOffer(Offer offer) async {
    if (offer.id == null) throw ArgumentError('Offer ID is required');
    final response = await BackendApiService.put(
      'offers/${offer.id}',
      _offerToApi(offer),
      {'businessId': '${offer.businessId}'},
    );
    final decoded = BackendApiService.decode(response);
    return (decoded is Map<String, dynamic>
            ? (decoded['id'] as num?)?.toInt()
            : null) ??
        offer.id!;
  }

  Future<int> deleteOffer(int id) async {
    await BackendApiService.delete('offers/$id');
    return 1;
  }

  static Map<String, dynamic> _offerToApi(Offer offer) => {
        'businessId': offer.businessId,
        'name': offer.name,
        'offerType': offer.offerType,
        'discountType': offer.discountType,
        'discountValue': offer.discountValue,
        'minQty': offer.minQty,
        'minAmount': offer.minAmount,
        'applyTo': offer.applyTo,
        'targetId': offer.targetId,
        'buyQty': offer.buyQty,
        'getQty': offer.getQty,
        'startDate': offer.startDate?.toIso8601String(),
        'endDate': offer.endDate?.toIso8601String(),
        'active': offer.isActive,
        'posterUrl': offer.posterPath,
      };

  static Offer _offerFromApi(Map<String, dynamic> json) => Offer(
        id: (json['id'] as num?)?.toInt(),
        businessId: (json['businessId'] as num?)?.toInt() ?? 1,
        name: json['name'] as String? ?? '',
        offerType: json['offerType'] as String? ?? '',
        discountType: json['discountType'] as String? ?? '',
        discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
        minQty: (json['minQty'] as num?)?.toDouble() ?? 0,
        minAmount: (json['minAmount'] as num?)?.toDouble() ?? 0,
        applyTo: json['applyTo'] as String? ?? 'all',
        targetId: (json['targetId'] as num?)?.toInt(),
        buyQty: (json['buyQty'] as num?)?.toDouble() ?? 0,
        getQty: (json['getQty'] as num?)?.toDouble() ?? 0,
        startDate: json['startDate'] == null
            ? null
            : DateTime.tryParse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : DateTime.tryParse(json['endDate'] as String),
        isActive: json['active'] != false,
        createdAt: json['createdAt'] == null
            ? DateTime.now()
            : DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
        posterPath: json['posterUrl'] as String?,
      );
}
