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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final data = await ApiClient.send(
        'POST',
        '/auth/login',
        body: {'email': _emailCtrl.text.trim(), 'password': _passCtrl.text},
      );
      if (data is! Map || data['user'] == null || data['token'] == null) {
        throw ApiException('Login failed');
      }
      final user = Map<String, dynamic>.from(data['user'] as Map);
      if (!allowedRoles.contains(user['role'])) {
        throw ApiException('Invalid Order Taker credentials');
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
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            _bbqBackground(),
            const _DarkOverlay(),
            CustomPaint(painter: _EmbersPainter(_ctrl.value)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          _logoPulse(),
                          const SizedBox(height: 6),
                          ShaderMask(
                            shaderCallback: (r) => const LinearGradient(
                              colors: [
                                Color(0xFFFDE68A),
                                Color(0xFFF5C542),
                                Color(0xFFD97706),
                              ],
                            ).createShader(r),
                            child: const Text(
                              'USMAN HOTEL',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'BBQ  •  RESTAURANT',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 6,
                              color: Color(0xFFF5C542),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '📋 Order Taker App',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFFCBD5E1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _orderTakerArt(),
                          const SizedBox(height: 10),
                          _loginCard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bbqBackground() {
    final t = Curves.easeInOut.transform(
      (sin(_ctrl.value * 2 * pi) + 1) / 2,
    );
    return Image.asset(
      'assets/img/bbq_bg.jpg',
      fit: BoxFit.cover,
      alignment: Alignment(lerpDouble(-0.08, 0.08, t)!, lerpDouble(-0.05, 0.05, t)!),
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
            BoxShadow(
              color: const Color(0xFFF5C542).withValues(alpha: 0.25 + 0.25 * t),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset('assets/img/logo.png', width: 108, height: 108),
        ),
      ),
    );
  }

  Widget _orderTakerArt() {
    final t = _ctrl.value * 2 * pi;
    final dy = sin(t) * 7;
    final rot = sin(t + 0.9) * 0.035;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.rotate(
        angle: rot,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _flameEmoji(t),
            const SizedBox(width: 8),
            Image.asset(
              'assets/img/order_taker.png',
              height: 150,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            _clipboardGlow(t),
          ],
        ),
      ),
    );
  }

  Widget _flameEmoji(double t) {
    final s = 1.0 + 0.18 * sin(t * 4.1);
    return Transform.scale(
      scale: s,
      child: const Text('🔥', style: TextStyle(fontSize: 34)),
    );
  }

  Widget _clipboardGlow(double t) {
    final o = 0.55 + 0.45 * sin(t * 2.6);
    return Opacity(
      opacity: o.clamp(0.15, 1),
      child: const Text('🧾', style: TextStyle(fontSize: 34)),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .5),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
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
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: () => setState(() => obscure = !obscure),
              ),
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4C0519).withValues(alpha: .6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(fontSize: 12, color: Color(0xFFFDA4AF)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (loading || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty)
                      ? null
                      : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF065F46).withValues(alpha: .5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                loading ? 'Logging in...' : 'Login',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF020617),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.4),
      ),
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
          colors: [
            const Color(0xFF020617).withValues(alpha: .72),
            const Color(0xFF020617).withValues(alpha: .38),
            const Color(0xFF020617).withValues(alpha: .85),
          ],
          stops: const [0, 0.42, 1],
        ),
      ),
    );
  }
}

class _EmbersPainter extends CustomPainter {
  final double t;
  _EmbersPainter(this.t);

  static final List<_Ember> _embers = List.generate(26, (i) {
    final rng = Random(i * 97 + 13);
    return _Ember(
      seedX: rng.nextDouble(),
      speed: 0.05 + rng.nextDouble() * 0.09,
      size: 1.5 + rng.nextDouble() * 3.2,
      phase: rng.nextDouble(),
      hueShift: rng.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final e in _embers) {
      final prog = ((t * e.speed * 10 + e.phase) % 1);
      final y = size.height * (1.05 - prog * 1.15);
      final sway = sin(prog * 6 * pi + e.phase * 10) * 26;
      final x = size.width * e.seedX + sway;
      final alpha = (sin(prog * pi) * 200).clamp(0, 255).toDouble();
      final warm = e.hueShift > 0.5;
      paint.color = warm
          ? Color.fromRGBO(255, 170, 60, alpha / 255)
          : Color.fromRGBO(245, 197, 66, alpha / 255);
      canvas.drawCircle(Offset(x, y), e.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmbersPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _Ember {
  final double seedX;
  final double speed;
  final double size;
  final double phase;
  final double hueShift;
  const _Ember({
    required this.seedX,
    required this.speed,
    required this.size,
    required this.phase,
    required this.hueShift,
  });
}
