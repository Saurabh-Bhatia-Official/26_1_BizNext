// lib/features/settings/models/app_settings.dart

class AppFeatureSettings {
  final bool customerDiscountEnabled;
  final bool productDiscountEnabled;
  final bool offersEnabled;
  final bool loyaltyEnabled;
  final bool gstEnabled;
  final bool inventoryTrackingEnabled;
  final bool notificationsEnabled;
  final bool autoSyncEnabled;
  final String scannerDevice;
  final int selectedCameraIndex;

  AppFeatureSettings({
    this.customerDiscountEnabled = true,
    this.productDiscountEnabled = true,
    this.offersEnabled = true,
    this.loyaltyEnabled = true,
    this.gstEnabled = true,
    this.inventoryTrackingEnabled = true,
    this.notificationsEnabled = true,
    this.autoSyncEnabled = true,
    this.scannerDevice = 'camera',
    this.selectedCameraIndex = 0,
  });

  AppFeatureSettings copyWith({
    bool? customerDiscountEnabled,
    bool? productDiscountEnabled,
    bool? offersEnabled,
    bool? loyaltyEnabled,
    bool? gstEnabled,
    bool? inventoryTrackingEnabled,
    bool? notificationsEnabled,
    bool? autoSyncEnabled,
    String? scannerDevice,
    int? selectedCameraIndex,
  }) {
    return AppFeatureSettings(
      customerDiscountEnabled: customerDiscountEnabled ?? this.customerDiscountEnabled,
      productDiscountEnabled: productDiscountEnabled ?? this.productDiscountEnabled,
      offersEnabled: offersEnabled ?? this.offersEnabled,
      loyaltyEnabled: loyaltyEnabled ?? this.loyaltyEnabled,
      gstEnabled: gstEnabled ?? this.gstEnabled,
      inventoryTrackingEnabled: inventoryTrackingEnabled ?? this.inventoryTrackingEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      scannerDevice: scannerDevice ?? this.scannerDevice,
      selectedCameraIndex: selectedCameraIndex ?? this.selectedCameraIndex,
    );
  }

  Map<String, String> toSqlMap() {
    return {
      'customer_discount_enabled': customerDiscountEnabled ? '1' : '0',
      'product_discount_enabled': productDiscountEnabled ? '1' : '0',
      'offers_enabled': offersEnabled ? '1' : '0',
      'loyalty_enabled': loyaltyEnabled ? '1' : '0',
      'gst_enabled': gstEnabled ? '1' : '0',
      'inventory_tracking_enabled': inventoryTrackingEnabled ? '1' : '0',
      'notifications_enabled': notificationsEnabled ? '1' : '0',
      'auto_sync_enabled': autoSyncEnabled ? '1' : '0',
      'scanner_device': scannerDevice,
      'selected_camera_index': selectedCameraIndex.toString(),
    };
  }

  factory AppFeatureSettings.fromSqlList(List<Map<String, dynamic>> maps) {
    bool customerDiscount = true;
    bool productDiscount = true;
    bool offers = true;
    bool loyalty = true;
    bool gst = true;
    bool inventory = true;
    bool notifications = true;
    bool autoSync = true;
    String scanner = 'camera';
    int cameraIndex = 0;

    for (var map in maps) {
      final key = map['key'];
      final value = map['value'];
      final boolValue = value == '1';
      switch (key) {
        case 'customer_discount_enabled':
          customerDiscount = boolValue;
          break;
        case 'product_discount_enabled':
          productDiscount = boolValue;
          break;
        case 'offers_enabled':
          offers = boolValue;
          break;
        case 'loyalty_enabled':
          loyalty = boolValue;
          break;
        case 'gst_enabled':
          gst = boolValue;
          break;
        case 'inventory_tracking_enabled':
          inventory = boolValue;
          break;
        case 'notifications_enabled':
          notifications = boolValue;
          break;
        case 'auto_sync_enabled':
          autoSync = boolValue;
          break;
        case 'scanner_device':
          scanner = value ?? 'camera';
          break;
        case 'selected_camera_index':
          cameraIndex = int.tryParse(value ?? '0') ?? 0;
          break;
      }
    }

    return AppFeatureSettings(
      customerDiscountEnabled: customerDiscount,
      productDiscountEnabled: productDiscount,
      offersEnabled: offers,
      loyaltyEnabled: loyalty,
      gstEnabled: gst,
      inventoryTrackingEnabled: inventory,
      notificationsEnabled: notifications,
      autoSyncEnabled: autoSync,
      scannerDevice: scanner,
      selectedCameraIndex: cameraIndex,
    );
  }
}
