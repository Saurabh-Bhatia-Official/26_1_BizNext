// test/pos_pricing_flow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:biz_next/features/inventory/models/product_model.dart';
import 'package:biz_next/features/customers/models/customer_model.dart';
import 'package:biz_next/features/billing/models/pos_model.dart';

// Standalone pricing resolution function to mirror pos_billing_screen & billing_provider logic
double resolveTestPrice({
  required Product product,
  required String priceScale,
  CustomerModel? customer,
  Map<int, List<ProductTierPrice>>? allTiers,
  double quantity = 1.0,
}) {
  final activeScale = (customer?.customerTypeName != null && customer!.customerTypeName!.trim().isNotEmpty)
      ? customer.customerTypeName!
      : priceScale;
  final lower = activeScale.toLowerCase();

  // 1. Check custom Tiered Prices for this product matching category id or category name
  if (allTiers != null && product.id != null && allTiers.containsKey(product.id)) {
    final tiers = allTiers[product.id!]!;
    final matchingTier = tiers.firstWhere(
      (t) =>
          ((customer?.customerTypeId != null && t.categoryId == customer!.customerTypeId) ||
           (t.categoryName != null && t.categoryName!.toLowerCase() == lower)) &&
          quantity >= t.minQty &&
          (quantity <= t.maxQty),
      orElse: () => tiers.firstWhere(
        (t) =>
            (customer?.customerTypeId != null && t.categoryId == customer!.customerTypeId) ||
            (t.categoryName != null && t.categoryName!.toLowerCase() == lower),
        orElse: () => const ProductTierPrice(productId: 0, categoryId: 0, price: -1),
      ),
    );

    if (matchingTier.price >= 0) {
      return matchingTier.price;
    }
  }

  // 2. Dedicated Wholesale Price
  if (lower.contains('wholesale') && product.wholesalePrice > 0) {
    return product.wholesalePrice;
  }

  // 3. Dedicated Dealer Price
  if (lower.contains('dealer') && product.dealerPrice > 0) {
    return product.dealerPrice;
  }

  // 4. Default Standard Selling Price
  return product.sellingPrice;
}

void main() {
  group('POS Pricing Architecture & Flow Control Suite', () {
    final productA = Product(
      id: 1,
      name: 'Wireless Mouse',
      sellingPrice: 500.0,
      wholesalePrice: 400.0,
      dealerPrice: 350.0,
      mrp: 600.0,
      stock: 100,
    );

    final productB = Product(
      id: 2,
      name: 'Mechanical Keyboard',
      sellingPrice: 2000.0,
      wholesalePrice: 1700.0,
      dealerPrice: 1500.0,
      mrp: 2500.0,
      stock: 50,
    );

    final tierPrices = <int, List<ProductTierPrice>>{
      1: [
        const ProductTierPrice(productId: 1, categoryId: 10, categoryName: 'VIP Customer', price: 380.0, minQty: 1),
        const ProductTierPrice(productId: 1, categoryId: 11, categoryName: 'Bulk Tier', price: 320.0, minQty: 10),
      ],
    };

    final retailCustomer = CustomerModel(id: 1, businessId: 1, name: 'Walk-in John');
    final wholesaleCustomer = CustomerModel(id: 2, businessId: 1, name: 'Apex Wholesalers', customerTypeId: 2, customerTypeName: 'Wholesale');
    final dealerCustomer = CustomerModel(id: 3, businessId: 1, name: 'Metro Distributors', customerTypeId: 3, customerTypeName: 'Dealer');
    final vipCustomer = CustomerModel(id: 4, businessId: 1, name: 'Sarah VIP', customerTypeId: 10, customerTypeName: 'VIP Customer');

    test('1. Default Standard Retail Pricing', () {
      final price = resolveTestPrice(
        product: productA,
        priceScale: 'Standard',
        customer: retailCustomer,
        allTiers: tierPrices,
      );
      expect(price, 500.0);
    });

    test('2. Automatic Wholesale Price Detection on Customer Type', () {
      final price = resolveTestPrice(
        product: productA,
        priceScale: 'Standard',
        customer: wholesaleCustomer,
        allTiers: tierPrices,
      );
      expect(price, 400.0);
    });

    test('3. Automatic Dealer Price Detection on Customer Type', () {
      final price = resolveTestPrice(
        product: productA,
        priceScale: 'Standard',
        customer: dealerCustomer,
        allTiers: tierPrices,
      );
      expect(price, 350.0);
    });

    test('4. Custom Tier Price Lookup by Category ID / Name (VIP)', () {
      final price = resolveTestPrice(
        product: productA,
        priceScale: 'Standard',
        customer: vipCustomer,
        allTiers: tierPrices,
      );
      expect(price, 380.0);
    });

    test('5. Quantity-based Tier Price Lookup', () {
      final bulkPrice = resolveTestPrice(
        product: productA,
        priceScale: 'Bulk Tier',
        quantity: 12,
        allTiers: tierPrices,
      );
      expect(bulkPrice, 320.0);
    });

    test('6. Dynamic Price Category Dropdown Override', () {
      // Cashier manually selects Wholesale from dropdown even for retail customer
      final wholesaleOverride = resolveTestPrice(
        product: productB,
        priceScale: 'Wholesale',
        customer: retailCustomer,
        allTiers: tierPrices,
      );
      expect(wholesaleOverride, 1700.0);

      // Cashier manually selects Dealer from dropdown
      final dealerOverride = resolveTestPrice(
        product: productB,
        priceScale: 'Dealer',
        customer: retailCustomer,
        allTiers: tierPrices,
      );
      expect(dealerOverride, 1500.0);
    });

    test('7. Cart Item Repricing Simulation on Customer Change', () {
      // Initial cart with Retail Prices
      final initialItemA = PosItemModel(product: productA, manualPrice: 0, priceScaleName: 'Standard', quantity: 2);
      final initialItemB = PosItemModel(product: productB, manualPrice: 0, priceScaleName: 'Standard', quantity: 1);

      expect(initialItemA.effectivePrice, 500.0);
      expect(initialItemB.effectivePrice, 2000.0);
      expect(initialItemA.subtotal + initialItemB.subtotal, 3000.0);

      // Changing customer to Wholesale Customer
      final repriceA = resolveTestPrice(product: initialItemA.product, priceScale: 'Standard', customer: wholesaleCustomer, allTiers: tierPrices);
      final repriceB = resolveTestPrice(product: initialItemB.product, priceScale: 'Standard', customer: wholesaleCustomer, allTiers: tierPrices);

      final wholesaleItemA = initialItemA.copyWith(manualPrice: repriceA, priceScaleName: 'Wholesale');
      final wholesaleItemB = initialItemB.copyWith(manualPrice: repriceB, priceScaleName: 'Wholesale');

      expect(wholesaleItemA.effectivePrice, 400.0);
      expect(wholesaleItemB.effectivePrice, 1700.0);
      expect(wholesaleItemA.subtotal + wholesaleItemB.subtotal, 2500.0);

      // Clearing customer reverts to Standard Retail
      final revertedItemA = wholesaleItemA.copyWith(manualPrice: 0, priceScaleName: 'Standard');
      final revertedItemB = wholesaleItemB.copyWith(manualPrice: 0, priceScaleName: 'Standard');

      expect(revertedItemA.effectivePrice, 500.0);
      expect(revertedItemB.effectivePrice, 2000.0);
      expect(revertedItemA.subtotal + revertedItemB.subtotal, 3000.0);
    });
  });
}
