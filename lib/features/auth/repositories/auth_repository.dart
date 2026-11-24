import '../../../core/services/backend_api_service.dart';
import '../../../core/security/token_service.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';

class AuthRepository {
  Future<UserModel?> login(String username, String password) async {
    final response = await BackendApiService.post('auth/login', {
      'username': username,
      'password': password,
    });
    final decoded = BackendApiService.decode(response);
    if (decoded is! Map<String, dynamic>) return null;
    await TokenService.instance.generateAndSaveSessionToken(
      userId: (decoded['userId'] as num).toInt(),
      businessId: (decoded['businessId'] as num?)?.toInt() ?? 1,
      username: decoded['username'] as String? ?? username,
      role: decoded['role'] as String? ?? 'owner',
    );
    return UserModel(
      id: (decoded['userId'] as num).toInt(),
      username: decoded['username'] as String? ?? username,
      passwordHash: '',
      fullName: decoded['fullName'] as String? ?? username,
      role: decoded['role'] as String? ?? 'owner',
    );
  }

  Future<UserModel?> getUserById(int id) async {
    final response = await BackendApiService.get('users/$id');
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic> ? _userFromJson(decoded) : null;
  }

  Future<List<BusinessModel>> getBusinessesForUser(int userId) async {
    final response = await BackendApiService.get(
      'businesses',
      {'userId': '$userId'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded
        .map((item) => _businessFromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BusinessModel?> getBusinessById(int id) async {
    final response = await BackendApiService.get('businesses/$id');
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? _businessFromJson(decoded)
        : null;
  }

  Future<BusinessModel> createBusiness({
    required BusinessModel business,
    required int userId,
    String role = 'owner',
  }) async {
    final response = await BackendApiService.post('businesses', {
      'name': business.name,
      'type': business.type,
      'address': business.address,
      'phone': business.phone,
      'email': business.email,
      'gstNumber': business.gstNumber,
      'currency': business.currency,
      'currencySymbol': business.currencySymbol,
      'ownerId': userId,
    });
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? _businessFromJson(decoded)
        : business;
  }

  Future<BusinessModel> updateBusiness(BusinessModel business) async {
    final response = await BackendApiService.put('businesses/${business.id}', {
      'name': business.name,
      'type': business.type,
      'address': business.address,
      'phone': business.phone,
      'email': business.email,
      'gstNumber': business.gstNumber,
      'currency': business.currency,
      'currencySymbol': business.currencySymbol,
    });
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? _businessFromJson(decoded)
        : business;
  }

  Future<void> deleteBusiness(int id) async {
    await BackendApiService.delete('businesses/$id');
  }

  Future<UserModel> createUser({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
    String role = 'admin',
    required int businessId,
  }) async {
    final response = await BackendApiService.post('auth/register', {
      'username': username,
      'password': password,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'businessId': businessId,
    });
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? _userFromJson(decoded)
        : UserModel(
            username: username,
            passwordHash: '',
            fullName: fullName,
            email: email,
            phone: phone,
            role: role,
          );
  }

  Future<bool> isUsernameTaken(String username) async {
    final response = await BackendApiService.get(
      'auth/usernames',
      {'username': username},
    );
    final decoded = BackendApiService.decode(response);
    return decoded is Map && decoded['taken'] == true;
  }

  Future<UserModel> registerUser({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
  }) async {
    return createUser(
      username: username,
      password: password,
      fullName: fullName,
      email: email,
      phone: phone,
      businessId: 1,
    );
  }

  Future<List<UserModel>> getAllUsers() async {
    final response = await BackendApiService.get('users');
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded
        .map((item) => _userFromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserModel>> getUsersForBusiness(int businessId) async {
    final response = await BackendApiService.get(
      'users',
      {'businessId': '$businessId'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! List) return const [];
    return decoded
        .map((item) => _userFromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> changePassword(int userId, String newPassword) async {
    await BackendApiService.put('users/$userId/password', {
      'password': newPassword,
    });
  }

  Future<UserModel> updateUser(UserModel user) async {
    final response = await BackendApiService.put('users/${user.id}', {
      'fullName': user.fullName,
      'email': user.email,
      'phone': user.phone,
      'role': user.role,
      'active': user.isActive,
    });
    final decoded = BackendApiService.decode(response);
    return decoded is Map<String, dynamic>
        ? _userFromJson(decoded)
        : user;
  }

  static BusinessModel _businessFromJson(Map<String, dynamic> json) =>
      BusinessModel(
        id: (json['id'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'Retail Shop',
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        gstNumber: (json['gstNumber'] ?? json['gst_number']) as String?,
        currency: json['currency'] as String? ?? 'INR',
        currencySymbol:
            (json['currencySymbol'] ?? json['currency_symbol']) as String? ??
                '₹',
        ownerId: ((json['ownerId'] ?? json['owner_id']) as num?)?.toInt(),
        isActive: json['isActive'] != false && json['is_active'] != false,
        userRole:
            (json['userRole'] ?? json['user_role']) as String?,
      );

  static UserModel _userFromJson(Map<String, dynamic> json) => UserModel(
        id: (json['id'] as num?)?.toInt(),
        username: (json['username'] as String?) ?? '',
        passwordHash: '',
        fullName:
            (json['fullName'] ?? json['full_name']) as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'owner',
        isActive: json['isActive'] != false && json['is_active'] != false,
      );
}
