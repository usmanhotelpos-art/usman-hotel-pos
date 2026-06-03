import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';

class ApiService {
  static String _baseUrl = 'http://10.0.2.2:5000/api';

  static void setBaseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '') + '/api';
  }

  static String get baseUrl => _baseUrl;

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('riderToken');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('riderToken', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('riderToken');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final h = <String, String>{'Content-Type': 'application/json'};
    final token = await getToken();
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['error']?.toString() ?? 'Server error: ${res.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> _fetchList(String url) async {
    final res = await http.get(Uri.parse(url), headers: await _authHeaders()).timeout(const Duration(seconds: 15));
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  // Auth
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/rider-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 15));
    return _handleResponse(res);
  }

  static Future<Rider> getRiderInfo() async {
    final res = await http.get(Uri.parse('$_baseUrl/auth/rider-me'), headers: await _authHeaders()).timeout(const Duration(seconds: 10));
    final data = await _handleResponse(res);
    return Rider.fromJson(data);
  }

  // Settings
  static Future<HotelSettings> getSettings() async {
    final res = await http.get(Uri.parse('$_baseUrl/settings')).timeout(const Duration(seconds: 10));
    return HotelSettings.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // Orders
  static Future<List<Map<String, dynamic>>> getAssignedOrders(String riderId) => _fetchList('$_baseUrl/rider/assigned-orders/$riderId');

  static Future<List<Map<String, dynamic>>> getDeliveredOrders(String riderId, String paymentMethod) => _fetchList('$_baseUrl/rider/delivered-orders/$riderId/$paymentMethod');

  static Future<List<Map<String, dynamic>>> getAllOrders() => _fetchList('$_baseUrl/pos/orders');

  static Future<List<Map<String, dynamic>>> getProducts() => _fetchList('$_baseUrl/pos/products');

  static Future<List<Map<String, dynamic>>> getRiders() => _fetchList('$_baseUrl/riders');

  static Future<void> markOrderDelivered(String orderId, Map<String, dynamic> existing, String paymentMethod, String paymentStatus, String deliveryAgent) async {
    await http.put(
      Uri.parse('$_baseUrl/pos/orders/$orderId'),
      headers: await _authHeaders(),
      body: jsonEncode({...existing, 'status': 'Payment Collected', 'paymentMethod': paymentMethod, 'paymentStatus': paymentStatus, 'deliveryAgent': deliveryAgent}),
    ).timeout(const Duration(seconds: 15));
  }

  static Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    await http.put(Uri.parse('$_baseUrl/pos/orders/$orderId'), headers: await _authHeaders(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
  }

  static Future<void> deleteOrder(String orderId) async {
    await http.delete(Uri.parse('$_baseUrl/pos/orders/$orderId'), headers: await _authHeaders()).timeout(const Duration(seconds: 15));
  }

  static Future<void> assignRiderToOrder(String orderId, Map<String, dynamic> existing, String riderName, String riderId) async {
    await http.put(
      Uri.parse('$_baseUrl/pos/orders/$orderId'),
      headers: await _authHeaders(),
      body: jsonEncode({...existing, 'deliveryAgent': riderName, 'deliveryAgentId': riderId, 'status': 'Riders Assigned'}),
    ).timeout(const Duration(seconds: 15));
  }
}
