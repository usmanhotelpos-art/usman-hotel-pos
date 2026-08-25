import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'login_screen.dart';
import 'orders_screen.dart';

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('serverUrl') ?? '';
    final token = prefs.getString('activeOrdersToken') ?? '';
    ApiClient.setHost(server);
    await prefs.setString('serverUrl', ApiClient.host);
    Widget home = LoginScreen(initialServerUrl: ApiClient.host);
    if (token.isNotEmpty) {
      home = const OrdersScreen();
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => home));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF020617),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
    );
  }
}
