// lib/features/settings/repositories/settings_repository.dart

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<AppFeatureSettings> getSettings(int businessId) async {
    final result = await _db.queryAll(
      AppConstants.tblAppSettings,
      where: 'business_id = ?',
      whereArgs: [businessId],
    );
    if (result.isEmpty) {
      return AppFeatureSettings();
    }
    return AppFeatureSettings.fromSqlList(result);
  }

  Future<void> updateSetting(int businessId, String key, String value) async {
    await _db.rawInsert('''
      INSERT OR REPLACE INTO ${AppConstants.tblAppSettings} (business_id, key, value)
      VALUES (?, ?, ?)
    ''', [businessId, key, value]);
  }

  Future<void> updateSettings(int businessId, AppFeatureSettings settings) async {
    final map = settings.toSqlMap();
    await _db.transaction((txn) async {
      for (var entry in map.entries) {
        await txn.rawInsert('''
          INSERT OR REPLACE INTO ${AppConstants.tblAppSettings} (business_id, key, value)
          VALUES (?, ?, ?)
        ''', [businessId, entry.key, entry.value]);
      }
    });
  }
}
