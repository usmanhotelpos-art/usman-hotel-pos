import 'dart:math';

import 'package:flutter/material.dart';

import 'api.dart';
import 'embedded/delivery/api.dart' as del_api;
import 'embedded/nashta/api.dart' as nash_api;
import 'launcher_screen.dart';
import 'session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();
  bool loading = false;
  bool obscure = true;
  bool advanced = false;
  String message = '';
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    _serverCtrl.text = ApiClient.host;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      if (advanced && _serverCtrl.text.trim().isNotEmpty) {
        ApiClient.setHost(_serverCtrl.text.trim());
      }
      final data = await ApiClient.send('POST', '/auth/login',
          body: {'email': _userCtrl.text.trim(), 'password': _passCtrl.text});
      if (data is! Map || data['user'] == null || data['token'] == null) {
        throw ApiException('Login failed');
      }
      final user = Map<String, dynamic>.from(data['user'] as Map);
      final token = data['token'].toString();
      if (!roleAllowedInDelivery(user['role']) &&
          !roleAllowedInNashta(user['role'])) {
        throw ApiException('Invalid credentials for this app');
      }
      await saveSession(token, user);
      await _refreshEmbeddedHosts();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => LauncherScreen(token: token, user: user),
      ));
    } on ApiException catch (e) {
      setState(() => message = e.message);
    } catch (e) {
      setState(() => message = 'Login failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _refreshEmbeddedHosts() async {
    del_api.ApiClient.setHost(ApiClient.host);
    nash_api.ApiClient.setHost(ApiClient.host);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 16),
                  _logoPulse(),
                  const SizedBox(height: 26),
                  _loginCard(),
                  const SizedBox(height: 20),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _logoPulse() {
    final t = (sin(_ctrl.value * 2 * pi * 3) + 1) / 2;
    final scale = 1.0 + 0.04 * t;
    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3 + 0.3 * t),
                blurRadius: 44,
                spreadRadius: 3),
          ],
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset('assets/img/logo.png',
              width: 112, height: 112, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _loginCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF5C542).withValues(alpha: .35)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Column(children: [
        TextField(
          controller: _userCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14),
          decoration: _inputDeco('Username / Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: obscure,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _login(),
          style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14),
          decoration: _inputDeco('Password').copyWith(
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8), size: 18),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 4),
            Text('Server',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: .7),
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => advanced = !advanced),
              child: Text(advanced ? 'Hide ' : 'Change ',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF93C5FD),
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        if (advanced) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _serverCtrl,
            style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 13),
            decoration: _inputDeco('Server URL'),
          ),
        ],
        if (message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF4C0519).withValues(alpha: .6), borderRadius: BorderRadius.circular(8)),
            child: Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFFFDA4AF))),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (loading || _userCtrl.text.isEmpty || _passCtrl.text.isEmpty) ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF1D4ED8).withValues(alpha: .5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(loading ? 'Logging in...' : 'Login', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF020617),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.4)),
    );
  }
}