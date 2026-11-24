import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../security/token_service.dart';

class BackendApiException implements Exception {
  final String message;
  final int statusCode;
  const BackendApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class BackendApiService {
  static const Duration timeoutDuration = Duration(seconds: 20);

  static Uri get root {
    const configured = String.fromEnvironment('BIZNEXT_API_BASE_URL');
    String base;
    if (configured.isNotEmpty) {
      base = configured;
    } else if (!kIsWeb && Platform.isAndroid) {
      base = 'http://10.0.2.2:8080';
    } else {
      base = 'http://localhost:8080';
    }

    final uri = Uri.parse(base);
    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.endsWith('/api/customers')) {
      path = path.substring(0, path.length - '/customers'.length);
    } else if (path.endsWith('/api')) {
      // already rooted
    } else {
      path = '$path/api';
    }
    return uri.replace(path: path);
  }

  static Uri uri(String path, [Map<String, String>? query]) =>
      root.replace(path: '${root.path}/$path', queryParameters: query);

  static Future<Map<String, String>> headers() async {
    final token = await TokenService.instance.getActiveToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String path,
      [Map<String, String>? query]) async {
    try {
      return await http
          .get(uri(path, query), headers: await headers())
          .timeout(timeoutDuration);
    } on TimeoutException {
      throw const BackendApiException(
          'Connection timed out. Please check your network connection.', 504);
    } on SocketException {
      throw const BackendApiException(
          'Cannot connect to the server. Please verify the backend is running.',
          503);
    }
  }

  static Future<http.Response> post(String path, Object body) async {
    try {
      return await http
          .post(uri(path), headers: await headers(), body: jsonEncode(body))
          .timeout(timeoutDuration);
    } on TimeoutException {
      throw const BackendApiException(
          'Connection timed out. Please check your network connection.', 504);
    } on SocketException {
      throw const BackendApiException(
          'Cannot connect to the server. Please verify the backend is running.',
          503);
    }
  }

  static Future<http.Response> put(
      String path, Object body, [Map<String, String>? query]) async {
    try {
      return await http
          .put(uri(path, query),
              headers: await headers(), body: jsonEncode(body))
          .timeout(timeoutDuration);
    } on TimeoutException {
      throw const BackendApiException(
          'Connection timed out. Please check your network connection.', 504);
    } on SocketException {
      throw const BackendApiException(
          'Cannot connect to the server. Please verify the backend is running.',
          503);
    }
  }

  static Future<http.Response> delete(
      String path, [Map<String, String>? query]) async {
    try {
      return await http
          .delete(uri(path, query), headers: await headers())
          .timeout(timeoutDuration);
    } on TimeoutException {
      throw const BackendApiException(
          'Connection timed out. Please check your network connection.', 504);
    } on SocketException {
      throw const BackendApiException(
          'Cannot connect to the server. Please verify the backend is running.',
          503);
    }
  }

  static Future<Map<String, dynamic>> uploadMultipart(
    String path,
    String localFilePath, {
    String fileField = 'file',
    Map<String, String>? fields,
  }) async {
    try {
      final token = await TokenService.instance.getActiveToken();
      final request = http.MultipartRequest('POST', uri(path));
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.add(await http.MultipartFile.fromPath(fileField, localFilePath));
      final streamed = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamed);
      final decoded = decode(response);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on TimeoutException {
      throw const BackendApiException(
          'Image upload timed out. Please check your network connection.', 504);
    } on SocketException {
      throw const BackendApiException(
          'Cannot connect to the server for image upload.', 503);
    }
  }

  static dynamic decode(http.Response response) {
    _throwIfError(response);
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  static void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = 'API request failed.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      } else if (decoded is Map && decoded['error'] is String) {
        message = decoded['error'] as String;
      }
    } catch (_) {}
    throw BackendApiException(message, response.statusCode);
  }
}
