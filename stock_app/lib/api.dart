import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, {this.statusCode = 0});
  bool get isAuthError => statusCode == 401 || statusCode == 403;
  @override
  String toString() => message;
}

class ApiClient {
  static String host = '';
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
    final hostName = uri?.host ?? '';
    if (hostName == 'localhost' || hostName == '127.0.0.1') return true;
    if (hostName.startsWith('10.') || hostName.startsWith('192.168.')) return true;
    final parts = hostName.split('.');
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
          res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          res = await http.post(uri, headers: _headers(token), body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          res = await http.put(uri, headers: _headers(token), body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: _headers(token)).timeout(const Duration(seconds: 20));
          break;
        default:
          throw ApiException('Unsupported method: $method');
      }
    } on TimeoutException {
      throw ApiException('Connection timed out');
    } catch (e) {
      throw ApiException('Network error: $e');
    }

    final bodyText = res.body;
    dynamic json;
    try {
      json = bodyText.isNotEmpty ? jsonDecode(bodyText) : null;
    } catch (_) {}

    if (res.statusCode >= 400) {
      final msg = (json is Map && json['error'] != null) ? json['error'].toString() : 'Request failed (${res.statusCode})';
      throw ApiException(msg, statusCode: res.statusCode);
    }

    return json;
  }

  // ─── Stock API Methods ───

  static Future<Map<String, dynamic>> stockLogin(String username, String password) async {
    final res = await send('POST', '/stock/login', body: {'username': username, 'password': password});
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getSettings({String? token}) async {
    final res = await send('GET', '/stock/settings', token: token);
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> data, {String? token}) async {
    final res = await send('PUT', '/stock/settings', token: token, body: data);
    return res as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getProducts({String? token}) async {
    final res = await send('GET', '/stock/products', token: token);
    return res as List<dynamic>;
  }

  static Future<List<dynamic>> getStockOrders({
    String? token,
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    final params = <String>[];
    if (startDate != null && startDate.isNotEmpty) params.add('startDate=$startDate');
    if (endDate != null && endDate.isNotEmpty) params.add('endDate=$endDate');
    if (status != null && status.isNotEmpty) params.add('status=$status');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final res = await send('GET', '/stock/orders$query', token: token);
    return res as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createStockOrder(Map<String, dynamic> data, {String? token}) async {
    final res = await send('POST', '/stock/orders', token: token, body: data);
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> approveStockOrder(String id, {String? token}) async {
    final res = await send('PUT', '/stock/orders/$id/approve', token: token);
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> rejectStockOrder(String id, {String? token}) async {
    final res = await send('PUT', '/stock/orders/$id/reject', token: token);
    return res as Map<String, dynamic>;
  }

  static Future<void> deleteStockOrder(String id, {String? token}) async {
    await send('DELETE', '/stock/orders/$id', token: token);
  }
}
