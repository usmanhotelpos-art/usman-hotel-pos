import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isAuthError;
  ApiException(this.message, {this.statusCode, this.isAuthError = false});
  @override
  String toString() => message;
}

class ApiClient {
  static String host = '';
  static const String defaultHost =
      'https://usman-hotel-pos-server-production.up.railway.app';

  static String get base => '$host/api';
  // Dashboard shows ALL orders from every app, so it always hits the live
  // hosted API (no private-IP override).
  static void setHost(String url) {
    var u = url.trim();
    if (u.isEmpty) {
      host = defaultHost;
      return;
    }
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (u.endsWith('/api')) u = u.substring(0, u.length - 4);
    if (u.endsWith('/api/')) u = u.substring(0, u.length - 5);
    host = u;
  }

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  static Future<dynamic> send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$base$path');
    late http.Response res;
    final timeout = Duration(seconds: method == 'GET' ? 25 : 30);
    try {
      if (method == 'GET') {
        res = await http.get(url, headers: _headers(token)).timeout(timeout);
      } else if (method == 'POST') {
        res = await http
            .post(url, headers: _headers(token), body: jsonEncode(body ?? {}))
            .timeout(timeout);
      } else if (method == 'PUT') {
        res = await http
            .put(url, headers: _headers(token), body: jsonEncode(body ?? {}))
            .timeout(timeout);
      } else if (method == 'DELETE') {
        res = await http.delete(url, headers: _headers(token)).timeout(timeout);
      } else {
        throw ApiException('Unsupported method $method');
      }
    } on TimeoutException {
      throw ApiException('Server time out. Zara baad mein try karein.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error. Server on ho?  $e');
    }

    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Error ${res.statusCode}';
    throw ApiException(
      msg,
      statusCode: res.statusCode,
      isAuthError: res.statusCode == 401 || res.statusCode == 403,
    );
  }

  static Future<String?> refreshToken(String stored) async {
    try {
      final data = await send('POST', '/auth/refresh', token: stored);
      if (data is Map && data['token'] != null) return data['token'].toString();
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final data = await send('POST', '/auth/login',
        body: {'email': email, 'password': password});
    if (data is! Map || data['token'] == null || data['user'] == null) {
      throw ApiException('Login failed');
    }
    return {
      'token': data['token'].toString(),
      'user': Map<String, dynamic>.from(data['user'] as Map),
    };
  }
}