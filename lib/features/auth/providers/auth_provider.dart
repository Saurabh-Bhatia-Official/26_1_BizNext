// lib/features/auth/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

final splashCompleteProvider = StateProvider<bool>((ref) => true);

// ── Repository Provider ───────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

// ── Auth State ─────────────────────────────────────────────────────────────────
enum AuthStatus { loading, unauthenticated, authenticated, businessNotSelected }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final BusinessModel? activeBusiness;
  final String? error;

  const AuthState({
    this.status = AuthStatus.loading,
    this.user,
    this.activeBusiness,
    this.error,
  });

  bool get isAuthenticated => user != null;
  bool get hasActiveBusiness => activeBusiness != null;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    BusinessModel? activeBusiness,
    String? error,
    bool clearError = false,
    bool clearBusiness = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      activeBusiness: clearBusiness ? null : (activeBusiness ?? this.activeBusiness),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final SharedPreferences _prefs;

  AuthNotifier(this._repo, this._prefs) : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final userId = _prefs.getInt(AppConstants.prefUserId);
    final businessId = _prefs.getInt(AppConstants.prefBusinessId);

    if (userId == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await _repo.getUserById(userId);
      if (user == null) {
        await _clearSession();
        return;
      }

      if (businessId != null) {
        final business = await _repo.getBusinessById(businessId);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          activeBusiness: business,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.businessNotSelected,
          user: user,
        );
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> reinitialize() async {
    state = state.copyWith(status: AuthStatus.loading);
    await _restoreSession();
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final found = await _repo.login(username, password);
      if (found == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Invalid username or password.',
        );
        return false;
      }
      final user = found;

      await _prefs.setInt(AppConstants.prefUserId, user.id!);

      final businesses = await _repo.getBusinessesForUser(user.id!);

      if (businesses.length == 1) {
        await selectBusiness(businesses.first, user: user);
      } else {
        state = state.copyWith(
          status: AuthStatus.businessNotSelected,
          user: user,
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Login failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      if (await _repo.isUsernameTaken(username)) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Username is already taken.',
        );
        return false;
      }

      final user = await _repo.registerUser(
        username: username,
        password: password,
        fullName: fullName,
        email: email,
        phone: phone,
      );

      await _prefs.setInt(AppConstants.prefUserId, user.id!);

      state = state.copyWith(
        status: AuthStatus.businessNotSelected,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Registration failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> selectBusiness(BusinessModel business, {UserModel? user}) async {
    final u = user ?? state.user!;
    await _prefs.setInt(AppConstants.prefBusinessId, business.id!);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: u,
      activeBusiness: business,
    );
  }

  Future<bool> createNewBusiness(BusinessModel business) async {
    try {
      await _repo.createBusiness(
        business: business,
        userId: state.user!.id!,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create business: ${e.toString()}');
      return false;
    }
  }

  Future<void> switchBusiness(BusinessModel business) async {
    await _prefs.setInt(AppConstants.prefBusinessId, business.id!);
    state = state.copyWith(activeBusiness: business);
  }

  Future<bool> updateActiveBusiness(BusinessModel business) async {
    try {
      await _repo.updateBusiness(business);
      state = state.copyWith(activeBusiness: business);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update business: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateProfile(UserModel user) async {
    try {
      final updated = await _repo.updateUser(user);
      state = state.copyWith(user: updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update profile: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateBusiness(BusinessModel business) async {
    try {
      await _repo.updateBusiness(business);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update business: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteBusiness(int businessId) async {
    try {
      await _repo.deleteBusiness(businessId);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete business: ${e.toString()}');
      return false;
    }
  }

  Future<void> goToBusinessSelector() async {
    await _prefs.remove(AppConstants.prefBusinessId);
    state = state.copyWith(
      status: AuthStatus.businessNotSelected,
      clearBusiness: true,
    );
  }

  Future<void> logout() async {
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await _prefs.remove(AppConstants.prefUserId);
    await _prefs.remove(AppConstants.prefBusinessId);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Main Provider ─────────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(repo, prefs);
});

// ── Derived Convenience Providers ─────────────────────────────────────────────
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

final currentBusinessProvider = Provider<BusinessModel?>((ref) {
  return ref.watch(authProvider).activeBusiness;
});

/// Active business ID — defaults to 1 to avoid null issues
final activeBusinessIdProvider = Provider<int>((ref) {
  return ref.watch(currentBusinessProvider)?.id ?? 1;
});

/// Businesses list for the current user (used by selector screen)
final userBusinessesProvider = FutureProvider.autoDispose<List<BusinessModel>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return repo.getBusinessesForUser(user.id!);
});
