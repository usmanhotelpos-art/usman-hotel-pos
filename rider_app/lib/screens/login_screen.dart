import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/order.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String _loginError = '';
  String _selectedRoleTab = 'biker';
  HotelSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final s = await ApiService.getSettings();
      if (mounted) setState(() => _settings = s);
    } catch (_) {}
  }

  bool get _shiftActive {
    final shifts = _settings?.riderShifts ?? [];
    return shifts.any((s) => s.active);
  }

  String _shiftHint() {
    if (_selectedRoleTab == 'admin-biker') return 'Admin Biker mode - No shift requirement';
    if (!_shiftActive) return 'Shift not started. Please ask Owner Farhan to start your shift.';
    final shifts = _settings?.riderShifts ?? [];
    final assigned = shifts.where((s) => s.active && (s.riderName != null || s.riderUsername != null)).toList();
    if (assigned.length == 1) return 'Shift active for ${assigned[0].riderName ?? assigned[0].riderUsername}';
    if (assigned.length > 1) return '${assigned.length} active shifts';
    return 'Shift is active. Please login.';
  }

  Future<void> _handleLogin() async {
    setState(() { _loading = true; _loginError = ''; });
    try {
      final latestSettings = await ApiService.getSettings();
      final activeShifts = latestSettings.riderShifts.where((s) => s.active).toList();
      final shiftActive = activeShifts.isNotEmpty;
      final anyAssignedActive = activeShifts.any((s) => (s.riderId?.isNotEmpty == true) || (s.riderUsername?.isNotEmpty == true));
      final assignedNames = activeShifts.where((s) => s.riderName != null || s.riderUsername != null).map((s) => s.riderName ?? s.riderUsername!).join(', ');

      final data = await ApiService.login(_emailController.text.trim(), _passwordController.text);
      final rider = Rider.fromJson(data['rider'] as Map<String, dynamic>);
      final riderRole = rider.role.toLowerCase();
      final isAdminRider = riderRole.contains('admin');
      final riderUsernameOrEmail = (data['rider']?['username'] ?? data['rider']?['email'] ?? '').toString().trim().toLowerCase();

      final matchingAssigned = activeShifts.any((s) {
        final id = s.riderId ?? '';
        final username = (s.riderUsername ?? '').trim().toLowerCase();
        return (id.isNotEmpty && rider.id == id) || (username.isNotEmpty && username == riderUsernameOrEmail);
      });

      if (_selectedRoleTab == 'biker' && !isAdminRider) {
        if (!shiftActive) {
          setState(() { _loginError = 'Shift not started. Please ask Owner Farhan to start your shift.'; _loading = false; });
          return;
        }
        if (anyAssignedActive && !matchingAssigned) {
          setState(() { _loginError = 'This shift is assigned to $assignedNames. Please login with the assigned rider account.'; _loading = false; });
          return;
        }
      } else if (_selectedRoleTab == 'admin-biker' && !isAdminRider) {
        setState(() { _loginError = 'Admin Biker tab requires an admin rider account.'; _loading = false; });
        return;
      }

      await ApiService.saveToken(data['token'] as String);
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HomeScreen(rider: rider, settings: latestSettings),
        ));
      }
    } catch (e) {
      setState(() => _loginError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: const Color(0xF00F172A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFFF1493)]),
                          ),
                          child: (_settings?.logo != null)
                              ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(_settings!.logo!, fit: BoxFit.cover))
                              : const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_settings?.hotelName ?? 'Usman Hotel', style: const TextStyle(color: Color(0xFFFF8C00), fontSize: 12, letterSpacing: 2)),
                              const SizedBox(height: 2),
                              Text(_settings?.riderAppTitle ?? 'Rider Portal', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        color: const Color(0xCC0F172A),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFF67E8F9), size: 24),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Welcome rider', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              Text(_settings?.riderAppLoginNote ?? 'Login to continue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRoleTab = 'biker'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: _selectedRoleTab == 'biker' ? const Color(0xFF059669) : const Color(0xFF1E293B),
                                border: _selectedRoleTab != 'biker' ? Border.all(color: const Color(0x33455675)) : null,
                              ),
                              child: const Text('Rider', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRoleTab = 'admin-biker'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: _selectedRoleTab == 'admin-biker' ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                                border: _selectedRoleTab != 'admin-biker' ? Border.all(color: const Color(0x33455675)) : null,
                              ),
                              child: const Text('Admin Rider', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email or username',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x33455675))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x33455675))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x33455675))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x33455675))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2)),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8)),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    if (_loginError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x4D7F1D1D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDC2626)),
                        ),
                        child: Text(_loginError, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _selectedRoleTab == 'admin-biker' ? const Color(0x332563EB) : const Color(0x33FF8C00)),
                        color: _selectedRoleTab == 'admin-biker' ? const Color(0x4D1E3A5F) : const Color(0x4D7C2D12),
                      ),
                      child: Text(_shiftHint(), style: TextStyle(
                        color: _selectedRoleTab == 'admin-biker' ? const Color(0xFF93C5FD) : const Color(0xFFFFEDD5),
                        fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: const Color(0xFFFF8C00),
                          disabledBackgroundColor: const Color(0x4DFF8C00),
                        ),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Login', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
