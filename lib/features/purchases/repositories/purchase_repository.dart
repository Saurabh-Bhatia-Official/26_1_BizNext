// lib/features/purchases/repositories/purchase_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../accounts/models/ledger_model.dart';
import '../models/purchase_model.dart';

class PurchaseRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<PurchaseModel>> getPurchases(int businessId) async {
    final result = await _db.rawQuery(
      "SELECT p.*, s.name as supplier_name, a.name as account_name FROM ${AppConstants.tblPurchases} p LEFT JOIN ${AppConstants.tblSuppliers} s ON p.supplier_id = s.id LEFT JOIN ${AppConstants.tblAccounts} a ON p.account_id = a.id WHERE p.business_id = ? ORDER BY p.date DESC",
      [businessId],
    );
    return result.map((m) => PurchaseModel.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>> getPurchaseStats(int businessId) async {
    final result = await _db.rawQuery(
      "SELECT COALESCE(SUM(grand_total), 0) as total_purchases, COALESCE(SUM(balance_due), 0) as total_payable, COUNT(*) as count FROM ${AppConstants.tblPurchases} WHERE business_id = ? AND status = 'completed'",
      [businessId],
    );
    return result.first;
  }

  Future<int> recordPurchase(PurchaseModel purchase) async {
    return await _db.transaction((txn) async {
      // 1. Insert Purchase Header
      final purchaseId = await txn.insert(AppConstants.tblPurchases, purchase.toMap());

      // 2. Insert Items and Update Stock
      if (purchase.items != null) {
        for (var item in purchase.items!) {
          await txn.insert(AppConstants.tblPurchaseItems, item.toMap(purchaseId));
          
          // Update Product Stock and Cost Price
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblProducts} SET stock = stock + ?, purchase_price = ? WHERE id = ?",
            [item.quantity, item.purchasePrice, item.productId],
          );
        }
      }

      // 3. Update Supplier Balance if Credit
      if (purchase.supplierId != null && purchase.balanceDue > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblSuppliers} SET balance = balance + ? WHERE id = ?",
          [purchase.balanceDue, purchase.supplierId],
        );
      }

      // 4. Record in Ledger
      final entityType = purchase.supplierId != null ? AppConstants.entitySupplier : AppConstants.entityBusiness;
      final entityId = purchase.supplierId ?? 0;

      await txn.insert(AppConstants.tblLedger, {
        'business_id': purchase.businessId,
        'entity_type': entityType,
        'entity_id': entityId,
        'type': AppConstants.ledgerCredit, // Liability or Cash decrease
        'amount': purchase.grandTotal,
        'reference_id': purchaseId,
        'account_id': purchase.accountId,
        'description': 'Purchase: ${purchase.billNo ?? "#$purchaseId"} ${purchase.supplierId == null ? "(Direct)" : ""}',
        'date': purchase.date.toIso8601String(),
      });

      if (purchase.paidAmount > 0) {
         await txn.insert(AppConstants.tblLedger, {
          'business_id': purchase.businessId,
          'entity_type': entityType,
          'entity_id': entityId,
          'type': AppConstants.ledgerDebit,
          'amount': purchase.paidAmount,
          'reference_id': purchaseId,
          'account_id': purchase.accountId,
          'description': 'Payment for Purchase: ${purchase.billNo ?? "#$purchaseId"}',
          'date': purchase.date.toIso8601String(),
        });
      }

      // 5. Update Account Balance
      if (purchase.accountId != null && purchase.paidAmount > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance - ? WHERE id = ?",
          [purchase.paidAmount, purchase.accountId],
        );
      }

      return purchaseId;
    });
  }
  Future<void> deletePurchase(int purchaseId) async {
    await _db.transaction((txn) async {
      // 1. Get Purchase and Items
      final purchaseResult = await txn.query(AppConstants.tblPurchases, where: 'id = ?', whereArgs: [purchaseId]);
      if (purchaseResult.isEmpty) return;
      final pMap = purchaseResult.first;

      final items = await txn.query(AppConstants.tblPurchaseItems, where: 'purchase_id = ?', whereArgs: [purchaseId]);

      // 2. Revert Stock (Decrement)
      for (final item in items) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock - ? WHERE id = ?",
          [item['quantity'], item['product_id']],
        );
      }

      // 3. Revert Supplier Balance if applicable
      final supplierId = pMap['supplier_id'] as int?;
      final balanceDue = (pMap['balance_due'] as num?)?.toDouble() ?? 0;
      if (supplierId != null && balanceDue > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblSuppliers} SET balance = balance - ? WHERE id = ?",
          [balanceDue, supplierId],
        );
      }

      // 4. Reverse Account Balance
      final oldAccId = pMap['account_id'] as int?;
      final oldPaid = (pMap['paid_amount'] as num?)?.toDouble() ?? 0;
      if (oldAccId != null && oldPaid > 0) {
        await txn.rawUpdate("UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?", [oldPaid, oldAccId]);
      }

      // 5. Delete Ledger entries
      await txn.delete(
        AppConstants.tblLedger, 
        where: 'reference_id = ? AND entity_type IN (?, ?)', 
        whereArgs: [purchaseId, AppConstants.entitySupplier, AppConstants.entityBusiness],
      );

      // 5. Delete Purchase and items
      await txn.delete(AppConstants.tblPurchaseItems, where: 'purchase_id = ?', whereArgs: [purchaseId]);
      await txn.delete(AppConstants.tblPurchases, where: 'id = ?', whereArgs: [purchaseId]);
    });
  }

  Future<void> addPurchasePayment(int purchaseId, double amount, String mode, {int? accountId}) async {
    await _db.transaction((txn) async {
      // 1. Get Purchase
      final purchaseResult = await txn.query(AppConstants.tblPurchases, where: 'id = ?', whereArgs: [purchaseId]);
      if (purchaseResult.isEmpty) return;
      final p = purchaseResult.first;
      final supplierId = p['supplier_id'] as int?;
      final businessId = p['business_id'] as int;
      final billNo = p['bill_no'] as String?;

      // 2. Update Purchase
      await txn.rawUpdate(
        "UPDATE ${AppConstants.tblPurchases} SET paid_amount = paid_amount + ?, balance_due = balance_due - ? WHERE id = ?",
        [amount, amount, purchaseId],
      );

      // 3. Update Supplier Balance
      if (supplierId != null) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblSuppliers} SET balance = balance - ? WHERE id = ?",
          [amount, supplierId],
        );
      }

      // 4. Record in Ledger
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': supplierId != null ? AppConstants.entitySupplier : AppConstants.entityBusiness,
        'entity_id': supplierId ?? 0,
        'type': AppConstants.ledgerDebit,
        'amount': amount,
        'reference_id': purchaseId,
        'description': 'Pending Payment for Bill: ${billNo ?? "#$purchaseId"} ($mode)',
        'date': DateTime.now().toIso8601String(),
      });

      // 5. Sync Account Balance
      if (accountId != null) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance - ? WHERE id = ?",
          [amount, accountId],
        );
      }
    });
  }

  Future<List<PurchaseItemModel>> getPurchaseItems(int purchaseId) async {
    final result = await _db.rawQuery(
      "SELECT * FROM ${AppConstants.tblPurchaseItems} WHERE purchase_id = ?",
      [purchaseId],
    );
    return result.map((m) => PurchaseItemModel.fromMap(m)).toList();
  }

  Future<List<LedgerModel>> getPurchasePaymentHistory(int purchaseId) async {
    final result = await _db.rawQuery(
      "SELECT * FROM ${AppConstants.tblLedger} WHERE reference_id = ? AND entity_type = ? ORDER BY date DESC",
      [purchaseId, AppConstants.entitySupplier],
    );
    return result.map((m) => LedgerModel.fromMap(m)).toList();
  }

  Future<PurchaseModel?> getPurchaseById(int id) async {
    final result = await _db.rawQuery(
      "SELECT p.*, s.name as supplier_name, a.name as account_name FROM ${AppConstants.tblPurchases} p LEFT JOIN ${AppConstants.tblSuppliers} s ON p.supplier_id = s.id LEFT JOIN ${AppConstants.tblAccounts} a ON p.account_id = a.id WHERE p.id = ?",
      [id],
    );
    if (result.isEmpty) return null;
    return PurchaseModel.fromMap(result.first);
  }
}
