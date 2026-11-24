import '../../../core/services/backend_api_service.dart';
import '../models/sale_history_model.dart';

class BillingRepository {
  Future<int> completeSale(SaleHistoryModel sale) async {
    final response = await BackendApiService.post('sales', _saleToApi(sale));
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? (decoded['id'] as num?)?.toInt() ?? 0
        : 0;
  }

  Future<int> recordSalesReturn(
      Map<String, dynamic> returnData,
      List<Map<String, dynamic>> items) async {
    final response = await BackendApiService.post('sales/returns', {
      ...returnData,
      'items': items,
    });
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? (decoded['id'] as num?)?.toInt() ?? 0
        : 0;
  }

  Future<void> voidSale(int saleId) async {
    await BackendApiService.delete(
      'sales/$saleId',
      {'businessId': '1'},
    );
  }

  Future<void> updateSale(SaleHistoryModel sale) async {
    await BackendApiService.put('sales/${sale.id}', _saleToApi(sale));
  }

  Future<String> getNextInvoiceNumber(int businessId) async {
    final response = await BackendApiService.get(
      'sales/next-invoice',
      {'businessId': '$businessId'},
    );
    final decoded = BackendApiService.decode(response);
    return decoded is Map && decoded['invoiceNo'] is String
        ? decoded['invoiceNo'] as String
        : 'INV-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> addSalePayment(
    int saleId,
    double amount,
    String mode, {
    int? accountId,
  }) async {
    await BackendApiService.put('sales/$saleId/payment', {
      'amount': amount,
      'mode': mode,
      'accountId': accountId,
    });
  }

  Future<void> settleCreditInvoice(
    int saleId,
    double amount, {
    String mode = 'Cash',
    int? accountId,
  }) async {
    await addSalePayment(saleId, amount, mode, accountId: accountId);
  }

  Future<SaleHistoryModel?> getSaleById(int id) async {
    final response = await BackendApiService.get(
      'sales/$id',
      {'businessId': '1'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! Map<String, dynamic>) return null;
    return SaleHistoryModel.fromMap(decoded);
  }

  static Map<String, dynamic> _saleToApi(SaleHistoryModel sale) => {
        'businessId': sale.businessId,
        'invoiceNo': sale.invoiceNo,
        'customerId': sale.customerId,
        'subtotal': sale.subtotal,
        'discount': sale.discount,
        'gstAmount': sale.gstAmount,
        'grandTotal': sale.grandTotal,
        'paidAmount': sale.paidAmount,
        'balanceDue': sale.balanceDue,
        'paymentMode': sale.paymentMode,
        'accountId': sale.accountId,
        'notes': sale.notes,
        'status': sale.status,
        'pointsEarned': sale.pointsEarned,
        'pointsRedeemed': sale.pointsRedeemed,
        'loyaltyDiscount': sale.loyaltyDiscount,
        'items': sale.items.map((item) => {
              'productId': item.productId,
              'quantity': item.quantity,
              'price': item.price,
              'purchasePrice': item.purchasePrice,
              'discount': item.discount,
              'gstAmount': item.gstAmount,
              'total': item.total,
            }).toList(),
      };
}
