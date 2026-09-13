// lib/core/services/rbac_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../constants/app_constants.dart';

enum AppPermission {
  // Navigation / module access
  viewReports,
  viewAccounts,
  manageSettings,
  manageBudgets,
  manageInventory,
  managePurchases,
  manageSuppliers,
  manageCustomers,
  manageOffers,
  manageLoyalty,
  manageCredentials,
  // Actions
  performBilling,
  deleteData,
  overridePrice,
  approveMinPriceOverride,
  recordStockAdjustment,
  editBasePrice,
  editPurchaseCost,
}

class RbacService {
  final String role;

  const RbacService(this.role);

  bool hasPermission(AppPermission permission) {
    switch (permission) {

      // ── Reports: Owner, Admin, Manager, PurchaseMgr, InventoryMgr ────────
      case AppPermission.viewReports:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager ||
            role == AppConstants.rolePurchaseManager ||
            role == AppConstants.roleInventoryManager;

      // ── Accounts: Owner & Admin only ─────────────────────────────────────
      case AppPermission.viewAccounts:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin;

      // ── Settings / Budgets: Owner, Admin, Manager ─────────────────────────
      case AppPermission.manageSettings:
      case AppPermission.manageBudgets:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;

      // ── Inventory: Owner, Admin, Manager, PurchaseMgr, InventoryMgr ──────
      case AppPermission.manageInventory:
      case AppPermission.recordStockAdjustment:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager ||
            role == AppConstants.rolePurchaseManager ||
            role == AppConstants.roleInventoryManager;

      // ── Purchases / Suppliers: Owner, Admin, Manager, PurchaseMgr ────────
      case AppPermission.managePurchases:
      case AppPermission.manageSuppliers:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager ||
            role == AppConstants.rolePurchaseManager;

      // ── Customers: Owner, Admin, Manager ─────────────────────────────────
      case AppPermission.manageCustomers:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;

      // ── Offers / Loyalty: Owner, Admin, Manager ───────────────────────────
      case AppPermission.manageOffers:
      case AppPermission.manageLoyalty:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;

      // ── Credentials: Owner & Admin only ──────────────────────────────────
      case AppPermission.manageCredentials:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin;

      // ── Billing: all roles ────────────────────────────────────────────────
      case AppPermission.performBilling:
        return true;

      // ── Destructive actions: Owner & Admin only ───────────────────────────
      case AppPermission.deleteData:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin;

      // ── Price overrides ───────────────────────────────────────────────────
      case AppPermission.overridePrice:
        return true; // All roles can request; approve gate is separate

      case AppPermission.approveMinPriceOverride:
      case AppPermission.editBasePrice:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager;

      case AppPermission.editPurchaseCost:
        return role == AppConstants.roleOwner ||
            role == AppConstants.roleAdmin ||
            role == AppConstants.roleManager ||
            role == AppConstants.rolePurchaseManager;
    }
  }

  // ── Convenience getters ──────────────────────────────────────────────────
  bool get isOwnerOrAdmin =>
      role == AppConstants.roleOwner || role == AppConstants.roleAdmin;

  bool get isManager => role == AppConstants.roleManager;

  bool get isPurchaseManager => role == AppConstants.rolePurchaseManager;

  bool get isInventoryManager => role == AppConstants.roleInventoryManager;

  bool get isCashier => role == AppConstants.roleCashier;

  bool get canApproveMinPriceOverride => hasPermission(AppPermission.approveMinPriceOverride);

  bool get canEditBasePrice => hasPermission(AppPermission.editBasePrice);

  bool get canEditPurchaseCost => hasPermission(AppPermission.editPurchaseCost);

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
