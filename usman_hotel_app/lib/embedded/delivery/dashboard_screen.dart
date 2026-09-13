import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'bmp_receipt.dart' as bmp;
import 'bt_service.dart';
import 'escpos.dart' as esc;
import 'order_taker_screen.dart' show sOf, numOf, dateTime12;

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
  String _dashTab = 'due';
  String _dashQ = '';
  String _riderF = '';
  String _userF = '';
  final Set<String> _mergeSel = {};
  final Set<String> _expandedItems = {};
  final Set<String> _expandedCards = {};
  final Set<String> _fading = {};
  Map<String, String> _prodCats = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshOrders);
  }

  bool get isManager {
    final r = sOf(widget.user['role']).toLowerCase();
    return r.contains('manager') || r.contains('admin');
  }

  bool get _isCashier =>
      sOf(widget.user['role']).toLowerCase().contains('cashier');

  static const Color _reserved = Color(0xFF991B1B);
  static const Color _reservedBg = Color(0xFFFFF1F2);
  static const Color _mergeBox = Color(0xFF4C1D95);

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
      .where((o) {
        if (sOf(o['orderType']).trim().toLowerCase() != 'delivery') return false;
        return sOf(o['source']).trim().toLowerCase() == 'bbq-delivery-app';
      })
      .toList();

  List<Map<String, dynamic>> get _allDelivery => _orders
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((o) => sOf(o['orderType']).trim().toLowerCase() == 'delivery')
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

  bool _isReserved(Map o) =>
      o['reserved'] == true || sOf(o['reserved']) == 'true';

  bool _isPaidOrDone(Map o) => _isPaid(o) || _isDone(o);

  bool _isActiveDelivery(Map o) {
    if (sOf(o['orderType']) != 'Delivery') return false;
    if (_isReserved(o)) return false;
    if (_isPaid(o) || _isDue(o) || _isDone(o) || _isCancelled(o)) return false;
    return true;
  }

  List<Map<String, dynamic>> _activeForRider(String rider) => _inRange
      .where((o) => _isActiveDelivery(o) && sOf(o['deliveryAgent']).trim() == rider)
      .toList();

  List<Map<String, dynamic>> get _activeUnassigned => _inRange
      .where((o) => _isActiveDelivery(o) && sOf(o['deliveryAgent']).trim().isEmpty)
      .toList();

  List<Map<String, dynamic>> get _dueOrders => _allDelivery
      .where((o) =>
          sOf(o['orderType']) == 'Delivery' &&
          _isDue(o) &&
          !_isCancelled(o) &&
          !_isReserved(o))
      .toList();

  List<Map<String, dynamic>> get _reservedOrders => _allDelivery
      .where((o) =>
          _isReserved(o) &&
          sOf(o['orderType']) == 'Delivery' &&
          !_isCancelled(o) &&
          !_isPaid(o))
      .toList();

  List<Map<String, dynamic>> _tabOrders(String tab) {
    final q = _dashQ.trim().toLowerCase();
    var list = tab == 'reserved' ? _reservedOrders : _dueOrders;
    if (_range == 'custom') {
      final (from, to) = _window();
      list = list
          .where((o) {
            final d = DateTime.tryParse(sOf(o['createdAt']));
            return d != null && !d.isBefore(from) && d.isBefore(to);
          })
          .toList();
    }
    if (_riderF.isNotEmpty) {
      final rf = _riderF.trim().toLowerCase();
      list = list
          .where((o) => sOf(o['deliveryAgent']).trim().toLowerCase() == rf)
          .toList();
    }
    if (_userF.isNotEmpty) {
      final uf = _userF.trim().toLowerCase();
      list = list
          .where((o) {
            final ot = sOf(o['orderTaker']).trim().toLowerCase();
            final ow = sOf(o['waiter']).trim().toLowerCase();
            final name = ot.isNotEmpty ? ot : ow;
            return name == uf;
          })
          .toList();
    }
    if (q.isEmpty) return list;
    return list.where((o) {
      return sOf(o['orderNumber']).toLowerCase().contains(q) ||
          sOf(o['id']).toLowerCase().contains(q) ||
          sOf(o['customerName']).toLowerCase().contains(q) ||
          sOf(o['phone']).toLowerCase().contains(q) ||
          sOf(o['address']).toLowerCase().contains(q) ||
          sOf(o['serviceType']).toLowerCase().contains(q) ||
          sOf(o['deliveryAgent']).toLowerCase().contains(q) ||
          sOf(o['notes']).toLowerCase().contains(q);
    }).toList();
  }

  Map<String, dynamic>? _orderById(String id) {
    for (final o in _all) {
      if (sOf(o['id']) == id) return o;
    }
    return null;
  }

  List<Map<String, dynamic>> _mergedMembers(String groupId) {
    final out = _allDelivery.where((o) => sOf(o['mergeGroupId']) == groupId).toList();
    out.sort((a, b) {
      final ta = DateTime.tryParse(sOf(a['createdAt'])) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(sOf(b['createdAt'])) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return out;
  }

  String _sig(Map<String, dynamic> o) =>
      '${_an(o['address'])}|${_an(o['serviceType'])}';

  String _an(dynamic v) => v == null ? '' : v.toString().trim().toLowerCase();

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
    final merged = <Map<String, dynamic>>[];
    for (final s in ['bbq-delivery-app', 'nashta-app']) {
      merged.addAll(await _fetchOrdersQ('?source=$s'));
    }
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final o in merged) {
      final id = sOf(o['id']);
      if (id.isNotEmpty && !seen.add(id)) continue;
      out.add(o);
    }
    try {
      final pr = await ApiClient.send('GET', '/pos/products', token: widget.token);
      if (pr is List) {
        final m = <String, String>{};
        for (final p in pr.whereType<Map>()) {
          final c = sOf(p['category']).toLowerCase();
          if (c.isEmpty) continue;
          final id = sOf(p['id']).trim().toLowerCase();
          final nm = sOf(p['name']).trim().toLowerCase();
          if (id.isNotEmpty) m['id:$id'] = c;
          if (nm.isNotEmpty) m['name:$nm'] = c;
        }
        _prodCats = m;
      }
    } catch (_) {}
    if (mounted) setState(() => _orders = out);
  }

  Future<List<Map<String, dynamic>>> _fetchOrdersQ(String q) async {
    try {
      final r =
          await ApiClient.send('GET', '/pos/orders$q', token: widget.token);
      if (r is List) {
        return r
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  String _itemCategory(Map<String, dynamic> item) {
    final id = sOf(item['productId']).trim().toLowerCase();
    final nm = sOf(item['name']).trim().toLowerCase();
    return _prodCats['id:$id'] ?? _prodCats['name:$nm'] ?? '';
  }

  num _extrasAmountOf(Map<String, dynamic> o) {
    final items = (o['items'] as List?)?.whereType<Map>() ?? const [];
    num sum = 0;
    for (final it in items) {
      final cat = _itemCategory(Map<String, dynamic>.from(it));
      if (!(cat.contains('extra') || cat.contains('addon'))) continue;
      sum += numOf(it['total'] ?? (numOf(it['price']) * numOf(it['quantity'])));
    }
    return sum;
  }

  num _revenueOf(Map<String, dynamic> o) =>
      numOf(o['total'] ?? o['amount']) +
      numOf(o['deliveryFee']) +
      _extrasAmountOf(o);

  Future<void> _markDuePaid(Map<String, dynamic> o) async {
    if (_busy) return;
    final gid = sOf(o['mergeGroupId']);
    final members = gid.isNotEmpty
        ? _mergedMembers(gid).toList()
        : <Map<String, dynamic>>[Map<String, dynamic>.from(o)];
    final targets = members.where((m) => sOf(m['id']).isNotEmpty).toList();
    if (targets.isEmpty) return;
    final fadeKey = gid.isNotEmpty ? 'g:$gid' : 'o:${sOf(o['id'])}';
    setState(() {
      _busy = true;
      _fading.add(fadeKey);
    });
    final paidAt = DateTime.now().toUtc().toIso8601String();
    try {
      await Future.wait(targets.map((m) async {
        final id = sOf(m['id']);
        await ApiClient.send('PUT', '/pos/orders/$id',
            token: widget.token,
            body: {
              'paymentStatus': 'paid',
              'status': 'Payment Collected',
              'paidAt': paidAt,
            });
        await ApiClient.send('POST', '/pos/payments', token: widget.token, body: {
          'orderId': id,
          'amount': m['total'] ?? m['amount'] ?? 0,
          'paymentMethod': 'Cash',
          'status': 'Completed',
          'description': 'Due payment for order ${m['orderNumber'] ?? id}',
        }).catchError((_) {});
      }));
      if (!mounted) return;
      setState(() {
        final ids = targets.map((m) => sOf(m['id'])).toSet();
        for (final x in _orders) {
          if (x is Map && ids.contains(sOf(x['id']))) {
            x['paymentStatus'] = 'paid';
            x['status'] = 'Payment Collected';
          }
        }
        _fading.remove(fadeKey);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(targets.length > 1 ? 'Merged (${targets.length}) marked as paid' : 'Marked as paid')));
    } catch (e) {
      if (mounted) {
        setState(() => _fading.remove(fadeKey));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markReturnToActive(Map<String, dynamic> o) async {
    final id = sOf(o['id']);
    if (id.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _fading.add('o:$id');
    });
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await ApiClient.send('PUT', '/pos/orders/$id', token: widget.token, body: {
        'status': 'Active',
        'paymentStatus': 'Pending',
        'activeAt': now,
      });
      if (!mounted) return;
      setState(() {
        for (final x in _orders) {
          if (x is Map && sOf(x['id']) == id) {
            x['status'] = 'Active';
            x['paymentStatus'] = 'Pending';
          }
        }
        _fading.remove('o:$id');
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order returned to Active \u2713')));
    } catch (e) {
      if (mounted) {
        setState(() => _fading.remove('o:$id'));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Merged sheet ke andar ek single order ko merged group se nikal kar paid
  /// mark karta hai. Returns true on success.
  Future<bool> _markOrderPaidDash(Map<String, dynamic> o) async {
    final id = sOf(o['id']);
    if (id.isEmpty || _busy) return false;
    setState(() => _busy = true);
    final paidAt = DateTime.now().toUtc().toIso8601String();
    try {
      await ApiClient.send('PUT', '/pos/orders/$id',
          token: widget.token,
          body: {
            'paymentStatus': 'paid',
            'status': 'Payment Collected',
            'paidAt': paidAt,
            'mergeGroupId': '',
            'mergedOrderIds': <dynamic>[],
            'mergedTotal': 0,
          });
      await ApiClient.send('POST', '/pos/payments', token: widget.token, body: {
        'orderId': id,
        'amount': o['total'] ?? o['amount'] ?? 0,
        'paymentMethod': 'Cash',
        'status': 'Completed',
        'description': 'Due payment for order ${o['orderNumber'] ?? id}',
      }).catchError((_) {});
      if (!mounted) return false;
      setState(() {
        for (final x in _orders) {
          if (x is Map && sOf(x['id']) == id) {
            x['paymentStatus'] = 'paid';
            x['status'] = 'Payment Collected';
            x['mergeGroupId'] = '';
            x['mergedOrderIds'] = <dynamic>[];
            x['mergedTotal'] = 0;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('#${o['orderNumber'] ?? id} marked as paid \u2713')));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markReservedDash(Map<String, dynamic> o) async {
    final id = sOf(o['id']);
    if (id.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _fading.add('o:$id');
    });
    try {
      await ApiClient.send('PUT', '/pos/orders/$id', token: widget.token, body: {
        'reserved': true,
        'reservedAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      setState(() {
        for (final x in _orders) {
          if (x is Map && sOf(x['id']) == id) {
            x['reserved'] = true;
            x['reservedAt'] = DateTime.now().toUtc().toIso8601String();
          }
        }
        _fading.remove('o:$id');
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as Reserved')));
    } catch (e) {
      if (mounted) {
        setState(() => _fading.remove('o:$id'));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _deleteOrderDash(Map<String, dynamic> o) async {
    final id = sOf(o['id']);
    if (id.isEmpty || _busy) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete order?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: Text('#${sOf(o['orderNumber']).isNotEmpty ? o['orderNumber'] : id} \u2014 kya yahi order delete karna hai?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return false;
    setState(() {
      _busy = true;
      _fading.add('o:$id');
    });
    try {
      await ApiClient.send('DELETE', '/pos/orders/$id', token: widget.token);
      if (!mounted) return false;
      setState(() {
        _orders.removeWhere((x) => x is Map && sOf(x['id']) == id);
        _fading.remove('o:$id');
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order deleted')));
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _fading.remove('o:$id'));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printDash(Map<String, dynamic> o0) async {
    final order = Map<String, dynamic>.from(o0);
    if (sOf(order['waiter']).isEmpty) order['waiter'] = order['orderTaker'];
    if (sOf(order['date']).isEmpty) {
      order['date'] = sOf(order['createdAt']).isNotEmpty
          ? order['createdAt']
          : DateTime.now().toIso8601String();
    }
    if (!(await BtService.ensurePermission())) {
      throw Exception(BtService.lastError.isEmpty
          ? 'Bluetooth permission denied'
          : BtService.lastError);
    }
    if (!(await BtService.bluetoothEnabled())) {
      throw Exception('Phone ka Bluetooth OFF hai - pehle Bluetooth on karein');
    }
    var printer = await BtService.savedPrinter();
    if (printer == null) {
      final list = await BtService.pairedPrinters();
      if (list.isEmpty) {
        throw Exception('No paired printer found - pair your thermal printer first');
      }
      printer = await showDialog<PrinterInfo>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Bluetooth Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.print, color: Color(0xFF059669)),
                title: Text(list[i].name),
                subtitle: Text(list[i].mac),
                onTap: () => Navigator.pop(ctx, list[i]),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
        ),
      );
      if (printer == null) return;
      await BtService.savePrinter(printer);
    }
    final target = printer;
    try {
      if (!(await BtService.isConnected())) {
        final ok = await BtService.connect(target);
        if (!ok) throw Exception('Could not connect to ${target.name}');
      }
      final prefs = await SharedPreferences.getInstance();
      final settings = <String, dynamic>{};
      final raw = prefs.getString('nshBtPrinterOverrides');
      if (raw != null && raw.isNotEmpty) {
        try {
          final d = jsonDecode(raw);
          if (d is Map) settings.addAll(Map<String, dynamic>.from(d));
        } catch (_) {}
      }
      final enc = (settings['btEncoding'] ?? '').toString();
      final isBmp = enc.isEmpty || enc == 'bmp';
      final out = BytesBuilder();
      if (isBmp) {
        out.add(await bmp.buildBmpReceipt(order, settings, host: ApiClient.host));
      } else {
        try {
          out.add(esc.buildEscposReceipt(order, settings));
        } catch (_) {
          out.add(await bmp.buildBmpReceipt(order, settings, host: ApiClient.host));
        }
      }
      await BtService.write(out.toBytes());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red));
      }
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
          isCashier: sOf(widget.user['role']).toLowerCase().contains('cashier'),
        ),
      ),
    ).whenComplete(_refreshOrders);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final inRange = _inRange;
    final activeRange = inRange.where((o) => !_isCancelled(o)).toList();
    final name = sOf(widget.user['name']).isNotEmpty
        ? sOf(widget.user['name'])
        : (sOf(widget.user['username']).isNotEmpty ? sOf(widget.user['username']) : 'Staff');

    int totalRev() =>
        activeRange.fold<int>(0, (s, o) => s + _revenueOf(o).round());
    int deliveryActive() => activeRange.where((o) => _isActiveDelivery(o) && sOf(o['deliveryAgent']).trim().isEmpty).length;
    int deliveryAssigned() => activeRange.where((o) => _isActiveDelivery(o) && sOf(o['deliveryAgent']).trim().isNotEmpty).length;

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
          Expanded(child: _mini('Total Delivery Orders', '${activeRange.length}', const Color(0xFF2563EB))),
          const SizedBox(width: 10),
          Expanded(child: _mini('Pending', '${deliveryActive()}', const Color(0xFFDC2626))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _mini('Rider Assigned', '${deliveryAssigned()}', const Color(0xFF0EA5E9))),
          const SizedBox(width: 10),
          Expanded(child: _mini('Delivered', '${activeRange.where((o) => _isPaidOrDone(o)).length}', const Color(0xFF059669))),
        ]),
        const SizedBox(height: 18),
        _buildOrdersTabs(),
      ]),
    );
  }

  Widget _buildOrdersTabs() {
    final due = _dueOrders;
    final reserved = _reservedOrders;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(children: [
              _orderTabChip('due', 'Due Orders', due.length, const Color(0xFFEA580C)),
              const SizedBox(width: 8),
              _orderTabChip('reserved', 'Reserved', reserved.length, _reserved),
              if (_mergeSel.isNotEmpty) const Spacer(),
              if (_mergeSel.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(_mergeSel.clear),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, size: 16, color: _txtDim),
                  ),
                ),
            ]),
          ),
          if (_mergeSel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: _mergeBar(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(children: [
              Expanded(
                child: _filterDropdown('All Riders', _riderF, _riderOptions,
                    (v) => setState(() => _riderF = v)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filterDropdown('All Users', _userF, _userOptions,
                    (v) => setState(() => _userF = v)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _dashSearchField(),
          ),
          const Divider(height: 0, color: _border),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: _listSection(_dashTab),
          ),
        ],
      ),
    );
  }

  List<String> get _riderOptions {
    final s = <String>{};
    for (final o in _allDelivery) {
      final r = sOf(o['deliveryAgent']).trim();
      if (r.isNotEmpty) s.add(r);
    }
    return s.toList()..sort();
  }

  List<String> get _userOptions {
    final s = <String>{};
    for (final o in _allDelivery) {
      final ot = sOf(o['orderTaker']).trim();
      final ow = sOf(o['waiter']).trim();
      if (ot.isNotEmpty) s.add(ot);
      if (ow.isNotEmpty) s.add(ow);
    }
    return s.toList()..sort();
  }

  Widget _filterDropdown(
      String hint, String value, List<String> opts, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty || !opts.contains(value) ? null : value,
          isDense: true,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 12, color: _txtDim)),
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: _txtDim),
          items: [
            DropdownMenuItem(
                value: '',
                child: Text(hint, style: const TextStyle(fontSize: 12))),
            ...opts.map((o) => DropdownMenuItem(
                value: o, child: Text(o, style: const TextStyle(fontSize: 12)))),
          ],
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }

  Widget _orderTabChip(String key, String label, int count, Color c) {
    final sel = _dashTab == key;
    return GestureDetector(
      onTap: () => setState(() {
        _dashTab = key;
        _mergeSel.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? c : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: sel ? c : const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Text('$label ($count)',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: sel ? Colors.white : c)),
      ),
    );
  }

  Widget _dashSearchField() => TextField(
        onChanged: (v) => setState(() => _dashQ = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search orders...',
          prefixIcon: const Icon(Icons.search, size: 18, color: _txtDim),
          suffixIcon: _dashQ.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16, color: _txtDim),
                  onPressed: () => setState(() => _dashQ = '')),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      );

  Widget _listSection(String tab) {
    final reservedTab = tab == 'reserved';
    final all = _tabOrders(tab);
    final singles = all.where((o) => sOf(o['mergeGroupId']).isEmpty).toList();
    final members = all.where((o) => sOf(o['mergeGroupId']).isNotEmpty).toList();
    if (singles.isEmpty && members.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Text('No orders in this view',
            style: TextStyle(fontSize: 13, color: _txtDim)),
      );
    }
    final sigGroups = <String, List<Map<String, dynamic>>>{};
    for (final o in singles) {
      (sigGroups[_sig(o)] ??= []).add(o);
    }
    final mergeable = <String>{
      for (final e in sigGroups.entries)
        if (e.value.length >= 2) e.key
    };
    for (final m in members) {
      mergeable.add(_sig(m));
    }
    final groupIds = <String>{};
    for (final o in members) {
      final g = sOf(o['mergeGroupId']);
      if (g.isNotEmpty) groupIds.add(g);
    }
    final groupList = groupIds.toList()..sort();
    final pendingSigs = <String>{
      for (final o in singles)
        if (mergeable.contains(_sig(o))) _sig(o)
    };
    final units = <({String label, DateTime when, Widget card})>[];
    for (final o in singles) {
      units.add((
        label: _dateHeaderOf(sOf(o['createdAt'])),
        when: _whenOf(o),
        card: _dashOrderCard(o,
            reservedTab: reservedTab,
            mergeable: mergeable.contains(_sig(o))),
      ));
    }
    for (final g in groupList) {
      final membersG = _mergedMembers(g);
      if (membersG.isEmpty) continue;
      units.add((
        label: _dateHeaderOf(sOf(membersG.first['createdAt'])),
        when: _whenOf(membersG.first),
        card: _mergedCard(g,
            pending: pendingSigs.contains(_sig(membersG.first)),
            tab: tab),
      ));
    }
    units.sort((a, b) => b.when.compareTo(a.when));
    final out = <Widget>[];
    ({String label, List<Widget> cards})? cur;
    for (final u in units) {
      if (cur == null || cur.label != u.label) {
        if (cur != null) {
          out.add(_dateSep(cur.label));
          out.addAll(cur.cards);
        }
        cur = (label: u.label, cards: [u.card]);
      } else {
        cur.cards.add(u.card);
      }
    }
    if (cur != null) {
      out.add(_dateSep(cur.label));
      out.addAll(cur.cards);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }

  DateTime _whenOf(Map<String, dynamic> o) =>
      DateTime.tryParse(sOf(o['createdAt'])) ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _dateHeaderOf(String iso) {
    final raw = DateTime.tryParse(iso);
    if (raw == null) return '';
    final d = esc.applyTimeZone(raw, 5);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    const mons = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${mons[d.month - 1]} ${d.year}';
  }

  Widget _dateSep(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.4)),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1, color: Color(0xFFE2E8F0))),
        ]),
      );

  Widget _dashOrderCard(Map<String, dynamic> o,
      {required bool reservedTab, required bool mergeable}) {
    final id = sOf(o['id']);
    final addr = sOf(o['address']);
    final loc = sOf(o['serviceType']);
    final total = numOf(o['total'] ?? o['amount']);
    final dt = dateTime12(sOf(o['createdAt']));
    final day = _dayOfWeek(sOf(o['createdAt']));
    final rider = sOf(o['deliveryAgent']);
    final _custN = sOf(o['customerName']);
    final _takerN = sOf(o['orderTaker']);
    final _waiterN = sOf(o['waiter']);
    final pickupFlagB = o['pickup'] == true || sOf(o['pickup']) == 'true';
    final isPickup = rider.isEmpty &&
        (pickupFlagB ||
            (_custN.isNotEmpty &&
                _custN == _takerN &&
                (_waiterN.isEmpty || _custN == _waiterN)));
    final pickUpName = isPickup ? _custN : '';
    final deliveryUser = rider.isNotEmpty
        ? rider
        : (_takerN.isNotEmpty ? _takerN : _waiterN);
    final selected = _mergeSel.contains(id);
    final items = (o['items'] as List?)?.whereType<Map>().toList() ?? [];
    final cardExpanded = _expandedCards.contains(id);
    final expandItems = _expandedItems.contains(id) || cardExpanded;
    final border = selected
        ? _reserved
        : (mergeable
            ? const Color(0xFFB91C1C)
            : (reservedTab
                ? const Color(0xFF7F1D1D)
                : const Color(0xFFEA580C)));
    final bg = mergeable
        ? _reservedBg
        : (reservedTab ? const Color(0xFFFFF1F2) : const Color(0xFFFFF7ED));
    final glow =
        reservedTab ? const Color(0xFFDC2626) : const Color(0xFFEA580C);
    final glow2 =
        reservedTab ? const Color(0xFF991B1B) : const Color(0xFFB45309);
    return _fadeWrap('o:$id', Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: selected || mergeable ? 1.6 : 1.2),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => _toggleCardExpand(id),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (loc.isNotEmpty)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_on_outlined, size: 17, color: _txtDim),
                const SizedBox(width: 6),
                Expanded(child: _glowText(loc, color: glow, size: 16)),
              ]),
            if (addr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.location_on, size: 17, color: _txtDim),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _glowText(
                      addr,
                      color: mergeable ? const Color(0xFFB91C1C) : glow2,
                      size: 15.5,
                      maxLines: 3,
                    ),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Row(children: [
                GestureDetector(
                  onTap: () => _toggleMergeId(o),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      selected ? Icons.check_circle : Icons.radio_button_off,
                      size: 22,
                      color: selected ? _reserved : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                Expanded(
                  child: _glowText('Total: ${_fmtNum(total)} PKR',
                      color: glow2, size: 16),
                ),
                if (mergeable)
                  GestureDetector(
                    onTap: () => _toggleMergeOrder(o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected ? _reserved : const Color(0xFFB91C1C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(selected ? 'Selected \u2713' : 'Merge',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
              ]),
            ),
            if (dt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(children: [
                  const Icon(Icons.calendar_month, size: 17, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _glowText(
                        (day.isNotEmpty ? '$day \u00B7 ' : '') + dt,
                        color: glow2,
                        size: 16),
                  ),
                ]),
              ),
            if (isPickup) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.takeout_dining, size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: _glowText(pickUpName.isEmpty ? 'Pick Up' : pickUpName,
                        color: const Color(0xFFB45309), size: 16, maxLines: 1),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _typePill('PICK UP', const Color(0xFFB45309), Icons.takeout_dining),
              ),
            ] else if (deliveryUser.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.delivery_dining, size: 18, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: _glowText(deliveryUser,
                        color: const Color(0xFF1D4ED8), size: 16, maxLines: 1),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _typePill('DELIVERY', const Color(0xFF1D4ED8), Icons.delivery_dining),
              ),
            ],
            if (items.isNotEmpty) ...[
              InkWell(
                onTap: () => _toggleItems(id),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Icon(
                        expandItems
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: glow2),
                    const SizedBox(width: 4),
                    Text('View Items (${items.length})',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: glow2)),
                  ]),
                ),
              ),
              if (expandItems)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final it in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              '${it['quantity']}x ${it['name']} ${sOf(it['flavor']).isNotEmpty ? '(${it['flavor']})' : ''}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B)),
                            ),
                          ),
                          Text(
                              _fmtNum(numOf(it['price']) * numOf(it['quantity'])),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B))),
                        ]),
                      ),
                  ]),
                ),
            ],
            if (sOf(o['notes']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(sOf(o['notes']),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155))),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(Icons.receipt_long, size: 13,
                    color: cardExpanded ? glow2 : const Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '#${sOf(o['orderNumber']).isNotEmpty ? o['orderNumber'] : id}',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cardExpanded ? glow2 : const Color(0xFF64748B)),
                  ),
                ),
                Icon(
                    cardExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 17,
                    color: glow2),
                const SizedBox(width: 4),
                Text(cardExpanded ? 'Hide' : 'Actions',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: glow2)),
              ]),
            ),
          ]),
        ),
        if (cardExpanded) ...[
          if (reservedTab) ...[
            if (isManager && !_isCashier)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  _miniBtn('Print', () => _printDash(o)),
                  _miniBtn('Mark Paid', () => _markDuePaid(o)),
                  _miniBtn('Delete', () => _deleteOrderDash(o)),
                ]),
              ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                _miniBtn('Print', () => _printDash(o)),
                _miniBtn('Mark Reserved', () => _markReservedDash(o)),
                if (isManager && !_isCashier) ...[
                  _miniBtn('Mark Paid', () => _markDuePaid(o)),
                  _miniBtn('Return to Active', () => _markReturnToActive(o)),
                ],
              ]),
            ),
          ],
        ],
      ]),
    ));
  }

  String _dayOfWeek(String iso) {
    final raw = DateTime.tryParse(iso);
    if (raw == null) return '';
    final d = esc.applyTimeZone(raw, 5);
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[d.weekday - 1];
  }

  Widget _glowText(String s,
          {required Color color, double size = 13, FontWeight weight = FontWeight.w900, int? maxLines}) =>
      Text(
        s,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          shadows: [
            Shadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 9,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      );

  Widget _fadeWrap(String key, Widget child) {
    final fading = _fading.contains(key);
    return AnimatedOpacity(
      opacity: fading ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      child: AnimatedScale(
        scale: fading ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }

  void _toggleMergeId(Map<String, dynamic> o) {
    setState(() {
      final id = sOf(o['id']);
      if (_mergeSel.contains(id)) {
        _mergeSel.remove(id);
      } else {
        _mergeSel.add(id);
      }
    });
  }

  void _toggleItems(String id) {
    setState(() {
      if (!_expandedItems.remove(id)) _expandedItems.add(id);
    });
  }

  void _toggleCardExpand(String id) {
    setState(() {
      if (!_expandedCards.remove(id)) _expandedCards.add(id);
    });
  }

  void _toggleMergeOrder(Map<String, dynamic> o) {
    setState(() {
      final id = sOf(o['id']);
      if (_mergeSel.contains(id)) {
        _mergeSel.remove(id);
      } else {
        final grp = _tabOrders(_dashTab)
            .where((x) => sOf(x['mergeGroupId']).isEmpty && _sig(x) == _sig(o))
            .toList();
        for (final x in grp) {
          _mergeSel.add(sOf(x['id']));
        }
      }
    });
  }

  Widget _mergeBar() {
    num sum = 0;
    for (final id in _mergeSel) {
      final o = _orderById(id);
      if (o != null) sum += numOf(o['total'] ?? o['amount']);
    }
    final isDueTab = _dashTab == 'due';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECDCA)),
      ),
      child: Row(children: [
        Expanded(
          child: Text('${_mergeSel.length} selected \u2022 ${_fmtNum(sum)} PKR',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _reserved)),
        ),
        if (isDueTab)
          _PressFx(
            enabled: !_busy && _mergeSel.isNotEmpty,
            builder: (_, pressed) => SizedBox(
              height: 34,
              child: ElevatedButton.icon(
                onPressed: _busy || _mergeSel.isEmpty ? null : _markReservedSelected,
                icon: const Icon(Icons.bookmark_add_outlined, size: 15),
                label: const Text('Mark Reserved',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pressed ? const Color(0xFF7F1D1D) : _reserved,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _reserved.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ),
        const SizedBox(width: 6),
        _PressFx(
          enabled: !_busy && _mergeSel.isNotEmpty,
          builder: (_, pressed) => SizedBox(
            height: 34,
            child: ElevatedButton.icon(
              onPressed: _busy || _mergeSel.isEmpty ? null : _mergeOrders,
              icon: _busy
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.call_merge, size: 16),
              label: const Text('Merge', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: pressed ? const Color(0xFF7F1D1D) : _reserved,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _reserved.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _markReservedSelected() async {
    if (_busy || _mergeSel.isEmpty) return;
    final ids = _mergeSel.toList();
    setState(() {
      _busy = true;
      for (final id in ids) {
        _fading.add('o:$id');
      }
    });
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      for (final id in ids) {
        await ApiClient.send('PUT', '/pos/orders/$id', token: widget.token, body: {
          'reserved': true,
          'reservedAt': now,
        });
      }
      if (!mounted) return;
      setState(() {
        for (final x in _orders) {
          if (x is Map && ids.contains(sOf(x['id']))) {
            x['reserved'] = true;
            x['reservedAt'] = now;
          }
        }
        for (final id in ids) {
          _fading.remove('o:$id');
        }
        _mergeSel.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked ${ids.length} as Reserved \u2713')));
    } catch (e) {
      if (mounted) {
        setState(() {
          for (final id in ids) {
            _fading.remove('o:$id');
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mergeOrders() async {
    final ids = _mergeSel.toList();
    final list = <Map<String, dynamic>>[];
    for (final id in ids) {
      final o = _orderById(id);
      if (o != null) list.add(o);
    }
    if (list.isEmpty || _busy) return;
    final sig = _sig(list.first);
    final sameSig = list.every((o) => _sig(o) == sig);
    final existing = sameSig ? _existingGroupForSig(sig) : null;
    if (existing == null && list.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Merge ke liye kam se kam 2 orders select karein'),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _busy = true);
    final groupId = existing != null
        ? sOf(existing.first['mergeGroupId'])
        : 'mg_${DateTime.now().microsecondsSinceEpoch}';
    final idSet = <String>{};
    for (final m in existing ?? <Map<String, dynamic>>[]) {
      idSet.add(sOf(m['id']).toString());
    }
    for (final o in list) {
      idSet.add(sOf(o['id']).toString());
    }
    final idList = idSet.toList();
    final total = _all
        .where((x) => idSet.contains(sOf(x['id'])))
        .fold<num>(0, (s, x) => s + numOf(x['total'] ?? x['amount']));
    final mergedAt = DateTime.now().toUtc().toIso8601String();
    try {
      for (final id in idSet) {
        await ApiClient.send('PUT', '/pos/orders/$id',
            token: widget.token,
            body: {
              'mergeGroupId': groupId,
              'mergedOrderIds': idList,
              'mergedTotal': total,
              'mergedAt': mergedAt,
            });
      }
      if (!mounted) return;
      setState(() {
        for (final id in idSet) {
          for (final x in _orders) {
            if (x is Map && sOf(x['id']) == id) {
              x['mergeGroupId'] = groupId;
              x['mergedOrderIds'] = idList;
              x['mergedTotal'] = total;
              x['mergedAt'] = mergedAt;
            }
          }
        }
        _mergeSel.clear();
      });
      final extra = existing != null && existing.length > 0
          ? ' into existing group (${idSet.length} total)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merged \u2713$extra')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _mergedGroupsAll() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final o in _all) {
      final g = sOf(o['mergeGroupId']);
      if (g.isNotEmpty) (map[g] ??= []).add(o);
    }
    return map;
  }

  List<Map<String, dynamic>>? _existingGroupForSig(String sig) {
    for (final members in _mergedGroupsAll().values) {
      if (members.isEmpty) continue;
      if (_sig(members.first) == sig) return members;
    }
    return null;
  }

  Widget _mergedCard(String groupId,
      {bool pending = false, String tab = 'due'}) {
    final members = _mergedMembers(groupId);
    if (members.isEmpty) return const SizedBox.shrink();
    final reservedTab = tab == 'reserved';
    final accent = pending ? const Color(0xFFB91C1C) : _mergeBox;
    final cardBg = pending ? _reservedBg : const Color(0xFFF5F3FF);
    final total =
        members.fold<num>(0, (s, o) => s + numOf(o['total'] ?? o['amount']));
    final first = members.first;
    final addr = sOf(first['address']);
    final loc = sOf(first['serviceType']);
    final dt = dateTime12(sOf(first['createdAt']));
    final day = _dayOfWeek(sOf(first['createdAt']));
    String rider = '';
    for (final m in members) {
      final r = sOf(m['deliveryAgent']);
      if (r.isNotEmpty) {
        rider = r;
        break;
      }
    }
    return _fadeWrap('g:$groupId', InkWell(
      onTap: () => _openMergedSheet(members),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent, width: pending ? 2 : 1.6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.call_merge, size: 16, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Merged Order \u2022 ${members.length} orders',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: accent)),
            ),
            Text('${_fmtNum(total)} PKR',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: accent)),
          ]),
          if (dt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: _glowText((day.isNotEmpty ? '$day \u00B7 ' : '') + dt,
                  color: accent, size: 15),
            ),
          if (loc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.location_on_outlined, size: 15, color: accent),
                const SizedBox(width: 5),
                Expanded(
                  child: _glowText(loc, color: accent, size: 15),
                ),
              ]),
            ),
          if (addr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.location_on, size: 15, color: accent),
                const SizedBox(width: 5),
                Expanded(
                  child: _glowText(
                    addr,
                    color: accent,
                    size: 14.5,
                    maxLines: 2,
                  ),
                ),
              ]),
            ),
          if (rider.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.delivery_dining, size: 18, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 5),
                Flexible(
                    child: _glowText(
                        rider, color: const Color(0xFF1D4ED8), size: 16)),
              ]),
            ),
          if (pending)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                    'Same location order available - merge karein',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          if (isManager && !_isCashier)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                if (reservedTab) ...[
                  _miniBtn('Mark Paid', () => _markGroupPaid(groupId)),
                  _miniBtn('Mark Due', () => _markGroupDue(groupId)),
                  _miniBtn('Delete', () => _deleteGroupDash(groupId)),
                ] else ...[
                  _miniBtn('Mark Paid', () => _markGroupPaid(groupId)),
                  _miniBtn('Return to Active',
                      () => _markGroupReturnToActive(groupId)),
                  _miniBtn('Delete', () => _deleteGroupDash(groupId)),
                ],
              ]),
            ),
        ]),
      ),
    ));
  }

  Future<void> _markGroupReturnToActive(String groupId) async {
    if (_busy) return;
    final members = _mergedMembers(groupId);
    if (members.isEmpty) return;
    setState(() {
      _busy = true;
      _fading.add('g:$groupId');
    });
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      for (final o in members) {
        final id = sOf(o['id']);
        if (id.isEmpty) continue;
        await ApiClient.send('PUT', '/pos/orders/$id', token: widget.token, body: {
          'status': 'Active',
          'paymentStatus': 'Pending',
          'activeAt': now,
        });
      }
      if (!mounted) return;
      setState(() {
        for (final o in members) {
          for (final x in _orders) {
            if (x is Map && sOf(x['id']) == sOf(o['id'])) {
              x['status'] = 'Active';
              x['paymentStatus'] = 'Pending';
            }
          }
        }
        _fading.remove('g:$groupId');
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${members.length} order(s) returned to Active \u2713')));
    } catch (e) {
      if (mounted) {
        setState(() => _fading.remove('g:$groupId'));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markGroupPaid(String groupId) async {
    final members = _mergedMembers(groupId);
    if (members.isEmpty) return;
    await _markDuePaid(members.first);
  }

  Future<void> _markGroupDue(String groupId) async {
    if (_busy) return;
    final members = _mergedMembers(groupId);
    setState(() => _busy = true);
    try {
      for (final o in members) {
        final id = sOf(o['id']);
        await ApiClient.send('PUT', '/pos/orders/$id', token: widget.token, body: {
          'paymentStatus': 'Due',
          'status': 'Due',
        });
      }
      if (!mounted) return;
      setState(() {
        for (final o in members) {
          for (final x in _orders) {
            if (x is Map && sOf(x['id']) == sOf(o['id'])) {
              x['paymentStatus'] = 'Due';
              x['status'] = 'Due';
            }
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked ${members.length} as Due \u2713')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteGroupDash(String groupId) async {
    if (_busy) return;
    final members = _mergedMembers(groupId);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete merged orders?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: Text('${members.length} merged orders delete ho jayenge. Confirm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      for (final o in members) {
        await ApiClient.send('DELETE', '/pos/orders/${o['id']}', token: widget.token);
      }
      if (!mounted) return;
      setState(() {
        final ids = members.map((o) => sOf(o['id'])).toSet();
        _orders.removeWhere((x) => x is Map && ids.contains(sOf(x['id'])));
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merged orders deleted \u2713')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openMergedSheet(List<Map<String, dynamic>> members) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MergedSheet(
        parent: this,
        members: List<Map<String, dynamic>>.from(members),
      ),
    ).whenComplete(_refreshOrders);
  }

  Future<bool> _unmergeSingle(Map<String, dynamic> o) async {
    final id = sOf(o['id']);
    if (id.isEmpty || _busy) return false;
    setState(() => _busy = true);
    try {
      await ApiClient.send('PUT', '/pos/orders/$id',
          token: widget.token,
          body: {'mergeGroupId': '', 'mergedOrderIds': [], 'mergedTotal': 0});
      if (!mounted) return false;
      setState(() {
        for (final x in _orders) {
          if (x is Map && sOf(x['id']) == id) {
            x['mergeGroupId'] = '';
            x['mergedOrderIds'] = <dynamic>[];
            x['mergedTotal'] = 0;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from merged group \u2713')));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _markOrderDueDash(Map<String, dynamic> o) async {
    final id = sOf(o['id']);
    if (id.isEmpty || _busy) return false;
    setState(() => _busy = true);
    try {
      await ApiClient.send('PUT', '/pos/orders/$id', token: widget.token, body: {
        'paymentStatus': 'Due',
        'status': 'Due',
      });
      if (!mounted) return false;
      setState(() {
        for (final x in _orders) {
          if (x is Map && sOf(x['id']) == id) {
            x['paymentStatus'] = 'Due';
            x['status'] = 'Due';
          }
        }
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Marked as Due')));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  Widget _typePill(String label, Color c, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: c,
              letterSpacing: 0.5),
        ),
      ]),
    );

  Widget _miniBtn(String label, VoidCallback onTap) => _PressFx(
        enabled: !_busy,
        onTap: onTap,
        builder: (_, pressed) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: pressed ? const Color(0xFF047857) : const Color(0xFF059669),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
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

class _MergedSheet extends StatefulWidget {
  final _DashboardScreenState parent;
  final List<Map<String, dynamic>> members;

  const _MergedSheet({required this.parent, required this.members});

  @override
  State<_MergedSheet> createState() => _MergedSheetState();
}

class _MergedSheetState extends State<_MergedSheet> {
  late List<Map<String, dynamic>> _members;
  final Set<String> _fading = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _members = List<Map<String, dynamic>>.from(widget.members);
  }

  Future<void> _run(Future<bool> Function() fn, Map<String, dynamic> o,
      {required bool remove}) async {
    if (_busy) return;
    final id = sOf(o['id']);
    setState(() {
      _busy = true;
      _fading.add(id);
    });
    final ok = await fn();
    if (!mounted) return;
    setState(() {
      if (ok && remove) {
        _members.removeWhere((m) => sOf(m['id']) == id);
      }
      _fading.remove(id);
      _busy = false;
    });
    if (_members.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final total = _members.fold<num>(
        0, (s, o) => s + numOf(o['total'] ?? o['amount']));
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _border)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                  'Merged Orders \u2022 ${_members.length} \u2022 ${widget.parent._fmtNum(total)} PKR',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _txtDark)),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: _txtDim),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _members.length,
            itemBuilder: (_, i) => _card(_members[i]),
          ),
        ),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final id = sOf(o['id']);
    final fading = _fading.contains(id);
    final items = (o['items'] as List?)?.whereType<Map>().toList() ?? [];
    final num = sOf(o['orderNumber']).isNotEmpty ? o['orderNumber'] : id;
    final dt = dateTime12(sOf(o['createdAt']));
    final p = widget.parent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        opacity: fading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: fading ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          '#$num  \u00B7  ${sOf(o['status'])}  \u00B7  ${sOf(o['paymentStatus'])}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: _txtDark)),
                    ),
                  ]),
                  if (dt.isNotEmpty)
                    Text(dt, style: const TextStyle(fontSize: 11, color: _txtDim)),
                  if (sOf(o['customerName']).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Customer: ${o['customerName']}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  if (sOf(o['phone']).isNotEmpty)
                    Text('Phone: ${o['phone']}',
                        style: const TextStyle(fontSize: 12)),
                  if (sOf(o['serviceType']).isNotEmpty)
                    Text('Location: ${o['serviceType']}',
                        style: const TextStyle(fontSize: 12)),
                  if (sOf(o['address']).isNotEmpty)
                    Text('Address: ${o['address']}',
                        style: const TextStyle(fontSize: 12)),
                  if (sOf(o['deliveryAgent']).isNotEmpty)
                    Text('Rider: ${o['deliveryAgent']}',
                        style: const TextStyle(fontSize: 12)),
                  const Divider(height: 12),
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                              '${it['quantity']}x ${it['name']} ${sOf(it['flavor']).isNotEmpty ? '(${it['flavor']})' : ''}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        Text(p._fmtNum(numOf(it['price']) * numOf(it['quantity'])),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  const Divider(height: 12),
                  Text('Total: ${p._fmtNum(numOf(o['total'] ?? o['amount']))} PKR',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _DashboardScreenState._mergeBox)),
                  if (p.isManager && !p._isCashier)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        p._miniBtn('Remove from Merge',
                            () => _run(() => p._unmergeSingle(o), o, remove: true)),
                        p._miniBtn('Mark Paid',
                            () => _run(() => p._markOrderPaidDash(o), o, remove: true)),
                        p._miniBtn('Mark Due',
                            () => _run(() => p._markOrderDueDash(o), o, remove: false)),
                        p._miniBtn('Delete',
                            () => _run(() => p._deleteOrderDash(o), o, remove: true)),
                      ]),
                    ),
                ]),
          ),
        ),
      ),
    );
  }
}

class _RidersOrdersSheet extends StatefulWidget {
  final String riderName;
  final List<Map<String, dynamic>> orders;
  final List<String> allRiders;
  final String token;
  final bool isCashier;

  const _RidersOrdersSheet({
    required this.riderName,
    required this.orders,
    required this.allRiders,
    required this.token,
    required this.isCashier,
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

  Future<void> _bulkMarkPaid() async {
    final ids = _selected.toList();
    if (ids.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final paidAt = DateTime.now().toUtc().toIso8601String();
      await Future.wait(ids.map((id) => ApiClient.send('PUT', '/pos/orders/$id',
          token: widget.token,
          body: {'paymentStatus': 'paid', 'status': 'Delivered', 'paidAt': paidAt}).catchError((_) => null)));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${ids.length} order(s) marked paid')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _bulkMarkDue() async {
    final ids = _selected.toList();
    if (ids.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await Future.wait(ids.map((id) => ApiClient.send('PUT', '/pos/orders/$id',
          token: widget.token,
          body: {'paymentStatus': 'Due', 'status': 'Due'}).catchError((_) => null)));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${ids.length} order(s) marked due')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _assignRiderSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty || _busy) return;
    final riders = widget.allRiders;
    if (riders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No riders available')));
      return;
    }
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign ${ids.length} order(s) to',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: riders.length,
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.delivery_dining, color: Color(0xFF2563EB)),
              title: Text(riders[i],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, riders[i]),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
    if (pick == null || pick.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await Future.wait(ids.map((id) => ApiClient.send('PUT', '/pos/orders/$id',
          token: widget.token,
          body: {'deliveryAgent': pick, 'status': 'Riders Assigned'}).catchError((_) => null)));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ids.length} order(s) assigned to $pick \u2713')));
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              if (_selected.isNotEmpty)
                Text('${_selected.length} selected',
                    style: const TextStyle(fontSize: 12, color: _txtDim)),
              OutlinedButton.icon(
                onPressed: _busy || _selected.isEmpty ? null : _assignRiderSelected,
                icon: const Icon(Icons.delivery_dining, size: 16),
                label: const Text('Assign Rider'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              if (!widget.isCashier)
                OutlinedButton.icon(
                  onPressed: _busy || _selected.isEmpty ? null : _bulkMarkPaid,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Mark Paid'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: const BorderSide(color: _accent),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _busy || _selected.isEmpty ? null : _bulkMarkDue,
                icon: const Icon(Icons.schedule, size: 16),
                label: const Text('Mark Due'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              
            ],
          ),
        ),
      ],
    );
  }
}

class _PressFx extends StatefulWidget {
  final VoidCallback? onTap;
  final bool enabled;
  final Widget Function(BuildContext context, bool pressed) builder;
  const _PressFx({
    required this.builder,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<_PressFx> createState() => _PressFxState();
}

class _PressFxState extends State<_PressFx> {
  bool _p = false;

  void _set(bool v) {
    if (mounted && _p != v) setState(() => _p = v);
  }

  @override
  Widget build(BuildContext context) {
    final en = widget.enabled;
    return Listener(
      onPointerDown: en ? (_) => _set(true) : null,
      onPointerUp: en
          ? (_) {
              _set(false);
              widget.onTap?.call();
            }
          : null,
      onPointerCancel: en ? (_) => _set(false) : null,
      child: AnimatedScale(
        scale: _p ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedOpacity(
          opacity: _p ? 0.65 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: widget.builder(context, _p),
        ),
      ),
    );
  }
}