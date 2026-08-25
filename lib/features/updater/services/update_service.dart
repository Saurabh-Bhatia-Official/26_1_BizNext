import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/update_info.dart';

class UpdateService {
  // Replace with your actual update server URL
  static const String _updateUrl = 'https://example.com/api/updates/latest.json';
  static const String _historyUrl = 'https://example.com/api/updates/history.json';
  
  final Dio _dio = Dio();

  /// Checks if an update is available.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get(_updateUrl);
      if (response.statusCode == 200) {
        final latestUpdate = UpdateInfo.fromJson(response.data);
        final packageInfo = await PackageInfo.fromPlatform();
        
        final currentVersion = packageInfo.version;
        if (_isNewerVersion(currentVersion, latestUpdate.version)) {
          return latestUpdate;
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }
  
  /// Fetches the version history.
  Future<List<UpdateInfo>> fetchVersionHistory() async {
    try {
      final response = await _dio.get(_historyUrl);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UpdateInfo.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching version history: $e');
    }
    return [];
  }

  /// Downloads and installs the update.
  Future<void> downloadAndInstall(UpdateInfo update, {Function(int, int)? onReceiveProgress}) async {
    try {
      final downloadUrl = Platform.isWindows ? update.exeUrl : update.apkUrl;
      final fileName = Platform.isWindows ? 'BizNext_Update.exe' : 'BizNext_Update.apk';
      
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$fileName';

      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: onReceiveProgress,
      );

      await _installUpdate(savePath);
    } catch (e) {
      debugPrint('Error downloading update: $e');
      rethrow;
    }
  }

  Future<void> _installUpdate(String filePath) async {
    final result = await OpenFile.open(filePath);
    debugPrint('Install result: ${result.message}');
  }

  bool _isNewerVersion(String currentVersion, String latestVersion) {
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    final latestParts = latestVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final current = i < currentParts.length ? currentParts[i] : 0;
      final latest = i < latestParts.length ? latestParts[i] : 0;
      if (latest > current) return true;
      if (latest < current) return false;
    }
    return false;
  }
}
