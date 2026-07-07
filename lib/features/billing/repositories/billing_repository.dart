// lib/features/billing/repositories/billing_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/sale_history_model.dart';

class BillingRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> completeSale(SaleHistoryModel sale) async {
    return await _db.transaction((txn) async {
      // 1. Insert Sale
      final saleId = await txn.insert(AppConstants.tblSales, sale.toMap());

      // 2. Insert Sale Items and update stock
      for (final item in sale.items) {
        // Record current purchase price for accurate historical COGS
        double costPrice = item.purchasePrice;
        try {
          final product = await txn.query(AppConstants.tblProducts, columns: ['purchase_price'], where: 'id = ?', whereArgs: [item.productId]);
          if (product.isNotEmpty) {
            costPrice = (product.first['purchase_price'] as num).toDouble();
          }
        } catch (_) {}

        final itemMap = item.toMap(saleId);
        itemMap['purchase_price'] = costPrice;

        await txn.insert(AppConstants.tblSaleItems, itemMap);

        // Update stock: decrement quantity
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock - ?, updated_at = datetime('now') WHERE id = ?",
          [item.quantity, item.productId],
        );
      }

      // 3. Update customer balance if it's a credit sale (not fully paid)
      if (sale.customerId != null && sale.balanceDue > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblCustomers} SET balance = balance + ? WHERE id = ?",
          [sale.balanceDue, sale.customerId],
        );
      }

      // 4. Record in Ledger
      // Always record the transaction, either against a customer or as a generic business entry
      final entityType = sale.customerId != null ? AppConstants.entityCustomer : AppConstants.entityBusiness;
      final entityId = sale.customerId ?? 0; // Use 0 for generic business entity

      // Record Full Invoice (Debit for customer, or just internal tracking for walk-in)
      await txn.insert(AppConstants.tblLedger, {
        'business_id': sale.businessId,
        'entity_type': entityType,
        'entity_id': entityId,
        'type': AppConstants.ledgerDebit,
        'amount': sale.grandTotal,
        'reference_id': saleId,
        'account_id': sale.accountId,
        'description': 'Sale Invoice: ${sale.invoiceNo} ${sale.customerId == null ? "(Walk-in)" : ""}',
        'date': sale.date.toIso8601String(),
      });

      // Record Payment (Credit)
      if (sale.paidAmount > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': sale.businessId,
          'entity_type': entityType,
          'entity_id': entityId,
          'type': AppConstants.ledgerCredit,
          'amount': sale.paidAmount,
          'reference_id': saleId,
          'account_id': sale.accountId,
          'description': 'Payment for Invoice: ${sale.invoiceNo}',
          'date': sale.date.toIso8601String(),
        });
      }

      // 5. Update Account Balance
      if (sale.accountId != null && sale.paidAmount > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?",
          [sale.paidAmount, sale.accountId],
        );
      }

      // 6. Update Customer Loyalty Points
      if (sale.customerId != null) {
        final pointBalanceChange = sale.pointsEarned - sale.pointsRedeemed;
        if (pointBalanceChange != 0) {
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblCustomers} SET loyalty_points = loyalty_points + ? WHERE id = ?",
            [pointBalanceChange, sale.customerId],
          );
        }
      }

      return saleId;
    });
  }

  Future<void> updateSale(SaleHistoryModel sale) async {
    return await _db.transaction((txn) async {
      // 1. Get Old Items to revert stock
      final oldItems = await txn.query(AppConstants.tblSaleItems, where: 'sale_id = ?', whereArgs: [sale.id]);
      for (final item in oldItems) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock + ? WHERE id = ?",
          [item['quantity'], item['product_id']],
        );
      }

      // 2. Sync Customer Balance: Revert Old
      final oldSaleResult = await txn.query(AppConstants.tblSales, where: 'id = ?', whereArgs: [sale.id]);
      if (oldSaleResult.isNotEmpty) {
        final oldSaleMap = oldSaleResult.first;
        final oldCustomerId = oldSaleMap['customer_id'] as int?;
        final oldBalanceDue = (oldSaleMap['balance_due'] as num?)?.toDouble() ?? 0;
        if (oldCustomerId != null && oldBalanceDue > 0) {
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblCustomers} SET balance = balance - ? WHERE id = ?",
            [oldBalanceDue, oldCustomerId],
          );
        }
      }

      // 3. Delete old items and ledger entries
      await txn.delete(AppConstants.tblSaleItems, where: 'sale_id = ?', whereArgs: [sale.id]);
      await txn.delete(AppConstants.tblLedger, where: 'reference_id = ? AND entity_type IN (?, ?)', whereArgs: [sale.id, AppConstants.entityCustomer, AppConstants.entityBusiness]);

      // 4. Update Sale Header
      await txn.update(AppConstants.tblSales, sale.toMap(), where: 'id = ?', whereArgs: [sale.id]);

      // 5. Update Customer Balance: Apply New
      if (sale.customerId != null && sale.balanceDue > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblCustomers} SET balance = balance + ? WHERE id = ?",
          [sale.balanceDue, sale.customerId],
        );
      }

      // 4. Re-insert items and update stock
      for (final item in sale.items) {
        await txn.insert(AppConstants.tblSaleItems, item.toMap(sale.id!));
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock - ? WHERE id = ?",
          [item.quantity, item.productId],
        );
      }

      // 5. Re-record in Ledger
      final entityType = sale.customerId != null ? AppConstants.entityCustomer : AppConstants.entityBusiness;
      final entityId = sale.customerId ?? 0;

      await txn.insert(AppConstants.tblLedger, {
        'business_id': sale.businessId,
        'entity_type': entityType,
        'entity_id': entityId,
        'type': AppConstants.ledgerDebit,
        'amount': sale.grandTotal,
        'reference_id': sale.id,
        'account_id': sale.accountId,
        'description': 'Updated Sale Invoice: ${sale.invoiceNo}',
        'date': sale.date.toIso8601String(),
      });

      if (sale.paidAmount > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': sale.businessId,
          'entity_type': entityType,
          'entity_id': entityId,
          'type': AppConstants.ledgerCredit,
          'amount': sale.paidAmount,
          'reference_id': sale.id,
          'account_id': sale.accountId,
          'description': 'Updated Payment for Invoice: ${sale.invoiceNo}',
          'date': sale.date.toIso8601String(),
        });
      }

      // Sync Account Balance
      final oldSaleData = await txn.query(AppConstants.tblSales, where: 'id = ?', whereArgs: [sale.id]);
      if (oldSaleData.isNotEmpty) {
        final oldAccId = oldSaleData.first['account_id'] as int?;
        final oldPaid = (oldSaleData.first['paid_amount'] as num?)?.toDouble() ?? 0;
        if (oldAccId != null && oldPaid > 0) {
          await txn.rawUpdate("UPDATE ${AppConstants.tblAccounts} SET balance = balance - ? WHERE id = ?", [oldPaid, oldAccId]);
        }
      }
      
      if (sale.accountId != null && sale.paidAmount > 0) {
        await txn.rawUpdate("UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?", [sale.paidAmount, sale.accountId]);
      }
    });
  }

  Future<void> voidSale(int saleId) async {
    await _db.transaction((txn) async {
      // 1. Get Sale and Items
      final saleResult = await txn.query(AppConstants.tblSales, where: 'id = ?', whereArgs: [saleId]);
      if (saleResult.isEmpty) return;
      final saleMap = saleResult.first;

      final items = await txn.query(AppConstants.tblSaleItems, where: 'sale_id = ?', whereArgs: [saleId]);

      // 2. Revert Stock
      for (final item in items) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock + ? WHERE id = ?",
          [item['quantity'], item['product_id']],
        );
      }

      // 3. Revert Customer Balance if applicable
      final customerId = saleMap['customer_id'] as int?;
      final balanceDue = (saleMap['balance_due'] as num?)?.toDouble() ?? 0;
      if (customerId != null && balanceDue > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblCustomers} SET balance = balance - ? WHERE id = ?",
          [balanceDue, customerId],
        );
      }

      // 4. Reverse Account Balance
      final oldAccId = saleMap['account_id'] as int?;
      final oldPaid = (saleMap['paid_amount'] as num?)?.toDouble() ?? 0;
      if (oldAccId != null && oldPaid > 0) {
        await txn.rawUpdate("UPDATE ${AppConstants.tblAccounts} SET balance = balance - ? WHERE id = ?", [oldPaid, oldAccId]);
      }

      // 5. Delete Ledger entries
      await txn.delete(AppConstants.tblLedger, where: 'reference_id = ? AND entity_type IN (?, ?)', whereArgs: [saleId, AppConstants.entityCustomer, AppConstants.entityBusiness]);

      // 6. Delete Sale
      await txn.delete(AppConstants.tblSaleItems, where: 'sale_id = ?', whereArgs: [saleId]);
      await txn.delete(AppConstants.tblSales, where: 'id = ?', whereArgs: [saleId]);

      // 7. Revert Loyalty Points
      if (customerId != null) {
        final ptsEarned = (saleMap['points_earned'] as num?)?.toDouble() ?? 0;
        final ptsRedeemed = (saleMap['points_redeemed'] as num?)?.toDouble() ?? 0;
        final balanceToRevert = ptsEarned - ptsRedeemed;
        if (balanceToRevert != 0) {
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblCustomers} SET loyalty_points = loyalty_points - ? WHERE id = ?",
            [balanceToRevert, customerId],
          );
        }
      }
    });
  }

  Future<String> getNextInvoiceNumber(int businessId) async {
    final result = await _db.rawQuery(
      "SELECT MAX(id) as max_id FROM ${AppConstants.tblSales}",
    );
    final maxId = (result.first['max_id'] as int?) ?? 0;
    return 'INV-${(maxId + 1).toString().padLeft(6, '0')}';
  }

  Future<void> addSalePayment(int saleId, double amount, String mode, {int? accountId}) async {
    await _db.transaction((txn) async {
      // 1. Get Sale
      final saleResult = await txn.query(AppConstants.tblSales, where: 'id = ?', whereArgs: [saleId]);
      if (saleResult.isEmpty) return;
      final s = saleResult.first;
      final customerId = s['customer_id'] as int?;
      final businessId = s['business_id'] as int;
      final invoiceNo = s['invoice_no'] as String?;

      // 2. Update Sale
      await txn.rawUpdate(
        "UPDATE ${AppConstants.tblSales} SET paid_amount = paid_amount + ?, balance_due = balance_due - ? WHERE id = ?",
        [amount, amount, saleId],
      );

      // 3. Update Customer Balance
      if (customerId != null) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblCustomers} SET balance = balance - ? WHERE id = ?",
          [amount, customerId],
        );
      }

      // 4. Record in Ledger
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': customerId != null ? AppConstants.entityCustomer : AppConstants.entityBusiness,
        'entity_id': customerId ?? 0,
        'type': AppConstants.ledgerCredit,
        'amount': amount,
        'reference_id': saleId,
        'account_id': accountId,
        'description': 'Collection for Invoice: ${invoiceNo ?? "#$saleId"} ($mode)',
        'date': DateTime.now().toIso8601String(),
      });

      // 5. Sync Account Balance
      if (accountId != null) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?",
          [amount, accountId],
        );
      }
    });
  }

  Future<SaleHistoryModel?> getSaleById(int id) async {
    final result = await _db.rawQuery(
      "SELECT s.*, c.name as customer_name, a.name as account_name FROM ${AppConstants.tblSales} s LEFT JOIN ${AppConstants.tblCustomers} c ON s.customer_id = c.id LEFT JOIN ${AppConstants.tblAccounts} a ON s.account_id = a.id WHERE s.id = ?",
      [id],
    );
    if (result.isEmpty) return null;
    
    final saleMap = Map<String, dynamic>.from(result.first);
    final items = await _db.rawQuery(
      "SELECT * FROM ${AppConstants.tblSaleItems} WHERE sale_id = ?",
      [id],
    );
    saleMap['items'] = items;
    return SaleHistoryModel.fromMap(saleMap);
  }
}
