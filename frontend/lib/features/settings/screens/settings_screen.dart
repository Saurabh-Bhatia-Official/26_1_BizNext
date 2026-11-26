// lib/features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/providers/notification_provider.dart';
import '../providers/settings_provider.dart';
import '../../loyalty/screens/loyalty_settings_screen.dart';
import 'gst_settings_screen.dart';
import 'package:camera/camera.dart';
import 'credentials_screen.dart';
import '../../../core/services/rbac_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import '../../billing/utils/invoice_service.dart';
import '../../billing/models/sale_history_model.dart';
import '../../../core/widgets/qr_scanner_screen.dart';
import '../../../core/services/hardware_scanner_service.dart';
import '../../auth/models/business_model.dart';
import 'shortcut_settings_screen.dart';
import '../../updater/screens/update_screen.dart';
import '../../../core/widgets/category_manager_screen.dart';
import '../../accounts/models/transaction_model.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../inventory/repositories/product_repository.dart';
import '../../inventory/models/product_model.dart';

class PermissionNotifier extends StateNotifier<PermissionStatus> {
  final Permission _permission;
  PermissionNotifier(this._permission) : super(PermissionStatus.denied) {
    checkPermission();
  }

  Future<void> checkPermission() async {
    final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (!isMobile) {
      state = PermissionStatus.granted;
      return;
    }
    try {
      state = await _permission.status;
    } catch (_) {
      state = PermissionStatus.granted;
    }
  }

  Future<void> requestPermission() async {
    final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (!isMobile) return;
    try {
      final res = await _permission.request();
      state = res;
    } catch (_) {
      state = PermissionStatus.granted;
    }
  }
}

final cameraPermissionProvider = StateNotifierProvider<PermissionNotifier, PermissionStatus>((ref) {
  return PermissionNotifier(Permission.camera);
});

final bluetoothPermissionProvider = StateNotifierProvider<PermissionNotifier, PermissionStatus>((ref) {
  return PermissionNotifier(Permission.bluetoothConnect);
});

String _getPermissionLabel(PermissionStatus status) {
  switch (status) {
    case PermissionStatus.granted:
      return 'Granted';
    case PermissionStatus.denied:
      return 'Denied (Tap to Request)';
    case PermissionStatus.permanentlyDenied:
      return 'Permanently Denied (Check Settings)';
    case PermissionStatus.restricted:
      return 'Restricted';
    case PermissionStatus.limited:
      return 'Limited';
    case PermissionStatus.provisional:
      return 'Provisional';
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final business = ref.watch(currentBusinessProvider);
    final rbac = ref.watch(rbacProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.textLight),
            ),
            const Text('Configure your business workspace and preferences', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 40),

            // ── Business Settings ──
            _SettingsSection(
              title: 'Business Information',
              isDark: isDark,
              children: [
                _SettingsTile(
                  label: 'Business Name',
                  value: business?.name ?? 'Not set',
                  icon: Icons.business_rounded,
                  onTap: !rbac.isOwnerOrAdmin ? null : () => _showEditDialog(context, ref, 'Business Name', business?.name ?? '', (v) async {
                    if (business == null) return;
                    final success = await ref.read(authProvider.notifier).updateActiveBusiness(business.copyWith(name: v));
                    if (success) AppAlert.success(ref, 'Business name updated');
                  }),
                ),
                _SettingsTile(
                  label: 'GST Number',
                  value: business?.gstNumber ?? 'Not provided',
                  icon: Icons.receipt_long_rounded,
                  onTap: !rbac.isOwnerOrAdmin ? null : () => _showEditDialog(context, ref, 'GST Number', business?.gstNumber ?? '', (v) async {
                    if (business == null) return;
                    final success = await ref.read(authProvider.notifier).updateActiveBusiness(business.copyWith(gstNumber: v));
                    if (success) AppAlert.success(ref, 'GST Number updated');
                  }),
                ),
                _SettingsTile(
                  label: 'Business Address',
                  value: business?.address ?? 'Not set',
                  icon: Icons.location_on_rounded,
                  onTap: !rbac.isOwnerOrAdmin ? null : () => _showEditDialog(context, ref, 'Business Address', business?.address ?? '', (v) async {
                    if (business == null) return;
                    final success = await ref.read(authProvider.notifier).updateActiveBusiness(business.copyWith(address: v));
                    if (success) AppAlert.success(ref, 'Address updated successfully');
                  }),
                ),
                _SettingsTile(
                  label: 'Phone',
                  value: business?.phone ?? 'Not set',
                  icon: Icons.phone_rounded,
                  onTap: !rbac.isOwnerOrAdmin ? null : () => _showEditDialog(context, ref, 'Phone', business?.phone ?? '', (v) async {
                    if (business == null) return;
                    final success = await ref.read(authProvider.notifier).updateActiveBusiness(business.copyWith(phone: v));
                    if (success) AppAlert.success(ref, 'Phone number updated');
                  }),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Appearance ──
            _SettingsSection(
              title: 'Appearance & System',
              isDark: isDark,
              children: [
                SwitchListTile.adaptive(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.amber : AppColors.primary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? Colors.amber : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text(
                    isDark ? 'Dark theme is currently active' : 'Light theme is currently active',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  value: isDark,
                  onChanged: (v) => ref.read(themeModeProvider.notifier).toggle(),
                  activeTrackColor: AppColors.primary,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Default Scanner Device',
                  value: _getScannerDeviceLabel(ref.watch(featureSettingsProvider).scannerDevice),
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () => _showScannerDeviceDialog(context, ref),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Default Camera',
                  value: 'Camera ${ref.watch(featureSettingsProvider).selectedCameraIndex}',
                  icon: Icons.camera_alt_rounded,
                  onTap: () => _showCameraSelectionDialog(context, ref),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Keyboard Shortcuts',
                  value: 'Manage and customize application hotkeys',
                  icon: Icons.keyboard_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShortcutSettingsScreen()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Feature Controls ──
            _SettingsSection(
              title: 'Feature Controls',
              isDark: isDark,
              children: [
                _FeatureToggle(
                  label: 'Customer Discount System',
                  value: ref.watch(featureSettingsProvider).customerDiscountEnabled,
                  onChanged: !rbac.isOwnerOrAdmin ? null : (v) => ref.read(featureSettingsProvider.notifier).toggleCustomerDiscount(v),
                ),
                _FeatureToggle(
                  label: 'Product Discount System',
                  value: ref.watch(featureSettingsProvider).productDiscountEnabled,
                  onChanged: !rbac.isOwnerOrAdmin ? null : (v) => ref.read(featureSettingsProvider.notifier).toggleProductDiscount(v),
                ),
                _FeatureToggle(
                  label: 'Offers & Promotions',
                  value: ref.watch(featureSettingsProvider).offersEnabled,
                  onChanged: !rbac.isOwnerOrAdmin ? null : (v) => ref.read(featureSettingsProvider.notifier).toggleOffers(v),
                ),
                _FeatureToggle(
                  label: 'Loyalty Program',
                  value: ref.watch(featureSettingsProvider).loyaltyEnabled,
                  onChanged: !rbac.isOwnerOrAdmin ? null : (v) => ref.read(featureSettingsProvider.notifier).toggleLoyalty(v),
                ),
                _FeatureToggle(
                  label: 'GST Features',
                  value: ref.watch(featureSettingsProvider).gstEnabled,
                  onChanged: !rbac.isOwnerOrAdmin ? null : (v) => ref.read(featureSettingsProvider.notifier).toggleGst(v),
                ),
                _FeatureToggle(
                  label: 'Inventory Tracking',
                  value: ref.watch(featureSettingsProvider).inventoryTrackingEnabled,
                  onChanged: !rbac.isOwnerOrAdmin ? null : (v) => ref.read(featureSettingsProvider.notifier).toggleInventoryTracking(v),
                ),
                _FeatureToggle(
                  label: 'WhatsApp/SMS Notifications',
                  value: ref.watch(featureSettingsProvider).notificationsEnabled,
                  onChanged: !rbac.isOwnerOrAdmin ? null : (v) => ref.read(featureSettingsProvider.notifier).toggleNotifications(v),
                ),
                _FeatureToggle(
                  label: 'Auto Sync Data',
                  value: ref.watch(featureSettingsProvider).autoSyncEnabled,
                  onChanged: !rbac.isOwnerOrAdmin ? null : (v) => ref.read(featureSettingsProvider.notifier).toggleAutoSync(v),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Shop Configuration ──
            _SettingsSection(
              title: 'Shop Configuration',
              isDark: isDark,
              children: [
                _SettingsTile(
                  label: 'GST Tax Scales',
                  value: 'Manage available tax percentages',
                  icon: Icons.receipt_long_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GstSettingsScreen()),
                    );
                  },
                ),
                _SettingsTile(
                  label: 'Loyalty Program Config',
                  value: 'Decide points earning and redemption rules',
                  icon: Icons.stars_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoyaltySettingsScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Customer Price Tiers',
                  value: 'Manage customer price categories (Wholesale, Dealer, VIP, etc.)',
                  icon: Icons.sell_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryManagerScreen(
                          title: 'Customer Price Tiers',
                          categoriesProvider: customerTypesProvider,
                          onSave: (name, id) async {
                            final repo = ref.read(productRepositoryProvider);
                            final biz = ref.read(currentBusinessProvider);
                            await repo.addCustomerType(CustomerType(id: id, name: name), biz?.id ?? 1);
                            ref.invalidate(customerTypesProvider);
                            return true;
                          },
                          onDelete: (id) async {
                            final repo = ref.read(productRepositoryProvider);
                            await repo.deleteCustomerType(id);
                            ref.invalidate(customerTypesProvider);
                            return true;
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Accounting & Categories ──
            _SettingsSection(
              title: 'Accounting & Categories',
              isDark: isDark,
              children: [
                _SettingsTile(
                  label: 'Income Categories',
                  value: 'Configure revenue sources, services & fees',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                  onTap: () => _openCategoryManager(context, ref, 'income'),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Expense Categories',
                  value: 'Configure operational overhead, utility & expense heads',
                  icon: Icons.trending_down_rounded,
                  color: AppColors.error,
                  onTap: () => _openCategoryManager(context, ref, 'expense'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Hardware & Permissions ──
            _SettingsSection(
              title: 'Hardware & Permissions',
              isDark: isDark,
              children: [
                _SettingsTile(
                  label: 'Camera Permission',
                  value: _getPermissionLabel(ref.watch(cameraPermissionProvider)),
                  icon: Icons.camera_alt_rounded,
                  onTap: () => ref.read(cameraPermissionProvider.notifier).requestPermission(),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Printer / Bluetooth Permission',
                  value: _getPermissionLabel(ref.watch(bluetoothPermissionProvider)),
                  icon: Icons.bluetooth_rounded,
                  onTap: () => ref.read(bluetoothPermissionProvider.notifier).requestPermission(),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Test Camera Scanner',
                  value: 'Open camera scanner overlay to test barcode detection',
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () {
                    final cameraIndex = ref.read(featureSettingsProvider).selectedCameraIndex;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => QRScannerScreen(initialCameraIndex: cameraIndex)),
                    );
                  },
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Test Print Receipt',
                  value: 'Send a mock test page to your default printer',
                  icon: Icons.print_rounded,
                  onTap: () => _testPrint(context, ref),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Test Barcode Scanner Input',
                  value: 'Verify USB/Bluetooth physical scanner input',
                  icon: Icons.keyboard_rounded,
                  onTap: () => _testScannerInput(context),
                ),
              ],
            ),

            if (rbac.isOwnerOrAdmin) ...[
              const SizedBox(height: 32),
              
              // ── Data Backup ──
              _SettingsSection(
                title: 'Data Backup & Recovery',
                isDark: isDark,
                children: [
                  _SettingsTile(
                    label: 'Export Database',
                    value: 'Create a backup of all your business data',
                    icon: Icons.backup_rounded,
                    onTap: () => _confirmBackup(context, ref),
                  ),
                  _SettingsTile(
                    label: 'Import Database',
                    value: 'Restore data from a previous backup file',
                    icon: Icons.settings_backup_restore_rounded,
                    onTap: () => _confirmRestore(context, ref),
                  ),
                  _SettingsTile(
                    label: 'Reset Shop Data',
                    value: 'Clear all data for THIS shop only',
                    icon: Icons.store_rounded,
                    color: AppColors.error,
                    onTap: () => _confirmShopReset(context, ref),
                  ),
                  _SettingsTile(
                    label: 'Reset All Data',
                    value: 'PERMANENTLY delete all software data',
                    icon: Icons.delete_forever_rounded,
                    color: AppColors.error,
                    onTap: () => _confirmReset(context, ref),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // ── About ──
            _SettingsSection(
              title: 'About',
              isDark: isDark,
              children: [
                if (rbac.hasPermission(AppPermission.manageCredentials)) ...[
                  _SettingsTile(
                    label: 'Login Credentials',
                    value: 'View all registered user accounts',
                    icon: Icons.key_rounded,
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CredentialsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
                _SettingsTile(
                  label: 'Software Updates',
                  value: 'Check for updates, view history & rollback',
                  icon: Icons.system_update_rounded,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UpdateScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'Version',
                  value: '1.0.0',
                  icon: Icons.info_outline_rounded,
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingsTile(
                  label: 'BizNext',
                  value: 'A production-ready POS & business management system',
                  icon: Icons.business_center_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _testPrint(BuildContext context, WidgetRef ref) async {
    try {
      final business = ref.read(currentBusinessProvider);
      await InvoiceService.generateAndPrintInvoice(
        context: context,
        business: business ?? BusinessModel(id: 1, name: 'BizNext Demo', type: 'Retail'),
        sale: SaleHistoryModel(
          id: 9999,
          businessId: business?.id ?? 1,
          invoiceNo: 'TEST-PRINT-001',
          date: DateTime.now(),
          customerName: 'Walk-In Customer',
          subtotal: 100.0,
          gstAmount: 0.0,
          grandTotal: 100.0,
          paidAmount: 100.0,
          balanceDue: 0.0,
          paymentMode: 'Cash',
          items: [
            SaleHistoryItemModel(
              productId: 1,
              productName: 'Hardware Test Item',
              quantity: 1.0,
              price: 100.0,
              gstAmount: 0.0,
              total: 100.0,
            ),
          ],
        ),
      );
    } catch (e) {
      AppAlert.error(ref, 'Printing test failed: $e');
    }
  }

  void _testScannerInput(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ScannerDiagnosticDialog(),
    );
  }

  String _getScannerDeviceLabel(String value) {
    switch (value) {
      case 'embedded':
        return 'Embedded Preview';
      case 'external':
        return 'External Scanner';
      case 'camera':
      default:
        return 'Full Screen Camera';
    }
  }

  void _showScannerDeviceDialog(BuildContext context, WidgetRef ref) {
    final current = ref.watch(featureSettingsProvider).scannerDevice;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Select Default Scanner', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Full Screen Camera'),
              subtitle: const Text('Opens full camera view'),
              leading: const Icon(Icons.fullscreen_rounded),
              trailing: current == 'camera' ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              onTap: () {
                ref.read(featureSettingsProvider.notifier).setScannerDevice('camera');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Embedded Preview'),
              subtitle: const Text('Shows live preview in POS'),
              leading: const Icon(Icons.videocam_rounded),
              trailing: current == 'embedded' ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              onTap: () {
                ref.read(featureSettingsProvider.notifier).setScannerDevice('embedded');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('External Scanner'),
              subtitle: const Text('Uses keyboard wedge scanner'),
              leading: const Icon(Icons.keyboard_rounded),
              trailing: current == 'external' ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              onTap: () {
                ref.read(featureSettingsProvider.notifier).setScannerDevice('external');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCameraSelectionDialog(BuildContext context, WidgetRef ref) async {
    try {
      final cameras = await availableCameras();
      final current = ref.read(featureSettingsProvider).selectedCameraIndex;
      
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Select Default Camera', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cameras.length,
              itemBuilder: (ctx, index) {
                final cam = cameras[index];
                return ListTile(
                  title: Text(cam.name),
                  subtitle: Text(cam.lensDirection.toString()),
                  trailing: current == index ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () {
                    ref.read(featureSettingsProvider.notifier).setCameraIndex(index);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      AppAlert.error(ref, 'Failed to list cameras: $e');
    }
  }


  void _openCategoryManager(BuildContext context, WidgetRef ref, String type) {
    final isIncome = type == 'income';
    final title = isIncome ? 'Income Categories' : 'Expense Categories';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryManagerScreen(
          title: title,
          categoriesProvider: transactionCategoriesProvider(type),
          nameExtractor: (cat) => (cat as TransactionCategoryModel).name,
          onSave: (name, id) async {
            final businessId = ref.read(activeBusinessIdProvider);
            final category = TransactionCategoryModel(
              id: id,
              businessId: businessId,
              name: name,
              type: type,
            );
            if (id == null) {
              await ref.read(accountsRepositoryProvider).addTransactionCategory(category);
            } else {
              await ref.read(accountsRepositoryProvider).updateTransactionCategory(category);
            }
            ref.invalidate(transactionCategoriesProvider(type));
            return true;
          },
          onDelete: (id) async {
            try {
              await ref.read(accountsRepositoryProvider).deleteTransactionCategory(id);
              ref.invalidate(transactionCategoriesProvider(type));
              return true;
            } catch (e) {
              AppAlert.error(ref, 'Cannot delete: Category is in use by transactions');
              return false;
            }
          },
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, String title, String current, Function(String) onSave) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'Enter new $title'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              onSave(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset Software?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This action will permanently delete ALL application data and cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.resetSoftware();
              if (context.mounted) {
                AppAlert.success(ref, 'Software reset successfully.');
                ref.read(authProvider.notifier).logout();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('RESET EVERYTHING'),
          ),
        ],
      ),
    );
  }

  void _confirmBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await BackupService.exportDatabase();
      if (result != null && context.mounted) {
        if (result.contains('failed')) {
          AppAlert.error(ref, result);
        } else {
          AppAlert.success(ref, result);
        }
      }
    } catch (e) {
      if (context.mounted) AppAlert.error(ref, 'Backup failed: $e');
    }
  }

  void _confirmRestore(BuildContext context, WidgetRef ref) async {
    try {
      final result = await BackupService.importDatabase();
      if (result != null && context.mounted) {
        if (result.contains('failed')) {
          AppAlert.error(ref, result);
        } else {
          // Reinitialize the app state
          await ref.read(authProvider.notifier).reinitialize();
          if (context.mounted) {
            AppAlert.success(ref, 'Database restored and data refreshed!');
          }
        }
      }
    } catch (e) {
      if (context.mounted) AppAlert.error(ref, 'Restore failed: $e');
    }
  }

  void _confirmShopReset(BuildContext context, WidgetRef ref) {
    final business = ref.read(currentBusinessProvider);
    if (business == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset Shop Data?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('This action will permanently delete all inventory, sales, purchases, and settings for "${business.name}". Other shops and your account will remain unaffected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await DatabaseHelper.instance.resetBusinessData(business.id!);
                if (context.mounted) {
                  AppAlert.success(ref, 'Shop data reset successfully. Re-initializing...');
                  await Future.delayed(const Duration(seconds: 1));
                  await ref.read(authProvider.notifier).reinitialize();
                }
              } catch (e) {
                if (context.mounted) AppAlert.error(ref, 'Reset failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('RESET SHOP'),
          ),
        ],
      ),
    );
  }
}


class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;
  const _SettingsSection({required this.title, required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5)),
        const SizedBox(height: 16),
        Material(
          color: isDark ? AppColors.darkCard : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _SettingsTile({required this.label, required this.value, required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (color ?? AppColors.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color ?? AppColors.primary, size: 18),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Text(value, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}

class _FeatureToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _FeatureToggle({required this.label, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primary,
    );
  }
}

class _ScannerDiagnosticDialog extends StatefulWidget {
  const _ScannerDiagnosticDialog();

  @override
  State<_ScannerDiagnosticDialog> createState() => _ScannerDiagnosticDialogState();
}

class _ScannerDiagnosticDialogState extends State<_ScannerDiagnosticDialog> {
  final TextEditingController _inputController = TextEditingController();
  HardwareScannerScanLog? _latestLog;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _latestLog = HardwareBarcodeScannerService.instance.lastScanLog.value;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _onScanDetected(String code) {
    setState(() {
      _lastScannedCode = code;
      _inputController.text = code;
      _latestLog = HardwareBarcodeScannerService.instance.lastScanLog.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HardwareBarcodeScannerListener(
      onBarcodeScanned: _onScanDetected,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scanner Diagnostic Studio', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  Text('Test USB/Bluetooth hardware scanner & camera', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live Status Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _latestLog != null
                        ? (_latestLog!.isHardwareScanner
                            ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                            : Colors.amber.withValues(alpha: 0.12))
                        : (isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _latestLog != null
                          ? (_latestLog!.isHardwareScanner ? const Color(0xFF22C55E) : Colors.amber)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _latestLog != null
                            ? (_latestLog!.isHardwareScanner ? Icons.check_circle_rounded : Icons.keyboard_rounded)
                            : Icons.sensors_rounded,
                        color: _latestLog != null
                            ? (_latestLog!.isHardwareScanner ? const Color(0xFF22C55E) : Colors.amber)
                            : AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _latestLog == null
                                  ? 'Scanner Listener Active'
                                  : (_latestLog!.isHardwareScanner
                                      ? 'Physical Barcode Scanner Verified'
                                      : 'Manual Keyboard Entry Detected'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _latestLog != null
                                    ? (_latestLog!.isHardwareScanner ? const Color(0xFF16A34A) : Colors.amber.shade800)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _latestLog == null
                                  ? 'Plug in your USB/Bluetooth scanner and scan any barcode now.'
                                  : '${_latestLog!.charCount} chars in ${_latestLog!.totalDurationMs}ms (Avg ${_latestLog!.avgMsPerChar.toStringAsFixed(1)}ms/char)',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Decoded Value Output Card
                const Text(
                  'DECODED OUTPUT',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Text(
                    _lastScannedCode ?? 'Waiting for scan...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                      color: _lastScannedCode != null ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Manual Test Input
                TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    labelText: 'Manual Entry / Barcode Input',
                    hintText: 'Type or scan with scanner focused here',
                    prefixIcon: const Icon(Icons.keyboard_alt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      setState(() {
                        _lastScannedCode = v.trim();
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Action Buttons (Simulate + Open Camera)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HardwareBarcodeScannerService.instance.simulateHardwareScan('8901030383321');
                          _onScanDetected('8901030383321');
                        },
                        icon: const Icon(Icons.flash_on_rounded, size: 16),
                        label: const Text('Simulate USB Scan'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final code = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                          );
                          if (code != null && code.isNotEmpty) {
                            _onScanDetected(code);
                          }
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('Test Webcam Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
