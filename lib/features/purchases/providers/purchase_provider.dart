// lib/features/purchases/providers/purchase_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/purchase_model.dart';
import '../repositories/purchase_repository.dart';
import '../../../core/database/database_providers.dart';

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
  }) : date = date ?? DateTime.now();

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get totalGst => items.fold(0, (sum, item) => sum + (item.total * (item.gstPercent / 100)));
  double get grandTotal => subtotal + totalGst - discount;
  double get balanceDue => grandTotal - paidAmount;

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
    state = state.copyWith(items: [...state.items, item]);
  }

  void removeItem(int productId) {
    state = state.copyWith(items: state.items.where((i) => i.productId != productId).toList());
  }

  void updateItem(int productId, {double? qty, double? price, double? gst}) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.productId == productId) {
          final newQty = qty ?? i.quantity;
          final newPrice = price ?? i.purchasePrice;
          final newGst = gst ?? i.gstPercent;
          return PurchaseItemModel(
            productId: i.productId,
            productName: i.productName,
            quantity: newQty,
            purchasePrice: newPrice,
            gstPercent: newGst,
            total: newQty * newPrice,
          );
        }
        return i;
      }).toList(),
    );
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
    state = state.copyWith(discount: amount);
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
      discount: state.discount,
      gstAmount: state.totalGst,
      grandTotal: state.grandTotal,
      paidAmount: state.paidAmount,
      balanceDue: state.balanceDue,
      paymentMode: state.paymentMode,
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
      
      reset();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving purchase: $e');
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
