// lib/features/loyalty/repositories/loyalty_repository.dart

import '../../../core/services/backend_api_service.dart';

class LoyaltyRepository {
  Future<void> adjustPoints(
    int customerId,
    double adjustment,
    String reason, {
    int businessId = 1,
  }) async {
    final response = await BackendApiService.post('loyalty/adjust', {
      'businessId': businessId,
      'customerId': customerId,
      'adjustment': adjustment,
      'reason': reason,
      'createdBy': 'system',
    });
    BackendApiService.decode(response);
  }

  Future<void> resetPoints(int customerId, {int businessId = 1}) async {
    final response = await BackendApiService.post('loyalty/reset', {
      'businessId': businessId,
      'customerId': customerId,
    });
    BackendApiService.decode(response);
  }
}
