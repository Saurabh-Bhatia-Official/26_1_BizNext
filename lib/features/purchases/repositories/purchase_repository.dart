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
    final result = await _db.transaction((txn) async {
      // ── VALIDATION RULES ──
      
      // 1. Supplier Validation
      if (purchase.supplierId == null) {
        throw Exception("Invalid Supplier: Supplier is required for recording purchases.");
      }
      final supplierCheck = await txn.query(
        AppConstants.tblSuppliers,
        columns: ['id'],
        where: 'id = ? AND business_id = ?',
        whereArgs: [purchase.supplierId, purchase.businessId],
      );
      if (supplierCheck.isEmpty) {
        throw Exception("Invalid Supplier: Supplier does not exist.");
      }

      // 2. Duplicate Purchase Invoice Validation
      if (purchase.billNo != null && purchase.billNo!.trim().isNotEmpty) {
        final duplicateCheck = await txn.query(
          AppConstants.tblPurchases,
          columns: ['id'],
          where: 'supplier_id = ? AND bill_no = ? AND business_id = ?',
          whereArgs: [purchase.supplierId, purchase.billNo, purchase.businessId],
        );
        if (duplicateCheck.isNotEmpty) {
          throw Exception("Duplicate Purchase Invoice: A purchase with bill number '${purchase.billNo}' already exists for this supplier.");
        }
      }

      // 3. Cash & Bank Validation
      if (purchase.paidAmount > 0) {
        if (purchase.accountId == null) {
          throw Exception("Invalid Account: A payment account is required when paid amount is greater than zero.");
        }
        final accountResult = await txn.query(
          AppConstants.tblAccounts,
          columns: ['balance', 'name'],
          where: 'id = ? AND business_id = ?',
          whereArgs: [purchase.accountId, purchase.businessId],
        );
        if (accountResult.isEmpty) {
          throw Exception("Invalid Account: Selected payment account does not exist.");
        }
        final currentBalance = (accountResult.first['balance'] as num?)?.toDouble() ?? 0.0;
        if (currentBalance < purchase.paidAmount) {
          throw Exception("Insufficient funds in account '${accountResult.first['name']}': Current Balance = ₹$currentBalance, Payment Required = ₹${purchase.paidAmount}");
        }
      }

      // 4. Item and GST Validation
      if (purchase.items == null || purchase.items!.isEmpty) {
        throw Exception("Invalid Purchase: Purchase must contain at least one line item.");
      }
      for (var item in purchase.items!) {
        if (item.quantity <= 0) {
          throw Exception("Negative Quantity Error: Product '${item.productName}' must have a positive quantity.");
        }
        if (item.purchasePrice < 0) {
          throw Exception("Negative Price Error: Product '${item.productName}' must have a positive cost price.");
        }
        if (item.gstPercent < 0 || item.gstPercent > 100) {
          throw Exception("Invalid GST: GST percentage for '${item.productName}' must be between 0% and 100%.");
        }
      }

      // ── EXECUTION ──

      // Get Default Warehouse scoped to the business
      final warehouseResult = await txn.query(
        AppConstants.tblWarehouses,
        columns: ['id'],
        where: 'business_id = ?',
        whereArgs: [purchase.businessId],
        limit: 1,
      );
      final warehouseId = warehouseResult.isNotEmpty ? (warehouseResult.first['id'] as int?) ?? 1 : 1;

      // 1. Insert Purchase Header
      final purchaseId = await txn.insert(AppConstants.tblPurchases, purchase.toMap());

      // 2. Insert Items, Update Stock & Cost (WAC)
      for (var item in purchase.items!) {
        await txn.insert(AppConstants.tblPurchaseItems, item.toMap(purchaseId));
        
        // Fetch current product state scoped to the business
        final productResult = await txn.query(
          AppConstants.tblProducts,
          columns: ['stock', 'purchase_price'],
          where: 'id = ? AND business_id = ?',
          whereArgs: [item.productId, purchase.businessId],
        );
        if (productResult.isEmpty) {
          throw Exception("Product '${item.productName}' not found in database.");
        }
        
        final currentStock = (productResult.first['stock'] as num?)?.toDouble() ?? 0.0;
        final currentWac = (productResult.first['purchase_price'] as num?)?.toDouble() ?? 0.0;

        // Calculate Weighted Average Cost (WAC)
        double newWac = currentWac;
        if (currentStock + item.quantity > 0) {
          newWac = ((currentStock * currentWac) + (item.quantity * item.purchasePrice)) / (currentStock + item.quantity);
        } else {
          newWac = item.purchasePrice;
        }

        // Update Product Master stock & price scoped to the business
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock + ?, purchase_price = ?, updated_at = datetime('now') WHERE id = ? AND business_id = ?",
          [item.quantity, newWac, item.productId, purchase.businessId],
        );

        // Update Warehouse Stocks (scoped to the business warehouse)
        final wsResult = await txn.rawQuery(
          "SELECT ws.id FROM ${AppConstants.tblWarehouseStocks} ws "
          "INNER JOIN ${AppConstants.tblWarehouses} w ON ws.warehouse_id = w.id "
          "WHERE ws.warehouse_id = ? AND ws.product_id = ? AND w.business_id = ?",
          [warehouseId, item.productId, purchase.businessId],
        );
        if (wsResult.isEmpty) {
          await txn.insert(AppConstants.tblWarehouseStocks, {
            'warehouse_id': warehouseId,
            'product_id': item.productId,
            'stock': item.quantity,
          });
        } else {
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblWarehouseStocks} SET stock = stock + ? WHERE warehouse_id = ? AND product_id = ?",
            [item.quantity, warehouseId, item.productId],
          );
        }

        // Record Stock Movement to Transaction Log
        await txn.insert(AppConstants.tblInventoryTransactions, {
          'product_id': item.productId,
          'warehouse_id': warehouseId,
          'transaction_type': AppConstants.transactionTypePurchase,
          'reference_number': purchase.billNo ?? "#$purchaseId",
          'quantity': item.quantity,
          'unit_cost': item.purchasePrice,
          'opening_stock': currentStock,
          'closing_stock': currentStock + item.quantity,
          'remarks': 'Purchase recorded via bill ${purchase.billNo ?? "#$purchaseId"}',
        });

        // Update supplier-product price mapping
        if (purchase.supplierId != null) {
          await txn.rawInsert('''
            INSERT INTO ${AppConstants.tblSupplierProducts} 
              (business_id, supplier_id, product_id, last_purchase_price, last_purchase_date, last_purchase_qty)
            VALUES (?, ?, ?, ?, datetime('now'), ?)
            ON CONFLICT(business_id, supplier_id, product_id) DO UPDATE SET
              last_purchase_price = excluded.last_purchase_price,
              last_purchase_date = excluded.last_purchase_date,
              last_purchase_qty = excluded.last_purchase_qty
          ''', [purchase.businessId, purchase.supplierId, item.productId, item.purchasePrice, item.quantity]);
        }
      }

      // 3. Update Supplier Balance scoped to the business
      if (purchase.balanceDue > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblSuppliers} SET balance = balance + ? WHERE id = ? AND business_id = ?",
          [purchase.balanceDue, purchase.supplierId, purchase.businessId],
        );
      }

      // 4. Double Entry Ledger Bookings
      final billRef = purchase.billNo ?? "#$purchaseId";
      final dateStr = purchase.date.toIso8601String();

      // Entry A: Debit Inventory Asset Account = Grand Total - GST Amount (Subtotal)
      await txn.insert(AppConstants.tblLedger, {
        'business_id': purchase.businessId,
        'entity_type': 'inventory',
        'entity_id': 0,
        'type': 'debit',
        'amount': purchase.subtotal,
        'reference_id': purchaseId,
        'description': 'Inventory Debit (Purchase): $billRef',
        'date': dateStr,
      });

      // Entry B: Debit Input GST Account = GST Amount
      if (purchase.gstAmount > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': purchase.businessId,
          'entity_type': 'gst',
          'entity_id': 0,
          'type': 'debit',
          'amount': purchase.gstAmount,
          'reference_id': purchaseId,
          'description': 'Input GST Debit (Purchase): $billRef',
          'date': dateStr,
        });
      }

      // Entry C: Credit Cash/Bank = Paid Amount
      if (purchase.paidAmount > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': purchase.businessId,
          'entity_type': 'account',
          'entity_id': purchase.accountId,
          'type': 'credit',
          'amount': purchase.paidAmount,
          'reference_id': purchaseId,
          'account_id': purchase.accountId,
          'description': 'Cash/Bank Credit (Purchase Payment): $billRef',
          'date': dateStr,
        });

        // Deduct Cash/Bank balance scoped to the business
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance - ? WHERE id = ? AND business_id = ?",
          [purchase.paidAmount, purchase.accountId, purchase.businessId],
        );
      }

      // Entry D: Credit Supplier Accounts Payable = Balance Due
      if (purchase.balanceDue > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': purchase.businessId,
          'entity_type': 'supplier',
          'entity_id': purchase.supplierId,
          'type': 'credit',
          'amount': purchase.balanceDue,
          'reference_id': purchaseId,
          'description': 'Accounts Payable Credit (Purchase Credit): $billRef',
          'date': dateStr,
        });
      }

      return purchaseId;
    });

    _db.notify(AppConstants.tblPurchases);
    _db.notify(AppConstants.tblPurchaseItems);
    _db.notify(AppConstants.tblProducts);
    _db.notify(AppConstants.tblWarehouseStocks);
    _db.notify(AppConstants.tblSuppliers);
    _db.notify(AppConstants.tblAccounts);
    _db.notify(AppConstants.tblLedger);
    return result;
  }

  Future<void> deletePurchase(int purchaseId) async {
    // Audit protection: prevent manual bill deletion
    throw Exception("Deleting purchase bills directly is prohibited to maintain audit trails. Please execute a Purchase Return (Credit Note) to reverse stock and balances.");
  }

  Future<int> recordPurchaseReturn(Map<String, dynamic> returnData, List<Map<String, dynamic>> items) async {
    final result = await _db.transaction((txn) async {
      final businessId = returnData['business_id'] as int;

      // 1. Validate stock availability scoped to business
      for (var item in items) {
        final productId = (item['product_id'] as num?)?.toInt() ?? 0;
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        
        final productResult = await txn.query(
          AppConstants.tblProducts,
          columns: ['stock', 'name'],
          where: 'id = ? AND business_id = ?',
          whereArgs: [productId, businessId],
        );
        if (productResult.isEmpty) throw Exception("Product ID $productId not found.");
        final currentStock = (productResult.first['stock'] as num?)?.toDouble() ?? 0.0;
        if (currentStock < qty) {
          throw Exception("Insufficient stock for product '${productResult.first['name']}': Available = $currentStock, Required return quantity = $qty");
        }
      }

      // 2. Insert Purchase Return Header
      final returnId = await txn.insert(AppConstants.tblPurchaseReturns, returnData);

      // Get Default Warehouse scoped to business
      final warehouseResult = await txn.query(
        AppConstants.tblWarehouses,
        columns: ['id'],
        where: 'business_id = ?',
        whereArgs: [businessId],
        limit: 1,
      );
      final warehouseId = warehouseResult.isNotEmpty ? (warehouseResult.first['id'] as int?) ?? 1 : 1;

      // 3. Deduct stock and update inventory logs
      for (var item in items) {
        final productId = (item['product_id'] as num?)?.toInt() ?? 0;
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final gstPercent = (item['gst_percent'] as num?)?.toDouble() ?? 0.0;
        final gstAmount = qty * price * (gstPercent / 100);
        final total = (qty * price) + gstAmount;

        final productResult = await txn.query(
          AppConstants.tblProducts,
          columns: ['stock', 'purchase_price'],
          where: 'id = ? AND business_id = ?',
          whereArgs: [productId, businessId],
        );
        final currentStock = (productResult.first['stock'] as num?)?.toDouble() ?? 0.0;
        final cost = (productResult.first['purchase_price'] as num?)?.toDouble() ?? 0.0;

        await txn.insert(AppConstants.tblPurchaseReturnItems, {
          'return_id': returnId,
          'product_id': productId,
          'product_name': item['product_name'] ?? 'Product',
          'quantity': qty,
          'price': price,
          'gst_percent': gstPercent,
          'gst_amount': gstAmount,
          'total': total,
        });

        // Deduct stock in Product Master scoped to business
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock - ?, updated_at = datetime('now') WHERE id = ? AND business_id = ?",
          [qty, productId, businessId],
        );

        // Deduct warehouse stock
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblWarehouseStocks} SET stock = stock - ? WHERE warehouse_id = ? AND product_id = ?",
          [qty, warehouseId, productId],
        );

        // Log stock movement
        await txn.insert(AppConstants.tblInventoryTransactions, {
          'product_id': productId,
          'warehouse_id': warehouseId,
          'transaction_type': 'PURCHASE_RETURN',
          'reference_number': returnData['return_no'] ?? '#PR-$returnId',
          'quantity': qty,
          'unit_cost': cost,
          'opening_stock': currentStock,
          'closing_stock': currentStock - qty,
          'remarks': 'Purchase return processed',
        });
      }

      // 4. Update Supplier Balance if credit return scoped to business
      final supplierId = returnData['supplier_id'] as int?;
      final grandTotal = (returnData['grand_total'] as num?)?.toDouble() ?? 0.0;
      final refundAmount = (returnData['refund_amount'] as num?)?.toDouble() ?? 0.0;
      final balanceDueReduction = grandTotal - refundAmount;

      if (supplierId != null && balanceDueReduction > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblSuppliers} SET balance = balance - ? WHERE id = ? AND business_id = ?",
          [balanceDueReduction, supplierId, businessId],
        );
      }

      // 5. Post Ledger entries (Reversal of Purchase DR/CR rules)
      final returnNo = returnData['return_no'] ?? '#PR-$returnId';
      final dateStr = returnData['date'] ?? DateTime.now().toIso8601String();

      // AP/Cash Debit
      if (refundAmount > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': businessId,
          'entity_type': 'account',
          'entity_id': returnData['account_id'] ?? 0,
          'type': 'debit',
          'amount': refundAmount,
          'reference_id': returnId,
          'description': 'Refund Debit (Purchase Return): $returnNo',
          'date': dateStr,
        });
        
        if (returnData['account_id'] != null) {
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ? AND business_id = ?",
            [refundAmount, returnData['account_id'], businessId],
          );
        }
      }
      
      if (balanceDueReduction > 0 && supplierId != null) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': businessId,
          'entity_type': 'supplier',
          'entity_id': supplierId,
          'type': 'debit',
          'amount': balanceDueReduction,
          'reference_id': returnId,
          'description': 'Accounts Payable Debit (Purchase Return Reversal): $returnNo',
          'date': dateStr,
        });
      }

      // Inventory credit
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': 'inventory',
        'entity_id': 0,
        'type': 'credit',
        'amount': (returnData['subtotal'] as num?)?.toDouble() ?? 0.0,
        'reference_id': returnId,
        'description': 'Inventory Credit (Purchase Return Reversal): $returnNo',
        'date': dateStr,
      });

      // GST credit
      final gstAmount = (returnData['gst_amount'] as num?)?.toDouble() ?? 0.0;
      if (gstAmount > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': businessId,
          'entity_type': 'gst',
          'entity_id': 0,
          'type': 'credit',
          'amount': gstAmount,
          'reference_id': returnId,
          'description': 'Input GST Credit (Purchase Return Reversal): $returnNo',
          'date': dateStr,
        });
      }

      return returnId;
    });

    _db.notify(AppConstants.tblPurchaseReturns);
    _db.notify(AppConstants.tblPurchaseReturnItems);
    _db.notify(AppConstants.tblProducts);
    _db.notify(AppConstants.tblWarehouseStocks);
    _db.notify(AppConstants.tblSuppliers);
    _db.notify(AppConstants.tblAccounts);
    _db.notify(AppConstants.tblLedger);
    return result;
  }

  Future<void> addPurchasePayment(int purchaseId, double amount, String mode, {int? accountId}) async {
    await _db.transaction((txn) async {
      final purchaseResult = await txn.query(AppConstants.tblPurchases, where: 'id = ?', whereArgs: [purchaseId]);
      if (purchaseResult.isEmpty) return;
      final p = purchaseResult.first;
      final supplierId = p['supplier_id'] as int?;
      final businessId = (p['business_id'] as num?)?.toInt() ?? 1;
      final billNo = p['bill_no'] as String?;

      // Validate account balance scoped to business
      if (accountId != null) {
        final accountResult = await txn.query(
          AppConstants.tblAccounts,
          columns: ['balance', 'name'],
          where: 'id = ? AND business_id = ?',
          whereArgs: [accountId, businessId],
        );
        if (accountResult.isNotEmpty) {
          final balance = (accountResult.first['balance'] as num?)?.toDouble() ?? 0.0;
          if (balance < amount) {
            throw Exception("Insufficient funds in account '${accountResult.first['name']}' to complete payment of ₹$amount.");
          }
        }
      }

      // Update Purchase scoped to business
      await txn.rawUpdate(
        "UPDATE ${AppConstants.tblPurchases} SET paid_amount = paid_amount + ?, balance_due = balance_due - ? WHERE id = ? AND business_id = ?",
        [amount, amount, purchaseId, businessId],
      );

      // Update Supplier Balance scoped to business
      if (supplierId != null) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblSuppliers} SET balance = balance - ? WHERE id = ? AND business_id = ?",
          [amount, supplierId, businessId],
        );
      }

      // Record in Ledger
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': supplierId != null ? AppConstants.entitySupplier : AppConstants.entityBusiness,
        'entity_id': supplierId ?? 0,
        'type': AppConstants.ledgerDebit,
        'amount': amount,
        'reference_id': purchaseId,
        'description': 'Payment for Bill: ${billNo ?? "#$purchaseId"} ($mode)',
        'date': DateTime.now().toIso8601String(),
      });

      // Sync Account Balance scoped to business
      if (accountId != null) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance - ? WHERE id = ? AND business_id = ?",
          [amount, accountId, businessId],
        );
      }
    });

    _db.notify(AppConstants.tblPurchases);
    _db.notify(AppConstants.tblSuppliers);
    _db.notify(AppConstants.tblAccounts);
    _db.notify(AppConstants.tblLedger);
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

  Future<double?> getLastPurchasePrice(int supplierId, int productId, int businessId) async {
    final result = await _db.rawQuery('''
      SELECT last_purchase_price 
      FROM ${AppConstants.tblSupplierProducts}
      WHERE supplier_id = ? AND product_id = ? AND business_id = ?
    ''', [supplierId, productId, businessId]);
    if (result.isNotEmpty) {
      final rate = (result.first['last_purchase_price'] as num?)?.toDouble();
      if (rate != null && rate > 0) return rate;
    }
    // Fallback: check most recent purchase item
    final fallback = await _db.rawQuery('''
      SELECT pi.price
      FROM ${AppConstants.tblPurchaseItems} pi
      JOIN ${AppConstants.tblPurchases} p ON pi.purchase_id = p.id
      WHERE p.supplier_id = ? AND pi.product_id = ? AND p.business_id = ?
      ORDER BY p.date DESC
      LIMIT 1
    ''', [supplierId, productId, businessId]);
    if (fallback.isNotEmpty) {
      return (fallback.first['price'] as num?)?.toDouble();
    }
    return null;
  }
}
