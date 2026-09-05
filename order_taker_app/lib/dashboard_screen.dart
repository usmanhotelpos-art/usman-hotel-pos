import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'login_screen.dart';
import 'order_taker_screen.dart';
import 'printer_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.token, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  List<dynamic> _recentOrders = [];
  Map<String, dynamic> _stats = {};
  String _message = '';
  Timer? _refreshTimer;

  static const accent = Color(0xFFF5C542);
  static const bg = Color(0xFFF8FAFC);
  static const cardBg = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const txtDark = Color(0xFF1E293B);
  static const txtDim = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String get _role => widget.user['role']?.toString() ?? '';
  bool get _isTakeawayOnly => _role == 'Takeaway Order Taker';
  bool get _isTableOnly => _role == 'Table Order Taker';

  bool _orderVisible(Map o) {
    final type = o['orderType']?.toString() ?? '';
    if (_isTakeawayOnly) return type == 'Takeaway';
    if (_isTableOnly) return type == 'Dine-In';
    return type == 'Dine-In' || type == 'Takeaway';
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      final orders = await ApiClient.send('GET', '/pos/orders', token: widget.token);
      if (orders is List) {
        final visibleOrders = orders.where((o) => o is Map && _orderVisible(o)).toList();
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayOrders = visibleOrders.where((o) {
          final d = DateTime.tryParse(o['createdAt']?.toString() ?? '');
          return d != null && d.isAfter(todayStart);
        }).toList();
        final totalRevenue = todayOrders.fold<double>(0, (sum, o) => sum + (o['total'] ?? o['amount'] ?? 0));
        setState(() {
          _recentOrders = visibleOrders.take(10).toList();
          _stats = {
            'todayOrders': todayOrders.length,
            'totalRevenue': totalRevenue,
            'totalOrders': visibleOrders.length,
          };
          _loading = false;
        });
      }
    } catch (e) {
      if (!silent && mounted) setState(() { _message = 'Error: $e'; _loading = false; });
    }
  }

  void _openOrderTaker() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderTakerScreen(token: widget.token, user: widget.user),
      ),
    );
  }

  void _openPrinterSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrderTakerPrinterSettings()),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('orderTakerToken');
    await prefs.remove('orderTakerUser');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                  child: Text(_message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: accent))
                  : RefreshIndicator(
                      color: accent,
                      onRefresh: () => _loadData(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildQuickActions(),
                          const SizedBox(height: 16),
                          _buildStatsGrid(),
                          const SizedBox(height: 16),
                          _buildRecentOrders(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: border))),
      child: Row(
        children: [
          Image.asset('assets/img/logo.png', width: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Taker', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: txtDark)),
                Text(
                  widget.user['name']?.toString() ?? widget.user['email']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11, color: txtDim),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openPrinterSettings,
            icon: const Icon(Icons.settings_outlined, color: txtDim),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: '📝',
            label: 'Take New\nOrder',
            color: const Color(0xFF059669),
            onTap: _openOrderTaker,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: '🖨️',
            label: 'Printer\nSettings',
            color: const Color(0xFF0EA5E9),
            onTap: _openPrinterSettings,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: '🔄',
            label: 'Refresh\nData',
            color: accent,
            onTap: () => _loadData(),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({required String icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _statCard('Today Orders', '${_stats['todayOrders'] ?? 0}', Icons.receipt_long, const Color(0xFF059669)),
        const SizedBox(width: 12),
        _statCard('Revenue', '${_stats['totalRevenue'] ?? 0} Rs', Icons.attach_money, accent),
        const SizedBox(width: 12),
        _statCard('Total', '${_stats['totalOrders'] ?? 0}', Icons.all_inclusive, const Color(0xFF7C3AED)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: txtDim)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    if (_recentOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
        child: const Center(
          child: Text('No orders yet', style: TextStyle(color: txtDim, fontSize: 14)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Recent Orders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: txtDark)),
          ),
          ..._recentOrders.take(8).map((o) {
            final num = o['orderNumber']?.toString() ?? o['id']?.toString() ?? '-';
            final type = o['orderType']?.toString() ?? '';
            final total = o['total'] ?? o['amount'] ?? 0;
            final status = o['status']?.toString() ?? '';
            final time = _fmtTime(o['createdAt']);
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                child: Text(type.isNotEmpty ? type[0] : '?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor(status))),
              ),
              title: Text('#$num  ·  $type', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: txtDark)),
              subtitle: Text(time, style: const TextStyle(fontSize: 11, color: txtDim)),
              trailing: Text('$total Rs', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: txtDark)),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('completed') || s.contains('paid')) return const Color(0xFF059669);
    if (s.contains('cancelled')) return Colors.red;
    if (s.contains('served')) return const Color(0xFFF59E0B);
    return const Color(0xFF7C3AED);
  }

  String _fmtTime(dynamic dt) {
    final d = DateTime.tryParse(dt?.toString() ?? '');
    if (d == null) return '';
    var h = d.hour % 12;
    if (h == 0) h = 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}
