// lib/core/security/token_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Cryptographically signed authentication session token.
class AuthSessionToken {
  final int userId;
  final int businessId;
  final String username;
  final String role;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String nonce;
  final String rawToken;

  const AuthSessionToken({
    required this.userId,
    required this.businessId,
    required this.username,
    required this.role,
    required this.issuedAt,
    required this.expiresAt,
    required this.nonce,
    required this.rawToken,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired && rawToken.isNotEmpty;

  Map<String, dynamic> toPayloadMap() {
    return {
      'uid': userId,
      'bid': businessId,
      'sub': username,
      'role': role,
      'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      'nonce': nonce,
    };
  }

  static AuthSessionToken? parse(String tokenString, {String? secretKey}) {
    try {
      if (!tokenString.startsWith('bztkn_v1_')) return null;
      final parts = tokenString.substring('bztkn_v1_'.length).split('.');
      if (parts.length != 2) return null;

      final payloadPart = parts[0];
      final signaturePart = parts[1];

      final key = secretKey ?? TokenService.defaultSecretKey;
      final expectedSignature = _generateSignature(payloadPart, key);
      if (expectedSignature != signaturePart) return null;

      final decodedJson = utf8.decode(base64Url.decode(base64Url.normalize(payloadPart)));
      final map = jsonDecode(decodedJson) as Map<String, dynamic>;

      final iat = DateTime.fromMillisecondsSinceEpoch((map['iat'] as int) * 1000);
      final exp = DateTime.fromMillisecondsSinceEpoch((map['exp'] as int) * 1000);

      return AuthSessionToken(
        userId: (map['uid'] as num).toInt(),
        businessId: (map['bid'] as num).toInt(),
        username: map['sub'] as String? ?? 'user',
        role: map['role'] as String? ?? AppConstants.roleAdmin,
        issuedAt: iat,
        expiresAt: exp,
        nonce: map['nonce'] as String? ?? '',
        rawToken: tokenString,
      );
    } catch (_) {
      return null;
    }
  }

  static String _generateSignature(String data, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }
}

/// Tokenization service managing user authentication session tokens.
class TokenService {
  TokenService._();
  static final TokenService instance = TokenService._();

  static const String defaultSecretKey = "biznext_enterprise_hmac_secret_2026_secure_key";

  /// Generates a cryptographically signed session token for authenticated user.
  String generateSessionToken({
    required int userId,
    required int businessId,
    required String username,
    String role = AppConstants.roleOwner,
    Duration duration = const Duration(days: 30),
    String secretKey = defaultSecretKey,
  }) {
    final now = DateTime.now();
    final expiresAt = now.add(duration);
    final randomBytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final nonce = base64UrlEncode(randomBytes);

    final payloadMap = {
      'uid': userId,
      'bid': businessId,
      'sub': username,
      'role': role,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      'nonce': nonce,
    };

    final payloadJson = jsonEncode(payloadMap);
    final payloadBase64 = base64Url.encode(utf8.encode(payloadJson)).replaceAll('=', '');
    final signature = AuthSessionToken._generateSignature(payloadBase64, secretKey);

    return 'bztkn_v1_$payloadBase64.$signature';
  }

  /// Generates and persists the session token in SharedPreferences.
  Future<String> generateAndSaveSessionToken({
    required int userId,
    required int businessId,
    required String username,
    String role = AppConstants.roleOwner,
    Duration duration = const Duration(days: 30),
  }) async {
    final token = generateSessionToken(
      userId: userId,
      businessId: businessId,
      username: username,
      role: role,
      duration: duration,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefAuthToken, token);
    return token;
  }

  /// Retrieves the active, valid session token.
  Future<String?> getActiveToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.prefAuthToken);
    if (token == null) {
      // Fallback: If userId exists in prefs, generate a fresh active token
      final userId = prefs.getInt(AppConstants.prefUserId);
      final businessId = prefs.getInt(AppConstants.prefBusinessId) ?? 1;
      if (userId != null) {
        return generateAndSaveSessionToken(
          userId: userId,
          businessId: businessId,
          username: 'user',
        );
      }
      return null;
    }

    final parsed = AuthSessionToken.parse(token);
    if (parsed == null || parsed.isExpired) {
      final userId = prefs.getInt(AppConstants.prefUserId);
      final businessId = prefs.getInt(AppConstants.prefBusinessId) ?? 1;
      if (userId != null) {
        return generateAndSaveSessionToken(
          userId: userId,
          businessId: businessId,
          username: parsed?.username ?? 'user',
          role: parsed?.role ?? AppConstants.roleOwner,
        );
      }
      await clearSession();
      return null;
    }
    return token;
  }

  /// Gets the parsed active session token if present and valid.
  Future<AuthSessionToken?> getActiveSession() async {
    final token = await getActiveToken();
    if (token == null) return null;
    return AuthSessionToken.parse(token);
  }

  /// Validates any token string.
  bool verifyToken(String token) {
    final parsed = AuthSessionToken.parse(token);
    return parsed != null && !parsed.isExpired;
  }

  /// Clears the persisted session token.
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefAuthToken);
  }
}

/// Tokenization manager for financial accounts, masking, and opaque reference generation.
class AccountTokenManager {
  AccountTokenManager._();

  /// Deterministically or cryptographically tokenizes an account identifier or account number.
  /// Resulting token: `TKN-ACC-XXXX-XXXX`
  static String tokenizeAccount(String accountNumber, {int? businessId}) {
    final clean = accountNumber.trim();
    if (clean.isEmpty) return '';
    final hmac = Hmac(sha256, utf8.encode('account_token_salt_${businessId ?? 1}'));
    final digest = hmac.convert(utf8.encode(clean)).toString().toUpperCase();
    final p1 = digest.substring(0, 4);
    final p2 = digest.substring(4, 8);
    final p3 = digest.substring(8, 12);
    return 'TKN-ACC-$p1-$p2-$p3';
  }

  /// Masks sensitive account numbers for safe display.
  /// Example: `123456789012` -> `•••• •••• 9012`
  static String maskAccountNumber(String? accountNumber) {
    if (accountNumber == null) return '';
    final trimmed = accountNumber.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 4) return '•••• $trimmed';

    final last4 = trimmed.substring(trimmed.length - 4);
    final maskedLength = trimmed.length - 4;
    final groupsOf4 = (maskedLength / 4).ceil();
    final bullets = List.generate(groupsOf4, (_) => '••••').join(' ');
    return '$bullets $last4';
  }

  /// Checks if a string is a valid tokenized account reference.
  static bool isAccountToken(String? value) {
    if (value == null) return false;
    return RegExp(r'^TKN-ACC-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}$').hasMatch(value);
  }
}

/// AES-256 CBC Encryption Service for Account Credentials & Numbers.
class AccountEncryptionService {
  AccountEncryptionService._();

  static final _key = enc.Key.fromUtf8('BizNextAcc256BitKeySecured2026!!'); // 32 bytes key
  static final _iv = enc.IV.fromUtf8('BizNextAccIV12345'); // 16 bytes IV

  /// Encrypts account string with AES-256 CBC
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    if (plainText.startsWith('enc_v1:')) return plainText;
    try {
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: _iv);
      return 'enc_v1:${encrypted.base64}';
    } catch (_) {
      return plainText;
    }
  }

  /// Decrypts encrypted account string
  static String decrypt(String cipherText) {
    if (!cipherText.startsWith('enc_v1:')) return cipherText;
    try {
      final raw = cipherText.substring('enc_v1:'.length);
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(enc.Encrypted.fromBase64(raw), iv: _iv);
    } catch (_) {
      return cipherText;
    }
  }
}
