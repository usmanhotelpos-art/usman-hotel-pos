import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

const List<String> deliveryRoles = [
  'Order Taker',
  'Admin Order Taker',
  'Takeaway Order Taker',
  'Table Order Taker',
  'Waiter',
  'Helper',
  'Cashier',
  'Admin',
  'Manager',
  'Admin Rider',
  'Biker',
  'Rider',
];

const List<String> nashtaRoles = [
  'Order Taker',
  'Admin Order Taker',
  'Takeaway Order Taker',
  'Table Order Taker',
  'Waiter',
  'Helper',
  'Cashier',
  'Manager',
];

bool roleAllowedInDelivery(String? role) =>
    role != null && deliveryRoles.contains(role);

bool roleAllowedInNashta(String? role) =>
    role != null && nashtaRoles.contains(role);

int tokenExpiryMs(String tok) {
  try {
    final parts = tok.split('.');
    if (parts.length < 2) return 0;
    final norm = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(norm)));
    if (payload is Map && payload['exp'] is num) {
      return ((payload['exp'] as num) * 1000).toInt();
    }
  } catch (_) {}
  return 0;
}

Future<void> saveSession(String token, Map<String, dynamic> user) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('deliveryToken', token);
  await prefs.setString('nashtaToken', token);
  await prefs.setString('deliveryUser', jsonEncode(user));
  await prefs.setString('nashtaUser', jsonEncode(user));
  await prefs.setString('serverUrl', ApiClient.host);
}

Future<Map<String, dynamic>?> loadUser() async {
  final prefs = await SharedPreferences.getInstance();
  final raw =
      prefs.getString('deliveryUser') ?? prefs.getString('nashtaUser');
  if (raw == null || raw.isEmpty) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return null;
  }
}

Future<String?> loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('deliveryToken') ?? prefs.getString('nashtaToken');
}

Future<void> refreshTokens(String stored) async {
  final newToken = await ApiClient.refreshToken(stored);
  if (newToken != null && newToken.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deliveryToken', newToken);
    await prefs.setString('nashtaToken', newToken);
  }
}

Future<void> clearSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('deliveryToken');
  await prefs.remove('deliveryUser');
  await prefs.remove('nashtaToken');
  await prefs.remove('nashtaUser');
}