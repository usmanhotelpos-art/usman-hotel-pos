import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import 'api.dart';
import 'background_alerts.dart';
import 'bmp_receipt.dart' as bmp;
import 'bt_service.dart';
import 'escpos.dart' as esc;
import 'login_screen.dart';
import 'notify.dart';
import 'printer_settings_screen.dart';
import 'siren.dart';

const List<String> _excludedStatuses = [
  'completed',
  'payment collected',
  'cancelled',
];

String _norm(dynamic v) =>
    (v ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _s(dynamic v) => v == null ? '' : v.toString();

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}

String _fnum(num v) => v == v.roundToDouble() ? v.round().toString() : '$v';

String _fmtTime(dynamic dt) {
  final d = DateTime.tryParse(_s(dt));
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return d.hour < 12 ? '$h:$m AM' : '$h:$m PM';
}

String _fmtFull(dynamic dt) {
  final d = DateTime.tryParse(_s(dt));
  if (d == null) return '-';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour < 12 ? 'AM' : 'PM';
  return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year} $h:$m $ap';
}

bool _isDineInActive(Map o) =>
    _s(o['orderType']) == 'Dine-In' &&
    !_excludedStatuses.contains(_norm(o['status']));

String _orderTypeLabel(String t) {
  switch (_norm(t)) {
    case 'delivery':
      return 'DELIVERY';
    case 'takeaway':
      return 'TAKEAWAY';
    case 'dine-in':
      return 'DINE-IN';
    default:
      return t.isEmpty ? 'ORDER' : t.toUpperCase();
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool ready = false;
  String token = '';
  List<dynamic> orders = [];
  List<dynamic> tables = [];
  Map<String, dynamic> settings = {};
  DateTime? lastUpdated;
  String activeTab = 'nashtaAll'; // default tab - Nashta All
  String _userFilter = ''; // cashier / orderTaker name filter for nashta orders
  String message = '';
  String connError = '';
  bool alertsEnabled = true;
  List<dynamic> newBanner = [];
  String? busyId;
  Map<String, dynamic>? viewOrder;
  String? previewImage;
  bool refreshing = false;

  Set<String>? seenIds;
  Timer? _pollTimer;
  Timer? _bannerTimer;
  Timer? _tablesTimer;
  final AudioPlayer _alertPlayer = AudioPlayer();
  final AudioPlayer _actionPlayer = AudioPlayer();
  bool _sirenReady = false;
  bool _sirenBusy = false;
  bool _loadingOrders = false;
  bool _suppressNextNewOrderAlert = false;

  // --- palette ------------------------------------------------------------
  static const bg = Color(0xFF020617);
  static const cardBg = Color(0xFF0F172A);
  static const panel = Color(0xFF1E293B);
  static const border = Color(0xFF334155);
  static const txtDim = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _bannerTimer?.cancel();
    _tablesTimer?.cancel();
    _actionPlayer.stop().whenComplete(() => _actionPlayer.dispose());
    _alertPlayer.stop().whenComplete(() => _alertPlayer.dispose());
    super.dispose();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('serverUrl') ?? ApiClient.defaultHost;
    final stored = prefs.getString('activeOrdersToken') ?? '';
    if (stored.isEmpty) {
      _logout();
      return;
    }
    ApiClient.setHost(server);
    await prefs.setString('serverUrl', ApiClient.host);
    token = stored;
    if (!mounted) return;
    setState(() => ready = true);
    unawaited(NotifyService.requestPermission());
    unawaited(BackgroundAlerts.start());
    unawaited(_loadSettings());
    unawaited(loadData(true));
    unawaited(_loadTables());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(loadData(true)),
    );
    _tablesTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_loadTables()),
    );
  }

  Future<void> _loadTables() async {
    try {
      final tbls = await ApiClient.send('GET', '/pos/tables', token: token);
      if (mounted && tbls is List) setState(() => tables = tbls);
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    try {
      final sets = await ApiClient.send('GET', '/settings');
      if (sets is Map) {
        final recFmt =
            _s(sets['receiptDateTimeFormat']).isEmpty
                ? 'DD/MM/YYYY hh:mm A'
                : _s(sets['receiptDateTimeFormat']);
        String fmt = recFmt;
        if (fmt.contains('HH')) {
          fmt = '${fmt.replaceFirst('HH', 'hh')} A';
        } else if (fmt.contains('hh') && !fmt.contains('A')) {
          fmt = '$fmt A';
        }
        setState(() {
          settings = {
            ...sets.cast<String, dynamic>(),
            'receiptDateTimeFormat': fmt,
          };
        });
      }
    } catch (_) {}
  }

  void _logout() {
    _pollTimer?.cancel();
    unawaited(BackgroundAlerts.stop());
    SharedPreferences.getInstance().then((p) => p.remove('activeOrdersToken'));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(initialServerUrl: ApiClient.host),
      ),
    );
  }

  // --- data ---------------------------------------------------------------

  List<Map<String, dynamic>> get _activeOrders {
    final list =
        orders
            .whereType<Map>()
            .where((o) => _isDineInActive(o) && _norm(o['status']) != 'served')
            .toList();
    list.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
    return list.cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get _servedOrders {
    final list =
        orders
            .whereType<Map>()
            .where((o) => _isDineInActive(o) && _norm(o['status']) == 'served')
            .toList();
    int key(Map o) {
      final d = DateTime.tryParse(
        _s(o['servedAt']).isEmpty ? _s(o['createdAt']) : _s(o['servedAt']),
      );
      return d?.millisecondsSinceEpoch ?? 0;
    }

    list.sort((a, b) => key(b).compareTo(key(a)));
    return list.cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get _cancelledOrders {
    final list =
        orders
            .whereType<Map>()
            .where((o) => _s(o['orderType']) == 'Dine-In' && _norm(o['status']) == 'cancelled')
            .toList();
    int key(Map o) {
      final d = DateTime.tryParse(
        _s(o['cancelledAt']).isEmpty ? _s(o['createdAt']) : _s(o['cancelledAt']),
      );
      return d?.millisecondsSinceEpoch ?? 0;
    }

    list.sort((a, b) => key(b).compareTo(key(a)));
    return list.cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get _displayOrders {
    if (activeTab == 'nashtaAll') return _nashtaOrders;
    if (activeTab == 'served') return _servedOrders;
    if (activeTab == 'cancelled') return _cancelledOrders;
    return _activeOrders;
  }

  // --- Nashta-all view -----------------------------------------------------
  bool _isNashta(Map o) {
    final src = _norm(o['source']);
    if (src == 'nashta-app') return true;
    // Fallback: orders not tagged by the (not-yet-deployed) server source
    // change are treated as nashta so the tab isn't empty.
    return src.isEmpty;
  }

  bool _matchesUser(Map o) {
    if (_userFilter.isEmpty) return true;
    final ot = _norm(o['orderTaker']);
    final w = _norm(o['waiter']);
    final f = _norm(_userFilter);
    return ot == f || w == f;
  }

  List<Map<String, dynamic>> get _nashtaOrders {
    final list =
        orders
            .whereType<Map>()
            .where((o) => _isNashta(o) && _matchesUser(o))
            .toList();
    list.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
    return list.cast<Map<String, dynamic>>();
  }

  List<String> get _nashtaUsers {
    final names = <String>{};
    for (final o in orders.whereType<Map>()) {
      if (!_isNashta(o)) continue;
      final ot = _s(o['orderTaker']).trim();
      final w = _s(o['waiter']).trim();
      if (ot.isNotEmpty) names.add(ot);
      if (w.isNotEmpty) names.add(w);
    }
    return names.toList()..sort();
  }

  DateTime _dateOf(Map o) =>
      DateTime.tryParse(
        _s(o['createdAt']).isEmpty ? _s(o['date']) : _s(o['createdAt']),
      ) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> loadData(bool silent) async {
    if (!ready || token.isEmpty || _loadingOrders) return;
    _loadingOrders = true;
    try {
      dynamic data;
      try {
        data = await ApiClient.send('GET', '/pos/orders', token: token);
      } catch (e) {
        final fresh = await ApiClient.refreshToken(token);
        if (fresh == null) rethrow;
        token = fresh;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('activeOrdersToken', fresh);
        data = await ApiClient.send('GET', '/pos/orders', token: fresh);
      }
      final list = data is List ? data : <dynamic>[];
      if (!mounted) return;
      setState(() {
        orders = list;
        lastUpdated = DateTime.now();
        message = '';
        connError = '';
      });

      // New-order detection (same logic as web)
      final suppressAlert = _suppressNextNewOrderAlert;
      _suppressNextNewOrderAlert = false;
      final activeIds =
          orders
              .whereType<Map>()
              .where(_isDineInActive)
              .map((o) => '${o['id']}')
              .toSet();
      if (seenIds == null) {
        seenIds = activeIds;
        return;
      }
      final freshOnes =
          orders
              .whereType<Map>()
              .where(
                (o) => _isDineInActive(o) && !seenIds!.contains('${o['id']}'),
              )
              .toList();
      seenIds = activeIds;
      if (freshOnes.isNotEmpty && mounted && !suppressAlert) {
        setState(() => newBanner = freshOnes);
        _bannerTimer?.cancel();
        _bannerTimer = Timer(const Duration(seconds: 8), () {
          if (mounted) setState(() => newBanner = []);
        });
        if (alertsEnabled) {
          _fireAlerts();
          for (final o in freshOnes.take(3)) {
            final label =
                _s(o['orderNumber']).isEmpty
                    ? _s(o['id'])
                    : _s(o['orderNumber']);
            await NotifyService.showNewOrder(
              title: '🆕 NEW DINE-IN ORDER!',
              body:
                  'Table ${_s(o['tableNumber']).isEmpty ? '-' : _s(o['tableNumber'])} · Order #$label',
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.toLowerCase().contains('token') ||
          msg.toLowerCase().contains('auth')) {
        _logout();
        return;
      }
      setState(
        () =>
            connError =
                '⚠️ Server not reachable — check WiFi & Server URL (${ApiClient.base}). Pull down to retry.',
      );
      if (!silent) setState(() => message = msg);
      _suppressNextNewOrderAlert = false;
    } finally {
      _loadingOrders = false;
    }
  }

  // --- alerts -------------------------------------------------------------

  Future<void> _playSiren() async {
    if (_sirenBusy) return;
    _sirenBusy = true;
    try {
      if (!_sirenReady) {
        await _alertPlayer.setReleaseMode(ReleaseMode.stop);
        await _alertPlayer.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
          ),
        );
        // Decode once; replays reuse the prepared source (repeated
        // play(BytesSource) calls crash on some Android devices).
        await _alertPlayer.setSourceBytes(buildSirenWav());
        _sirenReady = true;
      }
      await _alertPlayer.stop();
      await _alertPlayer.seek(Duration.zero);
      await _alertPlayer.resume();
    } catch (_) {
    } finally {
      _sirenBusy = false;
    }
  }

  Future<void> _vibrate(List<int> pattern) async {
    try {
      final has = await Vibration.hasVibrator();
      if (has == true) await Vibration.vibrate(pattern: pattern);
    } catch (_) {}
  }

  void _fireAlerts() {
    _playSiren();
    Future.delayed(const Duration(milliseconds: 3200), _playSiren);
    _vibrate([800, 200, 800, 200, 800]);
  }

  Future<void> _playActionSound(
    List<int> pattern,
    Uint8List Function() wav,
  ) async {
    unawaited(_vibrate(pattern));
    try {
      await _actionPlayer.stop();
      await _actionPlayer.setReleaseMode(ReleaseMode.stop);
      await _actionPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationEvent,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      await _actionPlayer.setSourceBytes(wav());
      await _actionPlayer.resume();
    } catch (_) {}
  }

  Future<void> _reloadAfterLocalAction() async {
    _suppressNextNewOrderAlert = true;
    await loadData(true);
  }

  Future<void> _enableAlerts() async {
    // Ask the OS for notification permission (system dialog on Android 13+).
    final granted = await NotifyService.requestPermission();
    if (!mounted) return;
    setState(() {
      alertsEnabled = true;
    });
    await _playSiren();
    _vibrate([500, 150, 500]);
    _showMsg(
      granted
          ? 'Alerts enabled - notification + sound + vibration ✅'
          : 'Alerts ON - allow notifications in Android settings for best results',
      seconds: 4,
    );
  }

  void _showMsg(String msg, {int seconds = 3}) {
    if (!mounted) return;
    setState(() => message = msg);
    Timer(Duration(seconds: seconds), () {
      if (mounted && message == msg) setState(() => message = '');
    });
  }

  Future<void> _manualRefresh() async {
    setState(() => refreshing = true);
    await loadData(true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => refreshing = false);
    });
  }

  // --- actions ------------------------------------------------------------

  Future<void> _markPaid(Map<String, dynamic> order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: cardBg,
            title: Text(
              'Mark order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])} as PAID?',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Paid'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    final id = _s(order['id']);
    setState(() => busyId = id);
    try {
      await ApiClient.send(
        'PUT',
        '/pos/orders/$id',
        token: token,
        body: {
          'status': 'Payment Collected',
          'paymentStatus': 'Paid',
          'items': order['items'] ?? [],
          'customerName': _s(order['customerName']),
          'phone': _s(order['phone']),
          'address': _s(order['address']),
          'tableNumber': _s(order['tableNumber']),
          'deliveryAgent': _s(order['deliveryAgent']),
          'serviceType': _s(order['serviceType']),
          'deliveryFee': order['deliveryFee'] ?? 0,
          'discount': order['discount'] ?? 0,
          'taxPercent': order['taxPercent'] ?? 0,
          'serviceCharge': order['serviceCharge'] ?? 0,
          'paymentMethod':
              _s(order['paymentMethod']).isEmpty
                  ? 'Cash'
                  : _s(order['paymentMethod']),
          'notes': _s(order['notes']),
        },
      );
      final amount = _n(
        order['total'] != null && _n(order['total']) != 0
            ? order['total']
            : order['amount'],
      );
      if (amount != 0) {
        try {
          await ApiClient.send(
            'POST',
            '/pos/payments',
            token: token,
            body: {
              'orderId': order['id'],
              'amount': amount,
              'paymentMethod':
                  _s(order['paymentMethod']).isEmpty
                      ? 'Cash'
                      : _s(order['paymentMethod']),
              'status': 'Completed',
              'description':
                  'Payment collected for order ${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])}',
            },
          );
        } catch (_) {}
      }
      final tbl = _s(order['tableNumber']);
      if (tbl.isNotEmpty) {
        Map? table;
        for (final t in tables.whereType<Map>()) {
          final label =
              _s(t['label']).isNotEmpty
                  ? _s(t['label'])
                  : (_s(t['name']).isNotEmpty
                      ? _s(t['name'])
                      : _s(t['number']));
          if (label == tbl) {
            table = t;
            break;
          }
        }
        if (table != null) {
          try {
            await ApiClient.send(
              'PUT',
              '/pos/tables/${table['id']}',
              token: token,
              body: {'status': 'available'},
            );
          } catch (_) {}
        }
      }
      _showMsg(
        'Order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])} marked paid ✅',
      );
      unawaited(_playActionSound([120, 60, 180], buildPaidWav));
      await _reloadAfterLocalAction();
    } catch (e) {
      _showMsg(e.toString(), seconds: 4);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _markServed(Map<String, dynamic> order) async {
    final id = _s(order['id']);
    setState(() => busyId = id);
    try {
      await ApiClient.send(
        'PUT',
        '/pos/orders/$id',
        token: token,
        body: {
          'status': 'Served',
          'servedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      _showMsg(
        'Order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])} marked served 🍽️',
      );
      unawaited(_playActionSound([90, 50, 90, 50, 160], buildServedWav));
      await _reloadAfterLocalAction();
    } catch (e) {
      _showMsg(e.toString(), seconds: 4);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final id = _s(order['id']);
    setState(() => busyId = id);
    try {
      await ApiClient.send('DELETE', '/pos/orders/$id', token: token);
      setState(() {
        orders.removeWhere((o) => '${o['id']}' == id);
        viewOrder = null;
      });
      _showMsg(
        'Order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])} deleted 🗑️',
      );
      unawaited(_playActionSound([250, 80, 250], buildDeleteWav));
      unawaited(_reloadAfterLocalAction());
    } catch (e) {
      _showMsg(e.toString(), seconds: 4);
      unawaited(_reloadAfterLocalAction());
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          'Cancel order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])}?',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text('This order will move to the Cancelled tab.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE11D48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = _s(order['id']);
    setState(() => busyId = id);
    try {
      await ApiClient.send(
        'PUT',
        '/pos/orders/$id',
        token: token,
        body: {
          'status': 'Cancelled',
          'cancelledAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      _showMsg(
        'Order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])} cancelled 🗑️',
      );
      await _reloadAfterLocalAction();
    } catch (e) {
      _showMsg(e.toString(), seconds: 4);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _restoreOrder(Map<String, dynamic> order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          'Restore order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])}?',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text('This order will move back to the Active tab.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = _s(order['id']);
    setState(() => busyId = id);
    try {
      await ApiClient.send(
        'PUT',
        '/pos/orders/$id',
        token: token,
        body: {
          'status': 'New',
        },
      );
      _showMsg(
        'Order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])} restored to Active ✅',
      );
      await _reloadAfterLocalAction();
    } catch (e) {
      _showMsg(e.toString(), seconds: 4);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  void _openEditOrder(Map<String, dynamic> order) {
    final notesCtrl = TextEditingController(text: _s(order['notes']));
    final nameCtrl = TextEditingController(text: _s(order['customerName']));
    final phoneCtrl = TextEditingController(text: _s(order['phone']));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 16),
              _buildLabel('Customer Name'),
              _buildTextField(nameCtrl),
              const SizedBox(height: 12),
              _buildLabel('Phone'),
              _buildTextField(phoneCtrl),
              const SizedBox(height: 12),
              _buildLabel('Notes'),
              _buildTextField(notesCtrl, maxLines: 3),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final id = _s(order['id']);
                    setState(() => busyId = id);
                    try {
                      await ApiClient.send(
                        'PUT',
                        '/pos/orders/$id',
                        token: token,
                        body: {
                          'notes': notesCtrl.text.trim(),
                          'customerName': nameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'items': order['items'] ?? [],
                          'tableNumber': _s(order['tableNumber']),
                        },
                      );
                      Navigator.pop(ctx);
                      _showMsg('Order updated ✅');
                      await _reloadAfterLocalAction();
                    } catch (e) {
                      _showMsg(e.toString(), seconds: 4);
                    } finally {
                      if (mounted) setState(() => busyId = null);
                    }
                  },
                  child: const Text('Save Changes',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- bluetooth printing ---------------------------------------------------

  Future<bool> _connectPrinter(PrinterInfo p) async {
    try {
      return await BtService.connect(p);
    } catch (_) {
      return false;
    }
  }

  Future<PrinterInfo?> _pickPrinterDialog(List<PrinterInfo> list) async {
    PrinterInfo? picked;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select Bluetooth Printer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                ...list.map(
                  (p) => ListTile(
                    leading: const Icon(Icons.print, color: Color(0xFF34D399)),
                    title: Text(p.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      p.mac,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    onTap: () {
                      picked = p;
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
    return picked;
  }

  Future<void> _printOrderBT(Map<String, dynamic> rawOrder) async {
    final order = {...rawOrder};

    // Match the web ticket content: sales person shown as taker fallback.
    if (_s(order['waiter']).isEmpty) {
      order['waiter'] = _s(order['orderTaker']);
    }
    if (_s(order['date']).isEmpty) {
      order['date'] =
          _s(order['createdAt']).isNotEmpty
              ? _s(order['createdAt'])
              : _s(order['date']);
    }

    if (!(await BtService.ensurePermission())) {
      _showMsg('Bluetooth permission denied', seconds: 4);
      return;
    }

    var printer = await BtService.savedPrinter();
    if (printer == null) {
      final list = await BtService.pairedPrinters();
      if (list.isEmpty) {
        _showMsg(
          'No paired printer found - pair your thermal printer in Android Bluetooth settings first',
          seconds: 5,
        );
        return;
      }
      printer = await _pickPrinterDialog(list);
      if (printer == null) return;
      await BtService.savePrinter(printer);
    }
    final PrinterInfo target = printer;

    Future<void> attemptPrint() async {
      if (!(await BtService.isConnected())) {
        final ok = await _connectPrinter(target);
        if (!ok) throw Exception('Could not connect to ${target.name}');
      }
      // Always use BMP/raster path for reliable printing (no blank slips)
      await BtService.write(
        await bmp.buildBmpReceipt(
          Map<String, dynamic>.from(order),
          Map<String, dynamic>.from(settings),
          host: ApiClient.host,
        ),
      );

      // Token slip (same conditions as web)
      final type = _s(order['orderType']);
      final shouldToken =
          settings['tokenSlipEnabled'] == true &&
          ((type == 'Dine-In' && settings['btTokenSlipDineIn'] != false) ||
              (type == 'Takeaway' &&
                  settings['btTokenSlipTakeaway'] != false) ||
              (type == 'Delivery' &&
                  settings['btTokenSlipDelivery'] != false) ||
              type.isEmpty && settings['btTokenSlipDineIn'] != false);
      if (shouldToken) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final tokOrder = <String, dynamic>{...order, 'items': []};
        await BtService.write(
          await bmp.buildBmpReceipt(
            tokOrder,
            Map<String, dynamic>.from(settings),
            tokenOnly: true,
            host: ApiClient.host,
          ),
        );
      }
    }

    try {
      await BtService.enqueue(attemptPrint);
      _showMsg(
        'Order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])} sent to printer 🖨️',
      );
    } catch (err) {
      // Reconnect once and retry (same as web)
      await BtService.disconnect();
      try {
        await BtService.enqueue(() async {
          final ok = await _connectPrinter(target);
          if (!ok) throw Exception('Reconnect failed');
          await attemptPrint();
        });
        _showMsg(
          'Order #${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])} sent to printer 🖨️',
        );
      } catch (retryErr) {
        _showMsg('Bluetooth print failed: $retryErr', seconds: 5);
      }
    }
  }

  // --- image preview --------------------------------------------------------

  Widget _orderImage(String src, {BoxFit fit = BoxFit.cover}) {
    if (src.startsWith('data:')) {
      final idx = src.indexOf(',');
      final b64 = idx >= 0 ? src.substring(idx + 1) : src;
      try {
        return Image.memory(base64Decode(b64), fit: fit);
      } catch (_) {
        return const Icon(Icons.broken_image, color: txtDim);
      }
    }
    return Image.network(
      src,
      fit: fit,
      errorBuilder: (_, __, ___) {
        return const Icon(Icons.broken_image, color: txtDim);
      },
    );
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                if (message.isNotEmpty) _buildMessageBar(),
                if (connError.isNotEmpty) _buildConnErrorBar(),
                _buildTabs(),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF10B981),
                    backgroundColor: cardBg,
                    onRefresh: () => loadData(true),
                    child: _buildList(),
                  ),
                ),
              ],
            ),
            if (newBanner.isNotEmpty) _buildNewOrderBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final count = _displayOrders.length;
    final title = activeTab == 'nashtaAll'
        ? 'Nashta • All Orders'
        : activeTab == 'served'
            ? 'Served Orders'
            : activeTab == 'cancelled'
                ? 'Cancelled Orders'
                : 'Active Dine-In Orders';
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF5020617),
        border: Border(bottom: BorderSide(color: panel)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(activeTab == 'nashtaAll' ? '📦' : '🆕',
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      lastUpdated != null
                          ? 'Updated ${_fmtTime(lastUpdated!.toIso8601String())} · auto-refresh 1s'
                          : 'Loading...',
                      style: const TextStyle(fontSize: 10, color: txtDim),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: count > 0 ? const Color(0xFF059669) : panel,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: count > 0 ? Colors.white : txtDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _roundIconBtn(
                refreshing
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF34D399),
                      ),
                    )
                    : const Text('🔄', style: TextStyle(fontSize: 15)),
                _manualRefresh,
              ),
              const SizedBox(width: 6),
              _roundIconBtn(
                const Text('🖨️', style: TextStyle(fontSize: 15)),
                _attachPrinterTap,
              ),
              const SizedBox(width: 6),
              _roundIconBtn(
                const Text('⚙️', style: TextStyle(fontSize: 15)),
                _openPrinterSettings,
              ),
              const SizedBox(width: 6),
              _roundIconBtn(
                const Text('🚪', style: TextStyle(fontSize: 15)),
                _logout,
              ),
              const Spacer(),
              GestureDetector(
                onTap: _enableAlerts,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: alertsEnabled ? const Color(0xFF059669) : null,
                    gradient:
                        alertsEnabled
                            ? null
                            : const LinearGradient(
                              colors: [Color(0xFFA21CAF), Color(0xFF7C3AED)],
                            ),
                    boxShadow:
                        alertsEnabled
                            ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: .6),
                                blurRadius: 16,
                              ),
                            ]
                            : null,
                  ),
                  child: Text(
                    alertsEnabled ? '🔔 Alerts ON' : '🔔 Enable Sound + Alerts',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (activeTab == 'nashtaAll') _buildUserFilter(),
        ],
      ),
    );
  }

  Widget _buildUserFilter() {
    final users = _nashtaUsers;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            const Text('👤', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            const Text(
              'Cashier:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: txtDim),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _userFilter.isEmpty ? null : _userFilter,
                  hint: const Text('All Cashiers',
                      style: TextStyle(fontSize: 12, color: txtDim)),
                  dropdownColor: panel,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  items: users
                      .map(
                        (u) => DropdownMenuItem(value: u, child: Text(u)),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _userFilter = v ?? '');
                  },
                ),
              ),
            ),
            if (_userFilter.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _userFilter = ''),
                child: const Text('✖️', style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roundIconBtn(Widget child, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: panel, shape: BoxShape.circle),
        child: child,
      ),
    );
  }

  Future<void> _attachPrinterTap() async {
    if (!(await BtService.ensurePermission())) {
      _showMsg('Bluetooth permission denied', seconds: 4);
      return;
    }
    final saved = await BtService.savedPrinter();
    final list = await BtService.pairedPrinters();
    if (!mounted) return;
    if (list.isEmpty) {
      _showMsg(
        'No paired printers - pair your thermal printer in Android Bluetooth settings first',
        seconds: 5,
      );
      return;
    }
    final picked = await _pickPrinterDialog(list);
    if (picked != null) {
      await BtService.savePrinter(picked);
      _showMsg('Bluetooth printer selected: ${picked.name}');
    } else if (saved != null) {
      _showMsg('Saved printer: ${saved.name}');
    }
  }

  void _openPrinterSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
    );
  }

  Widget _buildMessageBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF022C22).withValues(alpha: .7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6EE7B7),
          ),
        ),
      ),
    );
  }

  Widget _buildConnErrorBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GestureDetector(
        onTap: _logout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4C0519).withValues(alpha: .6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF7F1D1D)),
          ),
          child: Text(
            connError,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFDA4AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: panel),
        ),
        child: Row(
          children: [
            _tabButton('📦 NASHTA (${_nashtaOrders.length})', 'nashtaAll'),
            _tabButton('🔥 ACTIVE (${_activeOrders.length})', 'active'),
            _tabButton('🍽️ SERVED (${_servedOrders.length})', 'served'),
            _tabButton('🚫 CANCELLED (${_cancelledOrders.length})', 'cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, String tab) {
    final selected = activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => activeTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                selected
                    ? (tab == 'nashtaAll'
                        ? const Color(0xFF0EA5E9)
                        : tab == 'active'
                            ? const Color(0xFF059669)
                            : tab == 'served'
                                ? const Color(0xFFD97706)
                                : const Color(0xFFE11D48))
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : txtDim,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final display = _displayOrders;
    if (display.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    activeTab == 'nashtaAll'
                        ? (_userFilter.isNotEmpty ? '📦' : '📦')
                        : activeTab == 'served'
                            ? '🍽️'
                            : '🎉',
                    style: const TextStyle(fontSize: 44),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activeTab == 'nashtaAll'
                        ? (_userFilter.isEmpty
                            ? 'No nashta orders yet'
                            : 'No nashta orders for this cashier')
                        : activeTab == 'served'
                            ? 'No served orders yet'
                            : activeTab == 'cancelled'
                                ? 'No cancelled orders'
                                : 'No active dine-in orders',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    activeTab == 'nashtaAll'
                        ? 'Nashta orders (Delivery / Takeaway / Dine-in) from all cashiers'
                        : activeTab == 'served'
                            ? 'Marked-served orders move here'
                            : activeTab == 'cancelled'
                                ? 'Cancelled orders from all users appear here'
                                : 'New orders will appear here with a loud alert',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemCount: display.length,
      itemBuilder: (ctx, i) => _orderCard(display[i]),
    );
  }

  Widget _buildNewOrderBanner() {
    final names = newBanner
        .take(3)
        .map(
          (o) =>
              'Table ${_s(o['tableNumber']).isEmpty ? '-' : _s(o['tableNumber'])} (#${_s(o['orderNumber']).isEmpty ? _s(o['id']) : _s(o['orderNumber'])})',
        )
        .join(' · ');
    return Positioned(
      left: 16,
      right: 16,
      top: 56,
      child: GestureDetector(
        onTap: () => setState(() => newBanner = []),
        child: Container(
          padding: const EdgeInsets.all(14),
          transform: Matrix4.translationValues(0, 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE879F9), width: 2),
            gradient: const LinearGradient(
              colors: [Color(0xFFA21CAF), Color(0xFF7C3AED), Color(0xFFA21CAF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD946EF).withValues(alpha: .8),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                newBanner.length > 1
                    ? '🆕 ${newBanner.length} NEW ORDERS!'
                    : '🆕 NEW ORDER!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                names,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF5D0FE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final id = _s(order['id']);
    final numLabel =
        _s(order['orderNumber']).isEmpty
            ? _s(order['id'])
            : _s(order['orderNumber']);
    final created = _dateOf(order);
    final isNew =
        DateTime.now().difference(created) < const Duration(minutes: 5);
    final served = _norm(order['status']) == 'served';
    final cancelled = _norm(order['status']) == 'cancelled';
    final busy = busyId == id;

    final borderColor =
        cancelled
            ? const Color(0xFFE11D48)
            : isNew && !served
            ? const Color(0xFFD946EF)
            : served
            ? const Color(0xFFB45309)
            : const Color(0xFF047857);

    final itemsSummary = ((order['items'] as List?) ?? [])
        .whereType<Map>()
        .map((it) => '${_fnum(_n(it['quantity']))}x ${_s(it['name'])}')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF047857)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _orderTypeLabel(_s(order['orderType'])),
                      style: const TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      _s(order['orderType']) == 'Dine-In'
                          ? _s(order['tableNumber'])
                              .replaceAll(
                                RegExp(r'table', caseSensitive: false),
                                '',
                              )
                              .trim()
                          : _n(order['items'] != null
                                  ? (order['items'] as List).length
                                  : 0)
                              .toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#$numLabel',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _fmtTime(order['createdAt']),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF67E8F9),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fnum(
                          _n(
                            order['total'] != null && _n(order['total']) != 0
                                ? order['total']
                                : order['amount'],
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF34D399),
                        ),
                      ),
                      const Text(
                        ' Rs',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color:
                          cancelled
                              ? const Color(0xFFE11D48)
                              : served
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF7C3AED),
                    ),
                    child: Text(
                      cancelled
                          ? '🚫 CANCELLED'
                          : isNew && !served
                              ? '🔥 NEW'
                              : _s(order['status']),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                        color: served ? const Color(0xFF020617) : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '👤 ${_s(order['customerName']).isEmpty ? 'Walk-in' : _s(order['customerName'])}${_s(order['phone']).isNotEmpty ? ' · 📞 ${_s(order['phone'])}' : ''}',
            style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          ),
          Text(
            '🧑‍💼 Taker: ${_s(order['orderTaker']).isEmpty ? _s(order['waiter']) : _s(order['orderTaker'])}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC4B5FD),
            ),
          ),
          if (itemsSummary.isNotEmpty)
            Text(
              itemsSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: txtDim),
            ),
          if (_s(order['notes']).trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: panel.withValues(alpha: .8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '📝 ${_s(order['notes'])}',
                style: const TextStyle(fontSize: 10, color: Color(0xFFFDE68A)),
              ),
            ),
          if (_s(order['paymentRequestImage']).isNotEmpty)
            GestureDetector(
              onTap:
                  () => setState(
                    () => previewImage = _s(order['paymentRequestImage']),
                  ),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bg.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFB45309).withValues(alpha: .4),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: _orderImage(_s(order['paymentRequestImage'])),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📷 Payment photo attached',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFBBF24),
                            ),
                          ),
                          if (_s(order['paymentRequestedAt']).isNotEmpty)
                            Text(
                              _fmtFull(order['paymentRequestedAt']),
                              style: const TextStyle(
                                fontSize: 9,
                                color: txtDim,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Text('🔍', style: TextStyle(color: txtDim)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (activeTab == 'cancelled')
            Row(
              children: [
                _actionBtn('🖨️', 'PRINT', const [
                  Color(0xFF0EA5E9),
                  Color(0xFF0369A1),
                ], () => _printOrderBT(order)),
                _actionBtn(
                  '👁️',
                  'VIEW',
                  const [Color(0xFF6366F1), Color(0xFF4338CA)],
                  () {
                    setState(() => viewOrder = order);
                    _openViewSheet();
                  },
                ),
                _actionBtn('✏️', 'EDIT', const [
                  Color(0xFF8B5CF6),
                  Color(0xFF6D28D9),
                ], () => _openEditOrder(order)),
                _actionBtn('♻️', 'RESTORE', const [
                  Color(0xFF059669),
                  Color(0xFF047857),
                ], busy ? null : () => _restoreOrder(order)),
                _actionBtn('🗑️', 'DEL', const [
                  Color(0xFFF43F5E),
                  Color(0xFFBE123C),
                ], busy ? null : () => _deleteOrder(order)),
              ],
            )
          else
            Row(
              children: [
                _actionBtn('✅', 'PAID', const [
                  Color(0xFF10B981),
                  Color(0xFF047857),
                ], busy ? null : () => _markPaid(order)),
                if (activeTab != 'nashtaAll' ||
                    _s(order['orderType']) == 'Dine-In')
                  _actionBtn(
                    '🍽️',
                    served ? 'SERVED' : 'SERVE',
                    const [Color(0xFFFBBF24), Color(0xFFD97706)],
                    busy || served ? null : () => _markServed(order),
                  ),
                _actionBtn('🖨️', 'PRINT', const [
                  Color(0xFF0EA5E9),
                  Color(0xFF0369A1),
                ], () => _printOrderBT(order)),
                _actionBtn(
                  '👁️',
                  'VIEW',
                  const [Color(0xFF6366F1), Color(0xFF4338CA)],
                  () {
                    setState(() => viewOrder = order);
                    _openViewSheet();
                  },
                ),
                _actionBtn('🗑️', 'DEL', const [
                  Color(0xFFF43F5E),
                  Color(0xFFBE123C),
                ], busy ? null : () => _deleteOrder(order)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    String emoji,
    String label,
    List<Color> colors,
    VoidCallback? onPressed,
  ) {
    final disabled = onPressed == null;
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: disabled ? .5 : 1,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 17, height: 1)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8))),
      );

  Widget _buildTextField(TextEditingController ctrl, {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: panel,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
          ),
        ),
      );

  void _openViewSheet() {
    final order = viewOrder;
    if (order == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setSheet) {
              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: border)),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${_s(order['orderNumber']).isEmpty ? _s(order['id']) : _s(order['orderNumber'])}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Table ${_s(order['tableNumber']).isEmpty ? '-' : _s(order['tableNumber'])} · ${_fmtFull(order['createdAt'])}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: txtDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '👤 Customer: ${_s(order['customerName']).isEmpty ? 'Walk-in' : _s(order['customerName'])}${_s(order['phone']).isNotEmpty ? ' · 📞 ${_s(order['phone'])}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      Text(
                        '🧑‍💼 Order Taker: ${_s(order['orderTaker']).isEmpty ? _s(order['waiter']) : _s(order['orderTaker'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC4B5FD),
                        ),
                      ),
                      Text(
                        '💳 Payment: ${_s(order['paymentMethod']).isEmpty ? '-' : _s(order['paymentMethod'])} · ${_s(order['paymentStatus']).isEmpty ? '-' : _s(order['paymentStatus'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      Text(
                        '📍 Status: ${_s(order['status']).isEmpty ? '-' : _s(order['status'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      if (_s(order['notes']).isNotEmpty)
                        Text(
                          '📝 ${_s(order['notes'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: panel),
                        ),
                        child: Column(
                          children: [
                            ...((order['items'] as List?) ?? []).whereType<Map>().map(
                              (it) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_fnum(_n(it['quantity']))}x ${_s(it['name'])}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_fnum(_n(it['price']) * _n(it['quantity']))} Rs',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(color: panel),
                            Row(
                              children: [
                                const Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF34D399),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_fnum(_n(order['total'] != null && _n(order['total']) != 0 ? order['total'] : order['amount']))} Rs',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF34D399),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_s(order['paymentRequestImage']).isNotEmpty)
                        GestureDetector(
                          onTap:
                              () => setState(() {
                                previewImage = _s(order['paymentRequestImage']);
                                Navigator.pop(ctx);
                              }),
                          child: Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFFB45309,
                                ).withValues(alpha: .4),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: _orderImage(
                                      _s(order['paymentRequestImage']),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    '📷 Payment photo attached\nTap to view full image',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFBBF24),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _sheetBtn('✅ PAID', const Color(0xFF059669), () {
                            Navigator.pop(ctx);
                            _markPaid(order);
                          }),
                          _sheetBtn('🖨️ PRINT', const Color(0xFF0284C7), () {
                            _printOrderBT(order);
                          }),
                          _sheetBtn('🗑️ DEL', const Color(0xFFDC2626), () {
                            Navigator.pop(ctx);
                            _deleteOrder(order);
                          }),
                          _sheetBtn('CLOSE', const Color(0xFF475569), () {
                            Navigator.pop(ctx);
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    ).then((_) {
      if (mounted && viewOrder != null) setState(() => viewOrder = null);
    });
  }

  Widget _sheetBtn(String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
