import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'bmp_receipt.dart' as bmp;
import 'bt_service.dart';
import 'dashboard_screen.dart';
import 'escpos.dart' as esc;
import 'printer_settings_screen.dart';
import 'session.dart';
import '../offline_store.dart';

const Map<String, String> categoryIcons = {
  'All': '\u{1F3AF}', 'Chicken': '\u{1F357}', 'Steak': '\u{1F969}',
  'Fish': '\u{1F41F}', 'Salad': '\u{1F957}', 'Juice': '\u{1F9C3}',
  'Dessert': '\u{1F370}', 'Burger': '\u{1F354}', 'Pizza': '\u{1F355}',
  'Soup': '\u{1F35C}', 'Biryani': '\u{1F35A}', 'Mutton': '\u{1F411}',
  'Beef': '\u{1F969}', 'BBQ': '\u{1F525}', 'Grill': '\u{1F969}',
  'Chinese': '\u{1F95F}', 'Rice': '\u{1F35A}', 'Roll': '\u{1F95F}',
  'Wrap': '\u{1F95F}', 'Tea': '\u{2615}', 'Coffee': '\u{2615}',
  'Breakfast': '\u{1F373}', 'Sandwich': '\u{1F996}', 'Pasta': '\u{1F35D}',
  'Noodles': '\u{1F35C}', 'Ice Cream': '\u{1F366}', 'Smoothie': '\u{1F9C4}',
  'Combo': '\u{1F3AF}', 'Special': '\u{2B50}', 'Tikka': '\u{1F958}',
  'Karhai': '\u{1F372}', 'Drinks': '\u{1F9C4}', 'Beverage': '\u{1F9C4}',
  'Shawarma': '\u{1F95F}', 'Fries': '\u{1F35F}', 'Mandi': '\u{1F35B}',
  'Handi': '\u{1F372}', 'Kebab': '\u{1F959}', 'Nihari': '\u{1F372}',
  'Haleem': '\u{1F963}', 'Dosa': '\u{1F95E}', 'Curry': '\u{1F35B}',
  'Dal': '\u{1F963}', 'Paratha': '\u{1FAD3}', 'Roti': '\u{1FAD3}',
  'Bread': '\u{1F35E}', 'Seafood': '\u{1F990}', 'Platter': '\u{1F37D}',
  'Family': '\u{1F468}', 'Deal': '\u{1F4A5}', 'Addon': '\u{2795}',
  'Extra': '\u{2795}', 'Extras': '\u{2795}', 'Dips': '\u{1F96B}', 'Sauce': '\u{1F96B}',
  'Topping': '\u{1F9C0}', 'Cheese': '\u{1F9C0}', 'Mashallah': '\u{1F31F}',
  'Naan': '\u{1FAD3}', 'Naan Roti': '\u{1FAD3}', 'Special Naan': '\u{1FAD3}',
  'Nashta': '\u{1F373}',   'Nashta Usman Hotel': '\u{1F373}',
};

const Map<String, String> categoryUrdu = {
  'Nashta Usman Hotel': 'ناشتہ عثمان ہوٹل',
  'Nashta': 'ناشتہ',
  'ناشتے کی آئٹمز': 'ناشتہ',
  'Special Naan': 'سپیشل نان',
  'اسپیشل نان': 'سپیشل نان',
  'Naan Roti': 'نان روٹی',
  'نان اور روٹی': 'نان روٹی',
  'Naan': 'نان',
  'نان': 'نان',
  'Roti': 'روٹی',
  'روٹی': 'روٹی',
  'Paratha': 'پراٹھا',
  'Bread': 'بریڈ',
  'Extra': 'اضافی',
  'Extras': 'ایکسٹرا',
  'Mashallah': 'مشاء اللہ',
};

String catLabel(String name) => categoryUrdu[name] ?? name;
bool _isUrduCat(String name) => categoryUrdu.containsKey(name);

const String mashallahCategory =
    '\u{0645}\u{0627} \u{0634}\u{0627}\u{0621} \u{0627}\u{0644}\u{0651}\u{064E}\u{0607}\u{0629}\u{0650}';

String getCatIcon(String? name) {
  if (name == null || name.isEmpty) return '\u{1F4C1}';
  if (categoryIcons[name] != null) return categoryIcons[name]!;
  final lower = name.toLowerCase();
  for (final e in categoryIcons.entries) {
    if (e.key.toLowerCase() == lower) return e.value;
  }
  for (final e in categoryIcons.entries) {
    final k = e.key.toLowerCase();
    if (lower.contains(k) || k.contains(lower)) return e.value;
  }
  return '\u{1F4C1}';
}

String sOf(dynamic v) => v == null ? '' : v.toString();
double nOf(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}
double numOf(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
String two(int n) => n.toString().padLeft(2, '0');

String time12(String? iso, {int utcOffset = 5}) {
  final raw = DateTime.tryParse(iso ?? '');
  if (raw == null) return '';
  final d = raw.add(Duration(hours: utcOffset));
  var h = d.hour % 12;
  if (h == 0) h = 12;
  return '$h:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String dateTime12(String? iso, {int utcOffset = 5}) {
  final raw = DateTime.tryParse(iso ?? '');
  if (raw == null) return '';
  final d = raw.add(Duration(hours: utcOffset));
  var h = d.hour % 12;
  if (h == 0) h = 12;
  return '${two(d.day)}/${two(d.month)} ${two(d.year)} '
      '$h:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String _fmtNum(num v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

class SmartImage extends StatelessWidget {
  final String src;
  final double size;
  const SmartImage({super.key, required this.src, required this.size});
  static final Map<String, MemoryImage> _memCache = {};
  static final Map<String, NetworkImage> _netCache = {};

  ImageProvider? provider() {
    if (src.startsWith('data:')) {
      final cached = _memCache[src];
      if (cached != null) return cached;
      try {
        final i = src.indexOf(',');
        final b64 = i >= 0 ? src.substring(i + 1) : src;
        final img = MemoryImage(base64Decode(b64));
        if (_memCache.length > 120) _memCache.clear();
        _memCache[src] = img;
        return img;
      } catch (_) {
        return null;
      }
    }
    if (src.startsWith('http')) {
      return _netCache.putIfAbsent(src, () => NetworkImage(src));
    }
    final full = '${ApiClient.host}$src';
    return _netCache.putIfAbsent(full, () => NetworkImage(full));
  }

  @override
  Widget build(BuildContext context) {
    final p = provider();
    if (p == null) return _placeholder();
    return Image(
      image: p,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: const Color(0xFFE0F2FE),
        alignment: Alignment.center,
        child: Text('\u{1F4E6}', style: TextStyle(fontSize: size * 0.5)),
      );
}

class OrderTakerScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  const OrderTakerScreen({super.key, required this.token, required this.user});

  @override
  State<OrderTakerScreen> createState() => _OrderTakerScreenState();
}

class _OrderTakerScreenState extends State<OrderTakerScreen> {
  late String token = widget.token;
  Map<String, dynamic> get user => widget.user;

  List<dynamic> products = [];
  List<dynamic> categories = [];
  List<dynamic> orders = [];
  List<dynamic> tables = [];
  List<dynamic> settingsRaw = [];
  Map<String, dynamic> settings = {};
  List<dynamic> deliveryAgents = [];
  List<dynamic> serviceTypes = [];
  List<dynamic> customers = [];
  List<dynamic> deliveryLocations = [];
  List<dynamic> ridersRecords = [];
  List<dynamic> staffMembers = [];

  // Order types for this app
  static const List<String> orderTypes = ['Delivery', 'Table', 'Takeaway'];
  static const String _orderSource = 'nashta-app';
  String activeType = 'Delivery';
  final Map<String, List<Map<String, dynamic>>> carts = {
    'Delivery': [],
    'Table': [],
    'Takeaway': [],
  };

  String search = '';
  String selectedCategory = 'All';
  final Map<String, TextEditingController> fieldCtrls = {};
  String selectedZone = '';
  String selectedRider = '';
  String selectedCustomerId = '';
  List<Map<String, dynamic>> _addrSuggestions = [];
  bool selectMode = false;
  final Set<String> _selectedOrderIds = {};

  /// Locally staged (offline) orders not yet confirmed by the server.
  List<Map<String, dynamic>> pendingLocalOrders = [];

  /// Last known-good server snapshot for silent-refresh comparison.
  List<dynamic> serverOrders = [];
  bool offline = false;
  bool syncing = false;

  /// Last auto-sync outcome for the green/red indicator (null = unknown).
  bool? lastSyncOk;

  String ordersDateRange = 'today';
  DateTime? ordersFromDate;
  DateTime? ordersToDate;

  bool showCart = false;
  Map<String, dynamic>? editingOrder;
  bool showVariant = false;
  Map<String, dynamic>? variantProduct;
  Map<String, dynamic>? variantFlavor;
  String variantStep = 'flavors';

  bool initialLoading = true;
  bool showOrdersScreen = false;
  String ordersView = 'Delivery';
  String ordersSubTab = 'active';
  String ordersSearch = '';

  final ValueNotifier<DateTime> _now = ValueNotifier<DateTime>(DateTime.now());

  PrinterInfo? btInfo;
  bool btConnected = false;
  Map<String, dynamic> btOverrides = {};
  static const _btOverridesKey = 'nshBtPrinterOverrides';
  Map<String, dynamic> get btSettings =>
      <String, dynamic>{...settings, ...btOverrides};

  int get tzOffset => (btSettings['timezoneOffset'] as num?)?.toInt() ?? 5;

  String message = '';
  Timer? _messageTimer;
  Timer? _loadTimer;
  Timer? _tickTimer;
  Timer? _ordersTimer;
  Timer? _pressTimer;
  bool _pressFired = false;
  final Set<Timer> _feedbackTimers = {};
  Map<String, bool> orderedFeedback = {};
  bool _busy = false;
  final Set<String> _fadingIds = {};

  void _fadeOutOrders(List<Map<String, dynamic>> list) {
    final ids = list.map((o) => sOf(o['id'])).where((x) => x.isNotEmpty).toList();
    if (ids.isEmpty) return;
    setState(() => _fadingIds.addAll(ids));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _fadingIds.removeAll(ids));
    });
  }

  TextEditingController _c(String key) =>
      fieldCtrls.putIfAbsent(key, () => TextEditingController());

  @override
  void initState() {
    super.initState();
    OfflineStore.namespace = 'nsh';
    _loadData();
    _loadBtOverrides();
    _restorePendingOrders();
    OfflineStore.loadSyncOk().then((v) {
      if (mounted && v != null) setState(() => lastSyncOk = v);
    });
    _loadTimer = Timer.periodic(
        const Duration(seconds: 20), (_) => _loadData(silent: true));
    _tickTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => _now.value = DateTime.now());
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _tickTimer?.cancel();
    _ordersTimer?.cancel();
    _messageTimer?.cancel();
    _pressTimer?.cancel();
    for (final t in _feedbackTimers) t.cancel();
    _now.dispose();
    for (final c in fieldCtrls.values) c.dispose();
    super.dispose();
  }

  void toast(String m, {int seconds = 4}) {
    if (!mounted) return;
    setState(() => message = m);
    _messageTimer?.cancel();
    _messageTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => message = '');
    });
  }

  Future<dynamic> _fetch(String path,
      {String method = 'GET', Object? body, bool retried = false}) async {
    try {
      return await ApiClient.send(method, path, token: token, body: body);
    } on ApiException catch (e) {
      if (e.isAuthError && !retried && !path.contains('/auth/')) {
        final nt = await refreshTokenOp(token);
        if (nt != null && nt.isNotEmpty) {
          token = nt;
          return _fetch(path, method: method, body: body, retried: true);
        }
      }
      rethrow;
    }
  }

  Map<String, dynamic> _normSettings(dynamic raw) {
    final sets = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    var fmt = sOf(sets['receiptDateTimeFormat']);
    if (fmt.isEmpty) fmt = 'DD/MM/YYYY hh:mm A';
    if (fmt.contains('HH')) fmt = '${fmt.replaceFirst('HH', 'hh')} A';
    else if (fmt.contains('hh') && !fmt.contains('A')) fmt = '$fmt A';
    sets['receiptDateTimeFormat'] = fmt;
    return sets;
  }

  bool _sameAsOnScreen(List<dynamic> r) {
    String sig(dynamic v) => v == null ? 'null' : jsonEncode(v);
    return sig(categories) == sig(r[0]) &&
        sig(products) == sig(r[1]) &&
        sig(serverOrders) == sig(_appFilteredOrders(r[2] as List?)) &&
        sig(settings) == sig(_normSettings(r[3]));
  }

  List<dynamic> _appFilteredOrders(List<dynamic>? raw) {
    if (raw == null) return const [];
    return raw.where((o) {
      if (o is! Map) return false;
      final src = sOf(o['source']).trim().toLowerCase();
      return src == _orderSource;
    }).toList();
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      if (!silent && initialLoading) {
        final critical = await Future.wait([
          _fetch('/pos/categories').catchError((_) => null),
          _fetch('/pos/products').catchError((_) => null),
        ]);
        if (!mounted) return;
        setState(() {
          if (critical[0] is List) categories = critical[0] as List<dynamic>;
          if (critical[1] is List) products = critical[1] as List<dynamic>;
          initialLoading = false;
        });
      }
    } catch (_) {}
    try {
      final results = await Future.wait([
        _fetch('/pos/categories').catchError((_) => null),
        _fetch('/pos/products').catchError((_) => null),
        _fetch('/pos/orders?source=$_orderSource').catchError((_) => null),
        _fetch('/settings').catchError((_) => null),
        _fetch('/pos/delivery-agents').catchError((_) => null),
        _fetch('/delivery_service_types').catchError((_) => null),
        _fetch('/pos/customers').catchError((_) => null),
        _fetch('/delivery_locations').catchError((_) => null),
        _fetch('/riders').catchError((_) => null),
        _fetch('/staff').catchError((_) => null),
        _fetch('/pos/tables').catchError((_) => null),
      ]);
      if (!mounted) return;
      if (silent && initialLoading == false && _sameAsOnScreen(results)) {
        final pendSoon = pendingLocalOrders.isNotEmpty ||
            await OfflineStore.loadMutations().then((m) => m.isNotEmpty);
        if (!pendSoon) return;
      }
      if (silent && initialLoading == false && offline &&
          results.every((r) => r == null)) {
        return;
      }
      setState(() {
        if (results[0] is List) categories = results[0] as List<dynamic>;
        if (results[1] is List) products = results[1] as List<dynamic>;
        if (results[3] is Map) settings = _normSettings(results[3]);
        if (results[4] is List) deliveryAgents = results[4] as List<dynamic>;
        if (results[5] is List) serviceTypes = results[5] as List<dynamic>;
        if (results[6] is List) customers = results[6] as List<dynamic>;
        if (results[7] is List) deliveryLocations = results[7] as List<dynamic>;
        if (results[8] is List) ridersRecords = results[8] as List<dynamic>;
        if (results[9] is List) staffMembers = results[9] as List<dynamic>;
        if (results[10] is List) tables = results[10] as List<dynamic>;
        final ords = results[2];
        if (ords is List) {
          serverOrders = _appFilteredOrders(ords);
          _mergePendingOrders();
          offline = false;
          _saveCacheSnapshot();
        } else {
          offline = true;
          lastSyncOk = false;
          if (serverOrders.isEmpty && orders.isEmpty) _loadOfflineSnapshot();
        }
        initialLoading = false;
      });
      if (!offline && (pendingLocalOrders.isNotEmpty ||
          await OfflineStore.loadMutations().then((m) => m.isNotEmpty))) {
        _syncPendingOrders();
      } else if (mounted) {
        setState(() => lastSyncOk = true);
        unawaited(OfflineStore.saveSyncOk(true));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          initialLoading = false;
          offline = true;
          lastSyncOk = false;
          if (serverOrders.isEmpty && orders.isEmpty) _loadOfflineSnapshot();
        });
        if (!silent && orders.isEmpty) toast(e.toString());
      }
    }
  }

  Future<void> _refreshOrdersOnly() async {
    try {
      final r = await _fetch('/pos/orders?source=$_orderSource').catchError((_) => null);
      if (r is List && mounted) {
        setState(() {
          serverOrders = _appFilteredOrders(r);
          _mergePendingOrders();
          offline = false;
        });
        _saveCacheSnapshot();
      }
      if (!offline && (pendingLocalOrders.isNotEmpty ||
          await OfflineStore.loadMutations().then((m) => m.isNotEmpty))) {
        _syncPendingOrders();
      } else if (mounted) {
        setState(() => lastSyncOk = true);
        unawaited(OfflineStore.saveSyncOk(true));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          offline = true;
          lastSyncOk = false;
          if (serverOrders.isEmpty && orders.isEmpty) _loadOfflineSnapshot();
        });
      }
    }
  }

  void _mergePendingOrders() {
    final merged = <dynamic>[...serverOrders];
    for (final po in pendingLocalOrders) {
      if (!merged.any((e) => e is Map && sOf(e['id']) == sOf(po['id']))) {
        merged.add(Map<String, dynamic>.from(po));
      }
    }
    orders = merged;
  }

  void _saveCacheSnapshot() {
    OfflineStore.saveCache({
      'categories': categories,
      'products': products,
      'orders': serverOrders,
      'settings': settings,
      'tables': tables,
      'deliveryAgents': deliveryAgents,
      'serviceTypes': serviceTypes,
      'customers': customers,
      'deliveryLocations': deliveryLocations,
      'ridersRecords': ridersRecords,
      'staffMembers': staffMembers,
    });
  }

  void _loadOfflineSnapshot() {
    OfflineStore.loadCache().then((cache) {
      if (cache == null || !mounted) return;
      setState(() {
        if (cache['categories'] is List) categories = cache['categories'] as List<dynamic>;
        if (cache['products'] is List) products = cache['products'] as List<dynamic>;
        if (cache['orders'] is List) serverOrders = _appFilteredOrders(cache['orders'] as List<dynamic>);
        if (cache['settings'] is Map) settings = _normSettings(cache['settings']);
        if (cache['tables'] is List) tables = cache['tables'] as List<dynamic>;
        if (cache['deliveryAgents'] is List) deliveryAgents = cache['deliveryAgents'] as List<dynamic>;
        if (cache['serviceTypes'] is List) serviceTypes = cache['serviceTypes'] as List<dynamic>;
        if (cache['customers'] is List) customers = cache['customers'] as List<dynamic>;
        if (cache['deliveryLocations'] is List) deliveryLocations = cache['deliveryLocations'] as List<dynamic>;
        if (cache['ridersRecords'] is List) ridersRecords = cache['ridersRecords'] as List<dynamic>;
        if (cache['staffMembers'] is List) staffMembers = cache['staffMembers'] as List<dynamic>;
        _mergePendingOrders();
        offline = true;
        lastSyncOk = false;
        initialLoading = false;
      });
    });
  }

  Future<void> _restorePendingOrders() async {
    final pending = await OfflineStore.loadPendingOrders();
    if (pending.isEmpty || !mounted) return;
    setState(() {
      pendingLocalOrders = pending
          .map((e) => Map<String, dynamic>.from(e)..['localPending'] = true)
          .toList();
      _mergePendingOrders();
    });
    unawaited(_syncPendingOrders());
  }

  Future<void> _syncPendingOrders() async {
    if (syncing) return;
    syncing = true;
    try {
      var pending = await OfflineStore.loadPendingOrders();
      final mutations = await OfflineStore.loadMutations();
      if (pending.isEmpty && mutations.isEmpty) return;
      for (final m in List<Map<String, dynamic>>.from(mutations)) {
        final id = sOf(m['id']);
        try {
          if (m['op'] == 'DELETE') {
            await _fetch('/pos/orders/$id', method: 'DELETE');
          } else {
            await _fetch('/pos/orders/$id', method: 'PUT', body: m['body']);
          }
          final idx = (await OfflineStore.loadMutations()).indexWhere(
              (x) => x['id'] == m['id'] && x['op'] == m['op']);
          await OfflineStore.removeMutation(idx);
        } catch (e) {
          _markSyncFailed();
          break;
        }
      }
      await OfflineStore.compactMutations();
      pending = await OfflineStore.loadPendingOrders();
      for (final entry in List<Map<String, dynamic>>.from(pending)) {
        final clientId = sOf(entry['clientId']);
        try {
          final created = await _fetch('/pos/orders',
              method: 'POST', body: entry['payload']);
          if (created is Map) {
            await OfflineStore.removePendingOrder(clientId);
            final paid = entry['paid'] == true;
            if (paid) {
              _fetch('/pos/payments', method: 'POST', body: {
                'orderId': created['id'],
                'amount': created['total'],
                'paymentMethod': sOf(entry['payMethod']).isEmpty
                    ? 'Cash'
                    : entry['payMethod'],
                'status': 'Completed',
                'description':
                    'Payment for order ${created['orderNumber'] ?? created['id']}',
              }).catchError((_) => null);
            }
            if (mounted) {
              setState(() {
                pendingLocalOrders.removeWhere((p) => p['id'] == clientId);
                if (created['id'] != null) {
                  final appOrders = _appFilteredOrders([created]);
                  final i = orders.indexWhere(
                      (o) => o is Map && sOf(o['id']) == clientId);
                  if (appOrders.isNotEmpty) {
                    if (i >= 0 && i < orders.length) {
                      orders[i] = Map<String, dynamic>.from(appOrders.first);
                    } else {
                      orders.insert(0, Map<String, dynamic>.from(appOrders.first));
                    }
                  }
                }
                offline = false;
              });
              toast('Offline order synced to server ✅',
                  seconds: 3);
            }
          } else {
            _markSyncFailed();
            break;
          }
        } catch (e) {
          _markSyncFailed();
          break;
        }
      }
      await OfflineStore.compactMutations();
      if (mounted) {
        _markSyncOk();
        _refreshOrdersOnly();
      }
    } finally {
      syncing = false;
    }
  }

  void _markSyncOk() {
    if (!mounted) return;
    setState(() => lastSyncOk = true);
    unawaited(OfflineStore.saveSyncOk(true));
  }

  void _markSyncFailed() {
    if (!mounted) return;
    setState(() => lastSyncOk = false);
    unawaited(OfflineStore.saveSyncOk(false));
  }

  /// Applies a PUT/DELETE mutation either online, or (offline) queued to the
  /// local store with an optimistic UI patch. Pending local orders are patched
  /// in-place. Returns true when applied/queued, false on a real server error.
  Future<bool> _offlineAwareOrderCall(
      Map order, String method, Map<String, dynamic>? body) async {
    final id = sOf(order['id']);
    final isLocal = order['localPending'] == true;
    if (isLocal) {
      await _applyPendingLocalPatch(order, method, body);
      return true;
    }
    try {
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : (sOf(user['username']).isNotEmpty ? sOf(user['username']) : sOf(user['email']));
      final b = body == null ? null : <String, dynamic>{...body, 'orderTaker': me};
      await _fetch('/pos/orders/$id', method: method, body: b);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode != 0) rethrow;
      await OfflineStore.addMutation(
          {'id': id, 'op': method == 'DELETE' ? 'DELETE' : 'PUT', if (body != null) 'body': body});
      if (mounted) {
        setState(() {
          if (method == 'DELETE') {
            orders.removeWhere((o) => o is Map && sOf(o['id']) == id);
          } else if (body != null) {
            final i = orders.indexWhere((o) => o is Map && sOf(o['id']) == id);
            if (i >= 0 && orders[i] is Map) {
              final m = Map<String, dynamic>.from(orders[i] as Map);
              m.addAll(body);
              orders[i] = m;
            }
          }
          offline = true;
          lastSyncOk = false;
        });
      }
      unawaited(OfflineStore.saveSyncOk(false));
      unawaited(_syncPendingOrders());
      return true;
    }
  }

  Future<void> _applyPendingLocalPatch(
      Map order, String method, Map<String, dynamic>? body) async {
    final id = sOf(order['id']);
    if (mounted) {
      setState(() {
        final i = pendingLocalOrders.indexWhere((p) => sOf(p['id']) == id);
        if (method == 'DELETE') {
          if (i >= 0) pendingLocalOrders.removeAt(i);
        } else if (body != null && i >= 0) {
          pendingLocalOrders[i] =
              Map<String, dynamic>.from(pendingLocalOrders[i])..addAll(body);
        }
        _mergePendingOrders();
      });
    }
    final pl = await OfflineStore.loadPendingOrders();
    final pi = pl.indexWhere((p) => sOf(p['clientId']) == id || sOf(p['id']) == id);
    if (pi < 0) return;
    if (method == 'DELETE') {
      pl.removeAt(pi);
    } else if (body != null) {
      final entry = Map<String, dynamic>.from(pl[pi]);
      final payload = Map<String, dynamic>.from(entry['payload'] as Map? ?? {});
      payload.addAll(body);
      entry['payload'] = payload;
      pl[pi] = entry;
    }
    await OfflineStore.savePendingOrders(pl);
  }

  /// Saves an order locally when the server is unreachable and returns a
  /// display-ready order map so the UI/print flow keeps working.
  Future<Map<String, dynamic>> _stageOrderLocally(
      Map<String, dynamic> payload, String clientId, String me) async {
    final items = (payload['items'] as List? ?? []).cast<dynamic>().toList();
    final subtotal = items.fold<double>(
        0, (a, i) => a + (i is Map ? numOf(i['quantity']) * numOf(i['price']) : 0));
    final deliveryFee = numOf(payload['deliveryFee']);
    final now = DateTime.now();
    final display = <String, dynamic>{
      'id': clientId,
      'clientId': clientId,
      'orderNumber': 'OT-$clientId',
      'orderType': payload['orderType'],
      'source': _orderSource,
      'status': payload['status'],
      'paymentStatus': payload['paymentStatus'],
      'paymentMethod': payload['paymentMethod'],
      'customerName': payload['customerName'],
      'address': payload['address'],
      'phone': payload['phone'],
      'tableNumber': payload['tableNumber'],
      'notes': payload['notes'],
      'deliveryAgent': payload['deliveryAgent'],
      'serviceType': payload['serviceType'],
      'orderTaker': me,
      'waiter': me,
      'deliveryFee': deliveryFee,
      'cashReceived': numOf(payload['cashReceived']),
      'items': items,
      'subtotal': subtotal,
      'total': subtotal + deliveryFee,
      'createdAt': now.toIso8601String(),
      'date': now.toIso8601String(),
      'localPending': true,
    };
    final local = Map<String, dynamic>.from(display)
      ..['payload'] = payload
      ..['paid'] = payload['paymentStatus'] == 'Paid';
    await OfflineStore.addPendingOrder(local);
    if (mounted) {
      setState(() {
        pendingLocalOrders.add(display);
        _mergePendingOrders();
        offline = true;
        lastSyncOk = false;
      });
      toast('No internet - order saved locally, will sync automatically '
          '(${pendingLocalOrders.length} pending)',
          seconds: 5);
    }
    return display;
  }

  // ---------------------------------------------------------- POS categories
  // The web POS inventory stores categories under these REAL names (mostly
  // Urdu). We match by several aliases so the app shows whatever the server
  // actually returns instead of hardcoding English names that don't exist.
  static const List<String> _nashtaAliases = [
    'ناشتے کی آئٹمز',
    'Nashta',
    'Nashta Usman Hotel',
    'ناشتہ عثمان ہوٹل',
  ];
  static const List<String> _specialNaanAliases = [
    'اسپیشل نان',
    'Special Naan',
    'سپیشل نان',
  ];
  static const List<String> _breadAliases = [
    'نان اور روٹی',
    'Naan Roti',
    'Naan',
    'Roti',
    'نان',
    'روٹی',
  ];
  static const List<String> _extrasAliases = [
    'Extras',
    'ایکسٹرا',
  ];

  bool _aliasMatch(List<String> aliases, String name) =>
      aliases.any((a) => a.toLowerCase() == name.toLowerCase());

  List<String> _presentNames(List<String> aliases) => categories
      .whereType<Map>()
      .map((c) => sOf(c['name']))
      .where((name) => _aliasMatch(aliases, name))
      .toList();

  List<String> get _visiblePosCats {
    final present = <String>[
      ..._presentNames(_nashtaAliases),
      ..._presentNames(_specialNaanAliases),
      ..._presentNames(_extrasAliases),
    ];
    // For Delivery, Naan & Roti are shown on the POS too.
    if (activeType == 'Delivery') present.addAll(_presentNames(_breadAliases));
    return present;
  }

  List<String> get posCategories {
    final present = _visiblePosCats;
    // If nothing matched yet (data not loaded) show the primary aliases so the
    // POS isn't blank before the first refresh.
    if (present.isEmpty) {
      present.add(_nashtaAliases.first);
      present.add(_specialNaanAliases.first);
      present.add(_extrasAliases.first);
      if (activeType == 'Delivery') present.add(_breadAliases.first);
    }
    // Always keep the Nashta category pinned at the top.
    present.sort((a, b) {
      final na = _aliasMatch(_nashtaAliases, a) ? 0 : 1;
      final nb = _aliasMatch(_nashtaAliases, b) ? 0 : 1;
      return na.compareTo(nb);
    });
    return present;
  }

  List<Map<String, dynamic>> get breadProducts => products
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((p) => _aliasMatch(_breadAliases, sOf(p['category'])))
      .toList();

  bool _catMatches(Map p, String cat) =>
      sOf(p['category']).toLowerCase() == cat.toLowerCase();

  List<Map<String, dynamic>> get filteredProducts {
    final term = search.toLowerCase().trim();
    bool matches(Map p) =>
        term.isEmpty ||
        sOf(p['name']).toLowerCase().contains(term) ||
        sOf(p['category']).toLowerCase().contains(term) ||
        sOf(p['code']).toLowerCase().contains(term);
    final cat = selectedCategory;
    if (cat == 'All') {
      final lower = _visiblePosCats.map((e) => e.toLowerCase()).toList();
      return products
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) => lower.contains(sOf(p['category']).toLowerCase()) && matches(p))
          .toList();
    }
    // Any bread category shows all Naan / Roti items.
    if (_aliasMatch(_breadAliases, cat)) {
      final lower = _breadAliases.map((e) => e.toLowerCase()).toList();
      return products
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) => lower.contains(sOf(p['category']).toLowerCase()) && matches(p))
          .toList();
    }
    return products
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((p) => _catMatches(p, cat) && matches(p))
        .toList();
  }

  List<Map<String, dynamic>> get cart => carts[activeType] ?? [];

  int get cartTotal => cart.fold<int>(
      0, (sum, i) => sum + (numOf(i['price']) * numOf(i['quantity'])).round());
  int get cartCount =>
      cart.fold<int>(0, (s, i) => s + (numOf(i['quantity'])).round());

  Map<String, int> cartQtyByProductId() {
    final m = <String, int>{};
    for (final i in cart) {
      final id = sOf(i['id']);
      if (id.isNotEmpty) m[id] = (m[id] ?? 0) + (numOf(i['quantity'])).round();
    }
    return m;
  }

  List<Map<String, dynamic>> get allNashtaProducts {
    final lower = _visiblePosCats.map((e) => e.toLowerCase()).toList();
    final out = <Map<String, dynamic>>[];
    for (final p in products.whereType<Map>()) {
      if (lower.contains(sOf(p['category']).toLowerCase())) {
        out.add(Map<String, dynamic>.from(p));
      }
    }
    return out;
  }

  void addToCart(Map<String, dynamic> product) {
    final flavors = product['flavors'];
    if (flavors is List && flavors.isNotEmpty) {
      setState(() {
        variantProduct = product;
        variantFlavor = null;
        variantStep = 'flavors';
        showVariant = true;
      });
      return;
    }
    addPlainToCart(product);
  }

  void markOrdered(String productId) {
    setState(() => orderedFeedback[productId] = true);
    late final Timer t;
    t = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => orderedFeedback[productId] = false);
      _feedbackTimers.remove(t);
    });
    _feedbackTimers.add(t);
  }

  void addPlainToCart(Map<String, dynamic> product) {
    setState(() {
      final list = carts[activeType]!;
      final idx = list.indexWhere((i) =>
          sOf(i['id']) == sOf(product['id']) &&
          sOf(i['flavor']).isEmpty &&
          sOf(i['weight']).isEmpty);
      if (idx >= 0) {
        list[idx]['quantity'] = numOf(list[idx]['quantity']) + 1;
      } else {
        list.add({
          ...product,
          'quantity': 1,
          'price': numOf(product['price']),
          'weight': '',
          'flavor': '',
          'itemId':
              '${product['id']}-base-${DateTime.now().millisecondsSinceEpoch}',
        });
      }
    });
    markOrdered(sOf(product['id']));
  }

  void selectVariantFlavor(Map<String, dynamic> flavor) {
    final variants = flavor['variants'];
    if (variants is List && variants.isNotEmpty) {
      setState(() {
        variantFlavor = flavor;
        variantStep = 'variants';
      });
      return;
    }
    addVariantToCart(variantProduct!, flavor, null);
  }

  void addVariantToCart(Map product, Map? flavor, Map? variant) {
    setState(() {
      final flabel = sOf(flavor?['label']);
      final vlabel = sOf(variant?['label']);
      final price =
          variant?['price'] != null ? numOf(variant!['price']) : numOf(product['price']);
      final list = carts[activeType]!;
      final idx = list.indexWhere((i) =>
          sOf(i['id']) == sOf(product['id']) &&
          sOf(i['flavor']) == flabel &&
          sOf(i['weight']) == vlabel);
      if (idx >= 0) {
        list[idx]['quantity'] = numOf(list[idx]['quantity']) + 1;
      } else {
        list.add({
          ...product,
          'quantity': 1,
          'price': price,
          'weight': vlabel,
          'flavor': flabel,
          'itemId':
              '${product['id']}-${vlabel.isEmpty ? 'base' : vlabel}-${flabel.isEmpty ? 'noflavor' : flabel}-${DateTime.now().millisecondsSinceEpoch}',
        });
      }
      variantProduct = null;
      variantFlavor = null;
      variantStep = 'flavors';
      showVariant = false;
    });
    markOrdered(sOf(product['id']));
  }

  void updateCartQty(String itemId, int delta) {
    setState(() {
      final list = carts[activeType]!;
      carts[activeType] = list
          .map((i) {
            if (i['itemId'] == itemId) {
              i['quantity'] = (numOf(i['quantity']) + delta).clamp(0, 9999);
            }
            return i;
          })
          .where((i) => numOf(i['quantity']) > 0)
          .toList();
    });
  }

  Future<void> _editCartName(Map<String, dynamic> item) async {
    final ctrl = TextEditingController(text: sOf(item['name']));
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Item Name', isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty || !mounted) return;
    setState(() {
      for (final x in carts[activeType]!) {
        if (x['itemId'] == item['itemId']) x['name'] = newName;
      }
    });
  }

  Future<void> _editCartPrice(Map<String, dynamic> item) async {
    final ctrl = TextEditingController(text: numOf(item['price']).toStringAsFixed(0));
    final newPrice = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item Price', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Price (PKR)', isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim().replaceAll(',', ''));
              Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newPrice == null || newPrice < 0 || !mounted) return;
    setState(() {
      for (final x in carts[activeType]!) {
        if (x['itemId'] == item['itemId']) x['price'] = newPrice;
      }
    });
    toast('Price updated', seconds: 2);
  }

  void removeFromCart(String itemId) =>
      setState(() => carts[activeType]!.removeWhere((i) => i['itemId'] == itemId));

  void _onPressStart(Map<String, dynamic> product) {
    _pressFired = false;
    _pressTimer?.cancel();
    _pressTimer = Timer(const Duration(seconds: 1), () {
      _pressFired = true;
      HapticFeedback.heavyImpact();
      final line = cart.where((i) => sOf(i['id']) == sOf(product['id'])).toList();
      if (line.isNotEmpty) removeFromCart(sOf(line.first['itemId']));
      toast('${product['name']} removed', seconds: 2);
    });
  }

  void _onPressEnd() {
    _pressTimer?.cancel();
    _pressTimer = null;
  }

  void _onTapProduct(Map<String, dynamic> product) {
    if (_pressFired) {
      _pressFired = false;
      return;
    }
    addToCart(product);
  }

  // --------------------------------------------------------------- create
  Future<Map<String, dynamic>?> createOrder(String orderType,
      {bool paid = false, String payMethod = 'Cash', double cashReceived = 0}) async {
    final list = carts[orderType]!;
    if (list.isEmpty) {
      toast('Cart is empty');
      return null;
    }
    if (orderType == 'Delivery') {
      if (_c('address').text.trim().isEmpty) {
        toast('Delivery address required');
        return null;
      }
      if (selectedZone.trim().isEmpty && _c('zone').text.trim().isEmpty) {
        toast('Delivery area required');
        return null;
      }
    }
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : (sOf(user['username']).isNotEmpty ? sOf(user['username']) : '');
      String status;
      if (orderType == 'Delivery') {
        status = selectedRider.trim().isNotEmpty ? 'Riders Assigned' : 'Pending';
      } else if (orderType == 'Takeaway') {
        status = paid ? 'Paid' : 'Pay Later';
      } else {
        status = 'New';
      }
      final deliveryFee = orderType == 'Delivery'
          ? (double.tryParse(_c('fee').text.trim()) ?? 0)
          : 0;
      final payload = {
        'items': list
            .map((i) => {
                  'productId': i['id'],
                  'name': i['name'],
                  'price': numOf(i['price']),
                  'quantity': i['quantity'],
                  'code': i['code'] ?? '',
                  'weight': i['weight'] ?? '',
                  'flavor': i['flavor'] ?? '',
                })
            .toList(),
        'orderType': orderType == 'Table' ? 'Dine-In' : orderType,
        'source': _orderSource,
        'customerName': _c('cust').text.trim().isEmpty
            ? (orderType == 'Takeaway' ? 'Pickup' : '')
            : _c('cust').text.trim(),
        'phone': _c('phone').text.trim(),
        'address': _c('address').text.trim(),
        'tableNumber': orderType == 'Table' ? _c('table').text.trim() : '',
        'notes': _c('notes').text.trim(),
        'orderTaker': me,
        'waiter': me,
        'status': status,
        'paymentStatus': paid ? 'Paid' : 'Pending',
        'serviceType': selectedZone.isNotEmpty ? selectedZone : _c('zone').text.trim(),
        'deliveryAgent': orderType == 'Delivery' ? selectedRider : '',
        'deliveryFee': deliveryFee,
        'discount': 0,
        'taxPercent': 0,
        'serviceCharge': 0,
        'paymentMethod': paid ? payMethod : '',
        if (paid && cashReceived > 0) 'cashReceived': cashReceived,
      };
      final created0 = await Future<Map<String, dynamic>?>.sync(() async {
        final clientId = await OfflineStore.nextClientId();
        final payload2 = <String, dynamic>{...payload, 'clientId': clientId};
        try {
          final res = await _fetch('/pos/orders', method: 'POST', body: payload2);
          return res is Map ? Map<String, dynamic>.from(res) : null;
        } on ApiException catch (e) {
          if (e.statusCode != 0) rethrow;
          return await _stageOrderLocally(payload2, clientId, me);
        }
      });
      final created = created0 ?? <String, dynamic>{};
      final createdOk = created0 != null;
      if (createdOk && sOf(created['source']).trim().isEmpty &&
          created['localPending'] != true) {
        final cid = sOf(created['id']);
        if (cid.isNotEmpty) {
          await _fetch('/pos/orders/$cid', method: 'PUT', body: {'source': _orderSource}).catchError((_) => null);
        }
      }
      if (createdOk && created['localPending'] == true) {
        unawaited(_syncPendingOrders());
      }
      if (orderType == 'Delivery' && selectedCustomerId.isEmpty &&
          createdOk && created['localPending'] != true) {
        final ph = _c('phone').text.trim();
        final ad = _c('address').text.trim();
        if (ph.isNotEmpty || ad.isNotEmpty) {
          await _fetch('/pos_customers', method: 'POST', body: {
            'name': '',
            'phone': ph,
            'address': ad,
            'serviceType': selectedZone,
            'deliveryLocation': selectedZone,
            'source': 'nashta-app',
          }).catchError((_) => null);
        }
      }
      if (createdOk && paid && created['localPending'] != true) {
        await _fetch('/pos/payments', method: 'POST', body: {
          'orderId': created['id'],
          'amount': created['total'],
          'paymentMethod': payMethod,
          'status': 'Completed',
          'description': 'Payment for order ${created['orderNumber'] ?? created['id']}',
        }).catchError((_) => null);
      }
      if (!mounted) return createdOk ? Map<String, dynamic>.from(created) : null;
      setState(() {
        carts[orderType] = [];
        for (final k in ['cust', 'phone', 'address', 'table', 'notes', 'fee', 'zone']) {
          _c(k).clear();
        }
        selectedZone = '';
        selectedRider = '';
        selectedCustomerId = '';
        _addrSuggestions = [];
        showCart = false;
      });
      toast(created['localPending'] == true
          ? 'Order saved locally (offline - will auto-sync) \u2705'
          : paid
              ? 'Order created & paid \u2705'
              : orderType == 'Takeaway'
                  ? 'Takeaway order (Pay Later) created \u{1F6CD}'
                  : 'Order created successfully \u2705');
      if ((btConnected || btInfo != null || settings['btPrintEnabled'] == true) &&
          createdOk) {
        final printOrder = Map<String, dynamic>.from(created);
        if (sOf(printOrder['date']).isEmpty) {
          printOrder['date'] = sOf(printOrder['createdAt']).isNotEmpty
              ? sOf(printOrder['createdAt'])
              : DateTime.now().toIso8601String();
        }
        printOrderBT(printOrder).then((ok) {
          if (ok) toast('Order printed via Bluetooth');
        }).catchError((e) {
          toast('Order created but print failed: $e', seconds: 6);
        });
      }
      await _refreshOrdersOnly();
      return createdOk ? Map<String, dynamic>.from(created) : null;
    } catch (e) {
      toast(e.toString(), seconds: 6);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------ order actions
  bool _isPaidOrDone(Map o) {
    final st = sOf(o['status']).toLowerCase();
    final p = sOf(o['paymentStatus']).toLowerCase();
    return st == 'completed' ||
        st == 'payment collected' ||
        st == 'paid' ||
        p == 'paid';
  }

  bool _isCancelled(Map o) =>
      sOf(o['status']).toLowerCase() == 'cancelled' ||
      sOf(o['cancelledAt']).isNotEmpty;

  bool _isDueStatus(Map o) {
    final st = sOf(o['status']).toLowerCase();
    final p = sOf(o['paymentStatus']).toLowerCase();
    return st == 'due' || p == 'due';
  }

  Future<void> _putOrder(Map order, Map<String, dynamic> body) async {
    if (_busy) return;
    setState(() => _busy = true);
    _fadeOutOrders([Map<String, dynamic>.from(order)]);
    try {
      final ok = await _offlineAwareOrderCall(order, 'PUT', {...body});
      if (!ok) {
        toast('Failed to update order', seconds: 6);
        return;
      }
      if (!mounted) return;
      toast(offline
          ? 'Updated (offline - auto-sync ✅)'
          : 'Updated \u2705');
      await _refreshOrdersOnly();
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> assignRider(Map order, String name) async {
    final body = <String, dynamic>{'deliveryAgent': name};
    if (name.trim().isNotEmpty && sOf(order['status']).toLowerCase() == 'pending') {
      body['status'] = 'Riders Assigned';
    }
    await _putOrder(order, body);
  }

  Future<void> markDue(Map order) async {
    await _putOrder(order, {
      'paymentStatus': 'Due',
      'status': 'Due',
    });
  }

  Future<void> markPaid(Map order) async {
    final isDelivery = sOf(order['orderType']) == 'Delivery';
    await _putOrder(order, {
      'paymentStatus': 'paid',
      'status': isDelivery ? 'Delivered' : 'Payment Collected',
      'paidAt': DateTime.now().toUtc().toIso8601String(),
    });
    if (offline) return;
    final amt = order['total'] ?? order['amount'] ?? 0;
    await _fetch('/pos/payments', method: 'POST', body: {
      'orderId': order['id'],
      'amount': amt,
      'paymentMethod': 'Cash',
      'status': 'Completed',
      'description': 'Payment for order ${order['orderNumber'] ?? order['id']}',
    }).catchError((_) => null);
  }

  Future<void> cancelOrder(Map order) async => _putOrder(order, {
        'status': 'Cancelled',
        'cancelledAt': DateTime.now().toUtc().toIso8601String(),
      });

  Future<void> _deleteOrder(Map order) async {
    if (_busy) return;
    setState(() => _busy = true);
    _fadeOutOrders([Map<String, dynamic>.from(order)]);
    try {
      await _offlineAwareOrderCall(order, 'DELETE', null);
      if (!mounted) return;
      toast(offline
          ? 'Order deleted (offline - auto-sync 🗑️)'
          : 'Order deleted successfully');
      await _refreshOrdersOnly();
    } catch (e) {
      toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickRiderAndAssign(Map order) async {
    final list = ridersList;
    if (list.isEmpty) {
      toast('No riders available');
      return;
    }
    final me = sOf(order['deliveryAgent']);
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Rider',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.delivery_dining, color: Color(0xFF2563EB)),
              title: Text(list[i],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              trailing: list[i] == me
                  ? const Icon(Icons.check, color: Color(0xFF059669))
                  : null,
              onTap: () => Navigator.pop(ctx, list[i]),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
    if (pick != null && pick.isNotEmpty) await assignRider(order, pick);
  }

  List<Map<String, dynamic>> get _selectedOrdersList =>
      filteredVisibleOrders.where((o) => _selectedOrderIds.contains(sOf(o['id']))).toList();

  void _toggleSelectAll() {
    setState(() {
      if (_selectedOrdersList.length == filteredVisibleOrders.length) {
        _selectedOrderIds.clear();
      } else {
        _selectedOrderIds
          ..clear()
          ..addAll(filteredVisibleOrders.map((o) => sOf(o['id'])));
      }
    });
  }

  Future<void> _bulkDelete() async {
    final list = _selectedOrdersList;
    if (list.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${list.length} order(s)?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;
    if (_busy) return;
    setState(() => _busy = true);
    _fadeOutOrders(list);
    try {
      final ids = list.map((o) => sOf(o['id'])).where((x) => x.isNotEmpty).toList();
      for (final o in list) {
        if (sOf(o['id']).isEmpty) continue;
        await _offlineAwareOrderCall(o, 'DELETE', null);
      }
      if (!mounted) return;
      setState(() {
        orders = orders.whereType<Map>().where((o) => !ids.contains(sOf(o['id']))).toList();
        selectMode = false;
        _selectedOrderIds.clear();
      });
      toast(offline
          ? '${ids.length} order(s) deleted (offline - auto-sync 🗑️)'
          : '${ids.length} order(s) deleted');
      await _refreshOrdersOnly();
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkRider() async {
    final list = _selectedOrdersList;
    if (list.isEmpty) return;
    final riders = ridersList;
    if (riders.isEmpty) {
      toast('No riders available');
      return;
    }
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign ${list.length} order(s) to',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: riders.length,
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.delivery_dining, color: Color(0xFF2563EB)),
              title: Text(riders[i]),
              onTap: () => Navigator.pop(ctx, riders[i]),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
    if (pick == null || pick.isEmpty) return;
    if (_busy) return;
    setState(() => _busy = true);
    _fadeOutOrders(list);
    try {
      final ids = list.map((o) => sOf(o['id'])).where((x) => x.isNotEmpty).toList();
      for (final o in list) {
        if (sOf(o['id']).isEmpty) continue;
        await _offlineAwareOrderCall(o, 'PUT', {
          'deliveryAgent': pick,
          'status': 'Riders Assigned',
        });
      }
      if (!mounted) return;
      setState(() {
        for (final o in orders.whereType<Map>()) {
          if (ids.contains(sOf(o['id']))) {
            o['deliveryAgent'] = pick;
            if (sOf(o['status']).toLowerCase() == 'pending') o['status'] = 'Riders Assigned';
          }
        }
        selectMode = false;
        _selectedOrderIds.clear();
      });
      toast(offline
          ? '${ids.length} order(s) assigned to $pick (offline - auto-sync ✅)'
          : '${ids.length} order(s) assigned to $pick');
      await _refreshOrdersOnly();
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkMarkPaid() async {
    final list = _selectedOrdersList;
    if (list.isEmpty) return;
    if (_busy) return;
    setState(() => _busy = true);
    _fadeOutOrders(list);
    try {
      final ids = list.map((o) => sOf(o['id'])).where((x) => x.isNotEmpty).toList();
      final paidAt = DateTime.now().toUtc().toIso8601String();
      for (final o in list) {
        if (sOf(o['id']).isEmpty) continue;
        await _offlineAwareOrderCall(o, 'PUT', {
          'paymentStatus': 'paid',
          'status': 'Delivered',
          'paidAt': paidAt,
        });
      }
      if (!offline) {
        await Future.wait(list.map((o) => _fetch('/pos/payments', method: 'POST', body: {'orderId': sOf(o['id']), 'amount': o['total'] ?? o['amount'] ?? 0, 'paymentMethod': 'Cash', 'status': 'Completed', 'description': 'Bulk payment for order ${o['orderNumber'] ?? o['id']}'}).catchError((_) => null)));
      }
      if (!mounted) return;
      setState(() {
        for (final o in orders.whereType<Map>()) {
          if (ids.contains(sOf(o['id']))) {
            o['paymentStatus'] = 'paid';
            o['status'] = 'Delivered';
            o['paidAt'] = paidAt;
          }
        }
        selectMode = false;
        _selectedOrderIds.clear();
      });
      toast(offline
          ? '${ids.length} order(s) marked paid (offline - auto-sync ✅)'
          : '${ids.length} order(s) marked paid');
      await _refreshOrdersOnly();
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkMarkDue() async {
    final list = _selectedOrdersList;
    if (list.isEmpty) return;
    if (_busy) return;
    setState(() => _busy = true);
    _fadeOutOrders(list);
    try {
      final ids = list.map((o) => sOf(o['id'])).where((x) => x.isNotEmpty).toList();
      for (final o in list) {
        if (sOf(o['id']).isEmpty) continue;
        await _offlineAwareOrderCall(o, 'PUT', {
          'paymentStatus': 'Due',
          'status': 'Due',
        });
      }
      if (!mounted) return;
      setState(() {
        for (final o in orders.whereType<Map>()) {
          if (ids.contains(sOf(o['id']))) {
            o['paymentStatus'] = 'Due';
            o['status'] = 'Due';
          }
        }
        selectMode = false;
        _selectedOrderIds.clear();
      });
      toast(offline
          ? '${ids.length} order(s) marked due (offline - auto-sync 💰)'
          : '${ids.length} order(s) marked due');
      await _refreshOrdersOnly();
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------- riders list
  List<String> get ridersList {
    final names = <String, bool>{};
    // Only ACTIVE staff with the BIKER role are riders.
    // Rider/Admin Rider roles and test/inactive entries are never shown.
    for (final s in staffMembers) {
      if (s is! Map) continue;
      if (!sOf(s['role']).toLowerCase().contains('biker')) continue;
      if (sOf(s['status']).toLowerCase() != 'active') continue;
      final n = sOf(s['name']).trim();
      if (n.isNotEmpty) names[n] = true;
    }
    return names.keys.toList();
  }

  List<Map<String, dynamic>> get deliveryZones {
    final zones = <String, Map<String, dynamic>>{};
    for (final st in serviceTypes) {
      if (st is! Map) continue;
      final name = sOf(st['name']).trim();
      if (name.isEmpty) continue;
      zones[name] = {
        'name': name,
        'serviceType': name,
        'deliveryFee': numOf(st['charge'] ?? st['fee'] ?? st['price']),
      };
    }
    for (final loc in deliveryLocations) {
      if (loc is! Map) continue;
      final name = sOf(loc['name']).trim();
      if (name.isEmpty) continue;
      final existing = zones[name];
      zones[name] = {
        'name': name,
        'serviceType': existing?['serviceType'] ?? name,
        'deliveryFee': numOf(loc['charge'] ??
            loc['fee'] ??
            loc['deliveryFee'] ??
            (existing?['deliveryFee'] ?? 0)),
      };
    }
    return zones.values.toList();
  }

  double _feeFromZone() {
    final z = deliveryZones.firstWhere((zz) => sOf(zz['name']) == selectedZone, orElse: () => {});
    return z.isNotEmpty ? numOf(z['deliveryFee']) : (double.tryParse(_c('fee').text.trim()) ?? 0);
  }

  // --------------------------------------------------------------- printing
  Future<PrinterInfo?> _pickPrinterDialog(List<PrinterInfo> list) {
    return showDialog<PrinterInfo>(
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<bool> _connectPrinter(PrinterInfo p) async {
    final ok = await BtService.connect(p);
    if (ok) {
      setState(() {
        btConnected = true;
        btInfo = p;
      });
    }
    return ok;
  }

  Future<bool> printOrderBT(Map<String, dynamic> order0) async {
    final order = Map<String, dynamic>.from(order0);
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
    printer ??= btInfo;
    if (printer == null) {
      final list = await BtService.pairedPrinters();
      if (list.isEmpty) {
        throw Exception(
            'No paired printer found - pair your thermal printer in Android Bluetooth settings first');
      }
      if (!mounted) throw Exception('No printer selected');
      printer = await _pickPrinterDialog(list);
      if (printer == null) throw Exception('No printer selected');
      await BtService.savePrinter(printer);
    }
    final target = printer;
    Future<void> attemptPrint() async {
      if (!(await BtService.isConnected())) {
        final ok = await _connectPrinter(target);
        if (!ok) throw Exception('Could not connect to ${target.name}');
      }
      final enc = sOf(btSettings['btEncoding']);
      final isBmp = enc.isEmpty || enc == 'bmp';
      final out = BytesBuilder();
      if (isBmp) {
        out.add(await bmp.buildBmpReceipt(order, btSettings, host: ApiClient.host));
      } else {
        try {
          out.add(esc.buildEscposReceipt(order, btSettings));
        } catch (_) {
          out.add(await bmp.buildBmpReceipt(order, btSettings, host: ApiClient.host));
        }
      }
      await BtService.write(out.toBytes());
    }

    try {
      await BtService.enqueue(attemptPrint);
      return true;
    } catch (_) {
      await BtService.disconnect();
      await BtService.enqueue(() async {
        final ok = await _connectPrinter(target);
        if (!ok) throw Exception('Print failed');
        await attemptPrint();
      });
      return true;
    }
  }

  Future<void> _loadBtOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_btOverridesKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && mounted) {
        setState(() => btOverrides = Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
  }

  Future<void> _setBt(String key, dynamic value) async {
    setState(() => btOverrides[key] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_btOverridesKey, jsonEncode(btOverrides));
  }

  bool _isManager() {
    final role = sOf(user['role']).toLowerCase();
    return role.contains('manager') || role.contains('admin');
  }

  // ----------------------------------------------------------- orders screen
  bool _isMineOrder(Map<String, dynamic> o) {
    if (_isManager()) return true;
    final ot = sOf(o['orderTaker']).trim().toLowerCase();
    final name = sOf(user['name']).trim().toLowerCase();
    final uname = sOf(user['username']).trim().toLowerCase();
    if (name.isNotEmpty && ot == name) return true;
    if (uname.isNotEmpty && ot == uname) return true;
    return false;
  }

  List<Map<String, dynamic>> _byType(String type) => orders
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((o) => sOf(o['orderType']) == type && _isMineOrder(o))
      .toList();

  List<Map<String, dynamic>> get deliveryOrders {
    final out = _byType('Delivery');
    out.sort((a, b) {
      final ta = DateTime.tryParse(sOf(a['createdAt'])) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(sOf(b['createdAt'])) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return out;
  }

  bool _isDeliveryPaid(Map<String, dynamic> o) {
    final st = sOf(o['status']).toLowerCase();
    final p = sOf(o['paymentStatus']).toLowerCase();
    return st == 'payment collected' || st == 'paid' || p == 'paid';
  }

  bool _isDeliveryDue(Map<String, dynamic> o) {
    final st = sOf(o['status']).toLowerCase();
    final p = sOf(o['paymentStatus']).toLowerCase();
    return st == 'due' || p == 'due';
  }

  bool _isDeliveredOrDone(Map<String, dynamic> o) {
    final st = sOf(o['status']).toLowerCase();
    return st == 'completed' || st == 'delivered';
  }

  List<Map<String, dynamic>> get deliveryActive =>
      deliveryOrders.where((o) {
        final st = sOf(o['status']).toLowerCase();
        final assigned = sOf(o['deliveryAgent']).trim().isNotEmpty;
        return !assigned &&
            !_isDeliveryPaid(o) &&
            !_isDeliveryDue(o) &&
            !_isDeliveredOrDone(o) &&
            st != 'cancelled';
      }).toList();

  List<Map<String, dynamic>> get deliveryAssigned =>
      deliveryOrders.where((o) {
        final st = sOf(o['status']).toLowerCase();
        return sOf(o['deliveryAgent']).trim().isNotEmpty &&
            !_isDeliveryPaid(o) &&
            !_isDeliveryDue(o) &&
            !_isDeliveredOrDone(o) &&
            st != 'cancelled';
      }).toList();

  List<Map<String, dynamic>> get deliveryPaid =>
      deliveryOrders.where((o) =>
          (_isDeliveryPaid(o) || _isDeliveredOrDone(o)) &&
          sOf(o['status']).toLowerCase() != 'cancelled').toList();

  List<Map<String, dynamic>> get deliveryDue =>
      deliveryOrders.where((o) =>
          _isDeliveryDue(o) &&
          sOf(o['status']).toLowerCase() != 'cancelled').toList();

  List<Map<String, dynamic>> get deliveryCancelled =>
      deliveryOrders.where((o) => sOf(o['status']).toLowerCase() == 'cancelled').toList();

  List<Map<String, dynamic>> get takeawayOrders => _byType('Takeaway');
  List<Map<String, dynamic>> get takeawayPayLater => takeawayOrders.where((o) {
        final st = sOf(o['status']).toLowerCase();
        return !_isDueStatus(o) &&
            (st == 'pay later' ||
                ((st == 'pending' || st == 'new') && !_isPaidOrDone(o)));
      }).toList();
  List<Map<String, dynamic>> get takeawayPaid =>
      takeawayOrders.where(_isPaidOrDone).toList();
  List<Map<String, dynamic>> get takeawayDue =>
      takeawayOrders.where((o) =>
          _isDueStatus(o) &&
          sOf(o['status']).toLowerCase() != 'cancelled').toList();
  List<Map<String, dynamic>> get takeawayCancelled =>
      takeawayOrders.where((o) => sOf(o['status']).toLowerCase() == 'cancelled').toList();

  List<Map<String, dynamic>> get tableOrders => _byType('Dine-In');
  List<Map<String, dynamic>> get tableActive => tableOrders.where((o) {
        final st = sOf(o['status']).toLowerCase();
        return !_isPaidOrDone(o) && !_isDueStatus(o) && st != 'cancelled';
      }).toList();
  List<Map<String, dynamic>> get tablePaid => tableOrders.where(_isPaidOrDone).toList();
  List<Map<String, dynamic>> get tableDue =>
      tableOrders.where((o) =>
          _isDueStatus(o) &&
          sOf(o['status']).toLowerCase() != 'cancelled').toList();
  List<Map<String, dynamic>> get tableCancelled =>
      tableOrders.where((o) => sOf(o['status']).toLowerCase() == 'cancelled').toList();

  List<Map<String, dynamic>> get visibleOrders {
    switch (ordersView) {
      case 'Takeaway':
        if (ordersSubTab == 'cancelled') return takeawayCancelled;
        if (ordersSubTab == 'due') return takeawayDue;
        return ordersSubTab == 'paid' ? takeawayPaid : takeawayPayLater;
      case 'Table':
        if (ordersSubTab == 'cancelled') return tableCancelled;
        if (ordersSubTab == 'due') return tableDue;
        return ordersSubTab == 'paid' ? tablePaid : tableActive;
      default:
        if (ordersSubTab == 'assigned') return deliveryAssigned;
        if (ordersSubTab == 'paid') return deliveryPaid;
        if (ordersSubTab == 'due') return deliveryDue;
        if (ordersSubTab == 'cancelled') return deliveryCancelled;
        return deliveryActive;
    }
  }

  // -------------------------------------------------- orders date filter
  (DateTime, DateTime) _ordersDateWindow() {
    final now = DateTime.now();
    final sod = DateTime(now.year, now.month, now.day);
    switch (ordersDateRange) {
      case 'yesterday':
        return (sod.subtract(const Duration(days: 1)), sod);
      case 'last7':
        return (sod.subtract(const Duration(days: 6)), sod.add(const Duration(days: 1)));
      case 'last30':
        return (sod.subtract(const Duration(days: 29)), sod.add(const Duration(days: 1)));
      case 'month':
        return (DateTime(now.year, now.month, 1), sod.add(const Duration(days: 1)));
      case 'all':
        return (DateTime(2000), DateTime(2100));
      case 'custom':
        final f = ordersFromDate ?? sod;
        final t = ordersToDate != null
            ? DateTime(ordersToDate!.year, ordersToDate!.month, ordersToDate!.day)
                .add(const Duration(days: 1))
            : sod.add(const Duration(days: 1));
        return (f, t);
      default:
        return (sod, sod.add(const Duration(days: 1)));
    }
  }

  bool _inOrdersDateRange(Map<String, dynamic> o) {
    if (ordersDateRange == 'all') return true;
    final (from, to) = _ordersDateWindow();
    final d = DateTime.tryParse(sOf(o['createdAt']));
    if (d == null) return false;
    return !d.isBefore(from) && d.isBefore(to);
  }

  List<Map<String, dynamic>> get filteredVisibleOrders {
    final q = ordersSearch.trim().toLowerCase();
    if (q.isEmpty) return visibleOrders.where(_inOrdersDateRange).toList();
    return visibleOrders.where((o) {
      if (!_inOrdersDateRange(o)) return false;
      final num = (sOf(o['orderNumber']).isEmpty ? sOf(o['id']) : sOf(o['orderNumber'])).toLowerCase();
      final cust = sOf(o['customerName']).toLowerCase();
      final phone = sOf(o['customerPhone']).toLowerCase();
      final addr = sOf(o['address']).toLowerCase();
      final agent = sOf(o['deliveryAgent']).toLowerCase();
      final table = sOf(o['tableNumber']).toLowerCase();
      final st = sOf(o['serviceType']).toLowerCase();
      final loc = sOf(o['location']).toLowerCase();
      final notes = sOf(o['notes']).toLowerCase();
      return num.contains(q) ||
          cust.contains(q) ||
          phone.contains(q) ||
          addr.contains(q) ||
          agent.contains(q) ||
          table.contains(q) ||
          st.contains(q) ||
          loc.contains(q) ||
          notes.contains(q);
    }).toList();
  }

  void _openOrders() {
    setState(() => showOrdersScreen = true);
    _ordersTimer?.cancel();
    _ordersTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (showOrdersScreen && mounted) _refreshOrdersOnly();
    });
  }

  void _closeOrders() {
    setState(() => showOrdersScreen = false);
    _ordersTimer?.cancel();
  }

  // --------------------------------------------------------------- UI: build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                if (offline) _offlineBanner(),
                _header(),
                _typeTabs(),
                _searchBar(),
                Expanded(
                  child: initialLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF059669)))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _categoryRail(),
                            Expanded(child: _productGrid()),
                          ],
                        ),
                ),
              ],
            ),
            if (cart.isNotEmpty && !showCart && !showVariant)
              Positioned(
                right: 16,
                bottom: 24,
                child: FloatingActionButton.extended(
                  heroTag: 'cartFab',
                  onPressed: _openCart,
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  icon: const Text('\u{1F6D2}'),
                  label: Text('$cartCount items \u00B7 $cartTotal PKR'),
                ),
              ),
            if (showVariant) _variantSheet(),
            if (showCart) _cartSheet(),
            if (showOrdersScreen) _ordersScreen(),
            if (message.isNotEmpty) _toastOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _offlineBanner() {
    final count = pendingLocalOrders.where((o) => o['localPending'] == true).length;
    return Material(
      color: const Color(0xFFB91C1C),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Text('📡', style: TextStyle(fontSize: 16, color: Colors.white)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No internet — $count pending order(s) saved locally, auto-syncing when connected',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            if (syncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _syncIndicator() {
    final Color c;
    final Widget inner;
    if (syncing) {
      c = const Color(0xFF0284C7);
      inner = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
      );
    } else if (lastSyncOk == true) {
      c = const Color(0xFF16A34A);
      inner = const Icon(Icons.cloud_done, color: Colors.white, size: 18);
    } else if (lastSyncOk == false) {
      c = const Color(0xFFDC2626);
      inner = const Icon(Icons.cloud_off, color: Colors.white, size: 18);
    } else {
      c = const Color(0xFF94A3B8);
      inner = const Icon(Icons.cloud_outlined, color: Colors.white, size: 18);
    }
    return GestureDetector(
      onTap: () {
        if (!syncing) unawaited(_syncPendingOrders());
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: c, width: 1.5),
        ),
        child: inner,
      ),
    );
  }

  Widget _header() {
    final name = sOf(user['name']).isNotEmpty
        ? sOf(user['name'])
        : (sOf(user['username']).isNotEmpty ? sOf(user['username']) : 'Staff');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/img/logo.png',
                width: 30, height: 30, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nashta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
              Text(name, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
            ],
          ),
          const Spacer(),
          _hdrBtn('\u{1F4CB}', 'Orders', const Color(0xFFECFDF5), const Color(0xFF059669), _openOrders),
          const SizedBox(width: 6),
          _hdrBtn('\u{1F4CA}', 'Dash', const Color(0xFFECFDF5), const Color(0xFF7C3AED), () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DashboardScreen(orders: orders, user: user, riders: ridersRecords, token: token)));
          }),
          const SizedBox(width: 6),
          _hdrBtn('\u{1F9F1}', 'Printer', const Color(0xFFEFF6FF), const Color(0xFF2563EB), () {
            Navigator.of(context)
                .push(
                    MaterialPageRoute(builder: (_) => const OrderTakerPrinterSettings()))
                .then((_) => _loadBtOverrides());
          }),
          const SizedBox(width: 6),
          _hdrBtn('\u{1F6AA}', 'Exit', const Color(0xFFFEE2E2), const Color(0xFFDC2626), handleLogout, showLabel: false),
        ],
      ),
    );
  }

  Widget _hdrBtn(String icon, String label, Color bg, Color fg, VoidCallback onTap, {bool showLabel = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: showLabel ? 10 : 8, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
          ],
        ]),
      ),
    );
  }

  Widget _typeTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Row(
        children: orderTypes.map((t) {
          final sel = activeType == t;
          final emoji = t == 'Delivery'
              ? '\u{1F4E6}'
              : t == 'Parcel'
                  ? '\u{1F4E6}'
                  : t == 'Table'
                      ? '\u{1F37D}'
                      : '\u{1F6CD}';
          final count = carts[t]?.length ?? 0;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                activeType = t;
                showCart = false;
                selectedCategory = posCategories.isNotEmpty ? posCategories.first : 'All';
              }),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(t,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : const Color(0xFF475569))),
                  if (count > 0)
                    Text('$count',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white70 : const Color(0xFF94A3B8))),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: _c('search'),
        onChanged: (v) => setState(() => search = v),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: Color(0xFF059669)),
          ),
        ),
      ),
    );
  }

  String _catIconFor(String name) {
    for (final c in categories.whereType<Map>()) {
      if (sOf(c['name']) == name) return sOf(c['icon']);
    }
    return '';
  }

  Widget _catIconWidget(String cat) {
    final icon = _catIconFor(cat);
    if (icon.isNotEmpty) {
      return SmartImage(src: icon, size: 30);
    }
    return Text(getCatIcon(cat), style: const TextStyle(fontSize: 18));
  }

  Widget _categoryRail() {
    final cats = posCategories;
    final items = cats;
    return SizedBox(
      width: 70,
      child: Container(
        margin: const EdgeInsets.only(left: 12, bottom: 8),
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final cat = items[i];
            final selected = selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => setState(() => selectedCategory = cat),
                child: AnimatedScale(
                  scale: selected ? 1.05 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: const Color(0xFF34D399).withValues(alpha: .6), width: 2)
                          : null,
                    ),
                    child: Column(children: [
                      _catIconWidget(cat),
                      const SizedBox(height: 2),
                      Text(catLabel(cat),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: _isUrduCat(cat) ? 'Noto Naskh Arabic' : null,
                              fontSize: 8,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : const Color(0xFF475569))),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _productGrid() {
    final prods = filteredProducts;
    if (prods.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('\u{1F4E6}', style: TextStyle(fontSize: 34)),
          SizedBox(height: 6),
          Text('No products found', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        ]),
      );
    }
    final qtyMap = cartQtyByProductId();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 2, 12, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.52,
      ),
      itemCount: prods.length,
      itemBuilder: (_, i) {
        final p = prods[i];
        final pid = sOf(p['id']);
        final qty = qtyMap[pid] ?? 0;
        final selected = qty > 0;
        final justOrdered = orderedFeedback[pid] == true;
        final active = selected || justOrdered;
        return GestureDetector(
          onTapDown: (_) => _onPressStart(p),
          onTapUp: (_) => _onPressEnd(),
          onTapCancel: _onPressEnd,
          onTap: () => _onTapProduct(p),
          child: AnimatedScale(
            scale: justOrdered ? 1.06 : 1,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF059669).withValues(alpha: .16) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                  width: active ? 3 : 1,
                ),
                boxShadow: active
                    ? [BoxShadow(blurRadius: 14, spreadRadius: 1, color: const Color(0xFF059669).withValues(alpha: .4), offset: const Offset(0, 3))]
                    : const [BoxShadow(blurRadius: 3, color: Color(0x14000000))],
              ),
              child: Stack(clipBehavior: Clip.none, children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                          width: active ? 2.5 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: sOf(p['photo']).isNotEmpty
                            ? SmartImage(src: sOf(p['photo']), size: 100)
                            : Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(Icons.fastfood, color: Color(0xFF94A3B8), size: 40),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(p['name']?.toString() ?? '',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('${_fmtNum(numOf(p['price']))} PKR',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                  ],
                ),
                if (qty > 0)
                  Positioned(
                    top: -6, right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle),
                      child: Text('$qty', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _variantSheet() {
    return _sheet(Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(sOf(variantProduct?['name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        if (variantStep == 'flavors')
          ...? (variantProduct?['flavors'] as List?)?.map((f) {
            final m = Map<String, dynamic>.from(f as Map);
            return ListTile(
              title: Text(sOf(m['label'])),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => selectVariantFlavor(m),
            );
          }),
        if (variantStep == 'variants')
          ...? (variantFlavor?['variants'] as List?)?.map((v) {
            final m = Map<String, dynamic>.from(v as Map);
            return ListTile(
              title: Text('${sOf(m['label'])}  ${_fmtNum(numOf(m['price']))}'),
              onTap: () => addVariantToCart(variantProduct!, variantFlavor, m),
            );
          }),
        const SizedBox(height: 8),
        TextButton(onPressed: () => setState(() { showVariant = false; variantProduct = null; variantFlavor = null; }), child: const Text('Cancel')),
      ]),
    ));
  }

  Widget _sheet(Widget child) => Positioned.fill(
        child: Column(children: [
          Expanded(child: GestureDetector(onTap: _closeCartSheet, child: Container(color: Colors.black54))),
          child,
        ]),
      );

  void _closeCartSheet() {
    setState(() {
      showCart = false;
      showVariant = false;
    });
  }

  Widget _cartSheet() {
    final isDelivery = activeType == 'Delivery';
    final isTable = activeType == 'Table';
    final isTakeaway = activeType == 'Takeaway';
    return _sheet(Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Row(children: [
            Text(_cartSheetTitle(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
            const Spacer(),
            IconButton(onPressed: _closeCartSheet, icon: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (activeType != 'Delivery' && breadProducts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _breadChooser(),
                ),
              ],
              ...cart.map((i) => _cartItem(i)).toList(),
              const Divider(),
              if (isDelivery) ...[
                _customerAddressField(),
                GestureDetector(
                  onTap: _pickDeliveryLocation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: selectedZone.isNotEmpty ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selectedZone.isNotEmpty ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.location_on, size: 18, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedZone.isEmpty ? 'Select Delivery Location' : 'Location: $selectedZone  (${_fmtNum(numOf(_feeFromZone()))} PKR)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selectedZone.isNotEmpty ? const Color(0xFF059669) : const Color(0xFF475569)),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    ]),
                  ),
                ),
                if (selectedZone.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: editingOrder != null
                          ? updateOrder
                          : () => createOrder('Delivery', paid: false),
                      icon: Icon(
                          editingOrder != null ? Icons.save : Icons.shopping_cart_checkout,
                          color: Colors.white,
                          size: 20),
                      label: Text(
                          editingOrder != null ? 'Update Order' : 'Create Delivery Order',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                _field('Phone', _c('phone'), type: TextInputType.phone),
                _field('Delivery Fee', _c('fee'), type: TextInputType.number),
                _drop('Assign Rider (optional)', selectedRider, ['', ...ridersList], (v) => setState(() => selectedRider = v)),
              ] else if (isTable) ...[
                _field('Table No (optional)', _c('table')),
                _field('Customer Name (optional)', _c('cust')),
              ] else if (isTakeaway) ...[
                _field('Customer Name (optional)', _c('cust')),
              ] else ...[
                _field('Customer Name (optional)', _c('cust')),
                _field('Phone (optional)', _c('phone'), type: TextInputType.phone),
                _field('Address (optional)', _c('address')),
              ],
              _field('Notes (optional)', _c('notes')),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Column(children: [
            Row(children: [
              const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('$cartTotal PKR', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
            ]),
            const SizedBox(height: 10),
            if (isTakeaway)
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: () => createOrder('Takeaway', paid: false), style: _btn(const Color(0xFFF59E0B)), child: const Text('Pay Later'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => createOrder('Takeaway', paid: true), style: _btn(const Color(0xFF059669)), child: const Text('Paid'))),
              ])
            else if (isDelivery && selectedZone.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                child: const Text('Select delivery location to place order',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
              )
            else if (!isDelivery)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => createOrder(activeType, paid: false),
                  style: _btn(const Color(0xFF059669)),
                  child: Text('Create $activeType Order'),
                ),
              ),
          ]),
        ),
      ]),
    ));
  }

  void _openCart() {
    // For Table / Takeaway, first let the user pick Naan/Roti, then show cart.
    if (activeType != 'Delivery' && breadProducts.isNotEmpty) {
      _openBreadPicker().then((_) {
        if (mounted) setState(() => showCart = true);
      });
    } else {
      setState(() => showCart = true);
    }
  }

  Widget _breadChooser() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openBreadPicker,
          icon: const Text('\u{1FAD3}', style: TextStyle(fontSize: 16)),
          label: const Text('Choose Naan / Roti  (نان / روٹی)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Future<void> _openBreadPicker() async {
    final prods = breadProducts;
    if (prods.isEmpty) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نان / روٹی منتخب کریں',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: prods.length,
            itemBuilder: (_, i) {
              final p = prods[i];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: sOf(p['photo']).isNotEmpty
                      ? SmartImage(src: sOf(p['photo']), size: 40)
                      : Container(
                          width: 40,
                          height: 40,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.fastfood, color: Color(0xFF94A3B8), size: 18),
                        ),
                ),
                title: Text(sOf(p['name']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: Text('${_fmtNum(numOf(p['price']))} PKR',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF059669))),
                trailing: const Icon(Icons.add_circle, color: Color(0xFF059669)),
                onTap: () {
                  addPlainToCart(p);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _cartItem(Map<String, dynamic> i) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: sOf(i['photo']).isNotEmpty
              ? SmartImage(src: sOf(i['photo']), size: 44)
              : Container(width: 44, height: 44, color: const Color(0xFFF1F5F9), child: const Icon(Icons.fastfood, color: Color(0xFF94A3B8))),
        ),
        title: Row(children: [
          Expanded(
            child: Text('${i['name']} ${sOf(i['flavor']).isNotEmpty ? '(${i['flavor']})' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () => _editCartName(i),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.edit, size: 13, color: Color(0xFF94A3B8)),
            ),
          ),
        ]),
        subtitle: Row(children: [
          Text('${_fmtNum(numOf(i['price']))} PKR', style: const TextStyle(fontSize: 11, color: Color(0xFF059669))),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _editCartPrice(i),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.edit, size: 13, color: Color(0xFF94A3B8)),
            ),
          ),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(onPressed: () => updateCartQty(sOf(i['itemId']), -1), icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626))),
          Text('${i['quantity']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          IconButton(onPressed: () => updateCartQty(sOf(i['itemId']), 1), icon: const Icon(Icons.add_circle_outline, color: Color(0xFF059669))),
        ]),
      );

  Widget _field(String label, TextEditingController c, {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: c,
        keyboardType: type,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          filled: true, fillColor: const Color(0xFFF8FAFC),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF059669))),
        ),
      ),
    );
  }

  Widget _drop(String label, String value, List<String> opts, ValueChanged<String> onChanged, {Map<String, String>? labels}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: DropdownButton<String>(
            value: opts.contains(value) ? value : opts.first,
            isDense: true, underline: const SizedBox(),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            items: opts.map((o) => DropdownMenuItem(value: o, child: Text(labels?[o] ?? (o.isEmpty ? 'None' : o)))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ]),
    );
  }

  // --------------------------------------------------- delivery customers sync
  List<Map<String, dynamic>> get deliveryCustomers =>
      customers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((c) {
        final id = sOf(c['id']);
        final name = sOf(c['name']);
        final phone = sOf(c['phone']);
        final addr = sOf(c['address']);
        return id.isNotEmpty && (name.isNotEmpty || phone.isNotEmpty || addr.isNotEmpty);
      }).toList();

  List<Map<String, dynamic>> _matchCustomers(String q) {
    final term = q.trim().toLowerCase();
    if (term.length < 2) return [];
    final out = <Map<String, dynamic>>[];
    for (final c in deliveryCustomers) {
      final addr = sOf(c['address']).toLowerCase();
      final name = sOf(c['name']).toLowerCase();
      final phone = sOf(c['phone']).toLowerCase();
      if (addr.contains(term) || name.contains(term) || phone.contains(term)) {
        out.add(c);
      }
      if (out.length >= 5) break;
    }
    return out;
  }

  Widget _customerAddressField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _c('address'),
          onChanged: (v) => setState(() {
            _addrSuggestions = _matchCustomers(v);
            selectedCustomerId = '';
          }),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Address (House / Area)',
            labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            filled: true, fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF059669)),
            suffixIcon: _c('address').text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _c('address').clear();
                      setState(() => _addrSuggestions = []);
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF059669))),
          ),
        ),
        if (_addrSuggestions.isNotEmpty)
          ..._addrSuggestions.map((c) => _addrSuggestionTile(c)),
      ]),
    );
  }

  Widget _addrSuggestionTile(Map<String, dynamic> c) {
    final addr = sOf(c['address']);
    final name = sOf(c['name']);
    final phone = sOf(c['phone']);
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF059669)),
      ),
      child: Row(children: [
        const Icon(Icons.person_pin_circle, color: Color(0xFF059669), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${name.isNotEmpty ? '$name · ' : ''}${addr.isNotEmpty ? addr : '\u2014'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
            ),
            if (phone.isNotEmpty)
              Text(phone, style: const TextStyle(fontSize: 11, color: Color(0xFF059669))),
          ]),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _c('address').text = addr;
              if (phone.isNotEmpty && _c('phone').text.trim().isEmpty) {
                _c('phone').text = phone;
              }
              selectedCustomerId = sOf(c['id']);
              _addrSuggestions = [];
            });
            if (addr.isNotEmpty) _pickDeliveryLocation();
          },
          child: Text('Select', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
        ),
      ]),
    );
  }

  Future<void> _pickDeliveryLocation() async {
    final zones = deliveryZones;
    if (zones.isEmpty) return;
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delivery Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: zones.length,
            itemBuilder: (_, i) {
              final z = zones[i];
              final sel = selectedZone == sOf(z['name']);
              return ListTile(
                title: Text(sOf(z['name'])),
                subtitle: Text('Delivery Fee: ${_fmtNum(numOf(z['deliveryFee']))} PKR'),
                trailing: sel ? const Icon(Icons.check, color: Color(0xFF059669)) : null,
                onTap: () => Navigator.pop(ctx, sOf(z['name'])),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
    if (pick != null && mounted) {
      setState(() {
        selectedZone = pick;
        final z = zones.firstWhere((zz) => sOf(zz['name']) == pick, orElse: () => {});
        if (z.isNotEmpty) _c('fee').text = _fmtNum(numOf(z['deliveryFee']));
      });
    }
  }

  ButtonStyle _btn(Color c) => ElevatedButton.styleFrom(
      backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)));

  Color _viewColor(String v) {
    switch (v) {
      case 'Takeaway':
        return const Color(0xFFF59E0B);
      case 'Table':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color _tabGlowColor(String k) {
    switch (k) {
      case 'active':
        return const Color(0xFF2563EB);
      case 'assigned':
        return const Color(0xFF7C3AED);
      case 'paid':
        return const Color(0xFF059669);
      case 'due':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color _orderStatusColor(Map<String, dynamic> o) {
    if (_isCancelled(o)) return const Color(0xFFDC2626);
    if (_isDueStatus(o)) return const Color(0xFFF59E0B);
    if (_isDeliveryPaid(o) || _isDeliveredOrDone(o)) return const Color(0xFF059669);
    if (sOf(o['deliveryAgent']).trim().isNotEmpty) return const Color(0xFF7C3AED);
    return const Color(0xFF2563EB);
  }

  Widget _ordersDateFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text('Date:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
              ),
              ..._ordersRangeChips(),
            ],
          ),
        ),
        if (ordersDateRange == 'custom')
          Row(children: [
            Expanded(
              child: _datePickBtn('From: ${_fmtDatePicker(ordersFromDate)}', () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: ordersFromDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => ordersFromDate = p);
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _datePickBtn('To: ${_fmtDatePicker(ordersToDate)}', () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: ordersToDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => ordersToDate = p);
              }),
            ),
            if (ordersFromDate != null || ordersToDate != null)
              IconButton(
                onPressed: () => setState(() { ordersFromDate = null; ordersToDate = null; }),
                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Reset custom dates',
              ),
          ]),
      ]),
    );
  }

  List<Widget> _ordersRangeChips() {
    const ranges = [
      ('today', 'Today'),
      ('yesterday', 'Yesterday'),
      ('last7', '7 Days'),
      ('last30', '30 Days'),
      ('month', 'Month'),
      ('all', 'All'),
      ('custom', 'Custom'),
    ];
    return ranges.map((r) {
      final active = ordersDateRange == r.$1;
      final c = active ? const Color(0xFF0EA5E9) : const Color(0xFF64748B);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(r.$2),
          selected: active,
          onSelected: (_) => setState(() => ordersDateRange = r.$1),
          selectedColor: const Color(0xFF0EA5E9),
          backgroundColor: const Color(0xFFF1F5F9),
          labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : c),
          side: BorderSide(color: active ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
      );
    }).toList();
  }

  String _fmtDatePicker(DateTime? d) => d == null
      ? 'Any'
      : '${two(d.day)}/${two(d.month)}/${d.year}';

  Widget _datePickBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)))),
          ]),
        ),
      );

  // ---------------------------------------------- full-screen orders screen
  Widget _ordersScreen() {
    final views = ['Delivery', 'Takeaway', 'Table'];
    final subTabs = ordersView == 'Delivery'
        ? [
            const ['active', 'Active'],
            const ['assigned', 'Assigned'],
            const ['paid', 'Paid'],
            const ['due', 'Due'],
            const ['cancelled', 'Cancelled'],
          ]
        : ordersView == 'Takeaway'
            ? [
                const ['payLater', 'Pay Later'],
                const ['due', 'Due'],
                const ['paid', 'Paid'],
                const ['cancelled', 'Cancelled'],
              ]
            : [
                const ['active', 'Active'],
                const ['due', 'Due'],
                const ['paid', 'Paid'],
                const ['cancelled', 'Cancelled'],
              ];
    final list = filteredVisibleOrders;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(children: [
              const Text('Nashta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
              const Spacer(),
              if (offline || syncing || lastSyncOk != null) ...[
                _syncIndicator(),
                const SizedBox(width: 4),
              ],
              if (_isManager())
                IconButton(
                  onPressed: () => setState(() {
                    selectMode = !selectMode;
                    _selectedOrderIds.clear();
                    expandedOrderId = null;
                  }),
                  icon: Icon(
                    selectMode ? Icons.close : Icons.checklist_rtl,
                    color: selectMode ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                  tooltip: selectMode ? 'Exit Select' : 'Select Multi Orders',
                ),
              IconButton(onPressed: _closeOrders, icon: const Icon(Icons.close, color: Color(0xFFDC2626))),
            ]),
          ),
          if (selectMode && _isManager()) _bulkBar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: views.map((v) {
              final sel = ordersView == v;
              final color = _viewColor(v);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() { ordersView = v; ordersSubTab = subTabs.first[0]; }),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: sel ? color : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                    child: Text(v, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sel ? Colors.white : const Color(0xFF475569))),
                  ),
                ),
              );
            }).toList()),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: subTabs.map((t) {
                final sel = ordersSubTab == t[0];
                final tc = _tabGlowColor(t[0]);
                return GestureDetector(
                  onTap: () => setState(() => ordersSubTab = t[0]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? tc : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? tc : const Color(0xFFE2E8F0), width: sel ? 1.4 : 1),
                      boxShadow: [
                        BoxShadow(color: tc.withValues(alpha: sel ? 0.45 : 0.18), blurRadius: sel ? 12 : 7, spreadRadius: sel ? 1 : 0.2, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: Text(t[1], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: sel ? Colors.white : tc)),
                  ),
                );
              }).toList()),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: TextField(
              onChanged: (v) => setState(() => ordersSearch = v),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: 'Search order #, customer, phone, address, rider, table, location...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                suffixIcon: ordersSearch.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () => setState(() => ordersSearch = ''),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
              ),
            ),
          ),
          _ordersDateFilterBar(),
          if (selectMode && _isManager())
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Text('Tap orders to select. Then use the bar above for bulk actions.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No orders', style: TextStyle(color: Color(0xFF94A3B8))))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _orderCard(list[i]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _bulkBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFEEF2FF),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${_selectedOrderIds.length} / ${filteredVisibleOrders.length} selected',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
          ),
          TextButton(
            onPressed: () => setState(() { selectMode = false; _selectedOrderIds.clear(); }),
            child: Text('Done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
          ),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _actBtn('Select All', const Color(0xFF0EA5E9),
              filteredVisibleOrders.isEmpty ? null : _toggleSelectAll, glow: true),
          _actBtn('Delete', const Color(0xFFDC2626), _selectedOrderIds.isEmpty ? null : _bulkDelete, glow: true),
          _actBtn('Assign', const Color(0xFF2563EB), _selectedOrderIds.isEmpty ? null : _bulkRider, glow: true),
          _actBtn('Mark Paid', const Color(0xFF059669), _selectedOrderIds.isEmpty ? null : _bulkMarkPaid, glow: true),
          _actBtn('Due', const Color(0xFFF59E0B), _selectedOrderIds.isEmpty ? null : _bulkMarkDue, glow: true),
        ]),
      ]),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final id = sOf(o['id']);
    final num = o['orderNumber']?.toString() ?? id;
    final type = sOf(o['orderType']);
    final total = numOf(o['total'] ?? o['amount']);
    final cust = sOf(o['customerName']);
    final ot = sOf(o['orderTaker']);
    final loc = sOf(o['serviceType']);
    final addr = sOf(o['address']);
    final expanded = expandedOrderId == o['id'];
    final sel = _isManager() && selectMode && _selectedOrderIds.contains(id);
    final glow = _orderStatusColor(o);
    final fading = _fadingIds.contains(id);
    return AnimatedOpacity(
      opacity: fading ? 0 : 1,
      duration: const Duration(milliseconds: 350),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? const Color(0xFF2563EB) : glow, width: sel ? 2 : 1.4),
          boxShadow: [
            BoxShadow(color: glow.withValues(alpha: 0.28), blurRadius: 10, spreadRadius: 0.8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [
          InkWell(
            onTap: () {
              if (selectMode && _isManager()) {
                setState(() {
                  if (_selectedOrderIds.contains(id)) {
                    _selectedOrderIds.remove(id);
                  } else {
                    _selectedOrderIds.add(id);
                  }
                });
              } else {
                setState(() => expandedOrderId = expanded ? null : o['id']);
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(children: [
                if (selectMode && _isManager())
                  Icon(sel ? Icons.check_circle : Icons.radio_button_off,
                      color: sel ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                      size: 26)
                else
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF059669),
                    child: Icon(Icons.delivery_dining, size: 20, color: Colors.white),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          cust.isNotEmpty ? cust : 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _typePill(type),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      '${type.isNotEmpty ? '$type \u00B7 ' : ''}${_isManager() && ot.isNotEmpty ? '$ot \u00B7 ' : ''}${time12(o['createdAt'], utcOffset: tzOffset)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ]),
                ),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${_fmtNum(total)} PKR',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: glow)),
                  if (o['localPending'] == true)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFB45309), borderRadius: BorderRadius.circular(100)),
                      child: const Text('PENDING SYNC',
                          style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  if (_isPaidOrDone(o))
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFF059669), borderRadius: BorderRadius.circular(100)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text('PAID',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                      ]),
                    ),
                ]),
              ]),
            ),
          ),
          if (loc.isNotEmpty || addr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (loc.isNotEmpty)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(loc,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    ),
                  ]),
                if (addr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.home_work_outlined, size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(addr,
                            maxLines: expanded ? null : 2,
                            overflow: expanded ? null : TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      ),
                    ]),
                  ),
              ]),
            ),
          if (expanded) _orderDetail(o),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(children: [
              const Icon(Icons.receipt_long, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('Order #$num',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
              const Spacer(),
              if (selectMode && _isManager())
                const Text('Tap to select',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _orderDetail(Map<String, dynamic> o) {
    final items = (o['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final type = sOf(o['orderType']);
    final rider = sOf(o['deliveryAgent']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (rider.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.delivery_dining, size: 14, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 4),
              Expanded(child: _glowText(rider, color: const Color(0xFF1D4ED8), size: 13)),
            ]),
          ),
        ...items.map((it) => Row(children: [
              Expanded(child: Text('${it['quantity']}x ${it['name']} ${sOf(it['flavor']).isNotEmpty ? '(${it['flavor']})' : ''}')),
              Text(_fmtNum(numOf(it['price']) * numOf(it['quantity']))),
            ])),
        if (sOf(o['address']).isNotEmpty) Text('Address: ${o['address']}', style: const TextStyle(fontSize: 12)),
        if (sOf(o['phone']).isNotEmpty) Text('Phone: ${o['phone']}', style: const TextStyle(fontSize: 12)),
        if (type == 'Delivery' && numOf(o['deliveryFee']) > 0)
          Text('Delivery Charges: ${_fmtNum(numOf(o['deliveryFee']))} PKR', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
        if (sOf(o['tableNumber']).isNotEmpty) Text('Table: ${o['tableNumber']}', style: const TextStyle(fontSize: 12)),
        if (sOf(o['notes']).isNotEmpty) Text('Notes: ${o['notes']}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (type == 'Delivery' && !_isDeliveryPaid(o) && !_isDeliveredOrDone(o))
            _actBtn(rider.isEmpty ? 'Assign Rider' : 'Change Rider', const Color(0xFF2563EB), () => _pickRiderAndAssign(o)),
          if (_isManager() && type == 'Delivery' && !_isDeliveryPaid(o) && !_isDeliveryDue(o) && !_isDeliveredOrDone(o)) ...[
            _actBtn('Mark Paid', const Color(0xFF059669), () => markPaid(o)),
            _actBtn('Due', const Color(0xFFF59E0B), () => markDue(o)),
          ],
          if (_isManager() && type == 'Delivery' && _isDeliveryDue(o))
            _actBtn('Mark Paid', const Color(0xFF059669), () => markPaid(o)),
          if (type != 'Delivery' && !_isPaidOrDone(o)) ...[
            _actBtn('Mark Paid', const Color(0xFF059669), () => markPaid(o)),
            if (!_isDueStatus(o))
              _actBtn('Mark Due', const Color(0xFFF59E0B), () => markDue(o)),
          ],
          if (_isManager() && type != 'Delivery' && _isDueStatus(o))
            _actBtn('Mark Paid', const Color(0xFF059669), () => markPaid(o)),
          _actBtn('Print', const Color(0xFF0EA5E9), () async {
            try { await printOrderBT(o); toast('Printed'); } catch (e) { toast('$e', seconds: 6); }
          }),
          _actBtn('Edit', const Color(0xFF7C3AED), () => _editOrder(o)),
          _actBtn('Cancel', const Color(0xFFDC2626), () => cancelOrder(o)),
          if (_isManager())
            _actBtn('Delete', const Color(0xFFB91C1C), () => _deleteOrder(o)),
        ]),
      ]),
    );
  }

  Widget _typePill(String type) {
    String label;
    Color c;
    IconData icon;
    switch (type) {
      case 'Delivery':
        label = 'DELIVERY';
        c = const Color(0xFF1D4ED8);
        icon = Icons.delivery_dining;
        break;
      case 'Dine-In':
        label = 'TABLE';
        c = const Color(0xFF7C3AED);
        icon = Icons.table_restaurant;
        break;
      case 'Takeaway':
        label = 'TAKEAWAY';
        c = const Color(0xFFF59E0B);
        icon = Icons.takeout_dining;
        break;
      default:
        label = type.toUpperCase().isEmpty ? 'ORDER' : type.toUpperCase();
        c = const Color(0xFF64748B);
        icon = Icons.receipt_long;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: c,
                letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _glowText(String s,
          {required Color color,
          double size = 13,
          FontWeight weight = FontWeight.w900,
          int? maxLines}) =>
      Text(
        s,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 0)),
          ],
        ),
      );

  Widget _actBtn(String label, Color c, VoidCallback? onTap, {bool glow = false}) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
            backgroundColor: c,
            foregroundColor: Colors.white,
            disabledBackgroundColor: c.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: glow ? 4 : 2,
            shadowColor: onTap == null ? Colors.transparent : c.withValues(alpha: 0.8)),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      );

  // expand state
  dynamic expandedOrderId;

  Widget _toastOverlay() => Positioned(
        bottom: 90,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
          child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      );

  Future<void> handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('deliveryToken');
    await prefs.remove('deliveryUser');
    await prefs.remove('nashtaToken');
    await prefs.remove('nashtaUser');
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _editOrder(Map<String, dynamic> o) {
    final raw = (o['items'] as List?)?.whereType<Map>().toList() ?? [];
    final list = raw.map((e) {
      final m = Map<String, dynamic>.from(e);
      final pid = sOf(m['productId']).isNotEmpty ? sOf(m['productId']) : sOf(m['id']);
      m['id'] = pid;
      m['productId'] = pid;
      m['itemId'] = '${pid}_${sOf(m['flavor'])}_${DateTime.now().microsecondsSinceEpoch}';
      return m;
    }).toList();

    setState(() {
      showOrdersScreen = false;
      editingOrder = Map<String, dynamic>.from(o);
      carts['Delivery'] = list;
      _c('cust').clear();
      _c('phone').text = sOf(o['phone']);
      _c('address').text = sOf(o['address']);
      _c('notes').text = sOf(o['notes']);
      _c('fee').text = numOf(o['deliveryFee']) > 0 ? numOf(o['deliveryFee']).toStringAsFixed(0) : '';
      _c('zone').clear();
      selectedZone = sOf(o['serviceType']);
      selectedRider = sOf(o['deliveryAgent']);
      selectedCustomerId = '';
      _addrSuggestions = [];
      showCart = true;
    });
    toast('Editing order');
  }

  String _cartSheetTitle() {
    final o = editingOrder;
    if (o == null) return '$activeType Order';
    final n = sOf(o['orderNumber']);
    if (n.isNotEmpty) return 'Edit Order #$n';
    final id = sOf(o['id']);
    return 'Edit Order #${id.length > 6 ? id.substring(0, 6) : id}';
  }

  Future<void> updateOrder() async {
    final o = editingOrder;
    if (o == null) return;
    final list = carts['Delivery']!;
    if (list.isEmpty) {
      toast('Cart is empty');
      return;
    }
    if (_c('address').text.trim().isEmpty) {
      toast('Delivery address required');
      return;
    }
    if (selectedZone.trim().isEmpty && _c('zone').text.trim().isEmpty) {
      toast('Delivery area required');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : (sOf(user['username']).isNotEmpty ? sOf(user['username']) : sOf(user['email']));
      final status = selectedRider.trim().isNotEmpty ? 'Riders Assigned' : 'Pending';
      final deliveryFee = double.tryParse(_c('fee').text.trim()) ?? 0;
      final String paymentStatus;
      if (_isDeliveryPaid(o)) {
        paymentStatus = 'Paid';
      } else if (_isDeliveryDue(o)) {
        paymentStatus = 'Due';
      } else {
        paymentStatus = 'Pending';
      }
      final payload = <String, dynamic>{
        'items': list
            .map((i) => {
                  'productId': i['id'],
                  'name': i['name'],
                  'price': numOf(i['price']),
                  'quantity': numOf(i['quantity']),
                  'code': i['code'] ?? '',
                  'weight': i['weight'] ?? '',
                  'flavor': i['flavor'] ?? '',
                })
            .toList(),
        'orderType': 'Delivery',
        'source': _orderSource,
        'customerName': _c('cust').text.trim().isEmpty
            ? sOf(o['customerName'])
            : _c('cust').text.trim(),
        'phone': _c('phone').text.trim(),
        'address': _c('address').text.trim(),
        'notes': _c('notes').text.trim(),
        'orderTaker': me,
        'waiter': me,
        'status': status,
        'paymentStatus': paymentStatus,
        'serviceType': selectedZone.isNotEmpty ? selectedZone : _c('zone').text.trim(),
        'deliveryAgent': selectedRider,
        'deliveryFee': deliveryFee,
        'total': cartTotal,
      };
      await _offlineAwareOrderCall(o, 'PUT', payload);
      if (!mounted) return;
      setState(() {
        carts['Delivery'] = [];
        for (final k in ['cust', 'phone', 'address', 'table', 'notes', 'fee', 'zone']) {
          _c(k).clear();
        }
        selectedZone = '';
        selectedRider = '';
        selectedCustomerId = '';
        _addrSuggestions = [];
        showCart = false;
        editingOrder = null;
      });
      toast(offline
          ? 'Order updated (offline - auto-sync ✅)'
          : 'Order updated \u2705');
      await _refreshOrdersOnly();
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
