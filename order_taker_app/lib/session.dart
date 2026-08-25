import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

const List<String> allowedRoles = ['Order Taker', 'Admin Order Taker', 'Takeaway Order Taker', 'Table Order Taker', 'Waiter', 'Helper'];

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
  await prefs.setString('orderTakerToken', token);
  await prefs.setString('orderTakerUser', jsonEncode(user));
  await prefs.setString('serverUrl', ApiClient.host);
}

Future<String?> refreshTokenOp(String stored) async {
  if (stored.isEmpty) return null;
  final newToken = await ApiClient.refreshToken(stored);
  if (newToken != null && newToken.isNotEmpty) {
    await SharedPreferences.getInstance().then((p) {
      p.setString('orderTakerToken', newToken);
    });
  }
  return newToken;
}
