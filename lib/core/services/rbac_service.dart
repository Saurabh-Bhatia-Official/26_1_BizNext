// lib/core/services/rbac_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../constants/app_constants.dart';

enum AppPermission {
  viewReports,
  manageSettings,
  manageBudgets,
  manageInventory,
  manageCredentials,
  performBilling,
  deleteData,
}

class RbacService {
  final String role;

  const RbacService(this.role);

  bool hasPermission(AppPermission permission) {
    switch (permission) {
      case AppPermission.viewReports:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;
      case AppPermission.manageSettings:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;
      case AppPermission.manageBudgets:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;
      case AppPermission.manageInventory:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;
      case AppPermission.manageCredentials:
        return role == AppConstants.roleOwner || role == AppConstants.roleAdmin;
      case AppPermission.performBilling:
        return true; // All roles can perform billing
      case AppPermission.deleteData:
        return role == AppConstants.roleOwner || role == AppConstants.roleAdmin;
    }
  }

  bool get isOwnerOrAdmin =>
      role == AppConstants.roleOwner || role == AppConstants.roleAdmin;
  
  bool get isManager => role == AppConstants.roleManager;
  
  bool get isStaff =>
      role == AppConstants.roleCashier ||
      role == AppConstants.roleWaiter ||
      role == AppConstants.roleKitchen;

  String get displayName {
    switch (role) {
      case AppConstants.roleOwner:
        return 'Owner';
      case AppConstants.roleAdmin:
        return 'Admin';
      case AppConstants.roleManager:
        return 'Manager';
      case AppConstants.roleCashier:
        return 'Cashier';
      case AppConstants.roleWaiter:
        return 'Waiter';
      case AppConstants.roleKitchen:
        return 'Kitchen';
      default:
        return 'Staff';
    }
  }
}

final rbacProvider = Provider<RbacService>((ref) {
  final user = ref.watch(currentUserProvider);
  return RbacService(user?.role ?? AppConstants.roleOwner);
});
