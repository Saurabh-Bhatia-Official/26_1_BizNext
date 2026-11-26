// lib/features/discounts/repositories/discount_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../customers/models/customer_discount.dart';
import '../../inventory/models/product_discount.dart';
import '../models/offer.dart';

class DiscountRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ── Customer Discounts ─────────────────────────────────────────────────────

  Future<CustomerDiscount?> getCustomerDiscount(int customerId, int businessId) async {
    final result = await _db.queryAll(
      AppConstants.tblCustomerDiscounts,
      where: 'customer_id = ? AND business_id = ?',
      whereArgs: [customerId, businessId],
    );
    return result.isNotEmpty ? CustomerDiscount.fromMap(result.first) : null;
  }

  Future<int> upsertCustomerDiscount(CustomerDiscount discount) async {
    return _db.insert(AppConstants.tblCustomerDiscounts, discount.toMap());
  }

  Future<int> deleteCustomerDiscount(int id) async {
    return _db.delete(AppConstants.tblCustomerDiscounts, id);
  }

  // ── Product Discounts ──────────────────────────────────────────────────────

  Future<ProductDiscount?> getProductDiscount(int productId, int businessId) async {
    final result = await _db.queryAll(
      AppConstants.tblProductDiscounts,
      where: 'product_id = ? AND business_id = ?',
      whereArgs: [productId, businessId],
    );
    return result.isNotEmpty ? ProductDiscount.fromMap(result.first) : null;
  }

  Future<int> upsertProductDiscount(ProductDiscount discount) async {
    return _db.insert(AppConstants.tblProductDiscounts, discount.toMap());
  }

  Future<int> deleteProductDiscount(int id) async {
    return _db.delete(AppConstants.tblProductDiscounts, id);
  }

  // ── Offers ─────────────────────────────────────────────────────────────────

  Future<List<Offer>> getAllOffers(int businessId) async {
    final result = await _db.queryAll(
      AppConstants.tblOffers,
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'created_at DESC',
    );
    return result.map(Offer.fromMap).toList();
  }

  Future<int> addOffer(Offer offer) async {
    return _db.insert(AppConstants.tblOffers, offer.toMap());
  }

  Future<int> updateOffer(Offer offer) async {
    if (offer.id == null) throw ArgumentError('Offer ID is required for update');
    return _db.update(AppConstants.tblOffers, offer.toMap(), offer.id!);
  }

  Future<int> deleteOffer(int id) async {
    return _db.delete(AppConstants.tblOffers, id);
  }
}
