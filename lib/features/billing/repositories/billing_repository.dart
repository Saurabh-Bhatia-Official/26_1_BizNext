// lib/features/billing/repositories/billing_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/sale_history_model.dart';

class BillingRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> completeSale(SaleHistoryModel sale) async {
    final result = await _db.transaction((txn) async {
      // ── VALIDATIONS ──

      // 1. Duplicate Invoice Number
      final duplicateInvoice = await txn.query(
        AppConstants.tblSales,
        columns: ['id'],
        where: 'invoice_no = ? AND business_id = ?',
        whereArgs: [sale.invoiceNo, sale.businessId],
      );
      if (duplicateInvoice.isNotEmpty) {
        throw Exception("Duplicate Invoice: Invoice number '${sale.invoiceNo}' has already been processed.");
      }

      // 2. Validate Customer if Credit
      if (sale.customerId != null) {
        final custCheck = await txn.query(
          AppConstants.tblCustomers,
          columns: ['id'],
          where: 'id = ? AND business_id = ?',
          whereArgs: [sale.customerId, sale.businessId],
        );
        if (custCheck.isEmpty) {
          throw Exception("Invalid Customer: Customer does not exist.");
        }
      }

      // 3. Stock Level Validation & Negative Quantity check
      // Fetch settings to check if negative stock is permitted
      final settingsResult = await txn.query(
        AppConstants.tblAppSettings,
        columns: ['value'],
        where: 'business_id = ? AND key = ?',
        whereArgs: [sale.businessId, 'allow_negative_stock'],
      );
      final allowNegativeStock = settingsResult.isNotEmpty && settingsResult.first['value'] == '1';

      // Get Default Warehouse
      final warehouseResult = await txn.query(
        AppConstants.tblWarehouses,
        columns: ['id'],
        where: 'business_id = ?',
        whereArgs: [sale.businessId],
        limit: 1,
      );
      final warehouseId = warehouseResult.isNotEmpty ? warehouseResult.first['id'] as int : 1;

      double totalCogs = 0.0;

      for (final item in sale.items) {
        if (item.quantity <= 0) {
          throw Exception("Negative Quantity Error: Product '${item.productName}' must have a positive quantity.");
        }
        if (item.price < 0) {
          throw Exception("Negative Price Error: Product '${item.productName}' must have a positive price.");
        }

        // Query product stock
        final productResult = await txn.query(
          AppConstants.tblProducts,
          columns: ['stock', 'purchase_price', 'name'],
          where: 'id = ? AND business_id = ?',
          whereArgs: [item.productId, sale.businessId],
        );
        if (productResult.isEmpty) {
          throw Exception("Product '${item.productName}' not found in database.");
        }

        final currentStock = (productResult.first['stock'] as num?)?.toDouble() ?? 0.0;
        final unitCost = (productResult.first['purchase_price'] as num?)?.toDouble() ?? 0.0;
        
        // Stock Check validation
        if (currentStock < item.quantity && !allowNegativeStock) {
          throw Exception("Insufficient Stock for '${productResult.first['name']}': Available = $currentStock, Requested = ${item.quantity}");
        }

        totalCogs += item.quantity * unitCost;
      }

      // ── EXECUTION ──

      // 1. Insert Sale Header
      final saleId = await txn.insert(AppConstants.tblSales, sale.toMap());

      // 2. Insert Sale Items, snapshot cost price, decrement stock, and log inventory transactions
      for (final item in sale.items) {
        final product = await txn.query(
          AppConstants.tblProducts,
          columns: ['purchase_price', 'stock'],
          where: 'id = ? AND business_id = ?',
          whereArgs: [item.productId, sale.businessId],
        );
        final costPrice = product.isNotEmpty ? (product.first['purchase_price'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final openingStock = product.isNotEmpty ? (product.first['stock'] as num?)?.toDouble() ?? 0.0 : 0.0;

        final itemMap = item.toMap(saleId);
        itemMap['purchase_price'] = costPrice; // Snapshot cost price to secure historical COGS

        await txn.insert(AppConstants.tblSaleItems, itemMap);

        // Decrement Product Master stock
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock - ?, updated_at = datetime('now') WHERE id = ? AND business_id = ?",
          [item.quantity, item.productId, sale.businessId],
        );

        // Decrement Warehouse Stock
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblWarehouseStocks} SET stock = stock - ? WHERE warehouse_id = ? AND product_id = ?",
          [item.quantity, warehouseId, item.productId],
        );

        // Log Stock Transaction
        await txn.insert(AppConstants.tblInventoryTransactions, {
          'product_id': item.productId,
          'warehouse_id': warehouseId,
          'transaction_type': 'SALE',
          'reference_number': sale.invoiceNo,
          'quantity': item.quantity,
          'unit_cost': costPrice,
          'opening_stock': openingStock,
          'closing_stock': openingStock - item.quantity,
          'remarks': 'POS sale invoiced: ${sale.invoiceNo}',
        });
      }

      // 3. Update customer outstanding balance if credit sale
      if (sale.customerId != null && sale.balanceDue > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblCustomers} SET balance = balance + ? WHERE id = ? AND business_id = ?",
          [sale.balanceDue, sale.customerId, sale.businessId],
        );
      }

      // 4. Double Entry Ledger Bookings
      final invRef = sale.invoiceNo;
      final dateStr = sale.date.toIso8601String();

      // Entry A: Debit Cash/Bank = Paid Amount
      if (sale.paidAmount > 0) {
        if (sale.accountId == null) {
          throw Exception("Invalid Account: A payment account is required when payment is collected.");
        }
        await txn.insert(AppConstants.tblLedger, {
          'business_id': sale.businessId,
          'entity_type': 'account',
          'entity_id': sale.accountId,
          'type': 'debit',
          'amount': sale.paidAmount,
          'reference_id': saleId,
          'account_id': sale.accountId,
          'description': 'Cash/Bank Debit (Sales Payment): $invRef',
          'date': dateStr,
        });

        // Increase Cash/Bank balance
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?",
          [sale.paidAmount, sale.accountId],
        );
      }

      // Entry B: Debit Customer Accounts Receivable = Balance Due
      if (sale.balanceDue > 0 && sale.customerId != null) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': sale.businessId,
          'entity_type': 'customer',
          'entity_id': sale.customerId,
          'type': 'debit',
          'amount': sale.balanceDue,
          'reference_id': saleId,
          'description': 'Accounts Receivable Debit (Sales Credit): $invRef',
          'date': dateStr,
        });
      }

      // Entry C: Credit Sales Revenue = Grand Total - GST Amount (Subtotal)
      await txn.insert(AppConstants.tblLedger, {
        'business_id': sale.businessId,
        'entity_type': 'revenue',
        'entity_id': 0,
        'type': 'credit',
        'amount': sale.subtotal,
        'reference_id': saleId,
        'description': 'Sales Revenue Credit: $invRef',
        'date': dateStr,
      });

      // Entry D: Credit Output GST = GST Amount
      if (sale.gstAmount > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': sale.businessId,
          'entity_type': 'gst',
          'entity_id': 0,
          'type': 'credit',
          'amount': sale.gstAmount,
          'reference_id': saleId,
          'description': 'Output GST Credit: $invRef',
          'date': dateStr,
        });
      }

      // Entry E: Debit Cost of Goods Sold (COGS)
      await txn.insert(AppConstants.tblLedger, {
        'business_id': sale.businessId,
        'entity_type': 'cogs',
        'entity_id': 0,
        'type': 'debit',
        'amount': totalCogs,
        'reference_id': saleId,
        'description': 'Cost of Goods Sold Debit: $invRef',
        'date': dateStr,
      });

      // Entry F: Credit Inventory Asset
      await txn.insert(AppConstants.tblLedger, {
        'business_id': sale.businessId,
        'entity_type': 'inventory',
        'entity_id': 0,
        'type': 'credit',
        'amount': totalCogs,
        'reference_id': saleId,
        'description': 'Inventory Value Credit (COGS Match): $invRef',
        'date': dateStr,
      });

      // 5. Update Customer Loyalty Points
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
    
    _db.notify(AppConstants.tblSales);
    _db.notify(AppConstants.tblSaleItems);
    _db.notify(AppConstants.tblProducts);
    _db.notify(AppConstants.tblWarehouseStocks);
    _db.notify(AppConstants.tblCustomers);
    _db.notify(AppConstants.tblAccounts);
    _db.notify(AppConstants.tblLedger);
    return result;
  }

  Future<int> recordSalesReturn(Map<String, dynamic> returnData, List<Map<String, dynamic>> items) async {
    final result = await _db.transaction((txn) async {
      // 1. Insert Sales Return Header
      final returnId = await txn.insert(AppConstants.tblSalesReturns, returnData);

      // Get Default Warehouse
      final warehouseResult = await txn.query(AppConstants.tblWarehouses, columns: ['id'], limit: 1);
      final warehouseId = warehouseResult.isNotEmpty ? warehouseResult.first['id'] as int : 1;

      double totalReturnedCost = 0.0;

      // 2. Loop items to restore stock and record items
      for (var item in items) {
        final productId = (item['product_id'] as num?)?.toInt() ?? 0;
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final gstPercent = (item['gst_percent'] as num?)?.toDouble() ?? 0.0;
        final gstAmount = qty * price * (gstPercent / 100);
        final total = (qty * price) + gstAmount;

        // Fetch cost price from product master
        final productResult = await txn.query(AppConstants.tblProducts, columns: ['stock', 'purchase_price'], where: 'id = ?', whereArgs: [productId]);
        final currentStock = productResult.isNotEmpty ? (productResult.first['stock'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final costPrice = productResult.isNotEmpty ? (productResult.first['purchase_price'] as num?)?.toDouble() ?? 0.0 : 0.0;

        totalReturnedCost += qty * costPrice;

        await txn.insert(AppConstants.tblSalesReturnItems, {
          'return_id': returnId,
          'product_id': productId,
          'product_name': item['product_name'] ?? 'Product',
          'quantity': qty,
          'price': price,
          'gst_percent': gstPercent,
          'gst_amount': gstAmount,
          'total': total,
        });

        // Restore stock in Product Master
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock + ?, updated_at = datetime('now') WHERE id = ?",
          [qty, productId],
        );

        // Restore warehouse stock
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblWarehouseStocks} SET stock = stock + ? WHERE warehouse_id = ? AND product_id = ?",
          [qty, warehouseId, productId],
        );

        // Log stock movement
        await txn.insert(AppConstants.tblInventoryTransactions, {
          'product_id': productId,
          'warehouse_id': warehouseId,
          'transaction_type': 'SALES_RETURN',
          'reference_number': returnData['return_no'] ?? '#SR-$returnId',
          'quantity': qty,
          'unit_cost': costPrice,
          'opening_stock': currentStock,
          'closing_stock': currentStock + qty,
          'remarks': 'Sales return accepted',
        });
      }

      // 3. Update customer outstanding balance or issue refund
      final customerId = returnData['customer_id'] as int?;
      final grandTotal = (returnData['grand_total'] as num?)?.toDouble() ?? 0.0;
      final refundAmount = (returnData['refund_amount'] as num?)?.toDouble() ?? 0.0;
      final balanceDueReduction = grandTotal - refundAmount;

      if (customerId != null && balanceDueReduction > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblCustomers} SET balance = balance - ? WHERE id = ?",
          [balanceDueReduction, customerId],
        );
      }

      // 4. Double Entry Reversals
      final businessId = (returnData['business_id'] as num?)?.toInt() ?? 1;
      final returnNo = returnData['return_no'] ?? '#SR-$returnId';
      final dateStr = returnData['date'] ?? DateTime.now().toIso8601String();

      // Sales Revenue Reversal (Debit)
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': 'revenue',
        'entity_id': 0,
        'type': 'debit',
        'amount': (returnData['subtotal'] as num?)?.toDouble() ?? 0.0,
        'reference_id': returnId,
        'description': 'Sales Revenue Debit Reversal (Sales Return): $returnNo',
        'date': dateStr,
      });

      // Output GST Reversal (Debit)
      final gstAmount = (returnData['gst_amount'] as num?)?.toDouble() ?? 0.0;
      if (gstAmount > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': businessId,
          'entity_type': 'gst',
          'entity_id': 0,
          'type': 'debit',
          'amount': gstAmount,
          'reference_id': returnId,
          'description': 'Output GST Debit Reversal (Sales Return): $returnNo',
          'date': dateStr,
        });
      }

      // Customer Accounts Receivable / Cash refund Credit
      if (refundAmount > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': businessId,
          'entity_type': 'account',
          'entity_id': returnData['account_id'] ?? 0,
          'type': 'credit',
          'amount': refundAmount,
          'reference_id': returnId,
          'account_id': returnData['account_id'],
          'description': 'Cash Refund Credit (Sales Return): $returnNo',
          'date': dateStr,
        });

        // Deduct Cash/Bank balance
        if (returnData['account_id'] != null) {
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblAccounts} SET balance = balance - ? WHERE id = ?",
            [refundAmount, returnData['account_id']],
          );
        }
      }

      if (balanceDueReduction > 0 && customerId != null) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': businessId,
          'entity_type': 'customer',
          'entity_id': customerId,
          'type': 'credit',
          'amount': balanceDueReduction,
          'reference_id': returnId,
          'description': 'Accounts Receivable Credit Reversal (Sales Return): $returnNo',
          'date': dateStr,
        });
      }

      // COGS Reversal (Credit COGS, Debit Inventory Asset)
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': 'cogs',
        'entity_id': 0,
        'type': 'credit',
        'amount': totalReturnedCost,
        'reference_id': returnId,
        'description': 'Cost of Goods Sold Credit Reversal (Sales Return): $returnNo',
        'date': dateStr,
      });

      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': 'inventory',
        'entity_id': 0,
        'type': 'debit',
        'amount': totalReturnedCost,
        'reference_id': returnId,
        'description': 'Inventory Debit (Sales Return Reversal): $returnNo',
        'date': dateStr,
      });

      // 5. Revert Customer Loyalty Points (Heuristic: deduct based on return subtotal)
      if (customerId != null) {
        final loyaltySettings = await txn.query(AppConstants.tblLoyaltySettings, where: 'business_id = ?', whereArgs: [businessId]);
        if (loyaltySettings.isNotEmpty) {
          final earnRate = (loyaltySettings.first['earn_rate'] as num?)?.toDouble() ?? 1.0;
          final earnSpend = (loyaltySettings.first['earn_spend_amount'] as num?)?.toDouble() ?? 100.0;
          final subtotal = (returnData['subtotal'] as num?)?.toDouble() ?? 0.0;
          final pointsToDeduct = earnSpend > 0 ? (subtotal / earnSpend) * earnRate : 0.0;
          if (pointsToDeduct > 0) {
            await txn.rawUpdate(
              "UPDATE ${AppConstants.tblCustomers} SET loyalty_points = MAX(0, loyalty_points - ?) WHERE id = ?",
              [pointsToDeduct, customerId],
            );
          }
        }
      }

      return returnId;
    });

    _db.notify(AppConstants.tblSalesReturns);
    _db.notify(AppConstants.tblSalesReturnItems);
    _db.notify(AppConstants.tblProducts);
    _db.notify(AppConstants.tblWarehouseStocks);
    _db.notify(AppConstants.tblCustomers);
    _db.notify(AppConstants.tblAccounts);
    _db.notify(AppConstants.tblLedger);
    return result;
  }

  Future<void> voidSale(int saleId) async {
    // Audit protection void/cancellation
    await _db.transaction((txn) async {
      final saleResult = await txn.query(AppConstants.tblSales, where: 'id = ?', whereArgs: [saleId]);
      if (saleResult.isEmpty) return;
      final saleMap = saleResult.first;
      final customerId = saleMap['customer_id'] as int?;
      final businessId = (saleMap['business_id'] as num?)?.toInt() ?? 1;
      final invoiceNo = saleMap['invoice_no'] as String? ?? '#$saleId';

      final items = await txn.query(AppConstants.tblSaleItems, where: 'sale_id = ?', whereArgs: [saleId]);

      // Get Default Warehouse
      final warehouseResult = await txn.query(AppConstants.tblWarehouses, columns: ['id'], limit: 1);
      final warehouseId = warehouseResult.isNotEmpty ? (warehouseResult.first['id'] as num?)?.toInt() ?? 1 : 1;

      double totalCost = 0.0;

      // 1. Revert Stock & Log transaction
      for (final item in items) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final productId = (item['product_id'] as num?)?.toInt() ?? 0;
        final cost = (item['purchase_price'] as num?)?.toDouble() ?? 0.0;
        totalCost += qty * cost;

        // Fetch opening stock
        final product = await txn.query(AppConstants.tblProducts, columns: ['stock'], where: 'id = ?', whereArgs: [productId]);
        final openingStock = product.isNotEmpty ? (product.first['stock'] as num?)?.toDouble() ?? 0.0 : 0.0;

        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblProducts} SET stock = stock + ? WHERE id = ?",
          [qty, productId],
        );

        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblWarehouseStocks} SET stock = stock + ? WHERE warehouse_id = ? AND product_id = ?",
          [qty, warehouseId, productId],
        );

        await txn.insert(AppConstants.tblInventoryTransactions, {
          'product_id': productId,
          'warehouse_id': warehouseId,
          'transaction_type': 'SALES_RETURN',
          'reference_number': '$invoiceNo-VOID',
          'quantity': qty,
          'unit_cost': cost,
          'opening_stock': openingStock,
          'closing_stock': openingStock + qty,
          'remarks': 'Sale voided/cancelled: $invoiceNo',
        });
      }

      // 2. Revert Customer Balance
      final balanceDue = (saleMap['balance_due'] as num?)?.toDouble() ?? 0.0;
      if (customerId != null && balanceDue > 0) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblCustomers} SET balance = balance - ? WHERE id = ?",
          [balanceDue, customerId],
        );
      }

      // 3. Reverse Account Balance
      final oldAccId = saleMap['account_id'] as int?;
      final oldPaid = (saleMap['paid_amount'] as num?)?.toDouble() ?? 0.0;
      if (oldAccId != null && oldPaid > 0) {
        await txn.rawUpdate("UPDATE ${AppConstants.tblAccounts} SET balance = balance - ? WHERE id = ?", [oldPaid, oldAccId]);
      }

      // 4. Reverse Ledger entries
      // Post explicit reversals in ledger instead of deleting to keep audit trails
      final dateStr = DateTime.now().toIso8601String();

      // Reverse cash/bank debit (credit)
      if (oldPaid > 0 && oldAccId != null) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': businessId,
          'entity_type': 'account',
          'entity_id': oldAccId,
          'type': 'credit',
          'amount': oldPaid,
          'reference_id': saleId,
          'account_id': oldAccId,
          'description': 'Void Cash/Bank Collection Reversal: $invoiceNo',
          'date': dateStr,
        });
      }

      // Reverse customer receivable debit (credit)
      if (balanceDue > 0 && customerId != null) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': businessId,
          'entity_type': 'customer',
          'entity_id': customerId,
          'type': 'credit',
          'amount': balanceDue,
          'reference_id': saleId,
          'description': 'Void Accounts Receivable Reversal: $invoiceNo',
          'date': dateStr,
        });
      }

      // Reverse Revenue credit (debit)
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': 'revenue',
        'entity_id': 0,
        'type': 'debit',
        'amount': (saleMap['subtotal'] as num?)?.toDouble() ?? 0.0,
        'reference_id': saleId,
        'description': 'Void Sales Revenue Reversal: $invoiceNo',
        'date': dateStr,
      });

      // Reverse Output GST credit (debit)
      final oldGst = (saleMap['gst_amount'] as num?)?.toDouble() ?? 0.0;
      if (oldGst > 0) {
        await txn.insert(AppConstants.tblLedger, {
          'business_id': businessId,
          'entity_type': 'gst',
          'entity_id': 0,
          'type': 'debit',
          'amount': oldGst,
          'reference_id': saleId,
          'description': 'Void Output GST Reversal: $invoiceNo',
          'date': dateStr,
        });
      }

      // Reverse COGS debit (credit) and Inventory asset credit (debit)
      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': 'cogs',
        'entity_id': 0,
        'type': 'credit',
        'amount': totalCost,
        'reference_id': saleId,
        'description': 'Void Cost of Goods Sold Reversal: $invoiceNo',
        'date': dateStr,
      });

      await txn.insert(AppConstants.tblLedger, {
        'business_id': businessId,
        'entity_type': 'inventory',
        'entity_id': 0,
        'type': 'debit',
        'amount': totalCost,
        'reference_id': saleId,
        'description': 'Void Inventory Asset Reversal: $invoiceNo',
        'date': dateStr,
      });

      // 5. Update Sale status to cancelled
      await txn.rawUpdate("UPDATE ${AppConstants.tblSales} SET status = 'cancelled', paid_amount = 0, balance_due = 0 WHERE id = ?", [saleId]);

      // 6. Revert Loyalty Points
      if (customerId != null) {
        final ptsEarned = (saleMap['points_earned'] as num?)?.toDouble() ?? 0;
        final ptsRedeemed = (saleMap['points_redeemed'] as num?)?.toDouble() ?? 0;
        final balanceToRevert = ptsEarned - ptsRedeemed;
        if (balanceToRevert != 0) {
          await txn.rawUpdate(
            "UPDATE ${AppConstants.tblCustomers} SET loyalty_points = MAX(0, loyalty_points - ?) WHERE id = ?",
            [balanceToRevert, customerId],
          );
        }
      }
    });

    _db.notify(AppConstants.tblSales);
    _db.notify(AppConstants.tblSaleItems);
    _db.notify(AppConstants.tblProducts);
    _db.notify(AppConstants.tblWarehouseStocks);
    _db.notify(AppConstants.tblCustomers);
    _db.notify(AppConstants.tblAccounts);
    _db.notify(AppConstants.tblLedger);
  }

  Future<void> updateSale(SaleHistoryModel sale) async {
    // Production ERP standard: updating historical bills should trigger void + recreate
    // For safety, we will void the current sale first, then complete the new one.
    if (sale.id != null) {
      await voidSale(sale.id!);
      await completeSale(sale);
    }
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
      final saleResult = await txn.query(AppConstants.tblSales, where: 'id = ?', whereArgs: [saleId]);
      if (saleResult.isEmpty) return;
      final s = saleResult.first;
      final customerId = s['customer_id'] as int?;
      final businessId = s['business_id'] as int;
      final invoiceNo = s['invoice_no'] as String?;

      // Update Sale
      await txn.rawUpdate(
        "UPDATE ${AppConstants.tblSales} SET paid_amount = paid_amount + ?, balance_due = balance_due - ? WHERE id = ?",
        [amount, amount, saleId],
      );

      // Update Customer Balance
      if (customerId != null) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblCustomers} SET balance = balance - ? WHERE id = ?",
          [amount, customerId],
        );
      }

      // Record in Ledger
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

      // Sync Account Balance
      if (accountId != null) {
        await txn.rawUpdate(
          "UPDATE ${AppConstants.tblAccounts} SET balance = balance + ? WHERE id = ?",
          [amount, accountId],
        );
      }
    });

    _db.notify(AppConstants.tblSales);
    _db.notify(AppConstants.tblCustomers);
    _db.notify(AppConstants.tblLedger);
    _db.notify(AppConstants.tblAccounts);
  }

  Future<void> settleCreditInvoice(int saleId, double amount, {String mode = 'Cash', int? accountId}) async {
    await addSalePayment(saleId, amount, mode, accountId: accountId);
    
    await _db.rawUpdate(
      "UPDATE ${AppConstants.tblSales} SET status = ? WHERE id = ?",
      ['Payment Completed', saleId],
    );
    _db.notify(AppConstants.tblSales);
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
