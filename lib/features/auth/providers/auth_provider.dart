// lib/features/auth/providers/auth_provider.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
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
      final syncMode = _prefs.getString(AppConstants.prefSyncMode) ?? 'offline';

      UserModel user;

      if (syncMode == 'online') {
        final fbEmail = username.contains('@') ? username : '${username.trim().toLowerCase()}@biznext.local';
        await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: fbEmail,
          password: password,
        );
        user = await _repo.login(username, password) ??
               await _repo.registerUser(
                 username: username,
                 password: password,
                 fullName: username,
                 email: username.contains('@') ? username : null,
               );
      } else {
        final found = await _repo.login(username, password);
        if (found == null) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            error: 'Invalid username or password.',
          );
          return false;
        }
        user = found;
      }

      await _prefs.setInt(AppConstants.prefUserId, user.id!);

      if (syncMode == 'online') {
        await _prefs.setString('subscription_tier', 'pro');
      }

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

      final syncMode = _prefs.getString(AppConstants.prefSyncMode) ?? 'offline';
      if (syncMode == 'online') {
        try {
          final fbEmail = email ?? '${username.trim().toLowerCase()}@biznext.local';
          await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: fbEmail,
            password: password,
          );
        } catch (fbErr) {
          debugPrint("Firebase Auth creation skipped: $fbErr");
        }
        await _prefs.setString('subscription_tier', 'pro');
      }

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

  Future<bool> loginWithFirebaseToken(String idToken, {String? emailHint, String? nameHint, String? phoneHint}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await http.post(
        Uri.parse("http://localhost:8000/api/v1/auth/firebase-login"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id_token": idToken}),
      );
      
      if (response.statusCode != 200) {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: "Backend validation failed: ${response.body}");
        return false;
      }
      
      final body = json.decode(response.body);
      final accessToken = body["access_token"];
      final subscription = body["subscription"];
      
      await _prefs.setString("access_token", accessToken);
      await _prefs.setString("subscription_tier", subscription);
      
      final username = emailHint != null ? emailHint.split("@")[0] : (phoneHint ?? "firebase_user");
      
      var user = await _repo.login(username, "firebase_oauth_token");
      if (user == null) {
        user = await _repo.registerUser(
          username: username,
          password: "firebase_oauth_token",
          fullName: nameHint ?? username.toUpperCase(),
          email: emailHint,
          phone: phoneHint,
        );
      }
      
      await _prefs.setInt(AppConstants.prefUserId, user.id!);
      
      final businesses = await _repo.getBusinessesForUser(user.id!);
      if (businesses.isEmpty) {
        final defaultBiz = BusinessModel(
          name: "${user.fullName}'s Business",
          type: "Retail Shop",
        );
        final createdBiz = await _repo.createBusiness(business: defaultBiz, userId: user.id!);
        await selectBusiness(createdBiz, user: user);
      } else if (businesses.length == 1) {
        await selectBusiness(businesses.first, user: user);
      } else {
        state = state.copyWith(
          status: AuthStatus.businessNotSelected,
          user: user,
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString());
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return false;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb_auth.AuthCredential credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final fb_auth.UserCredential userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final fb_auth.User? user = userCredential.user;
      
      if (user == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: "Firebase User empty");
        return false;
      }
      
      final idToken = await user.getIdToken();
      if (idToken == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: "ID Token empty");
        return false;
      }
      
      return await loginWithFirebaseToken(
        idToken,
        emailHint: user.email,
        nameHint: user.displayName,
        phoneHint: user.phoneNumber,
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: "Google Sign-In failed: ${e.toString()}");
      return false;
    }
  }

  Future<bool> loginWithMicrosoft() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final microsoftProvider = fb_auth.OAuthProvider("microsoft.com");
      final fb_auth.UserCredential userCredential = await fb_auth.FirebaseAuth.instance.signInWithProvider(microsoftProvider);
      final fb_auth.User? user = userCredential.user;
      
      if (user == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: "Firebase User empty");
        return false;
      }
      
      final idToken = await user.getIdToken();
      if (idToken == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: "ID Token empty");
        return false;
      }
      
      return await loginWithFirebaseToken(
        idToken,
        emailHint: user.email,
        nameHint: user.displayName,
        phoneHint: user.phoneNumber,
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: "Microsoft Sign-In failed: ${e.toString()}");
      return false;
    }
  }

  Future<void> loginWithPhone(String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await fb_auth.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (fb_auth.PhoneAuthCredential credential) async {
          final fb_auth.UserCredential userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
          final user = userCredential.user;
          if (user != null) {
            final idToken = await user.getIdToken();
            if (idToken != null) {
              await loginWithFirebaseToken(idToken, phoneHint: user.phoneNumber);
            }
          }
        },
        verificationFailed: (fb_auth.FirebaseAuthException e) {
          onError(e.message ?? "Verification failed");
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<bool> verifyPhoneOTP(String verificationId, String smsCode) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final fb_auth.PhoneAuthCredential credential = fb_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      final fb_auth.UserCredential userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final fb_auth.User? user = userCredential.user;
      
      if (user == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: "Firebase User empty");
        return false;
      }
      
      final idToken = await user.getIdToken();
      if (idToken == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: "ID Token empty");
        return false;
      }
      
      return await loginWithFirebaseToken(
        idToken,
        phoneHint: user.phoneNumber,
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: "OTP verification failed: ${e.toString()}");
      return false;
    }
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
