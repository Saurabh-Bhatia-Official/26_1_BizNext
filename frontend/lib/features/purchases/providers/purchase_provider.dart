// lib/features/purchases/providers/purchase_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/purchase_model.dart';
import '../repositories/purchase_repository.dart';
import '../../../core/database/database_providers.dart';
import '../services/purchase_calculation_service.dart';
import '../../notifications/providers/notifications_provider.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) => PurchaseRepository());

final purchasesProvider = FutureProvider.autoDispose<List<PurchaseModel>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(purchaseRepositoryProvider).getPurchases(businessId);
});

final purchaseStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(databaseVersionProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return ref.watch(purchaseRepositoryProvider).getPurchaseStats(businessId);
});

class PurchaseFormState {
  final List<PurchaseItemModel> items;
  final int? supplierId;
  final String? supplierName;
  final String paymentMode;
  final double discount;
  final double paidAmount;
  final String? billNo;
  final String? notes;
  final int? selectedAccountId;
  final bool isProcessing;
  final int? editingPurchaseId;
  final DateTime date;
  final String? lastError;

  PurchaseFormState({
    this.items = const [],
    this.supplierId,
    this.supplierName,
    this.paymentMode = 'Cash',
    this.discount = 0,
    this.paidAmount = 0,
    this.billNo,
    this.notes,
    this.selectedAccountId,
    this.isProcessing = false,
    this.editingPurchaseId,
    DateTime? date,
    this.lastError,
  }) : date = date ?? DateTime.now();

  PurchaseCalculationSummary get summary => PurchaseCalculationService.calculateSummary(
        items: items,
        billDiscount: discount,
        paidAmount: paidAmount,
      );

  double get subtotal => summary.grossSubtotal;
  double get lineDiscountTotal => summary.lineDiscountTotal;
  double get totalDiscount => summary.totalDiscount;
  double get taxableAmount => summary.taxableAmount;
  double get totalGst => summary.totalGst;
  double get grandTotal => summary.grandTotal;
  double get balanceDue => summary.balanceDue;
  String get paymentStatus => summary.paymentStatus;

  PurchaseFormState copyWith({
    List<PurchaseItemModel>? items,
    int? supplierId,
    String? supplierName,
    String? paymentMode,
    double? discount,
    double? paidAmount,
    String? billNo,
    String? notes,
    int? selectedAccountId,
    bool? isProcessing,
    int? editingPurchaseId,
    DateTime? date,
    String? lastError,
    bool clearError = false,
  }) {
    return PurchaseFormState(
      items: items ?? this.items,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      paymentMode: paymentMode ?? this.paymentMode,
      discount: discount ?? this.discount,
      paidAmount: paidAmount ?? this.paidAmount,
      billNo: billNo ?? this.billNo,
      notes: notes ?? this.notes,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      isProcessing: isProcessing ?? this.isProcessing,
      editingPurchaseId: editingPurchaseId ?? this.editingPurchaseId,
      date: date ?? this.date,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

class PurchaseFormNotifier extends StateNotifier<PurchaseFormState> {
  final Ref _ref;
  PurchaseFormNotifier(this._ref) : super(PurchaseFormState());

  void initForEdit(PurchaseModel purchase, List<PurchaseItemModel> items) {
    state = PurchaseFormState(
      items: items,
      supplierId: purchase.supplierId,
      supplierName: purchase.supplierName,
      paymentMode: purchase.paymentMode,
      discount: purchase.discount,
      paidAmount: purchase.paidAmount,
      billNo: purchase.billNo,
      notes: purchase.notes,
      selectedAccountId: purchase.accountId,
      editingPurchaseId: purchase.id,
      date: purchase.date,
    );
  }

  void addItem(PurchaseItemModel item) {
    final newState = state.copyWith(items: [...state.items, item]);
    state = newState.copyWith(paidAmount: newState.grandTotal);
  }

  void removeItem(int productId) {
    final newState = state.copyWith(items: state.items.where((i) => i.productId != productId).toList());
    state = newState.copyWith(paidAmount: newState.grandTotal);
  }

  void updateItem(int productId, {double? qty, double? price, double? gst, double? discount}) {
    final newItems = state.items.map((i) {
      if (i.productId == productId) {
        final newQty = qty ?? i.quantity;
        final newPrice = price ?? i.purchasePrice;
        final newGst = gst ?? i.gstPercent;
        final newDiscount = discount ?? i.discount;
        final newGross = newQty * newPrice;
        final newTaxable = (newGross - newDiscount).clamp(0.0, double.infinity);
        return PurchaseItemModel(
          productId: i.productId,
          productName: i.productName,
          quantity: newQty,
          purchasePrice: newPrice,
          discount: newDiscount,
          taxableAmount: newTaxable,
          gstPercent: newGst,
          gstAmount: newTaxable * (newGst / 100),
          total: newGross,
        );
      }
      return i;
    }).toList();
    final newState = state.copyWith(items: newItems);
    state = newState.copyWith(paidAmount: newState.grandTotal);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  void selectSupplier(int id, String name) {
    state = state.copyWith(supplierId: id, supplierName: name);
  }

  void setPaymentMode(String mode) {
    state = state.copyWith(paymentMode: mode);
  }

  void setDiscount(double amount) {
    final newState = state.copyWith(discount: amount);
    state = newState.copyWith(paidAmount: newState.grandTotal);
  }

  void setPaidAmount(double amount) {
    state = state.copyWith(paidAmount: amount);
  }

  void setBillNo(String? no) {
    state = state.copyWith(billNo: no);
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  void setAccount(int? id) {
    state = state.copyWith(selectedAccountId: id);
  }

  Future<bool> savePurchase() async {
    if (state.items.isEmpty) return false;
    state = state.copyWith(isProcessing: true);

    final businessId = _ref.read(activeBusinessIdProvider);
    final purchase = PurchaseModel(
      businessId: businessId,
      billNo: state.billNo,
      supplierId: state.supplierId,
      supplierName: state.supplierName,
      subtotal: state.subtotal,
      discount: state.totalDiscount,
      taxableAmount: state.taxableAmount,
      gstAmount: state.totalGst,
      grandTotal: state.grandTotal,
      paidAmount: state.paidAmount,
      balanceDue: state.balanceDue,
      paymentMode: state.paymentMode,
      paymentStatus: state.paymentStatus,
      accountId: state.selectedAccountId,
      notes: state.notes,
      date: state.date,
      items: state.items,
    );

    try {
      final repo = _ref.read(purchaseRepositoryProvider);
      
      if (state.editingPurchaseId != null) {
        await repo.deletePurchase(state.editingPurchaseId!);
      }
      
      await repo.recordPurchase(purchase);
      _ref.read(notificationsProvider.notifier).scanAndGenerateAlerts();
      
      reset();
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (kDebugMode) debugPrint('Error saving purchase: $e');
      state = state.copyWith(lastError: msg);
      return false;
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }

  void reset() {
    state = PurchaseFormState();
  }
}

final purchaseFormProvider = StateNotifierProvider.autoDispose<PurchaseFormNotifier, PurchaseFormState>((ref) {
  return PurchaseFormNotifier(ref);
});
