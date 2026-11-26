// lib/core/services/backup_service.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import '../database/database_helper.dart';
import '../constants/app_constants.dart';

class BackupService {
  static final _key = enc.Key.fromUtf8('biz_next_secret_key_32_chars_ok!');
  static final _iv = enc.IV.fromLength(16);

  static Future<String?> exportDatabase() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDir.path, 'BizNext', AppConstants.dbName);
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return 'System data not found.';
      }

      // 1. Choose location
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export System Configuration',
        fileName: 'Config_${DateTime.now().millisecondsSinceEpoch}.${AppConstants.backupExtension}',
        type: FileType.any,
      );

      if (outputFile == null) return null;

      // 2. Read and Encrypt
      final bytes = await dbFile.readAsBytes();
      final encrypter = enc.Encrypter(enc.AES(_key));
      final encrypted = encrypter.encryptBytes(bytes, iv: _iv);

      // 3. Save Encrypted File
      await File(outputFile).writeAsBytes(encrypted.bytes);
      
      return 'Configuration exported successfully.';
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  static Future<String?> importDatabase() async {
    try {
      // 1. Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [AppConstants.backupExtension],
        dialogTitle: 'Select Configuration File',
      );

      if (result == null || result.files.single.path == null) return null;
      final selectedFile = File(result.files.single.path!);
      return await restoreFromFile(selectedFile);
    } catch (e) {
      return 'Import failed: $e';
    }
  }

  static Future<String?> restoreFromFile(File selectedFile) async {
    try {
      // 1. Decrypt bytes
      final encryptedBytes = await selectedFile.readAsBytes();
      final encrypter = enc.Encrypter(enc.AES(_key));
      
      final decryptedBytes = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: _iv);

      // 2. Close current database
      await DatabaseHelper.instance.close();

      // 3. Define target path
      final documentsDir = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDir.path, 'BizNext', AppConstants.dbName);
      
      // 4. Ensure directory exists
      await Directory(dirname(dbPath)).create(recursive: true);

      // 5. Replace file with decrypted data
      await File(dbPath).writeAsBytes(decryptedBytes);

      return 'Data restored successfully. Refreshing...';
    } catch (e) {
      return 'Import failed: Invalid file or corrupted data.';
    }
  }

  static Future<File?> findAvailableBackup() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      // Look for the obfuscated backup file
      final backupFile = File(join(documentsDir.path, 'biz_next_backup.${AppConstants.backupExtension}'));
      if (await backupFile.exists()) {
        return backupFile;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
