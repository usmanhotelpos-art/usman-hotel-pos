import 'package:flutter/material.dart';

import 'api.dart';
import 'dashboard_screen.dart';
import 'session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showPassword = false;
  bool _showServerField = false;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _serverCtrl.text = ApiClient.host.isEmpty ? ApiClient.defaultHost : ApiClient.host;
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _serverCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter username and password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      ApiClient.setHost(_serverCtrl.text.trim());
      final res = await ApiClient.stockLogin(username, password);
      final token = res['token'] as String;
      final user = res['user'] as Map<String, dynamic>;
      await Session.save(token, user);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Connection failed. Check server address.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Glowing logo
                AnimatedBuilder(
                  animation: _glowCtrl,
                  builder: (context, _) {
                    final glow = 0.3 + (_glowCtrl.value * 0.4);
                    return Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF38BDF8).withOpacity(glow),
                            blurRadius: 30 + (_glowCtrl.value * 15),
                            spreadRadius: 3 + (_glowCtrl.value * 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'STOCK',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Usman Hotel',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 48),
                // Username field
                _buildField(
                  controller: _usernameCtrl,
                  hint: 'Username',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                // Password field
                _buildField(
                  controller: _passwordCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline,
                  obscure: !_showPassword,
                  suffix: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                const SizedBox(height: 12),
                // Server toggle
                GestureDetector(
                  onTap: () => setState(() => _showServerField = !_showServerField),
                  child: Text(
                    _showServerField ? 'Hide server' : 'Server settings',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ),
                if (_showServerField) ...[
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _serverCtrl,
                    hint: 'Server URL',
                    icon: Icons.dns_outlined,
                    keyboardType: TextInputType.url,
                  ),
                ],
                const SizedBox(height: 24),
                // Error
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0F172A)),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 2),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings_outlined, color: Colors.white.withOpacity(0.5), size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Manager & Cashier only',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.35), size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onSubmitted: (_) => _login(),
      ),
    );
  }
}
