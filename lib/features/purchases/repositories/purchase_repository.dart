import '../../../core/services/backend_api_service.dart';
import '../../accounts/models/ledger_model.dart';
import '../models/purchase_model.dart';

class PurchaseRepository {
  Future<List<PurchaseModel>> getPurchases(int businessId) async {
    final response = await BackendApiService.get(
      'purchases',
      {'businessId': '$businessId'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded
        .map((item) => PurchaseModel.fromMap(
              Map<String, dynamic>.from(item as Map),
              items: const [],
            ))
        .toList();
  }

  Future<List<PurchaseItemModel>> getPurchaseItems(int purchaseId) async {
    final response = await BackendApiService.get(
      'purchases/$purchaseId',
      {'businessId': '1'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! Map<String, dynamic>) return const [];
    final items = decoded['items'];
    if (items is! List) return const [];
    return items
        .map((item) => PurchaseItemModel.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<Map<String, dynamic>> getPurchaseStats(int businessId) async {
    final purchases = await getPurchases(businessId);
    final total = purchases.fold<double>(
        0, (sum, purchase) => sum + purchase.grandTotal);
    final payable = purchases.fold<double>(
        0, (sum, purchase) => sum + purchase.balanceDue);
    return {'total_purchases': total, 'total_payable': payable, 'count': purchases.length};
  }

  Future<int> recordPurchase(PurchaseModel purchase) async {
    final response = await BackendApiService.post('purchases', {
      'businessId': purchase.businessId,
      'supplierId': purchase.supplierId,
      'invoiceNo': purchase.billNo ?? 'PO-${DateTime.now().millisecondsSinceEpoch}',
      'subtotal': purchase.subtotal,
      'discount': purchase.discount,
      'taxAmount': purchase.gstAmount,
      'grandTotal': purchase.grandTotal,
      'paidAmount': purchase.paidAmount,
      'balanceDue': purchase.balanceDue,
      'paymentStatus': purchase.paymentStatus,
      'status': purchase.status,
      'items': purchase.items?.map((item) => {
            'productId': item.productId,
            'quantity': item.quantity,
            'purchasePrice': item.purchasePrice,
            'discount': item.discount,
            'taxAmount': item.gstAmount,
            'total': item.total,
          }).toList() ?? const [],
    });
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? (decoded['id'] as num?)?.toInt() ?? 0
        : 0;
  }

  Future<void> deletePurchase(int purchaseId) async {
    throw Exception(
      'Deleting purchase bills is prohibited. Create a purchase return.',
    );
  }

  Future<int> recordPurchaseReturn(
      Map<String, dynamic> returnData,
      List<Map<String, dynamic>> items) async {
    final response = await BackendApiService.post('purchases/returns', {
      ...returnData,
      'items': items,
    });
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? (decoded['id'] as num?)?.toInt() ?? 0
        : 0;
  }

  Future<void> addPurchasePayment(
    int purchaseId,
    double amount,
    String mode, {
    int? accountId,
  }) async {
    await BackendApiService.put(
      'purchases/$purchaseId/payment',
      {'amount': amount, 'mode': mode, 'accountId': accountId},
      {'businessId': '1'},
    );
  }

  Future<List<LedgerModel>> getPurchasePaymentHistory(int purchaseId) async {
    final response = await BackendApiService.get(
      'journal/ledger',
      {'businessId': '1'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded
        .where((item) =>
            (item as Map)['referenceId'] == purchaseId ||
            item['reference_id'] == purchaseId)
        .map((item) => LedgerModel.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<PurchaseModel?> getPurchaseById(int id) async {
    final response = await BackendApiService.get(
      'purchases/$id',
      {'businessId': '1'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! Map<String, dynamic>) return null;
    final items = await getPurchaseItems(id);
    return PurchaseModel.fromMap(decoded, items: items);
  }

  Future<double?> getLastPurchasePrice(
      int supplierId, int productId, int businessId) async {
    final response = await BackendApiService.get(
      'purchases/last-price',
      {
        'supplierId': '$supplierId',
        'productId': '$productId',
        'businessId': '$businessId',
      },
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is Map) return (decoded['price'] as num?)?.toDouble();
    return null;
  }
}
