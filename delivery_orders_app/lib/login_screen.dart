import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'api.dart';
import 'order_taker_screen.dart';
import 'session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String message = '';
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { loading = true; message = ''; });
    try {
      final data = await ApiClient.send('POST', '/auth/login',
          body: {'email': _emailCtrl.text.trim(), 'password': _passCtrl.text});
      if (data is! Map || data['user'] == null || data['token'] == null) {
        throw ApiException('Login failed');
      }
      final user = Map<String, dynamic>.from(data['user'] as Map);
      if (!allowedRoles.contains(user['role'])) {
        throw ApiException('Invalid credentials for this app');
      }
      final token = data['token'].toString();
      await saveSession(token, user);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OrderTakerScreen(token: token, user: user),
      ));
    } on ApiException catch (e) {
      setState(() => message = e.message);
    } catch (e) {
      setState(() => message = 'Login failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Stack(fit: StackFit.expand, children: [
          _bg(),
          const _DarkOverlay(),
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 12),
                    _logoPulse(),
                    const SizedBox(height: 6),
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [Color(0xFF93C5FD), Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      ).createShader(r),
                      child: const Text('USMAN HOTEL', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
                    ),
                    const Text('FAST  •  DELIVERY  •  RIDER',
                        style: TextStyle(fontSize: 11, letterSpacing: 5, color: Color(0xFF3B82F6), fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    const Text('\u{1F69A} Evening Rider App', style: TextStyle(fontSize: 15, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 18),
                    _loginCard(),
                    const SizedBox(height: 20),
                  ]),
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }

  Widget _bg() {
    final t = Curves.easeInOut.transform((sin(_ctrl.value * 2 * pi) + 1) / 2);
    return Image.asset('assets/img/bbq_bg.jpg',
        fit: BoxFit.cover,
        alignment: Alignment(lerpDouble(-0.08, 0.08, t)!, lerpDouble(-0.05, 0.05, t)!));
  }

  Widget _logoPulse() {
    final t = (sin(_ctrl.value * 2 * pi * 3) + 1) / 2;
    final scale = 1.0 + 0.04 * t;
    return Transform.scale(
      scale: scale,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFFF5C542).withValues(alpha: 0.25 + 0.25 * t), blurRadius: 40, spreadRadius: 4)],
        ),
        child: ClipOval(child: Image.asset('assets/img/logo.png', width: 108, height: 108)),
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
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14),
          decoration: _inputDeco('Username'),
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
        if (message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF4C0519).withValues(alpha: .6), borderRadius: BorderRadius.circular(8)),
            child: Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFFFDA4AF))),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (loading || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) ? null : _login,
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

class _DarkOverlay extends StatelessWidget {
  const _DarkOverlay();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF020617).withValues(alpha: .72), const Color(0xFF020617).withValues(alpha: .38), const Color(0xFF020617).withValues(alpha: .85)],
          stops: const [0, 0.42, 1],
        ),
      ),
    );
  }
}
