import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static String? _token;
  static Map<String, dynamic>? _user;

  static String? get token => _token;
  static Map<String, dynamic>? get user => _user;
  static String get userName => _user?['name'] ?? 'User';
  static String get userRole => _user?['role'] ?? 'staff';
  static bool get isManager => userRole == 'manager';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('stock_token');
    final userRaw = prefs.getString('stock_user');
    if (userRaw != null) {
      try {
        _user = jsonDecode(userRaw) as Map<String, dynamic>;
      } catch (_) {
        _user = null;
      }
    }
  }

  static Future<void> save(String token, Map<String, dynamic> user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stock_token', token);
    await prefs.setString('stock_user', jsonEncode(user));
  }

  static Future<void> clear() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('stock_token');
    await prefs.remove('stock_user');
  }

  static bool get isLoggedIn => _token != null && _user != null;
}
