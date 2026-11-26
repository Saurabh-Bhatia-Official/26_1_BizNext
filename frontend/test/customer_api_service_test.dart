import 'package:biz_next/features/customers/models/customer_model.dart';
import 'package:biz_next/features/customers/services/customer_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer form validation before API requests', () {
    test('rejects an empty customer name', () async {
      await expectLater(
        CustomerApiService.validateCustomer(
          CustomerModel(businessId: 1, name: '', phone: '9876543210'),
          businessId: 1,
        ),
        throwsA(isA<CustomerApiException>()),
      );
    });

    test('rejects a phone number with an invalid digit count', () async {
      await expectLater(
        CustomerApiService.validateCustomer(
          CustomerModel(businessId: 1, name: 'Alice Johnson', phone: '12345'),
          businessId: 1,
        ),
        throwsA(isA<CustomerApiException>()),
      );
    });

    test('accepts valid required customer fields without reading SQLite', () async {
      await expectLater(
        CustomerApiService.validateCustomer(
          CustomerModel(businessId: 1, name: 'Alice Johnson', phone: '+1 (555) 123-4567'),
          businessId: 1,
        ),
        completes,
      );
    });
  });
}
