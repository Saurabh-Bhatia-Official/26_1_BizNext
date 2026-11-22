// lib/features/settings/repositories/settings_repository.dart

import '../../../core/services/backend_api_service.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  Future<AppFeatureSettings> getSettings(int businessId) async {
    final response = await BackendApiService.get(
      'settings',
      {'businessId': '$businessId'},
    );
    final decoded = BackendApiService.decode(response);
    if (decoded is! Map) return AppFeatureSettings();
    final list = decoded.entries
        .map((entry) => {'key': entry.key, 'value': entry.value})
        .toList();
    return AppFeatureSettings.fromSqlList(
      list.map((item) => Map<String, dynamic>.from(item)).toList(),
    );
  }

  Future<void> updateSetting(int businessId, String key, String value) async {
    final current = await getSettings(businessId);
    final map = current.toSqlMap();
    map[key] = value;
    await updateSettings(businessId, AppFeatureSettings.fromSqlList(
      map.entries
          .map((entry) => {'key': entry.key, 'value': entry.value})
          .toList(),
    ));
  }

  Future<void> updateSettings(int businessId, AppFeatureSettings settings) async {
    final response = await BackendApiService.put(
      'settings',
      settings.toSqlMap(),
      {'businessId': '$businessId'},
    );
    BackendApiService.decode(response);
  }
}
