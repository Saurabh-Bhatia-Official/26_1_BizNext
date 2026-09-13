import 'package:flutter_test/flutter_test.dart';
import 'package:biz_next/core/security/token_service.dart';
import 'package:biz_next/features/accounts/models/account_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TokenService - Cryptographic Session Tokenization', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('generateSessionToken produces valid verifiable token with correct claims', () {
      final token = TokenService.instance.generateSessionToken(
        userId: 42,
        businessId: 5,
        username: 'executive_user',
        role: 'owner',
        duration: const Duration(hours: 1),
      );

      expect(token, startsWith('bztkn_v1_'));
      expect(TokenService.instance.verifyToken(token), isTrue);

      final parsed = AuthSessionToken.parse(token);
      expect(parsed, isNotNull);
      expect(parsed!.userId, 42);
      expect(parsed.businessId, 5);
      expect(parsed.username, 'executive_user');
      expect(parsed.role, 'owner');
      expect(parsed.isExpired, isFalse);
      expect(parsed.isValid, isTrue);
    });

    test('Tampered token signature is rejected by parser', () {
      final token = TokenService.instance.generateSessionToken(
        userId: 1,
        businessId: 1,
        username: 'admin',
      );

      // Tamper with signature
      final tampered = '${token}extra_bytes';
      expect(TokenService.instance.verifyToken(tampered), isFalse);
      expect(AuthSessionToken.parse(tampered), isNull);

      // Tamper with payload
      final parts = token.split('.');
      final tamperedPayload = '${parts[0]}X.${parts[1]}';
      expect(AuthSessionToken.parse(tamperedPayload), isNull);
    });

    test('Expired token is marked as expired', () {
      final expiredToken = TokenService.instance.generateSessionToken(
        userId: 1,
        businessId: 1,
        username: 'admin',
        duration: const Duration(seconds: -10), // expired 10 seconds ago
      );

      final parsed = AuthSessionToken.parse(expiredToken);
      expect(parsed, isNotNull);
      expect(parsed!.isExpired, isTrue);
      expect(parsed.isValid, isFalse);
      expect(TokenService.instance.verifyToken(expiredToken), isFalse);
    });

    test('generateAndSaveSessionToken persists and retrieves from SharedPreferences', () async {
      final savedToken = await TokenService.instance.generateAndSaveSessionToken(
        userId: 7,
        businessId: 3,
        username: 'store_manager',
      );

      final active = await TokenService.instance.getActiveToken();
      expect(active, equals(savedToken));

      final session = await TokenService.instance.getActiveSession();
      expect(session, isNotNull);
      expect(session!.userId, 7);
      expect(session.businessId, 3);
      expect(session.username, 'store_manager');

      await TokenService.instance.clearSession();
      // If cleared, falls back to re-generating for persisted user if user_id exists, or null
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_auth_token'), isNull);
    });
  });

  group('AccountTokenManager - Financial Account Data Tokenization & Masking', () {
    test('maskAccountNumber masks leading digits and preserves last 4', () {
      expect(AccountTokenManager.maskAccountNumber('123456789012'), '•••• •••• 9012');
      expect(AccountTokenManager.maskAccountNumber('50100234567890'), '•••• •••• •••• 7890');
      expect(AccountTokenManager.maskAccountNumber('1234'), '•••• 1234');
      expect(AccountTokenManager.maskAccountNumber(''), '');
      expect(AccountTokenManager.maskAccountNumber(null), '');
    });

    test('tokenizeAccount generates consistent opaque token format', () {
      final token1 = AccountTokenManager.tokenizeAccount('50100234567890', businessId: 1);
      final token2 = AccountTokenManager.tokenizeAccount('50100234567890', businessId: 1);
      expect(token1, equals(token2));
      expect(token1, startsWith('TKN-ACC-'));
      expect(AccountTokenManager.isAccountToken(token1), isTrue);

      final differentAccount = AccountTokenManager.tokenizeAccount('987654321000', businessId: 1);
      expect(differentAccount, isNot(equals(token1)));
      expect(AccountTokenManager.isAccountToken(differentAccount), isTrue);
    });

    test('AccountModel integrates tokenization and masking cleanly', () {
      final account = AccountModel(
        id: 10,
        businessId: 1,
        name: 'HDFC Corporate Bank',
        type: 'Bank',
        openingBalance: 50000.0,
        balance: 75000.0,
        accountNumber: '50100889977665',
      );

      expect(account.maskedAccountNumber, '•••• •••• •••• 7665');
      expect(account.displayToken, startsWith('TKN-ACC-'));
      expect(AccountTokenManager.isAccountToken(account.displayToken), isTrue);

      final map = account.toMap();
      expect(map['account_number'], '50100889977665');
      expect(map['account_token'], startsWith('TKN-ACC-'));

      final restored = AccountModel.fromMap(map);
      expect(restored.accountNumber, '50100889977665');
      expect(restored.accountToken, equals(account.displayToken));
      expect(restored.maskedAccountNumber, '•••• •••• •••• 7665');
    });
  });
}
