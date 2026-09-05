import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'dashboard_screen.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  ApiClient.setHost(prefs.getString('serverUrl') ?? ApiClient.defaultHost);
  runApp(const DashboardApp());
}

class DashboardApp extends StatefulWidget {
  const DashboardApp({super.key});

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  ThemeMode _mode = ThemeMode.light;

  void _setMode(ThemeMode m) => setState(() => _mode = m);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Usman Hotel Dashboard',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _mode,
      home: SplashScreen(onToggleTheme: _setMode),
    );
  }

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    const seed = Color(0xFF059669);
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorSchemeSeed: seed,
      fontFamily: 'Noto Naskh Arabic',
    );
    return base.copyWith(
      scaffoldBackgroundColor: dark ? const Color(0xFF0B1220) : const Color(0xFFF4F6FB),
      cardColor: dark ? const Color(0xFF111A2C) : Colors.white,
      dividerColor: dark ? const Color(0xFF1E2A44) : const Color(0xFFE5EAF2),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

class SplashScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onToggleTheme;
  const SplashScreen({super.key, required this.onToggleTheme});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  String _status = 'Connecting to Usman Hotel server...';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0,
      upperBound: 1,
    )..forward();
    _boot();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      var token = await loadToken();
      var user = await loadUser();
      if (token != null && user != null) {
        final exp = tokenExpiryMs(token);
        if (exp > 0 && exp < DateTime.now().millisecondsSinceEpoch) {
          final fresh = await ApiClient.refreshToken(token);
          if (fresh != null) {
            token = fresh;
            await saveSession(fresh, user);
          }
        }
      }
      if (token == null || user == null) {
        setState(() => _status = 'Auto login kar rahe hain...');
        final r = await ApiClient.login(dashEmail, dashPassword);
        final rt = r['token'];
        final ru = r['user'];
        if (rt is! String || ru is! Map) throw ApiException('Login failed');
        token = rt;
        user = Map<String, dynamic>.from(ru);
        await saveSession(token, user);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            DashboardScreen(token: token!, user: user!, onToggleTheme: widget.onToggleTheme),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Server connect nahi hua.\n$e');
    }
  }

  void _retry() {
    setState(() => _status = 'Connecting to Usman Hotel server...');
    _boot();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF0B1220)
        : const Color(0xFF07101F);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                  Color(0x8821253A), BlendMode.srcIn),
              child: Image.asset('assets/img/bbq_bg.jpg', fit: BoxFit.cover),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _ctrl,
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x99F5C542),
                              blurRadius: 44,
                              spreadRadius: 6)
                        ],
                        border: Border.all(color: const Color(0xFFF5C542), width: 3),
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/img/logo.png',
                            fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store, size: 60, color: Color(0xFFF5C542))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text('USMAN HOTEL',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white)),
                const Text('DASHBOARD',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        color: Color(0xFFF5C542))),
                const SizedBox(height: 34),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(_status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF9FB0C9))),
                ),
                const SizedBox(height: 18),
                if (_status.contains('nahi hua'))
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFF5C542))),
                  )
                else
                  const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Color(0xFFF5C542))),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: Colors.white,
                ),
                onPressed: () => widget.onToggleTheme(
                    Theme.of(context).brightness == Brightness.dark
                        ? ThemeMode.light
                        : ThemeMode.dark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}