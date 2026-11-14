// lib/features/auth/repositories/auth_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';

class AuthRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Returns user if credentials match, null otherwise.
  Future<UserModel?> login(String username, String password) async {
    final rows = await _db.queryAll(
      AppConstants.tblUsers,
      where: 'username = ? AND is_active = 1',
      whereArgs: [username.trim().toLowerCase()],
    );

    if (rows.isEmpty) return null;

    final user = UserModel.fromMap(rows.first);
    if (!DatabaseHelper.verifyPassword(password, user.passwordHash)) return null;

    return user;
  }

  Future<UserModel?> getUserById(int id) async {
    final row = await _db.queryById(AppConstants.tblUsers, id);
    return row != null ? UserModel.fromMap(row) : null;
  }

  // ── Business ───────────────────────────────────────────────────────────────

  /// All businesses accessible by a user, with their role in each.
  Future<List<BusinessModel>> getBusinessesForUser(int userId) async {
    final rows = await _db.rawQuery('''
      SELECT b.*, ub.role AS user_role
      FROM ${AppConstants.tblBusinesses} b
      INNER JOIN ${AppConstants.tblUserBusinesses} ub
        ON b.id = ub.business_id
      WHERE ub.user_id = ? AND b.is_active = 1
      ORDER BY b.name ASC
    ''', [userId]);

    return rows.map(BusinessModel.fromMap).toList();
  }

  Future<BusinessModel?> getBusinessById(int id) async {
    final row = await _db.queryById(AppConstants.tblBusinesses, id);
    return row != null ? BusinessModel.fromMap(row) : null;
  }

  /// Creates a new business and links it to the user.
  Future<BusinessModel> createBusiness({
    required BusinessModel business,
    required int userId,
    String role = AppConstants.roleOwner,
  }) async {
    final data = business.toMap();
    data['owner_id'] = userId;

    final bizId = await _db.insert(AppConstants.tblBusinesses, data);

    // Link user ↔ business
    await _db.insert(AppConstants.tblUserBusinesses, {
      'user_id': userId,
      'business_id': bizId,
      'role': role,
    });

    // Seed all default data for new business (Categories, Accounts, Settings)
    await _db.seedBusinessDefaults(bizId);

    return business.copyWith(id: bizId, ownerId: userId);
  }

  Future<BusinessModel> updateBusiness(BusinessModel business) async {
    await _db.update(AppConstants.tblBusinesses, business.toMap(), business.id!);
    return business;
  }

  Future<void> deleteBusiness(int id) async {
    // Soft delete: set is_active = 0
    await _db.update(AppConstants.tblBusinesses, {'is_active': 0}, id);
  }

  // ── User Management ────────────────────────────────────────────────────────

  Future<UserModel> createUser({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
    String role = AppConstants.roleAdmin,
    required int businessId,
  }) async {
    final user = UserModel(
      username: username.trim().toLowerCase(),
      passwordHash: DatabaseHelper.hashPassword(password),
      fullName: fullName.trim(),
      email: email?.trim(),
      phone: phone?.trim(),
      role: role,
    );

    final userId = await _db.insert(AppConstants.tblUsers, user.toMap());

    await _db.insert(AppConstants.tblUserBusinesses, {
      'user_id': userId,
      'business_id': businessId,
      'role': role,
    });

    return user.copyWith(id: userId);
  }

  Future<bool> isUsernameTaken(String username) async {
    final rows = await _db.queryAll(
      AppConstants.tblUsers,
      where: 'username = ?',
      whereArgs: [username.trim().toLowerCase()],
    );
    return rows.isNotEmpty;
  }

  Future<UserModel> registerUser({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
  }) async {
    final user = UserModel(
      username: username.trim().toLowerCase(),
      passwordHash: DatabaseHelper.hashPassword(password),
      fullName: fullName.trim(),
      email: email?.trim(),
      phone: phone?.trim(),
      role: AppConstants.roleOwner,
    );

    final userId = await _db.insert(AppConstants.tblUsers, user.toMap());
    return user.copyWith(id: userId);
  }

  Future<List<UserModel>> getAllUsers() async {
    final rows = await _db.queryAll(AppConstants.tblUsers, where: 'is_active = 1', orderBy: 'full_name ASC');
    return rows.map(UserModel.fromMap).toList();
  }

  Future<List<UserModel>> getUsersForBusiness(int businessId) async {
    final rows = await _db.rawQuery('''
      SELECT u.*
      FROM ${AppConstants.tblUsers} u
      INNER JOIN ${AppConstants.tblUserBusinesses} ub ON u.id = ub.user_id
      WHERE ub.business_id = ? AND u.is_active = 1
      ORDER BY u.full_name ASC
    ''', [businessId]);
    return rows.map(UserModel.fromMap).toList();
  }

  Future<void> changePassword(int userId, String newPassword) async {
    await _db.update(
      AppConstants.tblUsers,
      {'password_hash': DatabaseHelper.hashPassword(newPassword)},
      userId,
    );
  }

  Future<UserModel> updateUser(UserModel user) async {
    await _db.update(AppConstants.tblUsers, user.toMap(), user.id!);
    return user;
  }
}
