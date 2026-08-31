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
  overridePrice,
  approveMinPriceOverride,
  manageSuppliers,
  managePurchases,
  recordStockAdjustment,
  editBasePrice,
  editPurchaseCost,
}

class RbacService {
  final String role;

  const RbacService(this.role);

  bool hasPermission(AppPermission permission) {
    switch (permission) {
      case AppPermission.viewReports:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager ||
            role == AppConstants.rolePurchaseManager ||
            role == AppConstants.roleInventoryManager;
      case AppPermission.manageSettings:
      case AppPermission.manageBudgets:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;
      case AppPermission.manageInventory:
      case AppPermission.recordStockAdjustment:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager ||
            role == AppConstants.roleInventoryManager;
      case AppPermission.manageSuppliers:
      case AppPermission.managePurchases:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager ||
            role == AppConstants.rolePurchaseManager;
      case AppPermission.manageCredentials:
        return role == AppConstants.roleOwner || role == AppConstants.roleAdmin;
      case AppPermission.performBilling:
        return true; // All roles can perform billing
      case AppPermission.deleteData:
        return role == AppConstants.roleOwner || role == AppConstants.roleAdmin;
      case AppPermission.overridePrice:
        return true; // Cashier can request override, managers can execute directly
      case AppPermission.approveMinPriceOverride:
      case AppPermission.editBasePrice:
      case AppPermission.editPurchaseCost:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;
    }
  }

  bool get isOwnerOrAdmin =>
      role == AppConstants.roleOwner || role == AppConstants.roleAdmin;
  
  bool get isManager => role == AppConstants.roleManager;
  
  bool get isPurchaseManager => role == AppConstants.rolePurchaseManager;
  
  bool get isInventoryManager => role == AppConstants.roleInventoryManager;

  bool get isCashier => role == AppConstants.roleCashier;

  bool get canApproveMinPriceOverride =>
      role == AppConstants.roleOwner ||
      role == AppConstants.roleAdmin ||
      role == AppConstants.roleManager;

  bool get canEditBasePrice =>
      role == AppConstants.roleOwner ||
      role == AppConstants.roleAdmin ||
      role == AppConstants.roleManager;

  bool get canEditPurchaseCost =>
      role == AppConstants.roleOwner ||
      role == AppConstants.roleAdmin ||
      role == AppConstants.roleManager ||
      role == AppConstants.rolePurchaseManager;

  String get displayName {
    switch (role) {
      case AppConstants.roleOwner:
        return 'Owner';
      case AppConstants.roleAdmin:
        return 'Admin';
      case AppConstants.roleManager:
        return 'Manager';
      case AppConstants.rolePurchaseManager:
        return 'Purchase Manager';
      case AppConstants.roleInventoryManager:
        return 'Inventory Manager';
      case AppConstants.roleCashier:
        return 'Cashier';
      default:
        return 'Staff';
    }
  }
}

final rbacProvider = Provider<RbacService>((ref) {
  final user = ref.watch(currentUserProvider);
  return RbacService(user?.role ?? AppConstants.roleOwner);
});
