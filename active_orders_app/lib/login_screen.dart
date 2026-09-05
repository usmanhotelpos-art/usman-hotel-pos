import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'background_alerts.dart';
import 'notify.dart';
import 'orders_screen.dart';
import 'printer_settings_screen.dart';

class LoginScreen extends StatefulWidget {
  final String initialServerUrl;
  const LoginScreen({super.key, this.initialServerUrl = ''});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  late final TextEditingController _serverCtrl;
  bool loading = false;
  bool obscure = true;
  String message = '';
  bool _rememberMe = true;
  bool _showServerField = false;
  bool _autoLoggingIn = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _serverCtrl = TextEditingController(text: widget.initialServerUrl);
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _loadRemembered();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('login_email') ?? '';
    final savedPass = prefs.getString('login_password') ?? '';
    final remember = prefs.getBool('login_remember') ?? false;
    final server = prefs.getString('serverUrl') ?? '';
    if (server.isNotEmpty && _serverCtrl.text.isEmpty) {
      _serverCtrl.text = server;
    }
    if (remember && savedEmail.isNotEmpty && savedPass.isNotEmpty) {
      _emailCtrl.text = savedEmail;
      _passCtrl.text = savedPass;
      _rememberMe = true;
      setState(() => _autoLoggingIn = true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) _login();
    }
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      ApiClient.setHost(_serverCtrl.text);
      final data = await ApiClient.send(
        'POST',
        '/auth/login',
        body: {'email': _emailCtrl.text.trim(), 'password': _passCtrl.text},
      );
      if (data is! Map || data['user'] == null || data['token'] == null) {
        throw ApiException('Login failed');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('serverUrl', ApiClient.host);
      await prefs.setString('activeOrdersToken', data['token'].toString());
      if (_rememberMe) {
        await prefs.setString('login_email', _emailCtrl.text.trim());
        await prefs.setString('login_password', _passCtrl.text);
        await prefs.setBool('login_remember', true);
      } else {
        await prefs.remove('login_email');
        await prefs.remove('login_password');
        await prefs.setBool('login_remember', false);
      }
      await NotifyService.requestPermission();
      await BackgroundAlerts.start();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
      );
    } on ApiException catch (e) {
      setState(() => message = e.message);
    } catch (e) {
      setState(() => message = 'Login failed: $e');
    } finally {
      if (mounted) setState(() { loading = false; _autoLoggingIn = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // Subtle gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF064E3B),
                    Color(0xFF020617),
                    Color(0xFF020617),
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF1E293B)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Active Orders',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF1F5F9),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Kitchen Display & Order Monitor',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '🏨 Usman Hotel POS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6EE7B7)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Server URL
                        GestureDetector(
                          onTap: () => setState(() => _showServerField = !_showServerField),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showServerField ? Icons.expand_less : Icons.expand_more,
                                size: 16,
                                color: const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showServerField ? 'Hide server settings' : 'Server Settings',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        if (_showServerField) ...[
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _serverCtrl,
                            label: 'Server URL',
                            hint: ApiClient.defaultHost,
                            keyboardType: TextInputType.url,
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Email
                        _buildTextField(
                          controller: _emailCtrl,
                          label: 'Email or Username',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 8),
                            child: Icon(Icons.person_outline, color: Color(0xFF64748B), size: 18),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),

                        // Password
                        _buildTextField(
                          controller: _passCtrl,
                          label: 'Password',
                          obscure: obscure,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 8),
                            child: Icon(Icons.lock_outline, color: Color(0xFF64748B), size: 18),
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => obscure = !obscure),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                obscure ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF64748B),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Remember me
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                activeColor: const Color(0xFF10B981),
                                side: const BorderSide(color: Color(0xFF334155)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Remember me & auto-login',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),

                        // Error message
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C0519).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF7F1D1D)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFFDA4AF), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    message,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFFDA4AF)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (loading || _autoLoggingIn) ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF059669).withValues(alpha: 0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _autoLoggingIn
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.login, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'Sign In',
                                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick access to printer settings
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print, size: 14, color: Color(0xFF475569)),
                              SizedBox(width: 4),
                              Text(
                                'Printer Settings (offline)',
                                style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_autoLoggingIn && !loading)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF020617).withValues(alpha: 0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF10B981)),
                      SizedBox(height: 16),
                      Text(
                        'Auto-logging in...',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String hint = '',
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF020617),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
    );
  }
}
