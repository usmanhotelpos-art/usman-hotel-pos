import 'package:flutter/material.dart';

import 'api.dart';
import 'order_taker_screen.dart' show sOf, numOf;

const Color _accent = Color(0xFF2563EB);
const Color _border = Color(0xFFE2E8F0);
const Color _txtDark = Color(0xFF1E293B);
const Color _txtDim = Color(0xFF64748B);

class DashboardScreen extends StatefulWidget {
  final List<dynamic> orders;
  final Map<String, dynamic> user;
  final List<dynamic> riders;
  final String token;
  const DashboardScreen({
    super.key,
    required this.orders,
    required this.user,
    this.riders = const [],
    this.token = '',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _range = 'today';
  DateTime? _from;
  DateTime? _to;
  bool _busy = false;
  late List<dynamic> _orders = widget.orders;

  static const List<Map<String, String>> _ranges = [
    {'key': 'today', 'label': 'Today'},
    {'key': 'yesterday', 'label': 'Yesterday'},
    {'key': 'last7', 'label': '7 Days'},
    {'key': 'last30', 'label': '30 Days'},
    {'key': 'month', 'label': 'This Month'},
    {'key': 'custom', 'label': 'Custom'},
    {'key': 'all', 'label': 'All'},
  ];

  List<Map<String, dynamic>> get _all => _orders
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((o) =>
        sOf(o['source']).trim().toLowerCase() == 'nashta-app')
      .toList();

  (DateTime, DateTime) _window() {
    final now = DateTime.now();
    final sod = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case 'yesterday':
        return (sod.subtract(const Duration(days: 1)), sod);
      case 'last7':
        return (sod.subtract(const Duration(days: 6)), sod.add(const Duration(days: 1)));
      case 'last30':
        return (sod.subtract(const Duration(days: 29)), sod.add(const Duration(days: 1)));
      case 'month':
        return (DateTime(now.year, now.month, 1), sod.add(const Duration(days: 1)));
      case 'custom':
        final f = _from ?? sod;
        final t = _to != null
            ? DateTime(_to!.year, _to!.month, _to!.day).add(const Duration(days: 1))
            : sod.add(const Duration(days: 1));
        return (f, t);
      case 'all':
        return (DateTime(2000), DateTime(2100));
      default:
        return (sod, sod.add(const Duration(days: 1)));
    }
  }

  List<Map<String, dynamic>> get _inRange {
    if (_range == 'all') return _all;
    final (from, to) = _window();
    return _all.where((o) {
      final d = DateTime.tryParse(sOf(o['createdAt']));
      return d != null && !d.isBefore(from) && d.isBefore(to);
    }).toList();
  }

  bool _isPaid(Map o) {
    final st = sOf(o['status']).toLowerCase();
    final p = sOf(o['paymentStatus']).toLowerCase();
    return st == 'payment collected' || st == 'paid' || p == 'paid';
  }

  bool _isDue(Map o) {
    final st = sOf(o['status']).toLowerCase();
    final p = sOf(o['paymentStatus']).toLowerCase();
    return st == 'due' || p == 'due';
  }

  bool _isDone(Map o) {
    final st = sOf(o['status']).toLowerCase();
    return st == 'completed' || st == 'delivered';
  }

  bool _isCancelled(Map o) => sOf(o['status']).toLowerCase() == 'cancelled';

  bool _isPaidOrDone(Map o) => _isPaid(o) || _isDone(o);

  bool _isActiveDelivery(Map o) {
    if (sOf(o['orderType']) != 'Delivery') return false;
    if (_isPaid(o) || _isDue(o) || _isDone(o) || _isCancelled(o)) return false;
    return true;
  }

  List<Map<String, dynamic>> _activeForRider(String rider) => _inRange
      .where((o) => _isActiveDelivery(o) && sOf(o['deliveryAgent']).trim() == rider)
      .toList();

  List<Map<String, dynamic>> get _activeUnassigned => _inRange
      .where((o) => _isActiveDelivery(o) && sOf(o['deliveryAgent']).trim().isEmpty)
      .toList();

  List<Map<String, dynamic>> get _dueOrders => _inRange
      .where((o) => sOf(o['orderType']) == 'Delivery' && _isDue(o) && !_isCancelled(o))
      .toList();

  List<String> get _allRiders {
    final set = <String>{};
    for (final r in widget.riders) {
      if (r is Map) {
        if (!sOf(r['role']).toLowerCase().contains('biker')) continue;
        if (sOf(r['status']).toLowerCase() != 'active') continue;
        final n = sOf(r['name']);
        if (n.isNotEmpty) set.add(n);
      }
    }
    for (final o in _all) {
      final a = sOf(o['deliveryAgent']).trim();
      if (a.isNotEmpty) set.add(a);
    }
    return set.toList();
  }

  Future<void> _refreshOrders() async {
    try {
      final r = await ApiClient.send('GET', '/pos/orders?source=nashta-app', token: widget.token);
      if (r is List && mounted) setState(() => _orders = r);
    } catch (_) {}
  }

  Future<void> _markDuePaid(Map<String, dynamic> o) async {
    final id = sOf(o['id']);
    if (id.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ApiClient.send('PUT', '/pos/orders/$id', token: widget.token, body: {
        'paymentStatus': 'paid',
        'status': 'Payment Collected',
        'paidAt': DateTime.now().toUtc().toIso8601String(),
      });
      await ApiClient.send('POST', '/pos/payments', token: widget.token, body: {
        'orderId': id,
        'amount': o['total'] ?? o['amount'] ?? 0,
        'paymentMethod': 'Cash',
        'status': 'Completed',
        'description': 'Due payment for order ${o['orderNumber'] ?? id}',
      }).catchError((_) {});
      if (!mounted) return;
      setState(() {
        for (final x in _orders) {
          if (x is Map && sOf(x['id']) == id) {
            x['paymentStatus'] = 'paid';
            x['status'] = 'Payment Collected';
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as paid')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openRiderSheet(String riderName, List<Map<String, dynamic>> orders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _RidersOrdersSheet(
          riderName: riderName,
          orders: orders,
          allRiders: _allRiders,
          token: widget.token,
        ),
      ),
    ).whenComplete(_refreshOrders);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final inRange = _inRange;
    final name = sOf(widget.user['name']).isNotEmpty
        ? sOf(widget.user['name'])
        : (sOf(widget.user['username']).isNotEmpty ? sOf(widget.user['username']) : 'Staff');

    int totalRev() => inRange.fold<int>(0, (s, o) => s + numOf(o['total'] ?? o['amount']).round());
    int byType(String t) => inRange.where((o) => sOf(o['orderType']) == t).length;
    int deliveryActive() => inRange.where((o) => _isActiveDelivery(o) && sOf(o['deliveryAgent']).trim().isEmpty).length;
    int deliveryAssigned() => inRange.where((o) => _isActiveDelivery(o) && sOf(o['deliveryAgent']).trim().isNotEmpty).length;
    int takeawayPaid() => inRange.where((o) => sOf(o['orderType']) == 'Takeaway' && _isPaidOrDone(o)).length;
    int takeawayLater() => inRange.where((o) => sOf(o['orderType']) == 'Takeaway' && !_isPaidOrDone(o)).length;
    int tablePaid() => inRange.where((o) => sOf(o['orderType']) == 'Dine-In' && _isPaidOrDone(o)).length;
    int tableActive() => inRange.where((o) => sOf(o['orderType']) == 'Dine-In' && !_isPaidOrDone(o) && !_isCancelled(o)).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        actions: [
          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Color(0xFFDC2626))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Text('Assalam o Alaikum, $name', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text('${now.day}/${now.month}/${now.year}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 8),
        _buildDateFilter(),
        const SizedBox(height: 12),
        _buildRidersPanel(),
        const SizedBox(height: 14),
        _card('Revenue', '${totalRev()} PKR', const Color(0xFF059669)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _mini('Total Orders', '${inRange.length}', const Color(0xFF2563EB))),
          const SizedBox(width: 10),
          Expanded(child: _mini('Delivery', '${byType('Delivery')}', const Color(0xFF0EA5E9))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _mini('Takeaway', '${byType('Takeaway')}', const Color(0xFFF59E0B))),
          const SizedBox(width: 10),
          Expanded(child: _mini('Table (Dine-In)', '${byType('Dine-In')}', const Color(0xFF7C3AED))),
        ]),
        const SizedBox(height: 14),
        const Text('Delivery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0EA5E9))),
        Row(children: [
          Expanded(child: _mini('Pending', '${deliveryActive()}', const Color(0xFFDC2626))),
          const SizedBox(width: 10),
          Expanded(child: _mini('Rider Assigned', '${deliveryAssigned()}', const Color(0xFF059669))),
        ]),
        const SizedBox(height: 14),
        const Text('Takeaway', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B))),
        Row(children: [
          Expanded(child: _mini('Paid', '${takeawayPaid()}', const Color(0xFF059669))),
          const SizedBox(width: 10),
          Expanded(child: _mini('Pay Later', '${takeawayLater()}', const Color(0xFFDC2626))),
        ]),
        const SizedBox(height: 14),
        const Text('Table', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))),
        Row(children: [
          Expanded(child: _mini('Paid', '${tablePaid()}', const Color(0xFF059669))),
          const SizedBox(width: 10),
          Expanded(child: _mini('Active', '${tableActive()}', const Color(0xFFDC2626))),
        ]),
        const SizedBox(height: 18),
        _buildDuePanel(),
      ]),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Date Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _txtDark)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _ranges.map((r) {
              final active = _range == r['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(r['label']!),
                  selected: active,
                  onSelected: (_) => setState(() => _range = r['key']!),
                  selectedColor: _accent,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : _txtDim,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: BorderSide(color: active ? _accent : _border),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_range == 'custom') ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _customDateBtn('From: ${_fmtDate(_from)}', () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _from ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => _from = p);
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _customDateBtn('To: ${_fmtDate(_to)}', () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _to ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => _to = p);
              }),
            ),
            if (_from != null || _to != null)
              IconButton(
                onPressed: () => setState(() { _from = null; _to = null; }),
                icon: const Icon(Icons.refresh, size: 18, color: _txtDim),
                tooltip: 'Reset custom dates',
              ),
          ]),
        ],
      ]),
    );
  }

  String _fmtDate(DateTime? d) => d == null
      ? 'Any'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _customDateBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _accent.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: _accent),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _txtDark))),
          ]),
        ),
      );

  Widget _buildRidersPanel() {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final rider in _allRiders) {
      final lst = _activeForRider(rider);
      if (lst.isNotEmpty) groups[rider] = lst;
    }
    final unassigned = _activeUnassigned;
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (unassigned.isNotEmpty) entries.add(MapEntry('Unassigned', unassigned));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('Riders & Orders', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _txtDark)),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text('No active delivery orders in range', style: TextStyle(fontSize: 13, color: _txtDim)),
            )
          else
            ...entries.map((e) => _riderRow(e.key, e.value)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _riderRow(String name, List<Map<String, dynamic>> orders) {
    final isUn = name == 'Unassigned';
    return InkWell(
      onTap: orders.isNotEmpty ? () => _openRiderSheet(name, orders) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: (isUn ? Colors.amber : _accent).withValues(alpha: 0.15),
              child: Icon(isUn ? Icons.help_outline : Icons.person, size: 18, color: isUn ? Colors.amber : _accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _txtDark)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
              child: Text('${orders.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _accent)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: _txtDim, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDuePanel() {
    if (_dueOrders.isEmpty) return const SizedBox.shrink();
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final o in _dueOrders) {
      final r = sOf(o['deliveryAgent']).trim();
      groups.putIfAbsent(r.isNotEmpty ? r : 'Unassigned', () => []).add(o);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFDBA74))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('Due Orders', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFFEA580C))),
          ),
          ...entries.map((e) => _dueRiderBlock(e.key, e.value)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _dueRiderBlock(String rider, List<Map<String, dynamic>> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Row(children: [
            const Icon(Icons.person_outline, size: 16, color: Color(0xFFEA580C)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(rider, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _txtDark)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(100)),
              child: Text('${orders.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
            ),
          ]),
        ),
        ...orders.map((o) => _dueOrderRow(o)),
      ],
    );
  }

  Widget _dueOrderRow(Map<String, dynamic> o) {
    final id = sOf(o['id']);
    final addr = sOf(o['address']);
    final loc = sOf(o['serviceType']);
    final total = numOf(o['total'] ?? o['amount']);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('#${sOf(o['orderNumber']).isNotEmpty ? o['orderNumber'] : id}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _txtDark)),
          ),
          _miniBtn('Mark Paid', () => _markDuePaid(o)),
        ]),
        if (loc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFFB45309)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(loc, style: const TextStyle(fontSize: 12, color: Color(0xFF78350F))),
              ),
            ]),
          ),
        if (addr.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(addr, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF78350F))),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Total: ${_fmtNum(total)} PKR',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
        ),
      ]),
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: _busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      );

  Widget _card(String label, String value, Color c) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        ]),
      );

  Widget _mini(String label, String value, Color c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
        child: Column(children: [
          Text(value, style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _txtDim, fontSize: 11)),
        ]),
      );

  String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);
}

class _RidersOrdersSheet extends StatefulWidget {
  final String riderName;
  final List<Map<String, dynamic>> orders;
  final List<String> allRiders;
  final String token;

  const _RidersOrdersSheet({
    required this.riderName,
    required this.orders,
    required this.allRiders,
    required this.token,
  });

  @override
  State<_RidersOrdersSheet> createState() => _RidersOrdersSheetState();
}

class _RidersOrdersSheetState extends State<_RidersOrdersSheet> {
  final Set<String> _selected = {};
  final TextEditingController _search = TextEditingController();
  String _q = '';
  bool _busy = false;

  List<Map<String, dynamic>> get _filtered {
    final q = _q.toLowerCase();
    if (q.isEmpty) return widget.orders;
    return widget.orders.where((o) {
      final addr = _addrStr(o['address']).toLowerCase();
      final loc = sOf(o['serviceType']).toLowerCase();
      final num = (sOf(o['orderNumber']).isEmpty ? sOf(o['id']) : sOf(o['orderNumber'])).toLowerCase();
      final cust = sOf(o['customerName']).toLowerCase();
      return addr.contains(q) || loc.contains(q) || num.contains(q) || cust.contains(q);
    }).toList();
  }

  String _addrStr(dynamic a) {
    if (a == null) return '';
    if (a is String) return a;
    if (a is Map) {
      return [
        a['street'] ?? a['line1'],
        a['city'],
        a['area'],
        a['block'],
      ].where((s) => s != null && s.toString().isNotEmpty).join(', ').trim();
    }
    return a.toString();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _changeRider() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final targets = widget.allRiders.where((r) => r != widget.riderName).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other rider available')));
      return;
    }
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign ${ids.length} order(s) to'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: targets.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(targets[i]),
              onTap: () => Navigator.pop(ctx, targets[i]),
            ),
          ),
        ),
      ),
    );
    if (pick == null || pick.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final id in ids) {
        await ApiClient.send(
          'PUT',
          '/pos/orders/$id/assign-rider',
          token: widget.token,
          body: {'deliveryAgent': pick},
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned to $pick')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUn = widget.riderName == 'Unassigned';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _border)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUn ? 'Unassigned Orders' : '${widget.riderName} \u2014 Orders',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _txtDark),
                    ),
                    const SizedBox(height: 2),
                    Text('${widget.orders.length} active orders', style: const TextStyle(fontSize: 11, color: _txtDim)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: _txtDim),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _q = v),
            style: const TextStyle(fontSize: 14, color: _txtDark),
            decoration: InputDecoration(
              hintText: 'Search address, location, order #',
              hintStyle: const TextStyle(fontSize: 13, color: _txtDim),
              prefixIcon: const Icon(Icons.search, size: 18, color: _txtDim),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('No orders', style: TextStyle(color: _txtDim)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final o = _filtered[i];
                    final id = sOf(o['id']);
                    final num = sOf(o['orderNumber']).isNotEmpty ? sOf(o['orderNumber']) : (id.isEmpty ? '-' : id);
                    final addr = _addrStr(o['address']);
                    final loc = sOf(o['serviceType']);
                    final sel = _selected.contains(id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: sel ? _accent : _border),
                      ),
                      child: InkWell(
                        onTap: () => _toggle(id),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                sel ? Icons.check_circle : Icons.radio_button_off,
                                color: sel ? _accent : _txtDim,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('#$num', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _txtDark)),
                                    const SizedBox(height: 3),
                                    if (addr.isNotEmpty)
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('\u{1F4E7} ', style: TextStyle(fontSize: 12)),
                                          Expanded(child: Text(addr, style: const TextStyle(fontSize: 12, color: _txtDim))),
                                        ],
                                      ),
                                    if (loc.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          children: [
                                            const Text('\u{1F4CD} ', style: TextStyle(fontSize: 12)),
                                            Expanded(child: Text(loc, style: const TextStyle(fontSize: 12, color: _txtDim))),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _border))),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selected.length == _filtered.length && _filtered.isNotEmpty) {
                      _selected.clear();
                    } else {
                      _selected.clear();
                      for (final o in _filtered) {
                        final id = sOf(o['id']);
                        if (id.isNotEmpty) _selected.add(id);
                      }
                    }
                  });
                },
                child: Text(
                  _selected.length == _filtered.length && _filtered.isNotEmpty ? 'Clear' : 'Select All',
                  style: const TextStyle(color: _accent, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _busy || _selected.isEmpty ? null : _changeRider,
                icon: _busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.swap_horiz, size: 16),
                label: Text(_selected.isEmpty ? 'Change Rider' : 'Change Rider (${_selected.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}