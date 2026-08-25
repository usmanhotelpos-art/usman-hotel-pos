import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'background_alerts.dart';
import 'notify.dart';
import 'orders_screen.dart';

class LoginScreen extends StatefulWidget {
  final String initialServerUrl;
  const LoginScreen({super.key, this.initialServerUrl = ''});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  late final TextEditingController _serverCtrl;
  bool loading = false;
  bool obscure = true;
  String message = '';

  @override
  void initState() {
    super.initState();
    _serverCtrl = TextEditingController(text: widget.initialServerUrl);
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      ApiClient.setHost(_serverCtrl.text);
      // Verify reachability implicitly via login call.
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
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 384),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🆕', style: TextStyle(fontSize: 34)),
                const SizedBox(height: 8),
                const Text(
                  'Active Orders Monitor',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
                const Text(
                  'Login to see live dine-in orders',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _serverCtrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Server URL (optional)',
                    hintText: ApiClient.defaultHost,
                    hintStyle: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                    ),
                    labelStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 14,
                  ),
                  decoration: _inputDeco('Email or username'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: obscure,
                  autofillHints: const [AutofillHints.password],
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 14,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C0519).withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFDA4AF),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      loading ? 'Signing in...' : 'Sign In',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        borderSide: const BorderSide(color: Color(0xFF10B981)),
      ),
    );
  }
}
