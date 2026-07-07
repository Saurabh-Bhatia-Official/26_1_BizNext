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
import '../../../core/services/auto_update_service.dart';
import 'package:camera/camera.dart';
import 'credentials_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final business = ref.watch(currentBusinessProvider);

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
                  onTap: () => _showEditDialog(context, ref, 'Business Name', business?.name ?? '', (v) async {
                    if (business == null) return;
                    final success = await ref.read(authProvider.notifier).updateActiveBusiness(business.copyWith(name: v));
                    if (success) AppAlert.success(ref, 'Business name updated');
                  }),
                ),
                _SettingsTile(
                  label: 'GST Number',
                  value: business?.gstNumber ?? 'Not provided',
                  icon: Icons.receipt_long_rounded,
                  onTap: () => _showEditDialog(context, ref, 'GST Number', business?.gstNumber ?? '', (v) async {
                    if (business == null) return;
                    final success = await ref.read(authProvider.notifier).updateActiveBusiness(business.copyWith(gstNumber: v));
                    if (success) AppAlert.success(ref, 'GST Number updated');
                  }),
                ),
                _SettingsTile(
                  label: 'Business Address',
                  value: business?.address ?? 'Not set',
                  icon: Icons.location_on_rounded,
                  onTap: () => _showEditDialog(context, ref, 'Business Address', business?.address ?? '', (v) async {
                    if (business == null) return;
                    final success = await ref.read(authProvider.notifier).updateActiveBusiness(business.copyWith(address: v));
                    if (success) AppAlert.success(ref, 'Address updated successfully');
                  }),
                ),
                _SettingsTile(
                  label: 'Phone',
                  value: business?.phone ?? 'Not set',
                  icon: Icons.phone_rounded,
                  onTap: () => _showEditDialog(context, ref, 'Phone', business?.phone ?? '', (v) async {
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
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: const Text('Switch between light and dark themes', style: TextStyle(fontSize: 12)),
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
                  onChanged: (v) => ref.read(featureSettingsProvider.notifier).toggleCustomerDiscount(v),
                ),
                _FeatureToggle(
                  label: 'Product Discount System',
                  value: ref.watch(featureSettingsProvider).productDiscountEnabled,
                  onChanged: (v) => ref.read(featureSettingsProvider.notifier).toggleProductDiscount(v),
                ),
                _FeatureToggle(
                  label: 'Offers & Promotions',
                  value: ref.watch(featureSettingsProvider).offersEnabled,
                  onChanged: (v) => ref.read(featureSettingsProvider.notifier).toggleOffers(v),
                ),
                _FeatureToggle(
                  label: 'Loyalty Program',
                  value: ref.watch(featureSettingsProvider).loyaltyEnabled,
                  onChanged: (v) => ref.read(featureSettingsProvider.notifier).toggleLoyalty(v),
                ),
                _FeatureToggle(
                  label: 'GST Features',
                  value: ref.watch(featureSettingsProvider).gstEnabled,
                  onChanged: (v) => ref.read(featureSettingsProvider.notifier).toggleGst(v),
                ),
                _FeatureToggle(
                  label: 'Inventory Tracking',
                  value: ref.watch(featureSettingsProvider).inventoryTrackingEnabled,
                  onChanged: (v) => ref.read(featureSettingsProvider.notifier).toggleInventoryTracking(v),
                ),
                _FeatureToggle(
                  label: 'WhatsApp/SMS Notifications',
                  value: ref.watch(featureSettingsProvider).notificationsEnabled,
                  onChanged: (v) => ref.read(featureSettingsProvider.notifier).toggleNotifications(v),
                ),
                _FeatureToggle(
                  label: 'Auto Sync Data',
                  value: ref.watch(featureSettingsProvider).autoSyncEnabled,
                  onChanged: (v) => ref.read(featureSettingsProvider.notifier).toggleAutoSync(v),
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
              ],
            ),

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

            const SizedBox(height: 32),

            // ── About ──
            _SettingsSection(
              title: 'About',
              isDark: isDark,
              children: [
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
                _SettingsTile(
                  label: 'Check for Software Updates',
                  value: 'Version: 1.0.0',
                  icon: Icons.system_update_rounded,
                  color: Colors.blue,
                  onTap: () => _handleSoftwareUpdate(context, ref),
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

  void _handleSoftwareUpdate(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Checking for updates...'),
              ],
            ),
          ),
        ),
      ),
    );

    final updater = AutoUpdateService();
    final res = await updater.checkAndUpdate();
    
    if (context.mounted) {
      Navigator.pop(context); // Close checking dialog
    }

    if (res != null && res["update_available"] == true && context.mounted) {
      final String version = res["version"];
      final String downloadUrl = res["download_url"];
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Available!', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('A new version ($version) of BizNext is available. Would you like to install it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _downloadAndInstall(context, ref, downloadUrl);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      );
    } else {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Up to Date', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Your software is already running the latest version.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  void _downloadAndInstall(BuildContext context, WidgetRef ref, String downloadUrl) {
    double progress = 0.0;
    StateSetter? dialogState;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          dialogState = setState;
          return AlertDialog(
            title: const Text('Downloading Update...', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Text('${(progress * 100).toStringAsFixed(0)}% completed'),
              ],
            ),
          );
        }
      ),
    );

    AutoUpdateService().downloadAndInstallUpdate(downloadUrl, (p) {
      if (dialogState != null) {
        dialogState!(() {
          progress = p;
        });
      }
    }).then((success) {
      if (!success && context.mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download update. Please try again later.')),
        );
      }
    });
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
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
  final VoidCallback onTap;
  final Color? color;

  const _SettingsTile({required this.label, required this.value, required this.icon, required this.onTap, this.color});

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
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}

class _FeatureToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FeatureToggle({required this.label, required this.value, required this.onChanged});

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
