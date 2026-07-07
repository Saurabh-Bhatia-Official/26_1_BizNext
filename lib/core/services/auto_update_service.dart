// lib/core/services/auto_update_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

class AutoUpdateService {
  static const String _baseUrl = "http://localhost:8000/api/v1";

  Future<Map<String, dynamic>?> checkAndUpdate() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/update/check?current_version=${AppConstants.appVersion}"),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool updateAvailable = data['update_available'] ?? false;
        
        if (updateAvailable) {
          final String downloadUrl = data['download_url'];
          final String latestVersion = data['latest_version'];
          return {
            "update_available": true,
            "version": latestVersion,
            "download_url": downloadUrl,
          };
        }
      }
    } catch (e) {
      if (kDebugMode) print("Update check failed: $e");
    }
    return {"update_available": false};
  }

  Future<bool> downloadAndInstallUpdate(String downloadUrl, Function(double) onProgress) async {
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request).timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) return false;

      final bytes = <int>[];
      final total = response.contentLength ?? 0;
      var received = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress(received / total);
        }
      }

      // Save executable to temporary directory
      final tempDir = await getTemporaryDirectory();
      final updateFile = File('${tempDir.path}/biz_next_update.exe');
      await updateFile.writeAsBytes(bytes);

      if (kDebugMode) print("Update downloaded to ${updateFile.path}");

      // Launch executable and exit the app (Desktop only)
      if (Platform.isWindows) {
        await Process.start(updateFile.path, []);
        exit(0);
      }
      return true;
    } catch (e) {
      if (kDebugMode) print("Failed to install update: $e");
      return false;
    }
  }
}
