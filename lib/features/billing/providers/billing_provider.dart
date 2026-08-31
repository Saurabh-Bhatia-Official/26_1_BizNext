// lib/features/billing/providers/billing_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../inventory/models/product_model.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/sale_history_model.dart';
import '../models/pos_model.dart';
import '../repositories/billing_repository.dart';
import 'sales_stats_provider.dart';
import '../../discounts/providers/discount_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../loyalty/providers/loyalty_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../customers/models/customer_model.dart';
import '../../inventory/models/product_discount.dart';
import '../../customers/models/customer_discount.dart';
import '../../accounts/providers/accounts_provider.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) => BillingRepository());

/// State provider for holding parked carts in the active session
final heldOrdersProvider = StateProvider<List<HeldOrderModel>>((ref) => []);

class BillingState extends PosModel {
  final String? lastError;
  final bool isProcessing;

  const BillingState({
    super.items = const [],
    super.selectedCustomerId,
    super.selectedCustomerName,
    super.paymentMode = 'Cash',
    super.manualDiscount = 0,
    super.selectedAccountId,
    super.editingSaleId,
    super.customInvoiceNo,
    super.originalInvoiceNo,
    super.notes,
    super.isTaxInclusive = false,
    super.autoBillDiscount = 0,
    super.pointsEarned = 0,
    super.pointsRedeemed = 0,
    super.loyaltyDiscount = 0,
    this.lastError,
    this.isProcessing = false,
    this.appliedOffers = const [],
  });

  final List<String> appliedOffers;

  factory BillingState.fromSaleHistory(SaleHistoryModel sale) {
    final pos = PosModel.fromSaleHistory(sale);
    return BillingState(
      items: pos.items,
      selectedCustomerId: pos.selectedCustomerId,
      selectedCustomerName: pos.selectedCustomerName,
      paymentMode: pos.paymentMode,
      manualDiscount: pos.manualDiscount,
      selectedAccountId: pos.selectedAccountId,
      editingSaleId: pos.editingSaleId,
      customInvoiceNo: pos.customInvoiceNo,
      originalInvoiceNo: pos.originalInvoiceNo,
      notes: pos.notes,
      isTaxInclusive: pos.isTaxInclusive,
      pointsEarned: pos.pointsEarned,
      pointsRedeemed: pos.pointsRedeemed,
      loyaltyDiscount: pos.loyaltyDiscount,
    );
  }

  @override
  BillingState copyWith({
    List<PosItemModel>? items,
    int? selectedCustomerId,
    String? selectedCustomerName,
    bool clearCustomer = false,
    String? paymentMode,
    double? manualDiscount,
    int? selectedAccountId,
    int? editingSaleId,
    String? customInvoiceNo,
    String? originalInvoiceNo,
    String? notes,
    bool? isTaxInclusive,
    double? autoBillDiscount,
    double? pointsEarned,
    double? pointsRedeemed,
    double? loyaltyDiscount,
    String? lastError,
    bool? isProcessing,
    List<String>? appliedOffers,
    bool clearError = false,
  }) {
    return BillingState(
      items: items ?? this.items,
      selectedCustomerId: clearCustomer ? null : (selectedCustomerId ?? this.selectedCustomerId),
      selectedCustomerName: clearCustomer ? null : (selectedCustomerName ?? this.selectedCustomerName),
      paymentMode: paymentMode ?? this.paymentMode,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      editingSaleId: editingSaleId ?? this.editingSaleId,
      customInvoiceNo: customInvoiceNo ?? this.customInvoiceNo,
      originalInvoiceNo: originalInvoiceNo ?? this.originalInvoiceNo,
      notes: notes ?? this.notes,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      autoBillDiscount: autoBillDiscount ?? this.autoBillDiscount,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      pointsRedeemed: pointsRedeemed ?? this.pointsRedeemed,
      loyaltyDiscount: loyaltyDiscount ?? this.loyaltyDiscount,
      lastError: clearError ? null : (lastError ?? this.lastError),
      isProcessing: isProcessing ?? this.isProcessing,
      appliedOffers: appliedOffers ?? this.appliedOffers,
    );
  }
}

class BillingNotifier extends StateNotifier<BillingState> {
  final BillingRepository _repo;
  final Ref _ref;

  BillingNotifier(this._repo, this._ref) : super(const BillingState()) {
    // Re-apply discounts whenever offers or settings change
    _ref.listen(offersProvider, (prev, next) {
      _applyAutomatedDiscounts();
    });
    _ref.listen(featureSettingsProvider, (prev, next) {
      _applyAutomatedDiscounts();
    });
  }

  double _resolveProductPrice(Product product, String scale, {CustomerModel? customer, double quantity = 1.0}) {
    final effectiveScale = (customer?.customerTypeName != null && customer!.customerTypeName!.trim().isNotEmpty)
        ? customer.customerTypeName!
        : scale;
    final lowerScale = effectiveScale.toLowerCase();

    // 1. Check allProductTierPricesProvider if available
    final tierMap = _ref.read(allProductTierPricesProvider).value;
    if (tierMap != null && product.id != null && tierMap.containsKey(product.id)) {
      final tiers = tierMap[product.id!]!;
      final matchingTier = tiers.firstWhere(
        (t) =>
            ((customer?.customerTypeId != null && t.categoryId == customer!.customerTypeId) ||
             (t.categoryName != null && t.categoryName!.toLowerCase() == lowerScale)) &&
            quantity >= t.minQty &&
            (quantity <= t.maxQty),
        orElse: () => tiers.firstWhere(
          (t) =>
              (customer?.customerTypeId != null && t.categoryId == customer!.customerTypeId) ||
              (t.categoryName != null && t.categoryName!.toLowerCase() == lowerScale),
          orElse: () => const ProductTierPrice(productId: 0, categoryId: 0, price: -1),
        ),
      );
      if (matchingTier.price >= 0) {
        return matchingTier.price;
      }
    }

    // 2. Check Wholesale price
    if (lowerScale.contains('wholesale') && product.wholesalePrice > 0) {
      return product.wholesalePrice;
    }

    // 3. Check Dealer price
    if (lowerScale.contains('dealer') && product.dealerPrice > 0) {
      return product.dealerPrice;
    }

    // 4. Standard selling price
    return product.sellingPrice;
  }

  /// Add product with stock validation and customer-tier pricing
  String? addProduct(Product product, {double? overridePrice, String? priceScaleName}) {
    final customers = _ref.read(customersProvider).value ?? [];
    final customer = state.selectedCustomerId != null
        ? customers.where((c) => c.id == state.selectedCustomerId).firstOrNull
        : null;

    final activeScale = priceScaleName ??
        (customer?.customerTypeName?.trim().isNotEmpty == true ? customer!.customerTypeName! : 'Standard');

    final double priceToAdd = overridePrice ??
        _resolveProductPrice(product, activeScale, customer: customer, quantity: 1.0);

    final scale = (priceToAdd != product.sellingPrice) ? activeScale : (priceScaleName ?? 'Standard');
    
    // Merge only if product ID AND the price we are adding at match
    final existingIndex = state.items.indexWhere((item) => 
      item.product.id == product.id && 
      item.effectivePrice == priceToAdd
    );
    final currentQty = existingIndex != -1 ? state.items[existingIndex].quantity : 0.0;

    if (currentQty + 1 > product.stock) {
      return 'Insufficient stock! Only ${product.stock} ${product.unit} available.';
    }

    if (existingIndex != -1) {
      final updatedItems = state.items.asMap().map((i, item) {
        if (i == existingIndex) {
          return MapEntry(i, item.copyWith(quantity: item.quantity + 1));
        }
        return MapEntry(i, item);
      }).values.toList();
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(
        items: [...state.items, PosItemModel(
          product: product, 
          manualPrice: overridePrice ?? (priceToAdd != product.sellingPrice ? priceToAdd : 0), 
          priceScaleName: scale,
          isTaxInclusive: state.isTaxInclusive,
        )]
      );
    }
    _applyAutomatedDiscounts();
    return null;
  }

  /// Update quantity using index
  String? updateQuantity(int index, double qty) {
    if (index < 0 || index >= state.items.length) return 'Invalid item';
    
    if (qty <= 0) {
      removeItem(index);
      return null;
    }

    final item = state.items[index];
    if (qty > item.product.stock) {
      return 'Only ${item.product.stock} ${item.product.unit} available.';
    }

    final updatedItems = [...state.items];
    updatedItems[index] = item.copyWith(quantity: qty);
    state = state.copyWith(items: updatedItems);
    _applyAutomatedDiscounts();
    return null;
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = [...state.items];
    updated.removeAt(index);
    state = state.copyWith(items: updated);
    _applyAutomatedDiscounts(); // Re-apply after removal
  }

  void setItemDiscount(int index, double discount) {
    if (index < 0 || index >= state.items.length) return;
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(discount: discount);
    state = state.copyWith(items: updated);
  }

  void updatePrice(int index, double price, {String? scaleName}) {
    if (index < 0 || index >= state.items.length) return;
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(manualPrice: price, priceScaleName: scaleName ?? 'Manual');
    state = state.copyWith(items: updated);
    _applyAutomatedDiscounts(); // Price change might affect bulk discounts
  }

  /// Set global price scale / category pricing for the active cart
  void setPriceScale(String scale) {
    final customers = _ref.read(customersProvider).value ?? [];
    final customer = state.selectedCustomerId != null
        ? customers.where((c) => c.id == state.selectedCustomerId).firstOrNull
        : null;

    final updatedItems = state.items.map((item) {
      if (item.priceScaleName == 'Retail' ||
          item.priceScaleName == 'Standard' ||
          item.priceScaleName == 'Wholesale' ||
          item.priceScaleName == 'Dealer' ||
          item.priceScaleName == null ||
          item.priceScaleName == scale) {
        final newPrice = _resolveProductPrice(item.product, scale, customer: customer, quantity: item.quantity);
        return item.copyWith(
          manualPrice: newPrice != item.product.sellingPrice ? newPrice : 0,
          priceScaleName: newPrice != item.product.sellingPrice ? scale : 'Standard',
        );
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
    _applyAutomatedDiscounts();
  }

  void selectCustomer(int id, String name) {
    // Check if customer has a special customer type and recalculate cart prices
    final customers = _ref.read(customersProvider).value ?? [];
    final customer = customers.where((c) => c.id == id).firstOrNull;
    final customerScale = customer?.customerTypeName?.trim().isNotEmpty == true
        ? customer!.customerTypeName!
        : 'Standard';

    final updatedItems = state.items.map((item) {
      if (item.priceScaleName == 'Retail' ||
          item.priceScaleName == 'Standard' ||
          item.priceScaleName == 'Wholesale' ||
          item.priceScaleName == 'Dealer' ||
          item.priceScaleName == null ||
          item.priceScaleName == customerScale) {
        final newPrice = _resolveProductPrice(item.product, customerScale, customer: customer, quantity: item.quantity);
        return item.copyWith(
          manualPrice: newPrice != item.product.sellingPrice ? newPrice : 0,
          priceScaleName: newPrice != item.product.sellingPrice ? customerScale : 'Standard',
        );
      }
      return item;
    }).toList();

    state = state.copyWith(
      selectedCustomerId: id, 
      selectedCustomerName: name,
      items: updatedItems,
    );
    _applyAutomatedDiscounts();
  }

  void clearCustomer() {
    // Revert items back to standard prices
    final updatedItems = state.items.map((item) {
      return item.copyWith(manualPrice: 0, priceScaleName: 'Standard');
    }).toList();

    state = state.copyWith(clearCustomer: true, items: updatedItems);
    _applyAutomatedDiscounts();
  }

  void setPaymentMode(String mode) {
    state = state.copyWith(paymentMode: mode);
  }

  void setDiscount(double discount) {
    state = state.copyWith(manualDiscount: discount);
  }

  void setTaxInclusive(bool isInclusive) {
    final updatedItems = state.items.map((i) => i.copyWith(isTaxInclusive: isInclusive)).toList();
    state = state.copyWith(isTaxInclusive: isInclusive, items: updatedItems);
    _applyAutomatedDiscounts();
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  /// Hold current cart / session
  String? holdCurrentOrder({String? note}) {
    if (state.items.isEmpty) return 'Cannot hold an empty cart';
    
    final heldOrder = HeldOrderModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: state.selectedCustomerId,
      customerName: state.selectedCustomerName,
      items: List.from(state.items),
      manualDiscount: state.manualDiscount,
      paymentMode: state.paymentMode,
      notes: note ?? state.notes,
    );

    final currentHeld = _ref.read(heldOrdersProvider);
    _ref.read(heldOrdersProvider.notifier).state = [...currentHeld, heldOrder];
    
    reset();
    return null;
  }

  /// Resume a held / parked cart
  void resumeHeldOrder(HeldOrderModel order) {
    // If current cart already has items, auto-hold it
    if (state.items.isNotEmpty) {
      holdCurrentOrder(note: 'Auto-held prior cart');
    }

    state = BillingState(
      items: List.from(order.items),
      selectedCustomerId: order.customerId,
      selectedCustomerName: order.customerName,
      paymentMode: order.paymentMode,
      manualDiscount: order.manualDiscount,
      notes: order.notes,
    );

    discardHeldOrder(order.id);
    _applyAutomatedDiscounts();
  }

  /// Discard a held order by id
  void discardHeldOrder(String orderId) {
    final currentHeld = _ref.read(heldOrdersProvider);
    _ref.read(heldOrdersProvider.notifier).state = currentHeld.where((o) => o.id != orderId).toList();
  }

  void clearCart() {
    state = state.copyWith(items: [], manualDiscount: 0);
  }

  void reset() {
    state = const BillingState();
  }

  void redeemPoints(double points) {
    final settings = _ref.read(loyaltySettingsProvider);
    if (settings == null || !settings.isActive) return;
    
    final discount = settings.calculateDiscount(points);
    final finalPoints = settings.maxRedeemLimit > 0 && points > settings.maxRedeemLimit 
        ? settings.maxRedeemLimit 
        : points;
    state = state.copyWith(pointsRedeemed: finalPoints, loyaltyDiscount: discount);
  }

  void loadSale(SaleHistoryModel sale) {
    state = BillingState.fromSaleHistory(sale);
  }

  void duplicateSale(SaleHistoryModel sale) {
    state = BillingState.fromSaleHistory(sale).copyWith(
      editingSaleId: null,
      originalInvoiceNo: null,
      customInvoiceNo: null,
    );
  }

  void setInvoiceNo(String no) {
    state = state.copyWith(customInvoiceNo: no);
  }
  
  void setAccount(int? id) {
    state = state.copyWith(selectedAccountId: id);
  }

  Future<void> settleInvoice(int saleId, double amount) async {
    final repo = _ref.read(billingRepositoryProvider);
    await repo.settleCreditInvoice(saleId, amount);
    _ref.invalidate(saleDetailProvider(saleId));
    _ref.invalidate(saleHistoryProvider);
    _ref.invalidate(salesStatsProvider);
  }

  Future<int?> completeSale() async {
    if (state.items.isEmpty) return null;

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final businessId = _ref.read(activeBusinessIdProvider);
      final isEditing = state.editingSaleId != null;
      
      String invoiceNo;
      if (state.customInvoiceNo != null && state.customInvoiceNo!.isNotEmpty) {
        invoiceNo = state.customInvoiceNo!;
      } else {
        invoiceNo = isEditing ? state.originalInvoiceNo! : await _repo.getNextInvoiceNumber(businessId);
      }

      int? finalAccountId = state.selectedAccountId;
      if (state.paymentMode != AppConstants.paymentCredit && finalAccountId == null) {
        try {
          final accountsList = await _ref.read(accountsProvider.future);
          if (accountsList.isNotEmpty) {
            final cashAcc = accountsList.firstWhere(
              (a) => a.name.toLowerCase().contains('cash'), 
              orElse: () => accountsList.first
            );
            finalAccountId = cashAcc.id;
          }
        } catch (_) {}
      }

      String finalNotes = state.notes ?? '';
      if (state.appliedOffers.isNotEmpty) {
        final offersStr = 'Offers Applied: ${state.appliedOffers.join(', ')}';
        if (!finalNotes.contains(offersStr)) {
          finalNotes = finalNotes.isEmpty ? offersStr : '$finalNotes\n$offersStr';
        }
      }

      final sale = state.copyWith(selectedAccountId: finalAccountId).toSaleHistory(
        businessId: businessId,
        invoiceNo: invoiceNo,
        notesOverride: finalNotes.isEmpty ? null : finalNotes,
      );

      final saleId = isEditing 
        ? await _repo.updateSale(sale).then((_) => sale.id!)
        : await _repo.completeSale(sale);

      // Invalidate related providers
      _ref.invalidate(productsProvider);
      _ref.invalidate(inventoryStatsProvider);
      _ref.invalidate(saleHistoryProvider);
      _ref.invalidate(salesStatsProvider);

      // Update Customer Loyalty Points
      if (state.selectedCustomerId != null) {
        final currentCustomer = _ref.read(customersProvider).value?.where((c) => c.id == state.selectedCustomerId).firstOrNull;
        if (currentCustomer != null) {
          final updatedPoints = currentCustomer.loyaltyPoints - state.pointsRedeemed + state.pointsEarned;
          await _ref.read(customerRepositoryProvider).updateCustomer(
            currentCustomer.copyWith(loyaltyPoints: updatedPoints)
          );
          _ref.invalidate(customersProvider);
        }
      }

      reset();
      return saleId;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        lastError: e.toString(),
      );
      return null;
    }
  }

  Future<void> _applyAutomatedDiscounts() async {
    final settings = _ref.read(featureSettingsProvider);
    if (!settings.productDiscountEnabled && !settings.customerDiscountEnabled && !settings.offersEnabled) {
      if (state.autoBillDiscount != 0) state = state.copyWith(autoBillDiscount: 0);
      return;
    }

    var updatedItems = [...state.items];
    bool changed = false;

    // --- 1. Product & Customer Discounts (Item Level) ---
    List<ProductDiscount?> productDiscounts = [];
    if (settings.productDiscountEnabled) {
      productDiscounts = await Future.wait(
        updatedItems.map((item) => _ref.read(productDiscountProvider(item.product.id!).future).catchError((_) => null))
      );
    }

    CustomerDiscount? cDisc;
    if (settings.customerDiscountEnabled && state.selectedCustomerId != null) {
      try {
        cDisc = await _ref.read(customerDiscountProvider(state.selectedCustomerId!).future);
      } catch (_) {}
    }

    for (int i = 0; i < updatedItems.length; i++) {
      var item = updatedItems[i];
      double productDiscount = 0;
      double customerDiscount = 0;

      if (settings.productDiscountEnabled) {
        final pDisc = productDiscounts.length > i ? productDiscounts[i] : null;
        if (pDisc != null && pDisc.isActive) {
          final now = DateTime.now();
          if ((pDisc.startDate == null || now.isAfter(pDisc.startDate!)) &&
              (pDisc.endDate == null || now.isBefore(pDisc.endDate!))) {
            productDiscount = pDisc.discountType == 'percentage'
                ? (item.product.sellingPrice * pDisc.discountValue / 100)
                : pDisc.discountValue;
          }
        }
      }

      if (settings.customerDiscountEnabled && cDisc != null && cDisc.isActive) {
        customerDiscount = cDisc.discountType == 'percentage'
            ? (item.product.sellingPrice * cDisc.discountValue / 100)
            : cDisc.discountValue;
      }

      final autoDiscountPerUnit = productDiscount > customerDiscount ? productDiscount : customerDiscount;
      final totalAutoDiscount = autoDiscountPerUnit * item.quantity;
      
      if (item.discount != totalAutoDiscount) {
        updatedItems[i] = item.copyWith(discount: totalAutoDiscount);
        changed = true;
      }
    }

    // --- 2. Offers (Buy X Get Y, etc.) ---
    double autoBillDiscount = 0;
    List<String> activeOffers = [];
    String? maxBillOfferName;

    if (settings.offersEnabled) {
      final validOffers = _ref.read(offersProvider.notifier).getValidOffers();
      
      for (final offer in validOffers) {
        bool offerApplied = false;
        if (offer.offerType == 'buy_x_get_y') {
          for (int i = 0; i < updatedItems.length; i++) {
            final item = updatedItems[i];
            if (offer.applyTo == 'all' || 
               (offer.applyTo == 'product' && offer.targetId == item.product.id)) {
              final totalBundleQty = offer.buyQty + offer.getQty;
              if (item.quantity >= totalBundleQty && totalBundleQty > 0) {
                final bundles = (item.quantity / totalBundleQty).floor();
                final freeUnits = bundles * offer.getQty;
                final offerDiscount = freeUnits * item.effectivePrice;
                if (updatedItems[i].discount < offerDiscount) {
                   updatedItems[i] = updatedItems[i].copyWith(discount: offerDiscount);
                   changed = true;
                   offerApplied = true;
                }
              }
            }
          }
        }
        
        if (offer.offerType == 'product_discount') {
          for (int i = 0; i < updatedItems.length; i++) {
            final item = updatedItems[i];
            if (offer.applyTo == 'all' || 
               (offer.applyTo == 'product' && offer.targetId == item.product.id)) {
              final unitDisc = offer.discountType == 'percentage' 
                ? (item.effectivePrice * offer.discountValue / 100)
                : offer.discountValue;
              final totalDisc = unitDisc * item.quantity;
              if (updatedItems[i].discount < totalDisc) {
                 updatedItems[i] = updatedItems[i].copyWith(discount: totalDisc);
                 changed = true;
                 offerApplied = true;
              }
            }
          }
        }
        
        if (offer.offerType == 'bill_amount' || offer.offerType == 'festival') {
          final currentSubtotal = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);
          if (currentSubtotal >= offer.minAmount) {
            final disc = offer.discountType == 'percentage' 
              ? (currentSubtotal * offer.discountValue / 100)
              : offer.discountValue;
            if (disc > autoBillDiscount) {
              autoBillDiscount = disc;
              maxBillOfferName = '${offer.name} (${offer.getOfferDescription(null)})';
            }
          }
        }

        if (offerApplied) {
           activeOffers.add('${offer.name} (${offer.getOfferDescription(null)})');
        }
      }
    }

    if (maxBillOfferName != null) {
      activeOffers.add(maxBillOfferName);
    }

    if (settings.loyaltyEnabled && state.loyaltyDiscount > 0) {
       activeOffers.add('Loyalty Discount');
    }

    if (changed || state.autoBillDiscount != autoBillDiscount || state.appliedOffers.join(',') != activeOffers.join(',')) {
      state = state.copyWith(items: updatedItems, autoBillDiscount: autoBillDiscount, appliedOffers: activeOffers);
    }

    // --- 3. Loyalty Points Earning ---
    if (settings.loyaltyEnabled) {
      final loyaltySettings = _ref.read(loyaltySettingsProvider);
      if (loyaltySettings != null && loyaltySettings.isActive) {
        final earned = loyaltySettings.calculateEarnedPoints(state.grandTotal);
        if (state.pointsEarned != earned) {
          state = state.copyWith(pointsEarned: earned);
        }
      }
    }
  }
}

final billingProvider = StateNotifierProvider<BillingNotifier, BillingState>((ref) {
  return BillingNotifier(ref.watch(billingRepositoryProvider), ref);
});
