import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  /// e.g. http://192.168.1.5:4000 (no trailing slash, no /api)
  static String host = '';

  /// Default server used when the login field is left empty.
  static const String defaultHost =
      'https://usman-hotel-pos-server-production.up.railway.app';

  static String get base => '$host/api';

  static void setHost(String url) {
    var h = url.trim();
    if (_shouldUseDefault(h)) h = defaultHost;
    final uri = Uri.tryParse(h);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      h = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    }
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    if (h.endsWith('/api')) {
      h = h.substring(0, h.length - 4);
    }
    host = h;
  }

  static bool _shouldUseDefault(String url) {
    final h = url.trim().toLowerCase();
    if (h.isEmpty) return true;
    final uri = Uri.tryParse(h.startsWith('http') ? h : 'http://$h');
    final host = uri?.host ?? '';
    if (host == 'localhost' || host == '127.0.0.1') return true;
    if (host.startsWith('10.') || host.startsWith('192.168.')) return true;
    final parts = host.split('.');
    if (parts.length == 4 && parts.first == '172') {
      final second = int.tryParse(parts[1]);
      if (second != null && second >= 16 && second <= 31) return true;
    }
    return false;
  }

  static Map<String, String> _headers(String? token) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> send(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final uri = Uri.parse('$base$path');
    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http
              .get(uri, headers: _headers(token))
              .timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          res = await http
              .post(uri, headers: _headers(token), body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 25));
          break;
        case 'PUT':
          res = await http
              .put(uri, headers: _headers(token), body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 25));
          break;
        case 'DELETE':
          res = await http
              .delete(uri, headers: _headers(token))
              .timeout(const Duration(seconds: 25));
          break;
        default:
          throw ApiException('Unsupported method');
      }
    } on TimeoutException {
      throw ApiException(
        'Railway server sync timeout. Internet connection check karein aur retry karein: $base',
      );
    } on Exception catch (e) {
      throw ApiException('Network error: $e');
    }

    dynamic data;
    try {
      data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      data = <String, dynamic>{};
    }

    if (res.statusCode >= 400) {
      final msg =
          (data is Map && data['error'] != null)
              ? data['error'].toString()
              : 'Request failed';
      throw ApiException(msg);
    }
    return data;
  }

  static Future<String?> refreshToken(String stored) async {
    if (stored.isEmpty) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$base/auth/refresh'),
            headers: _headers(stored),
            body: '{}',
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) return null;
      final data = jsonDecode(res.body);
      if (data is Map && data['token'] != null) return data['token'] as String;
      return null;
    } catch (_) {
      return null;
    }
  }
}
