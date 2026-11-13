import 'dart:io';

import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import 'media_upload_service.dart';

class MediaMigrationProgress {
  final int completed;
  final int total;
  final String currentItem;

  const MediaMigrationProgress({
    required this.completed,
    required this.total,
    required this.currentItem,
  });
}

class MediaMigrationResult {
  final int migrated;
  final int skipped;
  final int failed;

  const MediaMigrationResult({
    required this.migrated,
    required this.skipped,
    required this.failed,
  });
}

class MediaMigrationService {
  static Future<MediaMigrationResult> migrateLocalMedia({
    required int businessId,
    void Function(MediaMigrationProgress progress)? onProgress,
  }) async {
    if (!MediaUploadService.isConfigured) {
      throw const MediaUploadException(
        'Cloudinary is not configured. Set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.',
      );
    }

    final db = DatabaseHelper.instance;
    final items = <({String table, String column, int id, String path})>[];

    final products = await db.rawQuery(
      "SELECT id, image_path FROM ${AppConstants.tblProducts} WHERE business_id = ? AND image_path IS NOT NULL AND image_path <> ''",
      [businessId],
    );
    for (final row in products) {
      final path = row['image_path']?.toString();
      if (path != null && !MediaUploadService.isRemoteUrl(path)) {
        items.add((table: AppConstants.tblProducts, column: 'image_path', id: (row['id'] as num).toInt(), path: path));
      }
    }

    final offers = await db.rawQuery(
      "SELECT id, poster_path FROM ${AppConstants.tblOffers} WHERE business_id = ? AND poster_path IS NOT NULL AND poster_path <> ''",
      [businessId],
    );
    for (final row in offers) {
      final path = row['poster_path']?.toString();
      if (path != null && !MediaUploadService.isRemoteUrl(path)) {
        items.add((table: AppConstants.tblOffers, column: 'poster_path', id: (row['id'] as num).toInt(), path: path));
      }
    }

    var migrated = 0;
    var skipped = 0;
    var failed = 0;
    var completed = 0;

    for (final item in items) {
      final fileExists = await File(item.path).exists();
      if (!fileExists) {
        skipped++;
      } else {
        try {
          final secureUrl = await MediaUploadService.uploadMedia(item.path);
          final count = await db.update(item.table, {item.column: secureUrl}, item.id);
          if (count > 0) {
            migrated++;
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        }
      }

      completed++;
      onProgress?.call(MediaMigrationProgress(
        completed: completed,
        total: items.length,
        currentItem: item.path.split(Platform.pathSeparator).last,
      ));
    }

    return MediaMigrationResult(migrated: migrated, skipped: skipped, failed: failed);
  }
}
