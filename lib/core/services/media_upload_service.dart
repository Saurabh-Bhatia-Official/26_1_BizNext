import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class MediaUploadService {
  static const String _cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const String _uploadPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  static bool get isConfigured => _cloudName.isNotEmpty && _uploadPreset.isNotEmpty;

  static bool isRemoteUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('https://') || normalized.startsWith('http://');
  }

  /// Uploads an image using a restricted Cloudinary unsigned upload preset.
  /// The Cloudinary API secret must never be shipped in the Flutter application.
  static Future<String> uploadMedia(String localPath) async {
    if (!isConfigured) {
      throw const MediaUploadException(
        'Cloudinary is not configured. Build with CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.',
      );
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw const MediaUploadException('The selected image file could not be found.');
    }

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
}

class MediaUploadException implements Exception {
  final String message;

  const MediaUploadException(this.message);

  @override
  String toString() => message;
}
