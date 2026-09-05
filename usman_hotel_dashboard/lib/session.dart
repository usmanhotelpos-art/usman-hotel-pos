import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

// Dashboard connects silently with the built-in admin account (no login
// screen for now). The credentials below are the server's seeded defaults.
const String dashEmail = 'admin@usmanhotel.com';
const String dashPassword = 'admin123';

Future<void> saveSession(String token, Map<String, dynamic> user) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('dashToken', token);
  await prefs.setString('dashUser', jsonEncode(user));
  await prefs.setString('serverUrl', ApiClient.host);
}

Future<String?> loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('dashToken');
}

Future<Map<String, dynamic>?> loadUser() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('dashUser');
  if (raw == null || raw.isEmpty) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return null;
  }
}

int tokenExpiryMs(String tok) {
  try {
    final parts = tok.split('.');
    if (parts.length != 3) return 0;
    final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final exp = (payload is Map && payload['exp'] != null)
        ? (payload['exp'] as num).toInt()
        : 0;
    return exp * 1000;
  } catch (_) {
    return 0;
  }
}