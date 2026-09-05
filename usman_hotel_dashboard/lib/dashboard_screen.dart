import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'api.dart';
import 'session.dart';
import 'staff_screen.dart';

String sOf(dynamic v) => v == null ? '' : v.toString();
double numOf(dynamic v) {
  final d = double.tryParse(sOf(v).replaceAll(',', ''));
  return d ?? 0;
}

String two(int n) => n.toString().padLeft(2, '0');

final Map<String, Color> _appColors = {
  'nashta-app': const Color(0xFFF59E0B),
  'bbq-delivery-app': const Color(0xFF0EA5E9),
  'order-taker-app': const Color(0xFF8B5CF6),
  'web-order-taker': const Color(0xFFD946EF),
  'pos-web': const Color(0xFF10B981),
  '': const Color(0xFF64748B),
};

String appLabel(String src) {
  switch (src) {
    case 'nashta-app':
      return 'Nashta App';
    case 'bbq-delivery-app':
      return 'BBQ Delivery';
    case 'order-taker-app':
      return 'Order Taker';
    case 'web-order-taker':
      return 'Web Order Taker';
    case 'pos-web':
      return 'Web POS';
    default:
      return src.isEmpty ? 'Legacy / Web' : src;
  }
}

String appEmoji(String src) {
  switch (src) {
    case 'nashta-app':
      return '🍳';
    case 'bbq-delivery-app':
      return '🛵';
    case 'order-taker-app':
      return '📋';
    case 'web-order-taker':
      return '🌐';
    case 'pos-web':
      return '🖥️';
    default:
      return '🛎️';
  }
}

class DashboardScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final ValueChanged<ThemeMode> onToggleTheme;
  const DashboardScreen(
      {super.key,
      required this.token,
      required this.user,
      required this.onToggleTheme});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const accent = Color(0xFF059669);

  String _range = 'today';
  DateTime? _fromDate, _toDate;
  String _app = 'all';
  String _type = 'all';
  String _status = 'all';
  String _q = '';

  late String _token = widget.token;
  List<dynamic> _raw = [];
  Map<String, String> _prodCat = {};
  Map<String, String> _prodCatName = {};
  bool _loading = true;
  bool _fetching = false;
  String _err = '';
  DateTime? _lastRefreshed;
  Timer? _timer;

  String _tab = 'dashboard';
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && _fetching) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _err = '';
        _fetching = true;
      });
    }
    try {
      final data = await _fetchOrders(_token);
      if (data is! List) throw ApiException('Unexpected response');
      if (!mounted) return;
      setState(() {
        _raw = data;
        _lastRefreshed = DateTime.now();
        _loading = false;
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
        _fetching = false;
      });
    }
  }

  // Fetch orders; on an auth error, silently re-login with the built-in admin
  // account (bad/expired token) and retry once with the fresh token.
  Future<dynamic> _fetchOrders(String token) async {
    try {
      final data = await ApiClient.send('GET', '/pos/orders', token: token);
      final prods = await ApiClient.send('GET', '/pos/products', token: token);
      if (prods is List) _buildProductIndex(prods);
      return data;
    } on ApiException catch (e) {
      if (!e.isAuthError) rethrow;
      final r = await ApiClient.login(dashEmail, dashPassword);
      final newTok = r['token'];
      if (newTok is! String) rethrow;
      await saveSession(newTok, r['user']);
      _token = newTok;
      final data = await ApiClient.send('GET', '/pos/orders', token: newTok);
      await ApiClient.send('GET', '/pos/products', token: newTok);
      return data;
    }
  }

  // ---- order helpers -------------------------------------------------------
  bool _isCancelled(Map o) {
    final st = sOf(o['status']).toLowerCase();
    final ps = sOf(o['paymentStatus']).toLowerCase();
    return st == 'cancelled' ||
        ps == 'cancelled' ||
        sOf(o['cancelledAt']).isNotEmpty ||
        o['deleted'] == true ||
        sOf(o['deletedAt']).isNotEmpty;
  }

  bool _isPaid(Map o) {
    final st = sOf(o['status']).toLowerCase();
    final ps = sOf(o['paymentStatus']).toLowerCase();
    return ps == 'paid' ||
        st == 'paid' ||
        st == 'payment collected' ||
        st == 'completed' ||
        st == 'delivered';
  }

  bool _isDue(Map o) {
    final st = sOf(o['status']).toLowerCase();
    final ps = sOf(o['paymentStatus']).toLowerCase();
    return st == 'due' || ps == 'due';
  }

  bool _isDone(Map o) => _isPaid(o); // completed/paid = finished

  bool _isActive(Map o) =>
      !_isPaid(o) && !_isCancelled(o) && !_isDue(o);

  DateTime _orderTime(Map o) {
    final s = sOf(o['createdAt'] ?? o['date']);
    final d = DateTime.tryParse(s);
    if (d == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return d.isUtc
        ? d.add(const Duration(hours: 5))
        : d.toUtc().add(const Duration(hours: 5));
  }

  void _buildProductIndex(List<dynamic> prods) {
    _prodCat = {};
    _prodCatName = {};
    for (final p in prods) {
      if (p is! Map) continue;
      final cat = sOf(p['category']).trim().toLowerCase();
      for (final id in [sOf(p['id']), sOf(p['productId']), sOf(p['_id'])]) {
        final k = id.trim().toLowerCase();
        if (k.isNotEmpty && !_prodCat.containsKey(k)) _prodCat[k] = cat;
      }
      final nm = sOf(p['name']).trim().toLowerCase();
      if (nm.isNotEmpty && !_prodCatName.containsKey(nm)) _prodCatName[nm] = cat;
    }
  }

  String _catOf(Map item) {
    final id = sOf(item['productId'] ?? item['id']).trim().toLowerCase();
    if (id.isNotEmpty && _prodCat.containsKey(id)) return _prodCat[id]!;
    final nm = sOf(item['name']).trim().toLowerCase();
    return _prodCatName[nm] ?? '';
  }

  bool _isExtrasItem(Map item) {
    final c = _catOf(item);
    return c.contains('extras') || c.contains('extra');
  }

  double _extrasAmount(Map o) {
    final items = o['items'];
    if (items is! List) return 0;
    double s = 0;
    for (final it in items) {
      if (it is Map && _isExtrasItem(it)) {
        s += numOf(it['total'] ?? numOf(it['price']) * numOf(it['quantity']));
      }
    }
    return s;
  }

  double _deliveryFee(Map o) => sOf(o['orderType']).toLowerCase().contains('deliver')
      ? numOf(o['deliveryFee'])
      : 0;

  // Main dashboard revenue mirrors the web dashboard: PAID orders only,
  // excluding Extras items amount and Delivery charges.
  double _foodRev(Map o) =>
      _isPaid(o)
          ? max(0.0, numOf(o['total'] ?? o['amount']) - _extrasAmount(o) - _deliveryFee(o))
          : 0;

  double _extrasSum(List<Map> list) =>
      list.fold<double>(0, (s, o) => _isPaid(o) ? s + _extrasAmount(o) : s);

  double _delFeeSum(List<Map> list) =>
      list.fold<double>(0, (s, o) => _isPaid(o) ? s + _deliveryFee(o) : s);

  DateTime _pkNow() => DateTime.now().toUtc().add(const Duration(hours: 5));

  String _src(Map o) {
    final v = sOf(o['source']).trim().toLowerCase();
    return _appColors.containsKey(v) ? v : '';
  }

  String _staff(Map o) {
    final t = sOf(o['orderTaker']).trim();
    final w = sOf(o['waiter']).trim();
    if (t.isNotEmpty) return t;
    if (w.isNotEmpty) return w;
    return 'Unassigned';
  }

  (DateTime?, DateTime?) _window() {
    final now = _pkNow();
    DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
    final today = dayStart(now);
    switch (_range) {
      case 'today':
        return (today, today.add(const Duration(days: 1)));
      case 'yesterday':
        return (today.subtract(const Duration(days: 1)), today);
      case 'last7':
        return (today.subtract(const Duration(days: 6)), today.add(const Duration(days: 1)));
      case 'last30':
        return (today.subtract(const Duration(days: 29)), today.add(const Duration(days: 1)));
      case 'month':
        final first = DateTime(now.year, now.month, 1);
        return (first, DateTime(now.year, now.month + 1, 1));
      case 'all':
        return (null, null);
      default:
        if (_fromDate != null || _toDate != null) {
          final f = _fromDate != null
              ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day)
              : today.subtract(const Duration(days: 30));
          final t = _toDate != null
              ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day)
                  .add(const Duration(days: 1))
              : now.add(const Duration(days: 1));
          return (f, t);
        }
        return (today.subtract(const Duration(days: 30)), now.add(const Duration(days: 1)));
    }
  }

  List<Map> get _all {
    return _raw
        .where((o) => o is Map && !_isCancelled(Map<String, dynamic>.from(o)))
        .cast<Map>()
        .toList();
  }

  List<Map> get _filtered {
    final (f, t) = _window();
    final appOk = sOf(_app);
    final list = _all.where((o) {
      if (f != null && _orderTime(o).isBefore(f)) return false;
      if (t != null && !_orderTime(o).isBefore(t)) return false;
      if (_app != 'all' && _src(o) != appOk) return false;
      if (_type != 'all' && sOf(o['orderType']) != _type) return false;
      if (_status == 'active' && !_isActive(o)) return false;
      if (_status == 'paid' && !_isPaid(o)) return false;
      if (_status == 'due' && !_isDue(o)) return false;
      if (_status == 'done' && !_isDone(o)) return false;
      if (_q.trim().isNotEmpty &&
          !_staff(o).toLowerCase().contains(_q.trim().toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    return list;
  }

  double _totalRev(List<Map> list) =>
      list.fold<double>(0, (s, o) => s + _foodRev(o));

  int _countBy(List<Map> list, bool Function(Map) fn) =>
      list.where(fn).length;

  // ---- source aggregation --------------------------------------------------
  Map<String, List<Map>> _bySource() {
    final m = <String, List<Map>>{};
    for (final o in _filtered) {
      (m[_src(o)] ??= []).add(o);
    }
    return m;
  }

  Map<String, List<Map>> _byStaff(List<Map>? subset) {
    final src = subset ?? _filtered;
    final m = <String, List<Map>>{};
    for (final o in src) {
      (m[_staff(o)] ??= []).add(o);
    }
    return m;
  }

  List<Map<String, dynamic>> _typeSegments(List<Map> list) {
    const types = ['Dine-In', 'Takeaway', 'Delivery'];
    return types.map((tp) {
      final l = list.where((o) => sOf(o['orderType']) == tp).toList();
      return {
        'type': tp,
        'count': l.length,
        'rev': _totalRev(l),
      };
    }).toList();
  }

  // ---- UI ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sidebar(dark),
            Container(
              width: 1,
              color: dark ? const Color(0xFF1E2A44) : const Color(0xFFE5EAF2),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab == 'dashboard' ? 0 : 1,
                children: [
                  _dashboardView(context),
                  StaffScreen(token: _token, user: widget.user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardView(BuildContext context) {
    return Column(
      children: [
        _header(),
        Expanded(
          child: RefreshIndicator(
            color: accent,
            onRefresh: () => _load(),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: accent))
                : _err.isNotEmpty
                    ? _errorView()
                    : CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                            sliver: SliverToBoxAdapter(
                                child: _filters()),
                          ),
                          SliverToBoxAdapter(child: _overview()),
                          SliverToBoxAdapter(child: _charts()),
                          SliverToBoxAdapter(child: _extrasBlock()),
                          SliverToBoxAdapter(child: _byAppPanel()),
                          SliverToBoxAdapter(child: _byStaffPanel()),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 28),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _sidebar(bool dark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      width: _sidebarCollapsed ? 58 : 196,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(
              color: dark ? const Color(0xFF1E2A44) : const Color(0xFFE5EAF2)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment:
                  _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.asset('assets/img/logo.png',
                      width: 36,
                      height: 36,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.store, color: accent, size: 30)),
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Usman Hotel',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        Text('DASHBOARD',
                            style: TextStyle(
                                fontSize: 8.5,
                                letterSpacing: 2.4,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _navTile('dashboard', Icons.dashboard_outlined,
              Icons.dashboard, 'Dashboard'),
          _navTile('staff', Icons.group_outlined, Icons.group, 'Staff',
              badgeCount: _staffBadge),
          const Spacer(),
          const Divider(height: 1, indent: 12, endIndent: 12),
          IconButton(
            tooltip: _sidebarCollapsed ? 'Show sidebar' : 'Hide sidebar',
            icon: Icon(
              _sidebarCollapsed ? Icons.visibility : Icons.visibility_off,
              size: 20,
              color: _sidebarCollapsed ? accent : const Color(0xFF64748B),
            ),
            onPressed: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          ),
          if (!_sidebarCollapsed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '👁 eye: ${_sidebarCollapsed ? 'show' : 'hide'} sidebar',
                style: const TextStyle(
                    fontSize: 9.5, color: Color(0xFF94A3B8)),
              ),
            ),
        ],
      ),
    );
  }

  int get _staffBadge => 0;

  Widget _navTile(String key, IconData icon, IconData selIcon, String label,
      {int badgeCount = 0}) {
    final active = _tab == key;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => setState(() => _tab = key),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: .14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                active ? selIcon : icon,
                size: 20,
                color: active
                    ? accent
                    : Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9FB0C9)
                        : const Color(0xFF64748B),
              ),
              if (!_sidebarCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight:
                                    active ? FontWeight.w900 : FontWeight.w700,
                                color: active
                                    ? accent
                                    : Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569))),
                      ),
                      if (badgeCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('$badgeCount',
                              style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 14, offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset('assets/img/logo.png',
                width: 42, height: 42,
                errorBuilder: (_, __, ___) => const Icon(Icons.store, color: accent)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Usman Hotel',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                Text(
                  _lastRefreshed == null
                      ? 'Updating...'
                      : 'Updated ${_fmtT(_lastRefreshed!)} · ${_filtered.length} orders',
                  style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9FB0C9) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => widget.onToggleTheme(
                Theme.of(context).brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 54, color: Color(0xFFB45309)),
            const SizedBox(height: 14),
            const Text('Dashboard load nahi hua',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_err,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _load(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({required String label, required bool active, required VoidCallback onTap, Color? color}) {
    final base = color ?? accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? base : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: active ? base : const Color(0xFFD7DEE9), width: 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : const Color(0xFF5B6B82))),
      ),
    );
  }

  Widget _filters() {
    final ranges = [
      ('today', 'Today'),
      ('yesterday', 'Yesterday'),
      ('last7', '7D'),
      ('last30', '30D'),
      ('month', 'Month'),
      ('all', 'All'),
      ('custom', 'Custom'),
    ];
    final apps = <String, String>{
      'all': 'All Apps',
      'nashta-app': '🍳 Nashta',
      'bbq-delivery-app': '🛵 BBQ Delivery',
      'order-taker-app': '📋 Order Taker',
      'web-order-taker': '🌐 Web OT',
      'pos-web': '🖥️ Web POS',
      '': '🛎️ Legacy',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: rangeChips(ranges),
          ),
        ),
        if (_range == 'custom') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _dateBtn('From', _fromDate, true)),
              const SizedBox(width: 8),
              Expanded(child: _dateBtn('To', _toDate, false)),
            ],
          ),
        ],
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: apps.entries.map((e) {
              final active = _app == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _chip(
                    label: e.value,
                    active: active,
                    color: active && e.key != 'all'
                        ? _appColors[e.key]
                        : accent,
                    onTap: () => setState(() => _app = e.key)),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tp in ['all', 'Dine-In', 'Takeaway', 'Delivery'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _chip(
                      label: tp == 'all' ? '🪑 All Types' : tp,
                      active: _type == tp,
                      onTap: () => setState(() => _type = tp)),
                ),
              for (final st in [
                ('active', '🟢 Active'),
                ('paid', '✅ Paid'),
                ('due', '🟠 Due'),
                ('done', '✔ Done'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _chip(
                      label: st.$2,
                      active: _status == st.$1,
                      color: st.$1 == 'active'
                          ? const Color(0xFF059669)
                          : st.$1 == 'paid'
                              ? const Color(0xFF16A34A)
                              : st.$1 == 'due'
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF0EA5E9),
                      onTap: () => setState(() => _status = _status == st.$1 ? 'all' : st.$1)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: '🔍 Staff / user name search...',
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF8CA0B8)),
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD7DEE9))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD7DEE9))),
          ),
        ),
      ],
    );
  }

  Widget _dateBtn(String label, DateTime? val, bool isFrom) {
    return GestureDetector(
      onTap: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: val ?? DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime(2100),
        );
        if (p != null) {
          setState(() {
            if (isFrom) _fromDate = p;
            else _toDate = p;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD7DEE9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: accent),
            const SizedBox(width: 8),
            Text('$label: ${val == null ? 'Any' : '${val.day}/${val.month}/${val.year}'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  List<Widget> rangeChips(List<(String, String)> ranges) {
    return ranges.map((r) {
      final active = _range == r.$1;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _chip(label: r.$2, active: active, onTap: () {
          setState(() {
            if (_range == 'custom' && _fromDate != null) _fromDate = null;
            if (_range == 'custom' && _toDate != null) _toDate = null;
            _range = active ? 'all' : r.$1;
          });
        }),
      );
    }).toList();
  }

  Widget _overview() {
    final list = _filtered;
    final todayStart = (() { final n = _pkNow(); return DateTime(n.year, n.month, n.day); })();
    final todayList = _all.where((o) => !_orderTime(o).isBefore(todayStart) && _orderTime(o).isBefore(todayStart.add(const Duration(days: 1)))).toList();
    int active() => _countBy(list, _isActive);
    int paid() => _countBy(list, _isPaid);
    int due() => _countBy(list, _isDue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
          child: Text('OVERVIEW · ${list.length} orders · ${_fmtMoney(_totalRev(list))}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Color(0xFF64748B))),
        ),
        SizedBox(
          height: 118,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _bigCard('Total Orders', '${list.length}', '', accent, list, emoji: '🗂️'),
              _bigCard('Revenue', _fmtMoney(_totalRev(list)), 'Paid · no extras/dlv', const Color(0xFF059669), list.where(_isPaid).toList(), emoji: '💰'),
              _bigCard('Active', '${active()}', 'In progress', const Color(0xFF2563EB), list.where(_isActive).toList(), emoji: '🟢'),
              _bigCard('Due', '${due()}', 'Payment due', const Color(0xFFF59E0B), list.where(_isDue).toList(), emoji: '🟠'),
              _bigCard('Paid', '${paid()}', 'Completed', const Color(0xFF16A34A), list.where(_isPaid).toList(), emoji: '✅'),
              _bigCard('Today', '${todayList.length}', _fmtMoney(_totalRev(todayList)), const Color(0xFF0EA5E9), todayList, emoji: '📅'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bigCard(String label, String value, String sub, Color color, List<Map> orders, {String emoji = ''}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showOrders(orders, label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 10),
        width: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [color.withValues(alpha: .16), color.withValues(alpha: .04)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text('$emoji ',
                      style: const TextStyle(fontSize: 15)),
                  Expanded(
                    child: Text(label,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(value,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: color)),
              if (sub.isNotEmpty)
                Text(sub,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: dark ? const Color(0xFF9FB0C9) : const Color(0xFF8CA0B8))),
            ],
          ),
        ),
      ),
    );
  }

  // ---- charts --------------------------------------------------------------
  Widget _charts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📊 GRAPHICS'),
        _appChart(),
        const SizedBox(height: 12),
        _typeDonut(),
        const SizedBox(height: 12),
        _statusBars(),
        const SizedBox(height: 12),
        _trendChart(),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 10),
        child: Text(t,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Color(0xFF64748B))),
      );

  Widget _cardBox({required Widget child, Color? tint}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (tint ?? const Color(0xFF059669)).withValues(alpha: .25)),
      ),
      child: child,
    );
  }

  Widget _appChart() {
    final bySrc = _bySource();
    final colors = [const Color(0xFFF59E0B), const Color(0xFF0EA5E9), const Color(0xFF8B5CF6), const Color(0xFFD946EF), const Color(0xFF10B981), const Color(0xFF64748B)];
    final order = [
      'nashta-app', 'bbq-delivery-app', 'order-taker-app',
      'web-order-taker', 'pos-web', ''
    ];
    final data = order
        .where((k) => (bySrc[k] ?? []).isNotEmpty)
        .map((k) => (
              '${appEmoji(k)} ${appLabel(k)}',
              bySrc[k]!.length,
              _totalRev(bySrc[k]!),
              colors[order.indexOf(k) % colors.length],
              k,
              bySrc[k]!,
            ))
        .toList();
    if (data.isEmpty) return _empty('Koi app orders nahi mile filters mein');
    final maxC = data.fold<int>(1, (m, d) => max(m, d.$2));
    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Orders by App (count)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _showOrders(d.$6, d.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${d.$2}',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: d.$4)),
                          const SizedBox(height: 3),
                          Container(
                            height: max(6, 130 * (d.$2 / maxC)),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [d.$4.withValues(alpha: .95), d.$4.withValues(alpha: .55)]),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text('${d.$2}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: data.map((d) => _legendDot(
                  d.$4, d.$1, '${d.$2} · ${_fmtMoney(d.$3)}', d.$6,
                )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label, String sub, List<Map> orders) {
    return GestureDetector(
      onTap: () => _showOrders(orders, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('$label  $sub',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _typeDonut() {
    final segs = _typeSegments(_filtered);
    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFFF59E0B),
      const Color(0xFF0284C7),
    ];
    final total = segs.fold<int>(0, (s, x) => s + (x['count'] as int));
    final totalRev = _totalRev(_filtered);
    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Orders by Type (count + revenue)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(150, 150),
                        painter: _DonutPainter(
                          segs, colors, total == 0 ? 2.0 : 0.0),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          Text('Orders', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          Text(_fmtMoney(totalRev),
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(segs.length, (i) {
                      final s = segs[i];
                      final c = colors[i % colors.length];
                      return GestureDetector(
                        onTap: () => _showOrders(
                            _filtered.where((o) => sOf(o['orderType']) == s['type']).toList(),
                            '${s['type']}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(width: 9, height: 9,
                                  decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(s['type'] as String,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ),
                              Text('${s['count']} · ${_fmtMoney(numOf(s['rev']))}',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBars() {
    final rows = [
      ('🟢 Active', _countBy(_filtered, _isActive), const Color(0xFF2563EB), _filtered.where(_isActive).toList()),
      ('✅ Paid', _countBy(_filtered, _isPaid), const Color(0xFF16A34A), _filtered.where(_isPaid).toList()),
      ('🟠 Due', _countBy(_filtered, _isDue), const Color(0xFFF59E0B), _filtered.where(_isDue).toList()),
      ('🏁 Done', _countBy(_filtered, _isDone), const Color(0xFF0EA5E9), _filtered.where(_isDone).toList()),
    ];
    final maxV = rows.fold<int>(1, (m, r) => max(m, r.$2));
    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status Breakdown',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...rows.map((r) {
            return GestureDetector(
              onTap: () => _showOrders(r.$4, r.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 82,
                      child: Text(r.$1,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(height: 18,
                              decoration: BoxDecoration(
                                  color: r.$3.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(10))),
                          FractionallySizedBox(
                            widthFactor: maxV == 0 ? 0 : r.$2 / maxV,
                            child: Container(height: 18,
                                decoration: BoxDecoration(
                                    color: r.$3.withValues(alpha: .7),
                                    borderRadius: BorderRadius.circular(10))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 34,
                      child: Text('${r.$2}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _trendChart() {
    final (f, t) = _window();
    final days = <DateTime>[];
    final start = f ?? _pkNow().subtract(const Duration(days: 6));
    final last = (() {
      final n = _pkNow();
      return DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
    })();
    for (var d = DateTime(start.year, start.month, start.day);
        d.isBefore(last);
        d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    if (days.length > 60) days.removeRange(0, days.length - 60);
    final counts = days.map((d) {
      final e = d.add(const Duration(days: 1));
      return _all.where((o) {
        final ot = _orderTime(o);
        return !ot.isBefore(d) && ot.isBefore(e) &&
            (_app == 'all' || _src(o) == _app) &&
            (_type == 'all' || sOf(o['orderType']) == _type);
      }).length;
    }).toList();
    final maxC = counts.fold<int>(1, (m, v) => max(m, v));
    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Trend (orders)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(days.length, (i) {
                final v = counts[i];
                final isToday = (days[i].year == _pkNow().year &&
                    days[i].month == _pkNow().month &&
                    days[i].day == _pkNow().day);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => _showOrders(
                          _all.where((o) {
                            final ot = _orderTime(o);
                            final e = days[i].add(const Duration(days: 1));
                            return !ot.isBefore(days[i]) && ot.isBefore(e) &&
                                (_app == 'all' || _src(o) == _app) &&
                                (_type == 'all' || sOf(o['orderType']) == _type);
                          }).toList(),
                          '${two(days[i].day)}/${two(days[i].month)}'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (v > 0)
                            Text('$v',
                                style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          Container(
                            height: max(3, 90 * (v / maxC)),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF0EA5E9).withValues(alpha: .6),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _extrasBlock() {
    final paids = _filtered.where(_isPaid).toList();
    final extrasTotal = _extrasSum(paids);
    final delTotal = _delFeeSum(paids);
    final extrasOrders = paids.where((o) => _extrasAmount(o) > 0).toList();
    final delOrders = paids.where((o) => _deliveryFee(o) > 0).toList();

    final bikers = <String, List<Map>>{};
    for (final o in delOrders) {
      final b = sOf(o['deliveryAgent']).trim();
      (bikers[b.isEmpty ? 'Unassigned' : b] ??= []).add(o);
    }
    final bikersSorted = bikers.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final appsPaid = <String, List<Map>>{};
    for (final o in paids) {
      (appsPaid[_src(o)] ??= []).add(o);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('🧾 EXTRAS & DELIVERY CHARGES'),
        _cardBox(
          tint: const Color(0xFFF59E0B),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ye amounts main revenue mein shamil NAHI hote.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _minitap('Extras', _fmtMoney(extrasTotal),
                        const Color(0xFFF59E0B),
                        () => _showOrders(extrasOrders, '🧾 Extras', rev: extrasTotal)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _minitap('Delivery Charges', _fmtMoney(delTotal),
                        const Color(0xFF0284C7),
                        () => _showOrders(delOrders, '🚚 Delivery Charges', rev: delTotal)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._typeSegments(paids).map((s) {
                final segList =
                    paids.where((o) => sOf(o['orderType']) == s['type']).toList();
                final ex = _extrasSum(segList);
                final df = _delFeeSum(segList);
                return GestureDetector(
                  onTap: () => _showOrders(segList, '${s['type'] as String} · Paid'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(s['type'] as String,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        ),
                        Text('${s['count']} ord',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        const SizedBox(width: 10),
                        if (ex > 0)
                          Text('Extra ${_fmtMoney(ex)}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
                        if (ex > 0 && df > 0) const SizedBox(width: 8),
                        if (df > 0)
                          Text('Dlv ${_fmtMoney(df)}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const Divider(height: 20),
              const Text('BY APP',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              ...appsPaid.entries.map((e) {
                final ex = _extrasSum(e.value);
                final df = _delFeeSum(e.value);
                return GestureDetector(
                  onTap: () => _showOrders(e.value, '${appEmoji(e.key)} ${appLabel(e.key)} · Paid'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${appEmoji(e.key)} ${appLabel(e.key)}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        ),
                        if (ex > 0)
                          Text('Extra ${_fmtMoney(ex)}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
                        if (ex > 0 && df > 0) const SizedBox(width: 8),
                        if (df > 0)
                          Text('Dlv ${_fmtMoney(df)}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                      ],
                    ),
                  ),
                );
              }).toList(),
              if (bikersSorted.isNotEmpty) ...[
                const Divider(height: 20),
                const Text('🚴 BIKERS · delivery charges by rider',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                ...bikersSorted.take(20).map((e) {
                  final fee = _delFeeSum(e.value);
                  return GestureDetector(
                    onTap: () => _showOrders(e.value, '🚴 ${e.key} · Deliveries', rev: fee),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: const Color(0xFF0284C7).withValues(alpha: .15),
                            child: Text(_initial(e.key),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0284C7))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(e.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          ),
                          Text('${e.value.length} dlv',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          const SizedBox(width: 10),
                          Text(_fmtMoney(fee),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0284C7))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _minitap(String label, String value, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
            const SizedBox(height: 5),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _empty(String msg) => _cardBox(
        tint: const Color(0xFF94A3B8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
              child: Text(msg,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
        ),
      );

  // ---- by app / by staff ----------------------------------------------------
  Widget _byAppPanel() {
    final bySrc = _bySource();
    final colors = const [Color(0xFFF59E0B), Color(0xFF0EA5E9), Color(0xFF8B5CF6), Color(0xFFD946EF), Color(0xFF10B981), Color(0xFF64748B)];
    final order = ['nashta-app', 'bbq-delivery-app', 'order-taker-app', 'web-order-taker', 'pos-web', ''];
    final entries = order.where((k) => (bySrc[k] ?? []).isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📱 BY APP'),
        if (entries.isEmpty)
          _empty('Koi app orders nahi')
        else
          ...entries.map((k) {
            final list = bySrc[k]!;
            final i = entries.indexOf(k);
            final c = colors[i % colors.length];
            final segs = _typeSegments(list);
            final staff = _byStaff(list).entries.toList()
              ..sort((a, b) => b.value.length.compareTo(a.value.length));
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _cardBox(
                tint: c,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showOrders(list, '${appEmoji(k)} ${appLabel(k)}'),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                                child: Text(appEmoji(k),
                                    style: const TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(appLabel(k),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                Text('${list.length} orders',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${list.length}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c)),
                              Text(_fmtMoney(_totalRev(list)),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                            ],
                          ),
                          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: segs.map((s) {
                        final cc = s['type'] == 'Dine-In'
                            ? const Color(0xFF7C3AED)
                            : s['type'] == 'Takeaway'
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF0284C7);
                        return GestureDetector(
                          onTap: () => _showOrders(
                              list.where((o) => sOf(o['orderType']) == s['type']).toList(),
                              '${appEmoji(k)} ${appLabel(k)} · ${s['type'] as String}'),
                          child: _pill('${s['type'] as String} ${s['count']}', cc),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 18),
                    ...staff.take(5).map((e) {
                      final sl = e.value;
                      final rev = _totalRev(sl);
                      return GestureDetector(
                        onTap: () => _showOrders(sl, '${appEmoji(k)} ${appLabel(k)} · ${e.key}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: c.withValues(alpha: .18),
                                child: Text(_initial(e.key),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(e.key,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              ),
                              Text('${sl.length}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 68,
                                child: Text(_fmtMoney(rev),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _pill(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
    );
  }

  Widget _byStaffPanel() {
    final m = _byStaff(_filtered).entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (m.isEmpty) return const SizedBox.shrink();
    final maxC = m.first.value.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('👥 BY STAFF'),
        _cardBox(
          tint: const Color(0xFF2563EB),
          child: Column(
            children: m.take(20).map((e) {
              final list = e.value;
              final rev = _totalRev(list);
              final srcs = list.map(_src).toSet().toList();
              return GestureDetector(
                onTap: () => _showOrders(list, '👤 ${e.key}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF2563EB).withValues(alpha: .14),
                        child: Text(_initial(e.key),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 4,
                              children: [
                                for (final sToken in srcs)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: (_appColors[sToken] ?? const Color(0xFF64748B)).withValues(alpha: .15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(appLabel(sToken),
                                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: _appColors[sToken] ?? const Color(0xFF64748B))),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: maxC == 0 ? 0 : (e.value.length / maxC).clamp(0.05, 1.0),
                                  child: Container(height: 16,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: .15),
                                          borderRadius: BorderRadius.circular(9))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 32,
                        child: Text('${e.value.length}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 62,
                        child: Text(_fmtMoney(rev),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---- details sheet --------------------------------------------------------
  void _showOrders(List<Map> orders, String title, {double? rev}) {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No orders in this group')));
      return;
    }
    final extras = <String>{};
    for (final o in orders) {
      final items = o['items'];
      if (items is! List) continue;
      for (final it in items) {
        if (it is Map && _isExtrasItem(it)) {
          extras.add(sOf(it['productId'] ?? it['id'] ?? it['name']));
        }
      }
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrdersSheet(
        title: title,
        orders: orders,
        extras: extras,
        totalRev: rev ?? _totalRev(orders),
      ),
    );
  }

  String _fmtT(DateTime d) {
    final p = d.toUtc().add(const Duration(hours: 5));
    final h = two(p.hour);
    return '$h:${two(p.minute)}';
  }

  String _fmtMoney(double v) {
    final rounded = v.round();
    final s = rounded.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},');
    return 'Rs $s';
  }

  String _initial(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class _DonutPainter extends CustomPainter {
  final List<Map<String, dynamic>> segs;
  final List<Color> colors;
  final double stroke;
  _DonutPainter(this.segs, this.colors, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = rect.center;
    final r = (size.shortestSide - 12) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.butt;
    final total = segs.fold<int>(0, (s, x) => s + (x['count'] as int));
    if (total == 0) {
      paint.color = const Color(0xFFE2E8F0);
      paint.strokeWidth = 2;
      canvas.drawCircle(c, r, paint);
      return;
    }
    var start = -pi / 2;
    for (var i = 0; i < segs.length; i++) {
      final count = (segs[i]['count'] as int);
      if (count == 0) continue;
      final sweep = 2 * pi * count / total;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect.deflate(10), start, sweep - 0.02, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segs != segs || old.colors != colors;
}

class _OrdersSheet extends StatefulWidget {
  final String title;
  final List<Map> orders;
  final double totalRev;
  final Set<String> extras;
  const _OrdersSheet(
      {required this.title, required this.orders, required this.totalRev, this.extras = const {}});

  @override
  State<_OrdersSheet> createState() => _OrdersSheetState();
}

class _OrdersSheetState extends State<_OrdersSheet> {
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final list = widget.orders;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              Container(
                width: 42, height: 4,
                margin: const EdgeInsets.only(top: 9, bottom: 4),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 6),
                    _tag('${list.length}', const Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    _tag(_fmtMoney(widget.totalRev), const Color(0xFF059669)),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => OrderDetailTile(
                    order: list[i],
                    extras: widget.extras,
                    open: _open.contains(sOf(list[i]['id'])),
                    onToggle: () => setState(() {
                      final id = sOf(list[i]['id']);
                      if (_open.contains(id)) _open.remove(id);
                      else _open.add(id);
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tag(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c)),
    );
  }

  String _fmtMoney(double v) {
    final s = v.round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},');
    return 'Rs $s';
  }
}

class OrderDetailTile extends StatelessWidget {
  final Map order;
  final bool open;
  final VoidCallback onToggle;
  final Set<String> extras;
  const OrderDetailTile(
      {super.key, required this.order, required this.open, required this.onToggle, this.extras = const {}});

  bool _isPaid(Map o) {
    final st = sOf(o['status']).toLowerCase();
    final ps = sOf(o['paymentStatus']).toLowerCase();
    return ps == 'paid' || st == 'paid' || st == 'payment collected' ||
        st == 'completed' || st == 'delivered';
  }

  @override
  Widget build(BuildContext context) {
    final t = DateTime.tryParse(sOf(order['createdAt'] ?? order['date']));
    final dt = t?.toUtc().add(const Duration(hours: 5));
    final time = dt == null
        ? ''
        : '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
    final src = order['source']?.toString() ?? '';
    final items = (order['items'] is List) ? order['items'] as List : [];
    final total = numOf(order['total'] ?? order['amount']);
    final paid = _isPaid(Map<String, dynamic>.from(order));
    final type = sOf(order['orderType']);
    final typeColor = type == 'Dine-In'
        ? const Color(0xFF7C3AED)
        : type == 'Takeaway'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF0284C7);
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: (paid ? const Color(0xFF059669) : const Color(0xFFF59E0B)).withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                          child: Text(paid ? '✅' : '🕒',
                              style: const TextStyle(fontSize: 15))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text('#${sOf(order['orderNumber'] ?? order['id']).replaceAll('ORD-', '')}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 6),
                              Text(time,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${type.isNotEmpty ? '$type · ' : ''}${sOf(order['customerName']).isEmpty ? sOf(order['tableNumber']) : sOf(order['customerName'])}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text('$type',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: typeColor)),
                    ),
                    const SizedBox(width: 8),
                    Text(_fmtMoney(total),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 260),
                      child: const Icon(Icons.keyboard_arrow_down,
                          size: 20, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (src.isNotEmpty) ...[
                      Text('${appEmoji(src)} ${appLabel(src)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                    ],
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip2('Status: ${sOf(order['status']).isEmpty ? 'New' : order['status']}',
                            paid ? const Color(0xFF059669) : const Color(0xFFF59E0B)),
                        _chip2('Pay: ${sOf(order['paymentMethod'])}', const Color(0xFF64748B)),
                        if (sOf(order['paymentStatus']).isNotEmpty)
                          _chip2(sOf(order['paymentStatus']), const Color(0xFF64748B)),
                        if (sOf(order['orderTaker']).isNotEmpty)
                          _chip2('👤 ${order['orderTaker']}', const Color(0xFF2563EB)),
                        if (sOf(order['waiter']).isNotEmpty)
                          _chip2('👨‍🍳 ${order['waiter']}', const Color(0xFF7C3AED)),
                      ],
                    ),
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...items.map((it) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('▸ ${sOf(it['name'])}',
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                if (extras.contains(sOf(it['productId'] ?? it['id'] ?? it['name'])))
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Text('EXTRA',
                                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B))),
                                  ),
                                Text('${numOf(it['quantity']).round()} × ${numOf(it['price']).round()}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                const SizedBox(width: 8),
                                Text(_fmtMoney(numOf(it['total'] ?? (numOf(it['quantity']) * numOf(it['price'])))),
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          )),
                    ],
                    if (sOf(order['notes']).isNotEmpty) ...[
                      const Divider(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📝 ', style: TextStyle(fontSize: 11)),
                          Expanded(
                            child: Text(sOf(order['notes']),
                                style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                          ),
                        ],
                      ),
                    ],
                    if (sOf(order['address']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('📍 ${order['address']}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(_fmtMoney(numOf(order['total'] ?? order['amount'])),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState: open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 260),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip2(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: c)),
    );
  }

  String _fmtMoney(double v) {
    final s = v.round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},');
    return 'Rs $s';
  }
}