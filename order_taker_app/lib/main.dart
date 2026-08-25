import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'login_screen.dart';
import 'order_taker_screen.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  ApiClient.setHost(prefs.getString('serverUrl') ?? ApiClient.defaultHost);
  runApp(const OrderTakerApp());
}

class OrderTakerApp extends StatelessWidget {
  const OrderTakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Usman Hotel Order Taker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const Gate(),
    );
  }
}

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('orderTakerToken');
    final userRaw = prefs.getString('orderTakerUser');
    Map<String, dynamic>? user;
    if (userRaw != null) {
      try {
        user = Map<String, dynamic>.from(jsonDecode(userRaw) as Map);
      } catch (_) {}
    }
    if (!mounted) return;
    if (token != null &&
        token.isNotEmpty &&
        user != null &&
        allowedRoles.contains(user['role'])) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final exp = tokenExpiryMs(token);
      if (exp == 0 || exp > nowMs - 60000) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => OrderTakerScreen(token: token, user: user!),
        ));
        setState(() => _done = true);
        if (exp != 0 && exp < nowMs + 30 * 60 * 1000) {
          refreshTokenOp(token);
        }
        return;
      }
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/img/logo.png', width: 110),
            const SizedBox(height: 18),
            if (!_done) const CircularProgressIndicator(color: Color(0xFFF5C542)),
          ],
        ),
      ),
    );
  }
}
