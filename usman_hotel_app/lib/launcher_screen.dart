import 'package:flutter/material.dart';

import 'embedded/delivery/order_taker_screen.dart' as del;
import 'embedded/nashta/order_taker_screen.dart' as nash;

import 'api.dart';
import 'login_screen.dart';
import 'session.dart';

class LauncherScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  const LauncherScreen({super.key, required this.token, required this.user});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  late String _token;
  late Map<String, dynamic> _user;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _user = widget.user;
    _maybeRefresh();
  }

  Future<void> _maybeRefresh() async {
    if (_busy) return;
    final exp = tokenExpiryMs(_token);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (exp != 0 && exp < now + 30 * 60 * 1000) {
      _busy = true;
      final fresh = await ApiClient.refreshToken(_token);
      _busy = false;
      if (fresh != null && fresh.isNotEmpty) {
        await refreshTokens(fresh);
        if (mounted) setState(() => _token = fresh);
      }
    }
  }

  Future<String?> _ensureToken() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final exp = tokenExpiryMs(_token);
    if (exp != 0 && exp < now) {
      final fresh = await ApiClient.refreshToken(_token);
      if (fresh != null && fresh.isNotEmpty) {
        await refreshTokens(fresh);
        if (mounted) setState(() => _token = fresh);
        return fresh;
      }
      await clearSession();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      return null;
    }
    if (exp != 0 && exp < now + 5 * 60 * 1000) _maybeRefresh();
    return _token;
  }

  Future<void> _openNashta({bool force = false}) async {
    final role = _user['role'];
    if (!roleAllowedInNashta(role)) {
      _notAllowed('Nashta');
      return;
    }
    final t = await _ensureToken();
    if (t == null || !mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => nash.OrderTakerScreen(token: t, user: _user),
        ))
        .then((_) {
      if (mounted) _maybeRefresh();
    });
  }

  Future<void> _openDelivery() async {
    final role = _user['role'];
    if (!roleAllowedInDelivery(role)) {
      _notAllowed('Delivery');
      return;
    }
    final t = await _ensureToken();
    if (t == null || !mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => del.OrderTakerScreen(token: t, user: _user),
        ))
        .then((_) {
      if (mounted) _maybeRefresh();
    });
  }

  void _notAllowed(String app) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$app: aapka role ($_user[role]) is app ke liye allowed nahi hai.'),
      backgroundColor: const Color(0xFFB45309),
    ));
  }

  Future<void> _logout() async {
    await clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (sOf(_user['name']).isNotEmpty
            ? sOf(_user['name'])
            : sOf(_user['username']))
        .isEmpty
        ? 'Staff'
        : (sOf(_user['name']).isNotEmpty
            ? sOf(_user['name'])
            : sOf(_user['username']));
    final role = sOf(_user['role']).isEmpty ? 'Staff' : sOf(_user['role']);
    final canNashta = roleAllowedInNashta(_user['role']);
    final canDelivery = roleAllowedInDelivery(_user['role']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _header(name, role),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('SHUBH App Select Karein',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B))),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ListView(
                  children: [
                    _appCard(
                      icon: '\u{1F373}',
                      title: 'Nashta',
                      subtitle: 'Breakfast order taking, cart, print',
                      bg: const Color(0xFFECFDF5),
                      fg: const Color(0xFF059669),
                      enabled: canNashta,
                      onTap: canNashta ? _openNashta : null,
                    ),
                    const SizedBox(height: 14),
                    _appCard(
                      icon: '\u{1F69A}',
                      title: 'Delivery',
                      subtitle: 'Delivery orders, riders, dashboard',
                      bg: const Color(0xFFEFF6FF),
                      fg: const Color(0xFF2563EB),
                      enabled: canDelivery,
                      onTap: canDelivery ? _openDelivery : null,
                    ),
                    if (!canNashta && !canDelivery)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(
                          child: Text('Aapka role is app ke liye valid nahi hai.',
                              style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String name, String role) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/img/logo.png',
                width: 40, height: 40, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Usman Hotel',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF059669))),
              const SizedBox(height: 1),
              Text('$name  \u2022  $role',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color bg,
    required Color fg,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: enabled ? fg.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05)),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: fg.withValues(alpha: 0.15)),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: enabled ? fg : const Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (enabled)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_forward_ios, size: 16, color: fg),
              ),
          ],
        ),
      ),
    );
  }
}

String sOf(Object? v) => v == null ? '' : v.toString().trim();