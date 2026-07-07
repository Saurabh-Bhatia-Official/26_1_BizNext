import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MediaUploadService {
  static const String _baseUrl = "http://localhost:8000/api/v1";

  static Future<String> uploadMedia(String localPath) async {
    final prefs = await SharedPreferences.getInstance();
    final tier = prefs.getString('subscription_tier') ?? 'free';
    
    // If not PRO, simply return the local path to store in local SQLite database
    if (tier != 'pro') {
      if (kDebugMode) print("User is FREE tier. Storing media locally: $localPath");
      return localPath;
    }
    
    // If PRO, attempt to upload to Cloudinary via backend
    try {
      if (kDebugMode) print("User is PRO tier. Uploading media to Cloudinary...");
      // In a real app, you would retrieve the actual token from Auth provider
      final token = "dummy_token_12345";
      
      var request = http.MultipartRequest('POST', Uri.parse("$_baseUrl/upload"));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', localPath));
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        if (data['status'] == 'success' && data['url'] != null) {
          if (kDebugMode) print("Cloudinary upload success: ${data['url']}");
          return data['url']; // Return the Cloudinary URL
        }
      } else {
        if (kDebugMode) print("Backend upload failed with status ${response.statusCode}: $responseData");
      }
    } catch (e) {
      if (kDebugMode) print("Media upload error: $e");
    }
    
    // Fallback to local path if upload fails
    return localPath;
  }
}
