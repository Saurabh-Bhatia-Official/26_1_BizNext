import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'backend_api_service.dart';

class MediaUploadService {
  static const String _cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const String _uploadPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  static bool get isConfigured => _cloudName.isNotEmpty && _uploadPreset.isNotEmpty;

  static bool isRemoteUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('https://') || normalized.startsWith('http://');
  }

  /// Uploads media to Cloudinary.
  /// Prefers signed backend upload (/api/media/upload) so no API secret is exposed in Flutter.
  /// Falls back to direct unsigned preset if backend is unavailable and preset is configured.
  static Future<String> uploadMedia(String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw const MediaUploadException('The selected image file could not be found.');
    }

    // 1. Try secure backend-signed upload
    try {
      final result = await BackendApiService.uploadMultipart('media/upload', localPath);
      if (result['url'] is String && (result['url'] as String).isNotEmpty) {
        return result['url'] as String;
      }
    } catch (_) {
      // Backend unavailable or rejected, check if direct preset is configured
      if (!isConfigured) {
        rethrow;
      }
    }

    // 2. Direct unsigned upload preset fallback
    if (isConfigured) {
      final request = http.MultipartRequest(
        'POST',
        Uri.https('api.cloudinary.com', '/v1_1/$_cloudName/image/upload'),
      )..fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', localPath));

      try {
        final streamed = await request.send().timeout(const Duration(seconds: 60));
        final response = await http.Response.fromStream(streamed);
        final decoded = jsonDecode(response.body);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final message = decoded is Map<String, dynamic>
              ? (decoded['error'] as Map<String, dynamic>?)?['message'] as String?
              : null;
          throw MediaUploadException(message ?? 'Cloudinary upload failed (${response.statusCode}).');
        }
        if (decoded is! Map<String, dynamic> || decoded['secure_url'] is! String) {
          throw const MediaUploadException('Cloudinary returned an invalid upload response.');
        }
        return decoded['secure_url'] as String;
      } on MediaUploadException {
        rethrow;
      } on Exception catch (error) {
        throw MediaUploadException('Image upload failed: $error');
      }
    }

    throw const MediaUploadException(
      'Media upload failed. Ensure the BizNext backend is running or configure Cloudinary presets.',
    );
  }
}

class MediaUploadException implements Exception {
  final String message;

  const MediaUploadException(this.message);

  @override
  String toString() => message;
}
