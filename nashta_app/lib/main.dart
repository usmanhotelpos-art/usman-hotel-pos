import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'login_screen.dart';
import 'order_taker_screen.dart';
import 'session.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      _showFatal(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _showFatal(error, stack);
      return true;
    };
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    final prefs = await SharedPreferences.getInstance();
    ApiClient.setHost(prefs.getString('serverUrl') ?? ApiClient.defaultHost);
    runApp(const NashtaApp());
  }, (error, stack) {
    _showFatal(error, stack);
  });
}

void _showFatal(Object error, StackTrace? stack) {
  try {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('App Error',
                    style: TextStyle(color: Color(0xFFF5C542), fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(error.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 16),
                Text((stack ?? '').toString(),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    ));
  } catch (_) {}
}

class NashtaApp extends StatelessWidget {
  const NashtaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nashta Usman Hotel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
    _ctrl.forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _decide();
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _decide() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('nashtaToken');
    final userRaw = prefs.getString('nashtaUser');
    Map<String, dynamic>? user;
    if (userRaw != null) {
      try {
        user = Map<String, dynamic>.from(jsonDecode(userRaw) as Map);
      } catch (_) {}
    }
    if (!mounted) return;
    Widget home;
    if (token != null && token.isNotEmpty && user != null && allowedRoles.contains(user['role'])) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final exp = tokenExpiryMs(token);
      if (exp == 0 || exp > nowMs - 60000) {
        home = OrderTakerScreen(token: token, user: user!);
        if (exp != 0 && exp < nowMs + 30 * 60 * 1000) refreshTokenOp(token);
      } else {
        home = const LoginScreen();
      }
    } else {
      home = const LoginScreen();
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => home,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/img/logo.png', width: 110),
                const SizedBox(height: 20),
                const Text('Usman Hotel',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.5)),
                const SizedBox(height: 4),
                const Text('Nashta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                const SizedBox(height: 30),
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFF5C542))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
