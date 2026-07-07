// lib/features/loyalty/repositories/loyalty_repository.dart

import '../../../core/database/database_helper.dart';
import '../../../core/constants/app_constants.dart';

class LoyaltyRepository {
  final _db = DatabaseHelper.instance;

  Future<void> adjustPoints(int customerId, double adjustment, String reason) async {
    await _db.transaction((txn) async {
      // 1. Get current points
      final customer = await txn.query(AppConstants.tblCustomers, where: 'id = ?', whereArgs: [customerId]);
      if (customer.isEmpty) return;
      
      final currentPoints = (customer.first['loyalty_points'] as num).toDouble();
      final newPoints = currentPoints + adjustment;

      // 2. Update customer
      await txn.update(
        AppConstants.tblCustomers, 
        {'loyalty_points': newPoints}, 
        where: 'id = ?', 
        whereArgs: [customerId]
      );

      // 3. Log the change (optional but good practice)
      // For now we don't have a points_log table, but it's recommended
    });
  }

  Future<void> resetPoints(int customerId) async {
    await _db.update(
      AppConstants.tblCustomers, 
      {'loyalty_points': 0}, 
      customerId
    );
  }
}
