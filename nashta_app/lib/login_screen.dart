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
          const _MorningGlow(),
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 8),
                    _sunshine(),
                    const SizedBox(height: 4),
                    _logoPulse(),
                    const SizedBox(height: 6),
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFF59E0B), Color(0xFFEA580C)],
                      ).createShader(r),
                      child: const Text('USMAN HOTEL', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
                    ),
                    const SizedBox(height: 2),
                    Text('\u{1F305} NASHATA \u2600\uFE0F BREAKFAST \u{1F305}',
                        style: TextStyle(fontSize: 11, letterSpacing: 3, color: const Color(0xFFB45309), fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    const Text('\u{1F31E} Subah Ki Roshni, Nashta Ki Mithas \u{1F31E}',
                        style: TextStyle(fontSize: 13, color: Color(0xFF7C2D12), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text('\u{1F37D}\uFE0F Nashta App \u{1F64F}',
                        style: TextStyle(fontSize: 15, color: Color(0xFF92400E), fontWeight: FontWeight.w800)),
                    const SizedBox(height: 18),
                    _loginCard(),
                    const SizedBox(height: 16),
                    const Text('\u{1F64F} Dua Ke Saath Sab Unhe Nashta Mile Jo Bhukhe Hain \u{1F64F}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF7C2D12), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
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

  Widget _sunshine() {
    final t = (sin(_ctrl.value * 2 * pi * 3) + 1) / 2;
    final glow = 0.55 + 0.35 * t;
    return Container(
      width: 150,
      height: 86,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color.lerp(const Color(0xFFFFF7D6), const Color(0xFFFDE68A), t)!,
            const Color(0xFFFDE68A).withValues(alpha: 0.2),
          ],
          radius: 1,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(75)),
        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.9), width: 2),
        boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: glow), blurRadius: 46, spreadRadius: 8)],
      ),
      child: SizedBox(
        width: 120,
        height: 60,
        child: CustomPaint(painter: _SunRaysPainter(_ctrl.value)),
      ),
    );
  }

  Widget _logoPulse() {
    final t = (sin(_ctrl.value * 2 * pi * 3) + 1) / 2;
    final scale = 1.0 + 0.04 * t;
    return Transform.scale(
      scale: scale,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3 + 0.3 * t), blurRadius: 40, spreadRadius: 4),
            const BoxShadow(color: Color(0xFFFDE68A), blurRadius: 60, spreadRadius: -12),
          ],
        ),
        child: ClipOval(
          child: Image.asset('assets/img/logo.png', width: 108, height: 108),
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
        color: const Color(0xFFFFFBEB).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFBBF24), width: 2.4),
        boxShadow: [
          BoxShadow(color: const Color(0xFFB45309).withValues(alpha: .22), blurRadius: 30, offset: const Offset(0, 14)),
          BoxShadow(color: const Color(0xFFFDE68A).withValues(alpha: .5), blurRadius: 40, spreadRadius: -8),
        ],
      ),
      child: Column(children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('\u2600\uFE0F', style: TextStyle(fontSize: 16)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('SUBHA MUBARAK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF92400E), letterSpacing: 2))),
          Text('\u{1F64F}', style: TextStyle(fontSize: 16)),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14),
          decoration: _inputDeco('Username'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: obscure,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _login(),
          style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14),
          decoration: _inputDeco('Password').copyWith(
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF92400E), size: 18),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2).withValues(alpha: .85), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFCA5A5))),
            child: Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (loading || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFB45309).withValues(alpha: .5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 4,
              shadowColor: const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFFDE68A), width: 1.4),
              ),
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
      labelStyle: const TextStyle(color: Color(0xFFB45309), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFFFEF9C3).withValues(alpha: .6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFCD34D), width: 1.6)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD97706), width: 2)),
    );
  }
}

class _SunRaysPainter extends CustomPainter {
  final double t;
  _SunRaysPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.85);
    for (int i = 0; i < 8; i++) {
      final baseAngle = (i / 8) * pi * 2 + t * pi * 2;
      canvas.drawLine(
        center,
        center + Offset(cos(baseAngle), sin(baseAngle)) * size.width * 0.42,
        paint,
      );
    }
    final corePaint = Paint()..color = const Color(0xFFFFF3C4);
    canvas.drawCircle(center, size.width * 0.16, corePaint);
  }

  @override
  bool shouldRepaint(covariant _SunRaysPainter old) => old.t != t;
}

class _MorningGlow extends StatelessWidget {
  const _MorningGlow();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFF3C4).withValues(alpha: .20),
            const Color(0xFFFFF7D6).withValues(alpha: .12),
            const Color(0xFFFEF3C7).withValues(alpha: .30),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    );
  }
}