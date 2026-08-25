import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'bmp_receipt.dart' as bmp;
import 'bt_service.dart';
import 'escpos.dart' as esc;
import 'login_screen.dart';
import 'session.dart';

const Map<String, String> categoryIcons = {
  'All': '🎯', 'Chicken': '🍗', 'Steak': '🥩', 'Fish': '🐟', 'Salad': '🥗',
  'Juice': '🧃', 'Dessert': '🍰', 'Burger': '🍔', 'Pizza': '🍕', 'Soup': '🍜',
  'Biryani': '🍚', 'Mutton': '🐑', 'Beef': '🥩', 'BBQ': '🔥', 'Grill': '🥩',
  'Chinese': '🥟', 'Rice': '🍚', 'Roll': '🌯', 'Wrap': '🌯', 'Tea': '☕',
  'Coffee': '☕', 'Breakfast': '🍳', 'Sandwich': '🥪', 'Pasta': '🍝',
  'Noodles': '🍜', 'Ice Cream': '🍨', 'Smoothie': '🥤', 'Combo': '🎯',
  'Special': '⭐', 'Tikka': '🥘', 'Karhai': '🍲', 'Drinks': '🥤',
  'Beverage': '🥤', 'Shawarma': '🌯', 'Fries': '🍟', 'Mandi': '🍛',
  'Handi': '🍲', 'Kebab': '🥙', 'Nihari': '🍲', 'Haleem': '🥣', 'Dosa': '🥞',
  'Curry': '🍛', 'Dal': '🥣', 'Paratha': '🫓', 'Roti': '🫓', 'Bread': '🍞',
  'Seafood': '🦐', 'Platter': '🍽️', 'Family': '👨‍👩‍👧‍👦', 'Deal': '💥',
  'Addon': '➕', 'Extra': '➕', 'Dips': '🥫', 'Sauce': '🥫', 'Topping': '🧀',
  'Cheese': '🧀', 'Mashallah': '🌟',
};

const String mashallahCategory = 'مَا شَاءَ ٱللَّٰهُ';

String getCatIcon(String? name) {
  if (name == null || name.isEmpty) return '📁';
  if (categoryIcons[name] != null) return categoryIcons[name]!;
  final lower = name.toLowerCase();
  for (final e in categoryIcons.entries) {
    if (e.key.toLowerCase() == lower) return e.value;
  }
  for (final e in categoryIcons.entries) {
    final k = e.key.toLowerCase();
    if (lower.contains(k) || k.contains(lower)) return e.value;
  }
  return '📁';
}

String sOf(dynamic v) => v == null ? '' : v.toString();
double nOf(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}

double numOf(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

String two(int n) => n.toString().padLeft(2, '0');

String time12(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return '';
  var h = d.hour % 12;
  if (h == 0) h = 12;
  return '$h:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String dateTime12(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return '';
  var h = d.hour % 12;
  if (h == 0) h = 12;
  return '${two(d.year)}/${two(d.month)}/${two(d.day)} '
      '$h:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String formatDuration(int ms) {
  if (ms < 0) ms = 0;
  final h = ms ~/ 3600000;
  final m = (ms % 3600000) ~/ 60000;
  final sec = (ms % 60000) ~/ 1000;
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

String tableLabel(Map t) {
  final l = sOf(t['label']);
  if (l.isNotEmpty) return l;
  final nm = sOf(t['name']);
  if (nm.isNotEmpty) return nm;
  final num = sOf(t['number']);
  if (num.isNotEmpty) return num;
  return 'Table ${sOf(t['id'])}';
}

class SmartImage extends StatelessWidget {
  final String src;
  final double size;
  const SmartImage({super.key, required this.src, required this.size});

  /// Cache of decoded base64 images keyed by their source string. Without
  /// this every grid rebuild created a brand-new MemoryImage from the same
  /// bytes - Flutter re-decoded it, showed a blank frame in between and the
  /// item boxes appeared to blink on every refresh.
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
    return Image(image: p, width: size, height: size, fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: const Color(0xFFE0E7FF),
        alignment: Alignment.center,
        child: Text('📦', style: TextStyle(fontSize: size * 0.5)),
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

  bool get isTakeawayOnly => sOf(user['role']) == 'Takeaway Order Taker';
  bool get isTableOnly => sOf(user['role']) == 'Table Order Taker';
  bool get isBothTypes => !isTakeawayOnly && !isTableOnly;
  bool get isTakeawayOrderTaker => isTakeawayOnly;
  bool get isAdminOrderTaker => sOf(user['role']) == 'Admin Order Taker';

  List<dynamic> products = [];
  List<dynamic> categories = [];
  List<dynamic> tables = [];
  List<dynamic> orders = [];
  List<dynamic> mashallahSlots = [];
  Map<String, dynamic> settings = {};

  String activeType = 'Dine-In';
  String search = '';
  String selectedCategory = 'All';
  List<Map<String, dynamic>> cart = [];

  bool showCart = false;
  bool showOrdersPopup = false;
  bool showTakeawayOrdersPopup = false;
  bool showPaymentPopup = false;
  bool initialLoading = true;

  Map<String, dynamic>? variantProduct;
  Map<String, dynamic>? variantFlavor;
  String variantStep = 'flavors';

  final customerNameCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  final cashCtrl = TextEditingController();
  String tableNumber = '';
  String paymentMethod = 'Cash';

  Map<String, dynamic>? editOrder;
  List<Map<String, dynamic>> editCart = [];
  String editAddSearch = '';

  String ordersTab = 'new';
  String takeawayOrdersTab = 'pay_later';
  dynamic expandedOrderId;
  bool popupRefreshing = false;

  /// Ticks every second WITHOUT rebuilding the whole screen - only widgets
  /// wrapped in a ValueListenableBuilder listen to this. The old approach
  /// (setState on the entire state) re-rendered the items grid 60x/min,
  /// which made every item box blink/flicker.
  final ValueNotifier<DateTime> _now = ValueNotifier<DateTime>(DateTime.now());

  PrinterInfo? btInfo;
  bool btConnected = false;
  bool btConnecting = false;
  bool showPrinterSheet = false;
  List<PrinterInfo> pairedPrintersList = [];
  bool scanningPrinters = false;
  String connectingMac = '';

  /// Local BT-printer setting overrides (same keys as the web Bluetooth
  /// Printer Settings tab). Merged over server [settings] when printing and
  /// persisted in SharedPreferences so they survive restarts.
  Map<String, dynamic> btOverrides = {};
  static const _btOverridesKey = 'btPrinterOverrides';

  Map<String, dynamic> get btSettings => <String, dynamic>{...settings, ...btOverrides};

  final Map<String, TextEditingController> _btTextCtrls = {};

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

  Future<void> _resetBtSettings() async {
    setState(() => btOverrides = {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_btOverridesKey);
    toast('Bluetooth printer settings reset to defaults');
  }

  String message = '';
  Timer? _messageTimer;
  Timer? _loadTimer;
  Timer? _tickTimer;
  Timer? _popupTimer;
  Timer? _pressTimer;
  bool _pressFired = false;
  final Set<Timer> _feedbackTimers = {};
  Map<String, bool> orderedFeedback = {};

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (isTakeawayOnly) activeType = 'Take Away';
    else if (isTableOnly) activeType = 'Dine-In';
    _loadData();
    _loadBtOverrides();
    _loadTimer = Timer.periodic(
        const Duration(seconds: 20), (_) => _loadData(silent: true));
    _tickTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => _now.value = DateTime.now());
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _tickTimer?.cancel();
    _popupTimer?.cancel();
    _messageTimer?.cancel();
    _pressTimer?.cancel();
    for (final t in _feedbackTimers) {
      t.cancel();
    }
    _now.dispose();
    customerNameCtrl.dispose();
    notesCtrl.dispose();
    searchCtrl.dispose();
    cashCtrl.dispose();
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
    if (fmt.contains('HH')) {
      fmt = '${fmt.replaceFirst('HH', 'hh')} A';
    } else if (fmt.contains('hh') && !fmt.contains('A')) {
      fmt = '$fmt A';
    }
    sets['receiptDateTimeFormat'] = fmt;
    return sets;
  }

  /// True when the freshly fetched payload is identical to what is already
  /// on screen. Used by silent background refreshes so we never rebuild the
  /// items grid for no reason (a full rebuild re-decodes every base64 photo
  /// and makes all item boxes visibly blink).
  bool _sameAsOnScreen(List<dynamic> r) {
    String sig(dynamic v) => v == null ? 'null' : jsonEncode(v);
    return sig(categories) == sig(r[0]) &&
        sig(products) == sig(r[1]) &&
        sig(tables) == sig(r[2]) &&
        sig(orders) == sig(r[3]) &&
        sig(settings) == sig(_normSettings(r[4])) &&
        sig(mashallahSlots) == sig(r[5]);
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      final results = await Future.wait([
        _fetch('/pos/categories').catchError((_) => null),
        _fetch('/pos/products').catchError((_) => null),
        _fetch('/pos/tables').catchError((_) => null),
        _fetch('/pos/orders').catchError((_) => null),
        _fetch('/settings').catchError((_) => null),
        _fetch('/pos/mashallah-slots').catchError((_) => null),
      ]);
      if (!mounted) return;
      if (silent && initialLoading == false && _sameAsOnScreen(results)) {
        return;
      }
      setState(() {
        if (results[0] is List) categories = results[0] as List<dynamic>;
        if (results[1] is List) products = results[1] as List<dynamic>;
        if (results[2] is List) tables = results[2] as List<dynamic>;
        if (results[3] is List) orders = results[3] as List<dynamic>;
        if (results[4] is Map) settings = _normSettings(results[4]);
        if (results[5] is List) mashallahSlots = results[5] as List<dynamic>;
        initialLoading = false;
      });
      if (!silent && results[2] == null) {
        toast('Could not load tables from server - check connection or re-login');
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() => initialLoading = false);
        toast(e.toString());
      }
    }
  }

  Future<void> _refreshOrdersOnly({bool showSpin = false}) async {
    if (showSpin) setState(() => popupRefreshing = true);
    try {
      final ords = await _fetch('/pos/orders');
      if (ords is List && mounted) setState(() => orders = ords);
    } catch (e) {
      if (!showSpin) toast(e.toString());
    } finally {
      if (showSpin) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => popupRefreshing = false);
        });
      }
    }
  }

  void _setPopupTimer() {
    _popupTimer?.cancel();
    if (showOrdersPopup) {
      _refreshOrdersOnly();
      _popupTimer = Timer.periodic(
          const Duration(seconds: 2), (_) => _refreshOrdersOnly());
    }
  }

  // ------------------------------------------------------------ computed --

  List<Map<String, dynamic>> get mashallahProducts {
    final out = <Map<String, dynamic>>[];
    for (final slot in mashallahSlots) {
      if (slot is! Map) continue;
      final pid = sOf(slot['productId']);
      for (final p in products) {
        if (p is Map && sOf(p['id']) == pid) {
          out.add(Map<String, dynamic>.from(p));
          break;
        }
      }
    }
    return out;
  }

  List<Map<String, dynamic>> get filteredProducts {
    final term = search.toLowerCase().trim();
    bool matches(Map p) =>
        term.isEmpty ||
        sOf(p['name']).toLowerCase().contains(term) ||
        sOf(p['category']).toLowerCase().contains(term) ||
        sOf(p['code']).toLowerCase().contains(term) ||
        sOf(p['id']).toLowerCase().contains(term);
    Iterable<Map<String, dynamic>> cast(List<dynamic> l) =>
        l.whereType<Map>().map((e) => Map<String, dynamic>.from(e));
    if (selectedCategory == mashallahCategory) {
      return mashallahProducts.where(matches).toList();
    }
    return cast(products)
        .where((p) =>
            (selectedCategory == 'All' || sOf(p['category']) == selectedCategory) &&
            matches(p))
        .toList();
  }

  List<String> get allCategories {
    final names = <String>[];
    for (final c in categories) {
      if (c is Map && sOf(c['name']).isNotEmpty) names.add(sOf(c['name']));
    }
    return ['All', mashallahCategory, ...names];
  }

  Map<String, dynamic>? categoryByName(String name) {
    for (final c in categories) {
      if (c is Map && sOf(c['name']) == name) return Map<String, dynamic>.from(c);
    }
    return null;
  }

  String _norm(String v) => v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Set<String> get occupiedTables {
    final out = <String>{};
    for (final o in orders) {
      if (o is! Map) continue;
      final type = sOf(o['orderType']);
      final st = _norm(sOf(o['status']));
      if (type != 'Dine-In') continue;
      if (st == 'completed' || st == 'payment collected' || st == 'cancelled') {
        continue;
      }
      final t = _norm(sOf(o['tableNumber']));
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  List<Map<String, dynamic>> get availableDineInTables {
    final occ = occupiedTables;
    return tables.whereType<Map>().map((t0) {
      final t = Map<String, dynamic>.from(t0);
      t['isOccupied'] =
          occ.contains(_norm(tableLabel(t))) ||
              _norm(sOf(t['status'])) == 'reserved';
      return t;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get freeTablesBySection {
    final free =
        availableDineInTables.where((t) => t['isOccupied'] != true).toList();
    return {
      'floor': free.where((t) => (sOf(t['section']).isEmpty ? 'Floor' : sOf(t['section'])) == 'Floor').toList(),
      'outside': free.where((t) => (sOf(t['section']).isEmpty ? 'Floor' : sOf(t['section'])) == 'Outside').toList(),
    };
  }

  Set<String> get _myNames => {
        for (final v in [user['name'], user['username'], user['email']])
          if (sOf(v).trim().isNotEmpty) sOf(v).trim().toLowerCase()
      };

  bool isMyOrder(Map o) {
    final mine = _myNames;
    for (final key in ['orderTaker', 'waiter']) {
      final t = _norm(sOf(o[key]));
      if (t.isNotEmpty && mine.contains(t)) return true;
    }
    return false;
  }

  bool isServedOrder(Map o) =>
      _norm(sOf(o['status'])) == 'served' || sOf(o['servedAt']).isNotEmpty;

  bool isCancelledOrder(Map o) =>
      _norm(sOf(o['status'])) == 'cancelled' || sOf(o['cancelledAt']).isNotEmpty;

  bool isPaidOrDone(Map o) {
    final st = _norm(sOf(o['status']));
    final p = _norm(sOf(o['paymentStatus']));
    return st == 'completed' || st == 'payment collected' || p == 'paid';
  }

  List<Map<String, dynamic>> myOrdersBy(bool Function(Map) filter) => orders
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((o) =>
          sOf(o['orderType']) == 'Dine-In' && isMyOrder(o) && filter(o))
      .toList();

  List<Map<String, dynamic>> myTakeawayOrdersBy(bool Function(Map) filter) => orders
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((o) =>
          sOf(o['orderType']) == 'Takeaway' && isMyOrder(o) && filter(o))
      .toList();

  List<Map<String, dynamic>> get myTakeawayPayLaterOrders => myTakeawayOrdersBy((o) =>
      !isServedOrder(o) && !isCancelledOrder(o) && !isPaidOrDone(o));

  List<Map<String, dynamic>> get myTakeawayPaidOrders =>
      myTakeawayOrdersBy((o) => isPaidOrDone(o));

  List<Map<String, dynamic>> get myTakeawayDueOrders => myTakeawayOrdersBy((o) =>
      !isPaidOrDone(o) && !isCancelledOrder(o));

  List<Map<String, dynamic>> get takeawayPopupOrders {
    final base = takeawayOrdersTab == 'paid'
        ? myTakeawayPaidOrders
        : takeawayOrdersTab == 'due'
            ? myTakeawayDueOrders
            : myTakeawayPayLaterOrders;
    int ts(Map o) =>
        DateTime.tryParse(sOf(o['createdAt']))?.millisecondsSinceEpoch ?? 0;
    base.sort((a, b) => ts(b).compareTo(ts(a)));
    return base;
  }

  List<Map<String, dynamic>> get myNewOrders => myOrdersBy((o) =>
      !isServedOrder(o) && !isCancelledOrder(o) && !isPaidOrDone(o));

  List<Map<String, dynamic>> get myServedOrders =>
      myOrdersBy(isServedOrder);

  List<Map<String, dynamic>> get myCancelledOrders {
    final dayAgo =
        DateTime.now().millisecondsSinceEpoch - 24 * 60 * 60 * 1000;
    return myOrdersBy((o) {
      if (!isCancelledOrder(o)) return false;
      final c = DateTime.tryParse(sOf(o['cancelledAt']));
      return c == null || c.millisecondsSinceEpoch > dayAgo;
    });
  }

  List<Map<String, dynamic>> get popupOrders {
    if (isTakeawayOrderTaker) {
      final base = takeawayOrdersTab == 'paid'
          ? myTakeawayPaidOrders
          : myTakeawayPayLaterOrders;
      int ts(Map o) =>
          DateTime.tryParse(sOf(o['createdAt']))?.millisecondsSinceEpoch ?? 0;
      base.sort((a, b) => ts(b).compareTo(ts(a)));
      return base;
    }
    final base = ordersTab == 'served'
        ? myServedOrders
        : ordersTab == 'cancelled'
            ? myCancelledOrders
            : myNewOrders;
    int ts(Map o) =>
        DateTime.tryParse(sOf(o['createdAt']))?.millisecondsSinceEpoch ?? 0;
    base.sort((a, b) => ts(b).compareTo(ts(a)));
    return base;
  }

  int get cartTotal => cart.fold<int>(
      0, (sum, i) => sum + (numOf(i['price']) * numOf(i['quantity'])).round());

  int get cartCount =>
      cart.fold<int>(0, (s, i) => s + (numOf(i['quantity'])).round());

  Map<String, int> cartQtyByProductId() {
    final m = <String, int>{};
    for (final i in cart) {
      final id = sOf(i['id']);
      if (id.isNotEmpty) {
        m[id] = (m[id] ?? 0) + (numOf(i['quantity'])).round();
      }
    }
    return m;
  }

  // --------------------------------------------------------------- cart --

  void addToCart(Map<String, dynamic> product) {
    final flavors = product['flavors'];
    if (flavors is List && flavors.isNotEmpty) {
      setState(() {
        variantProduct = product;
        variantFlavor = null;
        variantStep = 'flavors';
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
      final idx = cart.indexWhere(
          (i) => sOf(i['id']) == sOf(product['id']) &&
              sOf(i['flavor']).isEmpty &&
              sOf(i['weight']).isEmpty);
      if (idx >= 0) {
        cart[idx]['quantity'] = numOf(cart[idx]['quantity']) + 1;
      } else {
        cart.add({
          ...product,
          'quantity': 1,
          'price': numOf(product['price']),
          'weight': '',
          'flavor': '',
          'itemId': '${product['id']}-base-${DateTime.now().millisecondsSinceEpoch}',
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
      final price = variant?['price'] != null
          ? numOf(variant!['price'])
          : numOf(product['price']);
      final idx = cart.indexWhere((i) =>
          sOf(i['id']) == sOf(product['id']) &&
          sOf(i['flavor']) == flabel &&
          sOf(i['weight']) == vlabel);
      if (idx >= 0) {
        cart[idx]['quantity'] = numOf(cart[idx]['quantity']) + 1;
      } else {
        cart.add({
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
    });
    markOrdered(sOf(product['id']));
  }

  void updateCartQty(String itemId, int delta) {
    setState(() {
      cart = cart
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

  void removeFromCart(String itemId) =>
      setState(() => cart.removeWhere((i) => i['itemId'] == itemId));

  void _removeProductLine(Map<String, dynamic> product) {
    final line = cart.where((i) => sOf(i['id']) == sOf(product['id'])).toList();
    if (line.isNotEmpty) removeFromCart(sOf(line.first['itemId']));
  }

  void _onPressStart(Map<String, dynamic> product) {
    _pressFired = false;
    _pressTimer?.cancel();
    _pressTimer = Timer(const Duration(seconds: 1), () {
      _pressFired = true;
      HapticFeedback.heavyImpact();
      _removeProductLine(product);
      toast('${product['name']} removed from cart', seconds: 2);
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

  // ------------------------------------------------------------- actions --

  Future<Map<String, dynamic>?> createOrder(String orderStatus,
      {bool paid = false, String payMethod = 'Cash', double cashReceived = 0}) async {
    if (cart.isEmpty) {
      toast('Cart is empty');
      return null;
    }
    final isTakeaway = activeType == 'Take Away';
    if (!isTakeaway && tableNumber.isEmpty) {
      toast('Please select a table or room');
      return null;
    }
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : (sOf(user['username']).isNotEmpty ? sOf(user['username']) : '');
      final payload = {
        'items': cart
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
        'orderType': isTakeaway ? 'Takeaway' : 'Dine-In',
        'customerName': isTakeaway
            ? (customerNameCtrl.text.trim().isEmpty
                ? 'Pickup'
                : customerNameCtrl.text.trim())
            : customerNameCtrl.text.trim(),
        'phone': '',
        'tableNumber': isTakeaway ? '' : tableNumber,
        'notes': notesCtrl.text.trim(),
        'orderTaker': me,
        'waiter': me,
        'status': orderStatus,
        'paymentStatus': paid ? 'Paid' : 'Pending',
        'serviceType': '',
        'deliveryFee': 0,
        'discount': 0,
        'taxPercent': 0,
        'serviceCharge': 0,
        'paymentMethod': isTakeaway ? payMethod : '',
        if (paid && cashReceived > 0) 'cashReceived': cashReceived,
      };
      final created = await _fetch('/pos/orders',
          method: 'POST', body: payload);
      if (created is Map && paid) {
        await _fetch('/pos/payments', method: 'POST', body: {
          'orderId': created['id'],
          'amount': created['total'],
          'paymentMethod': payMethod,
          'status': 'Completed',
          'description': 'Payment for order ${created['orderNumber'] ?? created['id']}',
        });
      }
      if (!mounted) return created is Map ? Map<String, dynamic>.from(created) : null;
      setState(() {
        cart = [];
        customerNameCtrl.clear();
        notesCtrl.clear();
        cashCtrl.clear();
        tableNumber = '';
        showCart = false;
        showPaymentPopup = false;
      });
      toast(paid
          ? 'Order created & payment completed ✅'
          : isTakeaway
              ? 'Takeaway order created 🛍️'
              : 'Order created successfully ✅');
      if ((btConnected || btInfo != null || settings['btPrintEnabled'] == true) &&
          created is Map) {
        final printOrder = Map<String, dynamic>.from(created);
        if (sOf(printOrder['date']).isEmpty) {
          printOrder['date'] =
              sOf(printOrder['createdAt']).isNotEmpty
                  ? sOf(printOrder['createdAt'])
                  : DateTime.now().toIso8601String();
        }
        if (paid && cashReceived > 0 && nOf(printOrder['cashReceived']) == 0) {
          printOrder['cashReceived'] = cashReceived;
        }
        printOrderBT(printOrder).then((ok) {
          if (ok) toast('Order created & printed via Bluetooth');
        }).catchError((e) {
          toast('Order created but Bluetooth print failed: $e', seconds: 6);
        });
      }
      await _loadData(silent: true);
      return created is Map ? Map<String, dynamic>.from(created) : null;
    } catch (e) {
      toast(e.toString(), seconds: 6);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void openEditOrder(Map order) {
    final items = <Map<String, dynamic>>[];
    for (final it in (order['items'] as List? ?? [])) {
      if (it is! Map) continue;
      final m = Map<String, dynamic>.from(it);
      m['itemId'] = sOf(m['itemId']).isNotEmpty
          ? m['itemId']
          : '${m['productId'] ?? m['id']}-${DateTime.now().millisecondsSinceEpoch}-${items.length}';
      items.add(m);
    }
    setState(() {
      editOrder = Map<String, dynamic>.from(order);
      editCart = items;
      editAddSearch = '';
    });
  }

  Future<void> saveEditOrder() async {
    final eo = editOrder;
    if (eo == null) return;
    if (editCart.isEmpty) {
      toast('Order must have at least one item.');
      return;
    }
    if (sOf(eo['tableNumber']).isEmpty) {
      toast('Please select a table or room for Dine-In orders.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final subtotal = editCart.fold<double>(
          0, (sum, i) => sum + numOf(i['price']) * numOf(i['quantity']));
      final discount = numOf(eo['discount']);
      final tax = (subtotal - discount) * numOf(eo['taxPercent']) / 100;
      final service = numOf(eo['serviceCharge']);
      final total = (subtotal - discount + tax + service).clamp(0, double.infinity);
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : (sOf(user['username']).isNotEmpty ? sOf(user['username']) : '');
      await _fetch('/pos/orders/${eo['id']}', method: 'PUT', body: {
        'items': editCart,
        'orderType': 'Dine-In',
        'customerName': eo['customerName'] ?? '',
        'phone': eo['phone'] ?? '',
        'tableNumber': eo['tableNumber'] ?? '',
        'deliveryAgent': '',
        'serviceType': '',
        'deliveryFee': 0,
        'discount': discount,
        'taxPercent': numOf(eo['taxPercent']),
        'serviceCharge': service,
        'paymentMethod': sOf(eo['paymentMethod']).isEmpty
            ? 'Cash'
            : eo['paymentMethod'],
        'paymentStatus': eo['paymentStatus'] ?? '',
        'notes': eo['notes'] ?? '',
        'status': sOf(eo['status']).isEmpty ? 'Pending' : eo['status'],
        'subtotal': subtotal,
        'total': total,
        'orderTaker': me,
      });
      if (!mounted) return;
      setState(() {
        editOrder = null;
        editCart = [];
      });
      toast('Order updated');
      await _loadData(silent: true);
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> markServed(Map order) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : sOf(user['username']);
      await _fetch('/pos/orders/${order['id']}', method: 'PUT', body: {
        'status': 'Served',
        'servedAt': DateTime.now().toUtc().toIso8601String(),
        'orderTaker': me,
      });
      if (!mounted) return;
      setState(() => expandedOrderId = null);
      toast('Order #${order['orderNumber'] ?? order['id']} marked served ✅');
      await _loadData(silent: true);
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> cancelOrder(Map order) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : sOf(user['username']);
      await _fetch('/pos/orders/${order['id']}', method: 'PUT', body: {
        'status': 'Cancelled',
        'cancelledAt': DateTime.now().toUtc().toIso8601String(),
        'paymentRequestStatus': '',
        'orderTaker': me,
      });
      if (!mounted) return;
      setState(() => expandedOrderId = null);
      toast('Order #${order['orderNumber'] ?? order['id']} cancelled ❌');
      await _loadData(silent: true);
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> attachPaymentPhoto(Map order) async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 72,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : sOf(user['username']);
      await _fetch('/pos/orders/${order['id']}', method: 'PUT', body: {
        'paymentRequestImage': image,
        'paymentRequestedAt': DateTime.now().toUtc().toIso8601String(),
        'orderTaker': me,
      });
      toast('Payment request sent with photo');
      await _loadData(silent: true);
    } catch (e) {
      toast(e.toString(), seconds: 6);
    }
  }

  Future<void> pushOwnerRequest(Map order, String method) async {
    if (sOf(order['paymentRequestImage']).isEmpty) {
      toast('Attach a payment photo first');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : sOf(user['username']);
      await _fetch('/pos/orders/${order['id']}', method: 'PUT', body: {
        'paymentRequestStatus': 'owner-request',
        'paymentRequestedAt': sOf(order['paymentRequestedAt']).isNotEmpty
            ? order['paymentRequestedAt']
            : DateTime.now().toUtc().toIso8601String(),
        'paymentMethod': method,
        'orderTaker': me,
      });
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      toast(
          'Payment request ($method) pushed to Farhan Owner for #${order['orderNumber'] ?? order['id']}');
      await _loadData(silent: true);
    } catch (e) {
      toast(e.toString(), seconds: 6);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, int> get editQtyById {
    final m = <String, int>{};
    for (final i in editCart) {
      final id = sOf(i['productId'] ?? i['id']);
      if (id.isNotEmpty) m[id] = (m[id] ?? 0) + (numOf(i['quantity'])).round();
    }
    return m;
  }

  double editLiveTotal() {
    final subtotal = editCart.fold<double>(
        0, (s, i) => s + numOf(i['price']) * numOf(i['quantity']));
    final discount = numOf(editOrder?['discount']);
    final tax = (subtotal - discount) * numOf(editOrder?['taxPercent']) / 100;
    final service = numOf(editOrder?['serviceCharge']);
    return (subtotal - discount + tax + service).clamp(0, double.infinity);
  }

  List<Map<String, dynamic>> get filteredEditAddProducts {
    final term = editAddSearch.toLowerCase().trim();
    return products
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((p) =>
            term.isEmpty || sOf(p['name']).toLowerCase().contains(term))
        .take(50)
        .toList();
  }

  void addProductToEditCart(Map product) {
    final idx = editCart.indexWhere((i) =>
        sOf(i['productId'] ?? i['id']) == sOf(product['id']));
    setState(() {
      if (idx >= 0) {
        editCart[idx]['quantity'] = numOf(editCart[idx]['quantity']) + 1;
      } else {
        editCart.add({
          'productId': product['id'],
          'id': product['id'],
          'name': product['name'],
          'price': numOf(product['price']),
          'quantity': 1,
          'itemId':
              '${product['id']}-${DateTime.now().millisecondsSinceEpoch}-${editCart.length}',
        });
      }
    });
    toast('${product['name']} added', seconds: 2);
  }

  // ----------------------------------------------------------- printing --

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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
    if (sOf(order['waiter']).isEmpty) {
      order['waiter'] = order['orderTaker'];
    }
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
      // Image (raster) mode is the default and the only reliable mode on
      // cheap BT thermal printers - text/codepage mode can print BLANK
      // slips on many models. Only an explicit server setting switches
      // to the text path.
      final enc = sOf(btSettings['btEncoding']);
      final isBmp = enc.isEmpty || enc == 'bmp';

      // Build the main receipt AND the token slip as ONE buffer - sending
      // them as a single write guarantees the token slip prints attached
      // right after the receipt (separate delayed writes can be dropped by
      // busy printer buffers).
      final out = BytesBuilder();
      if (isBmp) {
        out.add(
            await bmp.buildBmpReceipt(order, btSettings, host: ApiClient.host));
      } else {
        try {
          out.add(esc.buildEscposReceipt(order, btSettings));
        } catch (_) {
          out.add(await bmp.buildBmpReceipt(order, btSettings,
              host: ApiClient.host));
        }
      }

      final type = sOf(order['orderType']);
      final shouldToken = btSettings['tokenSlipEnabled'] == true &&
          ((type == 'Dine-In' && btSettings['btTokenSlipDineIn'] != false) ||
              (type == 'Takeaway' && btSettings['btTokenSlipTakeaway'] != false) ||
              (type == 'Delivery' && btSettings['btTokenSlipDelivery'] != false) ||
              (type.isEmpty && btSettings['btTokenSlipDineIn'] != false));
      if (shouldToken) {
        final tokOrder = <String, dynamic>{...order, 'items': []};
        // Small paper gap between receipt and token slip.
        out.add(List<int>.filled(24, 0x0A));
        if (isBmp) {
          out.add(await bmp.buildBmpReceipt(tokOrder, btSettings,
              tokenOnly: true, host: ApiClient.host));
        } else {
          try {
            out.add(esc.buildEscposReceipt(tokOrder, btSettings,
                tokenOnly: true));
          } catch (_) {
            out.add(await bmp.buildBmpReceipt(tokOrder, btSettings,
                tokenOnly: true, host: ApiClient.host));
          }
        }
      }
      await BtService.write(out.toBytes());
    }

    try {
      await BtService.enqueue(attemptPrint);
      return true;
    } catch (_) {
      // Stale socket - reset and try once more with a fresh connection.
      await BtService.disconnect();
      await BtService.enqueue(() async {
        final ok = await _connectPrinter(target);
        if (!ok) {
          throw Exception(
              'Print failed: ${BtService.lastError.isEmpty ? 'could not connect' : BtService.lastError}');
        }
        await attemptPrint();
      });
      return true;
    }
  }

  Future<void> _scanPrinters() async {
    setState(() => scanningPrinters = true);
    var permitted = false;
    try {
      permitted = await BtService.ensurePermission();
      final list = permitted ? await BtService.pairedPrinters() : <PrinterInfo>[];
      if (!mounted) return;
      setState(() => pairedPrintersList = list);
      if (list.isEmpty) {
        final btOn = await BtService.bluetoothEnabled();
        if (!mounted) return;
        if (!permitted) {
          toast(BtService.lastError.isNotEmpty
              ? BtService.lastError
              : 'Bluetooth permission required - App Settings > Permissions > Nearby devices',
          seconds: 6);
        } else if (!btOn) {
          toast('Phone ka Bluetooth OFF hai - pehle Bluetooth on karein',
              seconds: 6);
        } else {
          toast('Koi paired printer nahi mila - printer ko Android Bluetooth '
              'settings se pair karein', seconds: 6);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => scanningPrinters = false);
  }

  void _openPrinterSheet() {
    setState(() => showPrinterSheet = true);
    if (pairedPrintersList.isEmpty) {
      _scanPrinters();
    }
  }

  Future<void> _connectTo(PrinterInfo p) async {
    if (connectingMac.isNotEmpty) return;
    setState(() => connectingMac = p.mac);
    try {
      final ok = await BtService.connect(p);
      if (!mounted) return;
      if (ok) {
        await BtService.savePrinter(p);
        setState(() {
          btConnected = true;
          btInfo = p;
        });
        toast('Bluetooth printer connected: ${p.name}');
      } else {
        final btOn = await BtService.bluetoothEnabled();
        final extra = btOn ? '' : ' - phone ka Bluetooth OFF hai';
        final reason = BtService.lastError.isEmpty ? '' : ' (${BtService.lastError})';
        toast('Could not connect to ${p.name}$extra$reason'
                ' - printer on aur range mein rakhein',
            seconds: 6);
      }
    } catch (e) {
      toast('$e', seconds: 6);
    } finally {
      if (mounted) setState(() => connectingMac = '');
    }
  }

  Future<void> _disconnectPrinter() async {
    await BtService.disconnect();
    if (!mounted) return;
    setState(() {
      btConnected = false;
      btInfo = null;
    });
    toast('Printer disconnected');
  }

  bool _btUseImageMode() {
    final enc = sOf(btSettings['btEncoding']);
    return enc.isEmpty || enc == 'bmp';
  }

  Future<void> _testPrint() async {
    var target = btInfo ?? await BtService.savedPrinter();
    target ??= pairedPrintersList.isNotEmpty ? pairedPrintersList.first : null;
    if (target == null) {
      toast(
          'No paired printer found - pair your thermal printer in Android Bluetooth settings first',
          seconds: 6);
      return;
    }
    final me = sOf(user['name']).isNotEmpty
        ? sOf(user['name'])
        : sOf(user['username']);
    final testOrder = <String, dynamic>{
      'orderNumber': 'TEST',
      'id': 'TEST',
      'date': DateTime.now().toIso8601String(),
      'items': [
        {'name': 'Chicken Tikka', 'price': 350, 'quantity': 2},
        {'name': 'Naan / Roti', 'price': 40, 'quantity': 2},
      ],
      'orderType': activeType == 'Take Away' ? 'Takeaway' : 'Dine-In',
      'tableNumber': activeType == 'Take Away' ? '' : 'T-1',
      'customerName': 'Test Customer',
      'waiter': me,
      'status': 'Test Print',
    };
    Future<void> sendTest() async {
      if (!(await BtService.isConnected())) {
        final ok = await _connectPrinter(target!);
        if (!ok) throw Exception('Could not connect to ${target.name}');
      }
      if (_btUseImageMode()) {
        await BtService.write(
            await bmp.buildBmpReceipt(testOrder, btSettings, host: ApiClient.host));
      } else {
        try {
          await BtService.write(esc.buildEscposReceipt(testOrder, btSettings));
        } catch (_) {
          await BtService.write(
              await bmp.buildBmpReceipt(testOrder, btSettings, host: ApiClient.host));
        }
      }
    }

    try {
      await BtService.enqueue(sendTest);
      toast('Test receipt printed via ${target.name} 🖨️');
    } catch (_) {
      // Stale socket - reset and retry once with a fresh connection.
      await BtService.disconnect();
      try {
        await BtService.enqueue(() async {
          await sendTest();
        });
        toast('Test receipt printed via ${target.name} 🖨️');
      } catch (e) {
        toast('Test print failed: $e', seconds: 6);
      }
    }
  }

  Future<void> handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('orderTakerToken');
    await prefs.remove('orderTakerUser');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ----------------------------------------------------------------- UI --

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
            if (cart.isNotEmpty && !showCart && editOrder == null)
              Positioned(
                right: 16,
                bottom: 24,
                child: FloatingActionButton.extended(
                  heroTag: 'cartFab',
                  onPressed: () => setState(() => showCart = true),
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  icon: const Text('🛒'),
                  label: Text('$cartCount items · $cartTotal PKR'),
                ),
              ),
            if (variantProduct != null) _variantSheet(),
            if (showPrinterSheet) _printerSheet(),
            if (showCart) _cartSheet(),
            if (showPaymentPopup) _takeawayPaymentSheet(),
            if (showOrdersPopup) _ordersPopup(),
            if (showTakeawayOrdersPopup) _takeawayOrdersPopup(),
            if (editOrder != null) _editModal(),
            if (message.isNotEmpty) _toastOverlay(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------ BT settings widgets --

  bool _btFlag(String key, {bool def = false}) {
    if (btOverrides.containsKey(key)) return btOverrides[key] == true;
    final v = settings[key];
    if (v == null) return def;
    return v == true;
  }

  double _btNumOf(String key, num def) {
    final raw =
        btOverrides.containsKey(key) ? btOverrides[key] : settings[key];
    if (raw == null) return def.toDouble();
    if (raw is String) {
      final p = double.tryParse(raw.trim());
      if (p == null || p == 0) return def.toDouble();
      return p;
    }
    final v = nOf(raw);
    return v == 0 ? def.toDouble() : v;
  }

  String _btSel(String key, String def) =>
      sOf(btSettings[key]).isNotEmpty ? sOf(btSettings[key]) : def;

  Widget _btSectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 0, 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Color(0xFF64748B))),
      );

  Widget _btLabel(String t) => Text(t,
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8)));

  Widget _btSelect(String label, String value,
      List<MapEntry<String, String>> options, void Function(String) onChanged) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _btLabel(label),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: options.any((o) => o.key == value)
                    ? value
                    : options.first.key,
                isExpanded: true,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(
                    fontSize: 11.5, color: Color(0xFFE2E8F0)),
                icon: const Icon(Icons.expand_more,
                    size: 16, color: Color(0xFF94A3B8)),
                items: [
                  for (final o in options)
                    DropdownMenuItem(
                        value: o.key,
                        child:
                            Text(o.value, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btStepper(String label, num value, num min, num max,
      void Function(num) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _btLabel(label)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: .15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('$value px',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF34D399))),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min).round(),
            activeColor: const Color(0xFF059669),
            inactiveColor: const Color(0xFF334155),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  Widget _btToggle(String label, bool value, void Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF059669).withValues(alpha: .15)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: value
                  ? const Color(0xFF059669)
                  : const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                value
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 13,
                color: value
                    ? const Color(0xFF34D399)
                    : const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: value
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFCBD5E1))),
            ),
          ],
        ),
      ),
    );
  }

  TextEditingController _btTextCtrl(String key, String fallback) {
    var c = _btTextCtrls[key];
    if (c == null) {
      c = TextEditingController(
          text: sOf(btSettings[key]).isNotEmpty
              ? sOf(btSettings[key])
              : fallback);
      _btTextCtrls[key] = c;
    }
    return c;
  }

  Widget _btTextInput(String label, String key, String fallback,
      {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _btLabel(label),
        const SizedBox(height: 4),
        TextField(
          controller: _btTextCtrl(key, fallback),
          style: const TextStyle(fontSize: 12.5, color: Color(0xFFF1F5F9)),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint.isEmpty ? label : hint,
            hintStyle:
                const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF059669))),
          ),
          onChanged: (v) async {
            btOverrides[key] = v;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_btOverridesKey, jsonEncode(btOverrides));
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------ printer sheet --

  Widget _printerSheet() {
    final savedMac = btInfo?.mac ?? '';
    final encNow = _btSel('btEncoding', '');
    final imageMode = encNow.isEmpty || encNow == 'bmp';
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () => setState(() => showPrinterSheet = false),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.92),
                decoration: const BoxDecoration(
                  color: Color(0xFF020617),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                      top: BorderSide(color: Color(0xFF334155))),
                ),
                padding: const EdgeInsets.all(18),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('🖨️ Bluetooth Printer',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                            GestureDetector(
                              onTap: _resetBtSettings,
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('↺',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF94A3B8))),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(
                                  () => showPrinterSheet = false),
                              icon: const Icon(Icons.close,
                                  size: 19,
                                  color: Color(0xFFCBD5E1)),
                            ),
                          ],
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: btConnected
                                ? const Color(0xFF059669)
                                    .withValues(alpha: .12)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: btConnected
                                    ? const Color(0xFF059669)
                                        .withValues(alpha: .5)
                                    : const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: btConnected
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFF64748B),
                                  boxShadow: btConnected
                                      ? [BoxShadow(
                                            blurRadius: 8,
                                            color:
                                                const Color(0xFF22C55E)
                                                    .withValues(
                                                        alpha: .8))]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        btConnected
                                            ? (btInfo?.name ??
                                                'Printer')
                                            : 'Not connected',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                    Text(
                                        btConnected
                                            ? (btInfo?.mac ?? '')
                                            : 'Koi printer attach nahi hai',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color:
                                                Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: btConnected
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF334155),
                                  borderRadius:
                                      BorderRadius.circular(100),
                                ),
                                child: Text(
                                    btConnected
                                        ? 'Connected'
                                        : 'Offline',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: btConnected
                                            ? Colors.white
                                            : const Color(0xFFCBD5E1))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                                scanningPrinters
                                    ? 'Scanning paired printers...'
                                    : pairedPrintersList.isEmpty
                                        ? 'PAIRED PRINTERS'
                                        : 'PAIRED PRINTERS (${pairedPrintersList.length})',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: scanningPrinters
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF64748B))),
                            const Spacer(),
                            GestureDetector(
                              onTap: _scanPrinters,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius:
                                      BorderRadius.circular(100),
                                ),
                                child: const Row(
                                  children: [
                                    Text('🔄',
                                        style: TextStyle(
                                            fontSize: 11)),
                                    SizedBox(width: 4),
                                    Text('Refresh',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight:
                                                FontWeight.w700,
                                            color: Color(0xFFE2E8F0))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (scanningPrinters)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                  color: Color(0xFF059669)),
                            ),
                          )
                        else if (pairedPrintersList.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF78350F)
                                  .withValues(alpha: .35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: .5)),
                            ),
                            child: const Text(
                              '⚠️ No paired printer found.\nApna thermal printer Android ki Bluetooth settings mein pair karein, phir Refresh dabayein.',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.45,
                                  color: Color(0xFFFCD34D)),
                            ),
                          )
                        else
                          ...[
                            for (final p in pairedPrintersList.take(6))
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.fromLTRB(
                                    12, 8, 8, 8),
                                decoration: BoxDecoration(
                                  color: btConnected && savedMac == p.mac
                                      ? const Color(0xFF059669)
                                          .withValues(alpha: .1)
                                      : const Color(0xFF0F172A),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: btConnected &&
                                              savedMac == p.mac
                                          ? const Color(0xFF059669)
                                              .withValues(alpha: .55)
                                          : const Color(0xFF1E293B)),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                        btConnected && savedMac == p.mac
                                            ? '✅'
                                            : '🖨️',
                                        style: const TextStyle(
                                            fontSize: 16)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(p.name,
                                              overflow: TextOverflow
                                                  .ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: Color(
                                                      0xFFF1F5F9))),
                                          Text(p.mac,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(
                                                      0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    if (connectingMac == p.mac)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(
                                                    0xFF34D399)),
                                      )
                                    else if (btConnected &&
                                        savedMac == p.mac)
                                      const Text('Connected',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w800,
                                              color: Color(0xFF34D399)))
                                    else
                                      GestureDetector(
                                        onTap: () => _connectTo(p),
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 14,
                                              vertical: 7),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                                0xFF059669),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    100),
                                          ),
                                          child: const Text('Attach',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  color:
                                                      Colors.white)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _testPrint,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(100)),
                                ),
                                icon: const Text('🧾',
                                    style:
                                        TextStyle(fontSize: 13)),
                                label: const Text('Test Print',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w800)),
                              ),
                            ),
                            if (btConnected) ...[
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _disconnectPrinter,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFFE11D48)),
                                  foregroundColor:
                                      const Color(0xFFFB7185),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(100)),
                                ),
                                icon: const Icon(Icons.link_off,
                                    size: 15),
                                label: const Text('Disconnect',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),

                        // ---------------------------------- settings ----
                        _btSectionTitle('Basic'),
                        Row(
                          children: [
                            _btSelect(
                                'Paper Width',
                                _btSel('receiptPaperWidth', '58'),
                                [
                                  const MapEntry('58', '58mm (32 chars)'),
                                  const MapEntry('80', '80mm (42 chars)'),
                                ],
                                (v) => _setBt('receiptPaperWidth', v)),
                            const SizedBox(width: 8),
                            _btSelect(
                                'Text Encoding',
                                encNow.isEmpty ? 'bmp' : encNow,
                                [
                                  const MapEntry('bmp',
                                      'Image/Raster (Recommended)'),
                                  const MapEntry('cp1256',
                                      'Text CP1256 (Urdu/Arabic)'),
                                  const MapEntry('cp864',
                                      'Text CP864 (Arabic)'),
                                  const MapEntry('utf-8',
                                      'Text UTF-8'),
                                ],
                                (v) => _setBt('btEncoding', v)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                            'Tip: slip ke RIGHT side zyada blank aa rahi ho to Paper Width 80mm select karein (aapke printer ka roll 80mm hai).',
                            style: TextStyle(
                                fontSize: 10,
                                height: 1.4,
                                color: Color(0xFF94A3B8)
                                    .withValues(alpha: .9))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _btSelect(
                                'Font Family',
                                _btSel('btFontFamily',
                                    'Noto Naskh Arabic, Segoe UI, Arial, sans-serif'),
                                [
                                  const MapEntry(
                                      'Noto Naskh Arabic, Segoe UI, Arial, sans-serif',
                                      'Auto (Urdu Support)'),
                                  const MapEntry('Arial', 'Arial'),
                                  const MapEntry('Tahoma', 'Tahoma'),
                                  const MapEntry('Courier New',
                                      'Courier New'),
                                  const MapEntry('Times New Roman',
                                      'Times New Roman'),
                                  const MapEntry('Verdana', 'Verdana'),
                                ],
                                (v) => _setBt('btFontFamily', v)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _btSelect(
                                'Divider Style',
                                _btSel('btDividerStyle', 'dashed'),
                                [
                                  const MapEntry('dashed', 'Dashed (-)'),
                                  const MapEntry('solid', 'Solid (=)'),
                                  const MapEntry('double', 'Double (=)'),
                                  const MapEntry('thick', 'Thick (#)'),
                                ],
                                (v) => _setBt('btDividerStyle', v)),
                            const SizedBox(width: 8),
                            _btSelect(
                                'Text Alignment',
                                _btSel('btTextAlign', 'center'),
                                [
                                  const MapEntry('left', 'Left'),
                                  const MapEntry('center', 'Center'),
                                  const MapEntry('right', 'Right'),
                                ],
                                (v) => _setBt('btTextAlign', v)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _btToggle('Auto-enable BT printing',
                                settings['btPrintEnabled'] == true ||
                                    btOverrides['btPrintEnabled'] == true,
                                (v) => _setBt('btPrintEnabled', v)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: imageMode
                                    ? const Color(0xFF059669)
                                        .withValues(alpha: .15)
                                    : const Color(0xFF0F172A),
                                borderRadius:
                                    BorderRadius.circular(100),
                                border: Border.all(
                                    color: imageMode
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF334155)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(imageMode
                                      ? Icons.image
                                      : Icons.text_fields,
                                      size: 13,
                                      color: imageMode
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF64748B)),
                                  const SizedBox(width: 5),
                                  Text(
                                      imageMode
                                          ? 'Mode: Image (no blank slips)'
                                          : 'Mode: ESC/POS Text',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: imageMode
                                              ? const Color(0xFFA7F3D0)
                                              : const Color(
                                                  0xFFCBD5E1))),
                                ],
                              ),
                            ),
                          ],
                        ),

                        _btSectionTitle('Location on Receipt'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _btToggle('Show Location',
                                _btFlag('btReceiptLocationShow'),
                                (v) =>
                                    _setBt('btReceiptLocationShow', v)),
                          ],
                        ),
                        if (_btFlag('btReceiptLocationShow')) ...[
                          const SizedBox(height: 8),
                          _btTextInput('Location Text',
                              'btReceiptLocationText',
                              sOf(settings['btReceiptLocationText']),
                              hint: 'e.g. Usman Hotel, Main Branch'),
                        ],

                        _btSectionTitle('Font Sizes & Styles'),
                        _btStepper(
                            'Base Font Size',
                            _btNumOf('btFontSize', 20), 8, 72,
                            (v) => _setBt('btFontSize', v)),
                        _btStepper(
                            'Product Font Size',
                            _btNumOf('btProductFontSize', 20), 8, 72,
                            (v) => _setBt('btProductFontSize', v)),
                        _btStepper(
                            'Total Amount Font Size',
                            _btNumOf('btTotalFontSize', 26), 8, 72,
                            (v) => _setBt('btTotalFontSize', v)),
                        _btStepper(
                            'Order Type Font Size',
                            _btNumOf('btOrderTypeFontSize', 18), 8, 72,
                            (v) => _setBt('btOrderTypeFontSize', v)),
                        _btStepper(
                            'Service Type Font Size',
                            _btNumOf('btServiceTypeFontSize', 16), 8, 72,
                            (v) => _setBt('btServiceTypeFontSize', v)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _btToggle('Bold Service Type',
                                _btFlag('btServiceTypeBold'),
                                (v) =>
                                    _setBt('btServiceTypeBold', v)),
                            _btToggle('Bold Location',
                                _btFlag('btLocationBold'),
                                (v) => _setBt('btLocationBold', v)),
                            _btToggle('Bold Address',
                                _btFlag('btDeliveryAddressBold'),
                                (v) => _setBt(
                                    'btDeliveryAddressBold', v)),
                          ],
                        ),
                        _btStepper(
                            'Location Font Size',
                            _btNumOf('btLocationFontSize', 14), 8, 72,
                            (v) => _setBt('btLocationFontSize', v)),
                        _btStepper(
                            'Delivery Address Font Size',
                            _btNumOf('btDeliveryAddressFontSize', 14),
                            8, 72,
                            (v) =>
                                _setBt('btDeliveryAddressFontSize', v)),
                        _btStepper(
                            'Total Due Font Size',
                            _btNumOf('btTotalDueFontSize', 22), 8, 72,
                            (v) => _setBt('btTotalDueFontSize', v)),
                        _btStepper(
                            'PAID Stamp Font Size',
                            _btNumOf('btPaidFontSize', 12), 8, 72,
                            (v) => _setBt('btPaidFontSize', v)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _btToggle('Bold Total Due',
                                _btFlag('btTotalDueBold', def: true),
                                (v) => _setBt('btTotalDueBold', v)),
                            _btToggle('Bold Product Name',
                                _btFlag('btProductBold'),
                                (v) => _setBt('btProductBold', v)),
                            _btToggle('Bold Qty',
                                _btFlag('btQtyBold'),
                                (v) => _setBt('btQtyBold', v)),
                            _btToggle('Bold PAID Stamp',
                                _btFlag('btPaidBold', def: true),
                                (v) => _setBt('btPaidBold', v)),
                            _btToggle('Show Logo on receipt',
                                _btFlag('btLogoEnabled', def: true),
                                (v) => _setBt('btLogoEnabled', v)),
                          ],
                        ),

                        _btSectionTitle('Customer Details Labels'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final e in const [
                              MapEntry('btShowOrderType', 'Order Type'),
                              MapEntry('btShowCustomerName', 'Customer'),
                              MapEntry('btShowTable', 'Table No.'),
                              MapEntry('btShowSalesPerson',
                                  'Sales Person'),
                              MapEntry('btShowMobile', 'Mobile'),
                              MapEntry('btShowDeliveryLocation',
                                  'Location'),
                              MapEntry('btShowServiceType',
                                  'Service Type'),
                              MapEntry('btShowRider', 'Rider'),
                            ])
                              _btToggle(e.value,
                                  _btFlag(e.key, def: true),
                                  (v) => _setBt(e.key, v)),
                          ],
                        ),

                        _btSectionTitle('Header / Footer / Logo'),
                        _btTextInput('BT Receipt Header',
                            'btReceiptHeader',
                            sOf(settings['btReceiptHeader']).isNotEmpty
                                ? sOf(settings['btReceiptHeader'])
                                : (sOf(settings['receiptHeader']).isNotEmpty
                                    ? sOf(settings['receiptHeader'])
                                    : 'Usman Hotel')),
                        const SizedBox(height: 8),
                        _btTextInput('BT Receipt Footer',
                            'btReceiptFooter',
                            sOf(settings['btReceiptFooter']).isNotEmpty
                                ? sOf(settings['btReceiptFooter'])
                                : (sOf(settings['receiptFooter']).isNotEmpty
                                    ? sOf(settings['receiptFooter'])
                                    : 'Thank you for your business')),
                        const SizedBox(height: 8),
                        _btStepper('Receipt Logo Width',
                            _btNumOf('receiptLogoWidth', 80), 30, 380,
                            (v) => _setBt('receiptLogoWidth', v)),
                        _btStepper('Token Slip Logo Width',
                            _btNumOf('btLogoWidth', 70), 20, 140,
                            (v) => _setBt('btLogoWidth', v)),

                        _btSectionTitle('Token Slip'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _btToggle('Print token slip with receipt',
                                btSettings['tokenSlipEnabled'] == true,
                                (v) => _setBt('tokenSlipEnabled', v)),
                            _btToggle('Token on receipt',
                                _btFlag('btTokenOnReceipt', def: true),
                                (v) =>
                                    _setBt('btTokenOnReceipt', v)),
                            _btToggle('Total on token slip',
                                _btFlag('btShowTotalOnToken', def: true),
                                (v) => _setBt(
                                    'btShowTotalOnToken', v)),
                          ],
                        ),

                        _btSectionTitle('Margins'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _btToggle('Use custom margins',
                                _btFlag('btMarginCustom'),
                                (v) => _setBt('btMarginCustom', v)),
                          ],
                        ),
                        if (_btFlag('btMarginCustom')) ...[
                          _btStepper('Top Margin',
                              _btNumOf('btMarginTop', 10), 0, 50,
                              (v) => _setBt('btMarginTop', v)),
                          _btStepper('Bottom Margin',
                              _btNumOf('btMarginBottom', 10), 0, 50,
                              (v) => _setBt('btMarginBottom', v)),
                        ],
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toastOverlay() {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 96,
      child: Align(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: const [BoxShadow(blurRadius: 18, color: Colors.black38)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => message = ''),
                  child: const Text('✕',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required VoidCallback onTap,
    Color? bg,
    Color? fg,
    Widget? badge,
    EdgeInsets pad = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: pad,
            decoration: BoxDecoration(
              color: bg ?? const Color(0xFF0369A1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: fg ?? Colors.white)),
          ),
        ),
        if (badge != null) Positioned(top: -7, right: -7, child: badge),
      ],
    );
  }

  Widget _header() {
    final name = sOf(user['name']).isNotEmpty
        ? sOf(user['name'])
        : (sOf(user['username']).isNotEmpty ? sOf(user['username']) : 'User');
    final role = sOf(user['role']).isEmpty ? 'Order Taker' : sOf(user['role']);
    final printerLabel = btConnecting
        ? '⏳'
        : btConnected
            ? '🖨️ ${(btInfo?.name ?? 'Printer').substring(0, btInfo!.name.length > 10 ? 10 : btInfo!.name.length)}'
            : '🖨️';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Text('📋', style: TextStyle(fontSize: 17)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                Text(role,
                    style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          _pillButton(
            label: printerLabel,
            onTap: _openPrinterSheet,
            bg: btConnected ? const Color(0xFF059669) : const Color(0xFFE0F2FE),
            fg: btConnected ? Colors.white : const Color(0xFF0369A1),
          ),
          const SizedBox(width: 6),
          if (isAdminOrderTaker) ...[
            _pillButton(
              label: '🛍️ Takeaway',
              onTap: () {
                setState(() => showTakeawayOrdersPopup = true);
                _setPopupTimer();
              },
              bg: const Color(0xFFFEF3C7),
              fg: const Color(0xFF92400E),
              badge: myTakeawayPayLaterOrders.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 19, minHeight: 19),
                      child: Text('${myTakeawayPayLaterOrders.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          _pillButton(
            label: '📋 Orders',
            onTap: () {
              setState(() => showOrdersPopup = true);
              _setPopupTimer();
            },
            bg: const Color(0xFFD1FAE5),
            fg: const Color(0xFF065F46),
            badge: myNewOrders.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 19, minHeight: 19),
                    child: Text('${myNewOrders.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          _pillButton(
            label: 'Logout',
            onTap: handleLogout,
            bg: const Color(0xFFE11D48),
          ),
        ],
      ),
    );
  }

  Widget _typeTabs() {
    Widget tab(String label, String emoji, String value, Color activeColor) {
      final active = activeType == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => activeType = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? activeColor
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$emoji $label',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : const Color(0xFF475569))),
          ),
        ),
      );
    }

    if (isTakeawayOnly) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [tab('Take Away', '🛍️', 'Take Away', const Color(0xFFF59E0B))]),
      );
    }
    if (isTableOnly) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [tab('Table', '🍽️', 'Dine-In', const Color(0xFF059669))]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          tab('Table', '🍽️', 'Dine-In', const Color(0xFF059669)),
          const SizedBox(width: 6),
          tab('Take Away', '🛍️', 'Take Away', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: searchCtrl,
        onChanged: (v) => setState(() => search = v),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search menu...',
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
            borderSide: const BorderSide(color: Color(0xFF34D399)),
          ),
        ),
      ),
    );
  }

  Widget _categoryRail() {
    return SizedBox(
      width: 64,
      child: Container(
        margin: const EdgeInsets.only(left: 12, bottom: 8),
        child: ListView.builder(
          itemCount: allCategories.length,
          itemBuilder: (_, i) {
            final cat = allCategories[i];
            final selected = selectedCategory == cat;
            final catObj = categoryByName(cat);
            final isMash = cat == mashallahCategory;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => setState(() => selectedCategory = cat),
                child: AnimatedScale(
                  scale: selected ? 1.05 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isMash ? const Color(0xFFD97706) : const Color(0xFF059669))
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(
                              color: isMash
                                  ? const Color(0xFFFBBF24).withValues(alpha: .5)
                                  : const Color(0xFF34D399).withValues(alpha: .5),
                              width: 2)
                          : null,
                    ),
                    child: Column(
                      children: [
                        if (catObj?['icon'] != null &&
                            sOf(catObj!['icon']).isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: SmartImage(src: sOf(catObj['icon']), size: 20),
                          )
                        else
                          Text(getCatIcon(cat),
                              style: const TextStyle(fontSize: 19)),
                        const SizedBox(height: 2),
                        Text(cat,
                            maxLines: cat.length > 14 ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 8,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF475569))),
                      ],
                    ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🍽️', style: TextStyle(fontSize: 34)),
            SizedBox(height: 6),
            Text('No products found',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }
    final qtyMap = cartQtyByProductId();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 2, 12, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.56,
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
                color: active
                    ? const Color(0xFF059669).withValues(alpha: .16)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: active
                        ? const Color(0xFF059669)
                        : const Color(0xFFE2E8F0),
                    width: active ? 3 : 1),
                boxShadow: active
                    ? [BoxShadow(
                          blurRadius: 14,
                          spreadRadius: 1,
                          color: const Color(0xFF059669).withValues(alpha: .45),
                          offset: const Offset(0, 3))]
                    : const [BoxShadow(blurRadius: 3, color: Color(0x14000000))],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: active
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFE2E8F0),
                                width: active ? 2.5 : 1),
                          ),
                          child: ClipOval(
                            child: sOf(p['photo']).isNotEmpty
                                ? SmartImage(src: sOf(p['photo']), size: 83)
                                : Container(
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFE0F2FE),
                                          Color(0xFFE0E7FF)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Text('📦',
                                        style: TextStyle(fontSize: 34)),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [
                            Color(0xFF8B5CF6),
                            Color(0xFFEC4899),
                            Color(0xFFF97316),
                          ],
                        ).createShader(r),
                        child: Text(
                          sOf(p['name']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15.5,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 5),
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [
                            Color(0xFF059669),
                            Color(0xFF10B981),
                            Color(0xFFF59E0B),
                          ],
                        ).createShader(r),
                        child: Text(
                          '${_fmtNum(numOf(p['price']))} PKR',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  if (selected)
                    Positioned(
                      top: -9,
                      left: -8,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF059669),
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(14)),
                          boxShadow: [
                            BoxShadow(blurRadius: 6, color: Colors.black26)
                          ],
                        ),
                        child: Text('\u{1F6D2} \u00D7 $qty',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .3,
                                color: Colors.white)),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Container(
                        constraints: const BoxConstraints(
                            minWidth: 34, minHeight: 34),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                blurRadius: 10,
                                color: const Color(0xFF059669)
                                    .withValues(alpha: .65),
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Text('$qty',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  // ------------------------------------------------------------ overlays --

  void _closeVariant() =>
      setState(() {
        variantProduct = null;
        variantFlavor = null;
        variantStep = 'flavors';
      });

  Widget _variantSheet() {
    final p = variantProduct!;
    final isFlavors = variantStep == 'flavors';
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: GestureDetector(
          onTap: _closeVariant,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: const BoxDecoration(
                  color: Color(0xFF020617),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Color(0xFF334155))),
                ),
                padding: const EdgeInsets.all(20),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFlavors ? 'CHOOSE FLAVOR' : 'SELECT SIZE / WEIGHT',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 2,
                                      color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 8),
                                Text(sOf(p['name']),
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                if (!isFlavors)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('Flavor: ${sOf(variantFlavor?['label'])}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Color(0xFF94A3B8))),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _closeVariant,
                            icon: const Text('✕',
                                style: TextStyle(color: Color(0xFFCBD5E1))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: isFlavors
                              ? ((p['flavors'] as List?) ?? []).length
                              : ((variantFlavor?['variants'] as List?) ?? []).length,
                          itemBuilder: (_, i) {
                            if (isFlavors) {
                              final flavor =
                                  Map<String, dynamic>.from((p['flavors'] as List)[i] as Map);
                              final vCount = (flavor['variants'] as List?)?.length ?? 0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF334155)),
                                    backgroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(100)),
                                    alignment: Alignment.centerLeft,
                                  ),
                                  onPressed: () => selectVariantFlavor(flavor),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(sOf(flavor['label']),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFFF1F5F9))),
                                      ),
                                      if (vCount > 0)
                                        Text('$vCount options',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              );
                            }
                            final variant = Map<String, dynamic>.from(
                                (variantFlavor!['variants'] as List)[i] as Map);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF334155)),
                                  backgroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(100)),
                                  alignment: Alignment.centerLeft,
                                ),
                                onPressed: () => addVariantToCart(p, variantFlavor!, variant),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(sOf(variant['label']),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13, color: Color(0xFFF1F5F9))),
                                    ),
                                    Text('${numOf(variant['price'])} PKR',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFF1F5F9))),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartSheet() {
    final floor = freeTablesBySection['floor'] ?? [];
    final outside = freeTablesBySection['outside'] ?? [];
    final noFreeTables = floor.isEmpty && outside.isEmpty;
    final isTakeaway = activeType == 'Take Away';
    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('🛒 Place Order ($cartCount items)',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                  ),
                  IconButton(
                    onPressed: () => setState(() => showCart = false),
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('ITEMS',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Colors.grey.shade600)),
                    ),
                    ...cart.map((item) => Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sOf(item['name']),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                    if (sOf(item['flavor']).isNotEmpty ||
                                        sOf(item['weight']).isNotEmpty)
                                      Text(
                                          '${sOf(item['flavor'])}${sOf(item['flavor']).isNotEmpty && sOf(item['weight']).isNotEmpty ? ' • ' : ''}${sOf(item['weight'])}',
                                          style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Color(0xFF64748B))),
                                    Text('${numOf(item['price'])} PKR each',
                                        style: const TextStyle(
                                            fontSize: 11, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              _qtyBtn('−', const Color(0xFFF1F5F9), const Color(0xFF334155),
                                  () => updateCartQty(sOf(item['itemId']), -1)),
                              SizedBox(
                                width: 26,
                                child: Text('${numOf(item['quantity']).round()}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w800)),
                              ),
                              _qtyBtn('+', const Color(0xFF059669), Colors.white,
                                  () => updateCartQty(sOf(item['itemId']), 1)),
                              const SizedBox(width: 4),
                              _qtyBtn('✕', const Color(0xFFFFF1F2), const Color(0xFFF43F5E),
                                  () => removeFromCart(sOf(item['itemId']))),
                            ],
                          ),
                        )),
                    if (cart.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              const Text('🛒', style: TextStyle(fontSize: 34)),
                              const Text('Cart is empty',
                                  style: TextStyle(
                                      fontSize: 13, color: Color(0xFF94A3B8))),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => setState(() => showCart = false),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 8)),
                                child: const Text('Back to Menu',
                                    style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      width: double.infinity,
                      color: const Color(0xFFF8FAFC),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isTakeaway ? '🛍️ TAKE AWAY DETAILS' : 'ORDER DETAILS',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: Colors.grey.shade600)),
                          if (!isTakeaway) ...[
                            const SizedBox(height: 10),
                            const Text.rich(TextSpan(children: [
                              TextSpan(text: 'Table / Room ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569))),
                              TextSpan(text: '*',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFF43F5E))),
                            ])),
                            const SizedBox(height: 8),
                            if (noFreeTables)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: const Text(
                                    'No free tables available right now',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB45309))),
                              )
                            else ...[
                              if (floor.isNotEmpty) ...[
                                Text(
                                    '⬆️ Floor Tables (${floor.length} free)',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                        color: Color(0xFF059669))),
                                const SizedBox(height: 6),
                                _tableGrid(floor, const Color(0xFF059669),
                                    const Color(0xFFECFDF5), const Color(0xFF065F46)),
                                const SizedBox(height: 10),
                              ],
                              if (outside.isNotEmpty) ...[
                                Text(
                                    '⬇️ Outside Tables (${outside.length} free)',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                        color: Color(0xFF0284C7))),
                                const SizedBox(height: 6),
                                _tableGrid(outside, const Color(0xFF0284C7),
                                    const Color(0xFFF0F9FF), const Color(0xFF075985)),
                              ],
                            ],
                            if (tableNumber.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                    'Please select a table to place the order',
                                    style: TextStyle(
                                        fontSize: 11, color: Color(0xFFD97706))),
                              ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                              isTakeaway
                                  ? 'Customer Name (optional)'
                                  : 'Customer Name',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: customerNameCtrl,
                            style: const TextStyle(fontSize: 13),
                            decoration: _lightInput('Customer name'),
                          ),
                          const SizedBox(height: 10),
                          const Text('Notes (optional)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notesCtrl,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                            decoration: _lightInput('Order notes'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      Text('$cartTotal PKR',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_busy ||
                              cart.isEmpty ||
                              (!isTakeaway && tableNumber.isEmpty))
                          ? null
                          : () {
                              if (isTakeaway) {
                                setState(() => showPaymentPopup = true);
                              } else {
                                createOrder('Pending');
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTakeaway
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: (isTakeaway
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF059669))
                            .withValues(alpha: .45),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _busy
                            ? 'Creating...'
                            : isTakeaway
                                ? 'Place 🛍️ Take Away Order'
                                : 'Place 🍽️ Dine-In Order',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableGrid(List<Map<String, dynamic>> list, Color activeColor,
      Color idleBg, Color idleFg) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: list.map((t) {
        final label = tableLabel(t);
        final sel = tableNumber == label;
        return GestureDetector(
          onTap: () => setState(() => tableNumber = sel ? '' : label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? activeColor : idleBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? activeColor : activeColor.withValues(alpha: .35)),
            ),
            constraints: const BoxConstraints(minWidth: 64),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : idleFg)),
          ),
        );
      }).toList(),
    );
  }

  Widget _qtyBtn(String ch, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(ch,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: fg)),
      ),
    );
  }

  InputDecoration _lightInput(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF059669)),
      ),
    );
  }

  Widget _takeawayPaymentSheet() {
    final isTakeaway = activeType == 'Take Away';
    final cashVal = double.tryParse(cashCtrl.text.trim()) ?? 0;
    final cartTotalNum = numOf(cartTotal);
    final returnVal = cashVal > 0 ? cashVal - cartTotalNum : 0.0;
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Align(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Color(0xFF334155)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PAYMENT',
                              style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          Text(isTakeaway
                                  ? '🛍️ Take Away Payment'
                                  : '🍽️ Table Payment',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => showPaymentPopup = false),
                      icon: const Text('✕',
                          style: TextStyle(color: Color(0xFFCBD5E1))),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(isTakeaway ? 'Order type: Takeaway' : 'Order type: Dine-In',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                const SizedBox(height: 12),
                Row(
                  children: ['Cash', 'Card', 'Online']
                      .map((m) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => paymentMethod = m),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: paymentMethod == m
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(m,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: paymentMethod == m
                                              ? const Color(0xFF020617)
                                              : const Color(0xFFE2E8F0))),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      Text('$cartTotal PKR',
                          style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF34D399))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: cashCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Cash Received (optional)',
                    labelStyle:
                        const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: const BorderSide(color: Color(0xFF334155))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide:
                            const BorderSide(color: Color(0xFF059669))),
                  ),
                ),
                if (returnVal > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: const Color(0xFF059669).withValues(alpha: .5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('↩️ Customer Return',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA7F3D0))),
                            Text('${esc.fnum(returnVal)} PKR',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF34D399))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await createOrder(isTakeaway ? 'Pay Later' : 'Pending');
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF334155)),
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                    child: Text(_busy ? 'Saving...' : '⏳ Pay Later',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final cr =
                                double.tryParse(cashCtrl.text.trim()) ?? 0;
                            await createOrder('Completed',
                                paid: true,
                                payMethod: paymentMethod,
                                cashReceived: cr);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF059669).withValues(alpha: .45),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                    child: Text(_busy ? 'Saving...' : '💳 Pay Now ($paymentMethod)',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ordersPopup() {
    final list = popupOrders;
    final bool isTakeawayOT = isTakeawayOrderTaker;
    final Map<String, (String, int, Color)> tabs;
    if (isTakeawayOT) {
      tabs = {
        'new': ('🛍️ Pay Later', myTakeawayPayLaterOrders.length, const Color(0xFFD97706)),
        'served': ('✅ Paid', myTakeawayPaidOrders.length, const Color(0xFF059669)),
      };
    } else {
      tabs = {
        'new': ('🆕 New', myNewOrders.length, const Color(0xFFD97706)),
        'served': ('✅ Served', myServedOrders.length, const Color(0xFF059669)),
        'cancelled': ('❌ Cancelled', myCancelledOrders.length, const Color(0xFFE11D48)),
      };
    }
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 24),
              width: double.infinity,
              constraints: BoxConstraints(
                  maxWidth: 440, maxHeight: MediaQuery.of(context).size.height * 0.8),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              isTakeawayOT ? '🛍️ Takeaway Orders' : '📋 My Orders',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                        GestureDetector(
                          onTap: () => _refreshOrdersOnly(showSpin: true),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: popupRefreshing
                                ? const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Color(0xFF34D399)))
                                : const Text('🔄', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _popupTimer?.cancel();
                            setState(() => showOrdersPopup = false);
                          },
                          icon:
                              const Icon(Icons.close, size: 18, color: Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: tabs.entries.map((e) {
                        final key = e.key;
                        final label = e.value.$1;
                        final count = e.value.$2;
                        final color = e.value.$3;
                        final active = isTakeawayOT
                            ? takeawayOrdersTab == (key == 'new' ? 'pay_later' : 'paid')
                            : ordersTab == key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isTakeawayOT) {
                                    takeawayOrdersTab = key == 'new' ? 'pay_later' : 'paid';
                                  } else {
                                    ordersTab = key;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: active
                                      ? color
                                      : const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(label,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              color: active
                                                  ? Colors.white
                                                  : const Color(0xFF94A3B8))),
                                    ),
                                    if (count > 0) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: .2),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: Text('$count',
                                            style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                                color: active
                                                    ? Colors.white
                                                    : const Color(0xFF94A3B8))),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                              ordersTab == 'new'
                                  ? 'No orders yet'
                                  : ordersTab == 'served'
                                      ? 'No served orders yet'
                                      : 'No cancelled orders yet',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: list.length,
                            itemBuilder: (_, i) =>
                                _orderCard(list[i], i, list,
                                    printOnly: isTakeawayOT),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _takeawayOrdersPopup() {
    final list = takeawayPopupOrders;
    final tabs = {
      'pay_later': ('🛍️ Pay Later', myTakeawayPayLaterOrders.length, const Color(0xFFD97706)),
      'paid': ('✅ Paid', myTakeawayPaidOrders.length, const Color(0xFF059669)),
      'due': ('💰 Due', myTakeawayDueOrders.length, const Color(0xFFE11D48)),
    };
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 24),
              width: double.infinity,
              constraints: BoxConstraints(
                  maxWidth: 440, maxHeight: MediaQuery.of(context).size.height * 0.8),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('🛍️ Takeaway Orders',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                        GestureDetector(
                          onTap: () => _refreshOrdersOnly(showSpin: true),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: popupRefreshing
                                ? const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Color(0xFF34D399)))
                                : const Text('🔄', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _popupTimer?.cancel();
                            setState(() => showTakeawayOrdersPopup = false);
                          },
                          icon:
                              const Icon(Icons.close, size: 18, color: Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: tabs.entries.map((e) {
                        final key = e.key;
                        final label = e.value.$1;
                        final count = e.value.$2;
                        final color = e.value.$3;
                        final active = takeawayOrdersTab == key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setState(() => takeawayOrdersTab = key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: active
                                      ? color
                                      : const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(label,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              color: active
                                                  ? Colors.white
                                                  : const Color(0xFF94A3B8))),
                                    ),
                                    if (count > 0) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: .2),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: Text('$count',
                                            style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                                color: active
                                                    ? Colors.white
                                                    : const Color(0xFF94A3B8))),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(
                            child: Text(
                              'No takeaway orders',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: list.length,
                            itemBuilder: (_, i) =>
                                _orderCard(list[i], i, list),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String orderStateOf(Map o) {
    if (isCancelledOrder(o)) return 'cancelled';
    if (isServedOrder(o)) return 'served';
    return 'new';
  }

  Map<String, dynamic> orderTotals(Map o) {
    final items = (o['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    double subtotal = numOf(o['subtotal']);
    if (subtotal == 0) {
      subtotal = items.fold<double>(
          0,
          (s, i) =>
              s +
              (numOf(i['total']) != 0
                  ? numOf(i['total'])
                  : numOf(i['price']) * numOf(i['quantity'])));
    }
    double total = numOf(o['total']);
    if (total == 0) total = numOf(o['amount']);
    if (total == 0) total = subtotal;
    return {'subtotal': subtotal, 'total': total};
  }

  int durationBaseMs(Map o) {
    final st = orderStateOf(o);
    final iso = st == 'new'
        ? sOf(o['createdAt'])
        : st == 'served'
            ? sOf(o['servedAt'])
            : sOf(o['cancelledAt']);
    final d = DateTime.tryParse(iso);
    return d?.millisecondsSinceEpoch ?? _now.value.millisecondsSinceEpoch;
  }

  Widget _orderCard(Map<String, dynamic> o, int idx, List list, {bool printOnly = false}) {
    final id = o['id'];
    final expanded = expandedOrderId == id;
    final totals = orderTotals(o);
    final subtotal = totals['subtotal'] as double;
    final total = totals['total'] as double;
    final st = orderStateOf(o);
    final isPaid = _norm(sOf(o['paymentStatus'])) == 'paid' ||
        ['completed', 'payment collected'].contains(_norm(sOf(o['status'])));
    final requestSent = sOf(o['paymentRequestStatus']) == 'owner-request';
    final baseMs = durationBaseMs(o);
    final createdMs =
        DateTime.tryParse(sOf(o['createdAt']))?.millisecondsSinceEpoch;
    final cancelledMs =
        DateTime.tryParse(sOf(o['cancelledAt']))?.millisecondsSinceEpoch;

    Color stateColor;
    if (st == 'new') {
      stateColor = const Color(0xFFFBBF24);
    } else if (st == 'served') {
      stateColor = const Color(0xFF34D399);
    } else {
      stateColor = const Color(0xFFFB7185);
    }

    final items = (o['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: st == 'cancelled'
                ? const Color(0xFF881337)
                : const Color(0xFF1E293B)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => expandedOrderId = expanded ? null : id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('#${sOf(o['orderNumber']).isEmpty ? sOf(o['id']) : sOf(o['orderNumber'])}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF818CF8))),
                      const Spacer(),
                      if (createdMs != null && st == 'new')
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(time12(sOf(o['createdAt'])),
                              style: const TextStyle(
                                  fontSize: 9.5, color: Color(0xFF94A3B8))),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: stateColor.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: ValueListenableBuilder<DateTime>(
                          valueListenable: _now,
                          builder: (_, nowVal, __) => Text(
                              '⏱ ${formatDuration(nowVal.millisecondsSinceEpoch - baseMs)}',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: stateColor)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Text('▼',
                              style: TextStyle(
                                  fontSize: 9, color: Color(0xFF64748B))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                          st == 'new'
                              ? sOf(o['orderType'])
                              : st == 'served'
                                  ? 'Served'
                                  : 'Cancelled',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: stateColor)),
                      const Text(' • ',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      Flexible(
                        child: Text(
                            sOf(o['customerName']).isNotEmpty
                                ? sOf(o['customerName'])
                                : (sOf(o['tableNumber']).isNotEmpty
                                    ? sOf(o['tableNumber'])
                                    : '-'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF94A3B8))),
                      ),
                      const Text(' • ',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? const Color(0xFF34D399).withValues(alpha: .15)
                              : st == 'cancelled'
                                  ? const Color(0xFFFB7185).withValues(alpha: .15)
                                  : const Color(0xFFFBBF24).withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                            sOf(o['status']).isEmpty
                                ? (sOf(o['paymentStatus']).isEmpty
                                    ? 'New'
                                    : sOf(o['paymentStatus']))
                                : sOf(o['status']),
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isPaid
                                    ? const Color(0xFF34D399)
                                    : st == 'cancelled'
                                        ? const Color(0xFFFB7185)
                                        : const Color(0xFFFBBF24))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_fmtNum(total)} PKR',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF34D399))),
                      Text(expanded ? 'Hide details' : 'Tap for details',
                          style: const TextStyle(
                              fontSize: 9.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      children: [
                        ...items.map((item) {
                          final lineTotal = numOf(item['total']) != 0
                              ? numOf(item['total'])
                              : numOf(item['price']) * numOf(item['quantity']);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                Text('${numOf(item['quantity']).round()}x',
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFFBBF24))),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(sOf(item['name']),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFFE2E8F0))),
                                ),
                                Text(
                                    '${_fmtNum(numOf(item['price']))} × ${numOf(item['quantity']).round()} = ${_fmtNum(lineTotal)}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          );
                        }),
                        const Divider(color: Color(0xFF1E293B), height: 14),
                        _kvRow('Subtotal', '${_fmtNum(subtotal)} PKR'),
                        if (numOf(o['discount']) > 0)
                          _kvRow('Discount',
                              '-${_fmtNum(numOf(o['discount']))} PKR',
                              valueColor: const Color(0xFFFB7185)),
                        if (numOf(o['taxPercent']) > 0)
                          _kvRow(
                              'Tax (${_fmtNum(numOf(o['taxPercent']))}%)',
                              '${((subtotal - numOf(o['discount'])) * numOf(o['taxPercent']) / 100).toStringAsFixed(0)} PKR'),
                        if (numOf(o['serviceCharge']) > 0)
                          _kvRow('Service Charge',
                              '${_fmtNum(numOf(o['serviceCharge']))} PKR'),
                        if (numOf(o['deliveryFee']) > 0)
                          _kvRow('Delivery Fee',
                              '${_fmtNum(numOf(o['deliveryFee']))} PKR'),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFCBD5E1))),
                              Text('${_fmtNum(total)} PKR',
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF34D399))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (st == 'new') ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _actionChip('🖨️ Print', const Color(0xFF1E293B),
                            const Color(0xFFE2E8F0), () async {
                          try {
                            await printOrderBT(o);
                            toast('Order sent to printer 🖨️');
                          } catch (e) {
                            toast('Bluetooth print failed: $e', seconds: 6);
                          }
                        }),
                        if (!printOnly) ...[
                          _actionChip('✏️ Edit Order', const Color(0xFF1E293B),
                              const Color(0xFFE2E8F0), () => openEditOrder(o)),
                          _actionChip(
                              '✅ Mark Served',
                              const Color(0xFF059669),
                              Colors.white,
                              () => markServed(o)),
                          _actionChip('❌ Cancel Order', const Color(0xFFE11D48),
                              Colors.white, () => cancelOrder(o)),
                        ],
                      ],
                    ),
                  ],
                  if (st == 'served') ...[
                    const SizedBox(height: 10),
                    if (!isPaid)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF020617),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: sOf(o['paymentRequestImage']).isNotEmpty
                            ? Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _showImagePreview(
                                        sOf(o['paymentRequestImage'])),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SmartImage(
                                          src: sOf(o['paymentRequestImage']),
                                          size: 46),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('📷 Payment Photo Attached',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFFBBF24))),
                                        Text(
                                            dateTime12(
                                                sOf(o['paymentRequestedAt'])),
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: Color(0xFF64748B))),
                                        if (requestSent)
                                          const Text('✅ Request sent to Farhan Owner',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFA78BFA))),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => attachPaymentPhoto(o),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: const Text('Retake',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFE2E8F0))),
                                    ),
                                  ),
                                ],
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => attachPaymentPhoto(o),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  icon: const Text('📷',
                                      style: TextStyle(fontSize: 12)),
                                  label: const Text('Attach Payment Photo',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                      ),
                    const SizedBox(height: 8),
                    if (isPaid)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  const Color(0xFF34D399).withValues(alpha: .3)),
                        ),
                        child: Text(
                          '✅ Payment ${sOf(o['paymentMethod']).isNotEmpty ? 'collected via ${o['paymentMethod']}' : 'collected'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF34D399)),
                        ),
                      )
                    else if (requestSent)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  const Color(0xFF8B5CF6).withValues(alpha: .3)),
                        ),
                        child: Text(
                          '👤 Request sent to Farhan Owner${sOf(o['paymentMethod']).isNotEmpty ? ' (${o['paymentMethod'] == 'Online' ? '📱' : '💵'} ${o['paymentMethod']})' : ''} - awaiting approval',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFA78BFA)),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: sOf(o['paymentRequestImage']).isEmpty || _busy
                              ? null
                              : () => _pushOwnerDialog(o),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFF7C3AED).withValues(alpha: .4),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Text('👤', style: TextStyle(fontSize: 12)),
                          label: const Text('Push to Farhan Owner Request',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await printOrderBT(o);
                                toast('Order sent to printer 🖨️');
                              } catch (e) {
                                toast('Bluetooth print failed: $e', seconds: 6);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF334155)),
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: const Color(0xFFE2E8F0),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100)),
                            ),
                            icon: const Text('🖨️', style: TextStyle(fontSize: 11)),
                            label: const Text('Print',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => openEditOrder(o),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100)),
                            ),
                            icon: const Text('➕', style: TextStyle(fontSize: 11)),
                            label: const Text('Add More Items',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (st == 'cancelled') ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB7185).withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFFFB7185).withValues(alpha: .3)),
                      ),
                      child: Text(
                        '❌ Order cancelled${cancelledMs != null ? ' at ${time12(sOf(o['cancelledAt']))}' : ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFB7185)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Widget _kvRow(String k, String v, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
          Text(v,
              style: TextStyle(
                  fontSize: 10.5,
                  color: valueColor ?? const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _actionChip(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(minWidth: 120),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      ),
    );
  }

  void _pushOwnerDialog(Map o) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF334155).withValues(alpha: .6))),
        title: Row(
          children: [
            const Expanded(
              child: Text('💳 Payment Method',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, size: 18, color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(children: [
              const TextSpan(
                  text: 'Push request for order ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              TextSpan(
                  text:
                      '#${sOf(o['orderNumber']).isEmpty ? sOf(o['id']) : sOf(o['orderNumber'])}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF818CF8))),
              const TextSpan(
                  text: ' to Farhan Owner.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ])),
            const SizedBox(height: 4),
            const Text('Select how the customer will pay:',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => pushOwnerRequest(o, 'Cash'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Text('💵'),
                label: const Text('Cash',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => pushOwnerRequest(o, 'Online'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Text('📱'),
                label: const Text('Online',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String src) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: src.startsWith('data:')
                    ? Image.memory(base64Decode(src.substring(src.indexOf(',') + 1)))
                    : Image.network(
                        src.startsWith('http') ? src : '${ApiClient.host}$src'),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                child: const Text('✕ Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------- edit modal --

  Widget _editModal() {
    final eo = editOrder!;
    final allTables = availableDineInTables;
    final addList = filteredEditAddProducts;
    final qtyMap = <String, int>{};
    for (final i in editCart) {
      final key = sOf(i['productId'] ?? i['id']);
      qtyMap[key] = (qtyMap[key] ?? 0) + (numOf(i['quantity'])).round();
    }
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            width: double.infinity,
            constraints: BoxConstraints(
                maxWidth: 440, maxHeight: MediaQuery.of(context).size.height * 0.9),
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            '✏️ Edit Order #${sOf(eo['orderNumber']).isEmpty ? sOf(eo['id']) : sOf(eo['orderNumber'])}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          editOrder = null;
                          editCart = [];
                        }),
                        icon: const Icon(Icons.close,
                            size: 18, color: Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value:
                              sOf(eo['tableNumber']).isEmpty ? '' : sOf(eo['tableNumber']),
                          dropdownColor: const Color(0xFF0F172A),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFF1F5F9)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF334155))),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('Select table or room')),
                            ...allTables.map((t) {
                              final label = tableLabel(t);
                              final busy = t['isOccupied'] == true &&
                                  label != sOf(eo['tableNumber']);
                              return DropdownMenuItem(
                                  value: label,
                                  child: Text('$label${busy ? ' (Busy)' : ''}',
                                      style: const TextStyle(fontSize: 12)));
                            }),
                          ],
                          onChanged: (v) =>
                              setState(() => eo['tableNumber'] = v ?? ''),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          onChanged: (v) => eo['notes'] = v,
                          controller: TextEditingController(text: sOf(eo['notes'])),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFF1F5F9)),
                          decoration: InputDecoration(
                            hintText: 'Notes',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF334155))),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...editCart.asMap().entries.map((e) {
                          final idx = e.key;
                          final item = e.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(sOf(item['name']),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFE2E8F0))),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      final q = numOf(item['quantity']) - 1;
                                      if (q <= 0) {
                                        editCart.removeAt(idx);
                                      } else {
                                        item['quantity'] = q;
                                      }
                                    });
                                  },
                                  child: circleIcon('−'),
                                ),
                                SizedBox(
                                  width: 26,
                                  child: Text('${numOf(item['quantity']).round()}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    item['quantity'] = numOf(item['quantity']) + 1;
                                  }),
                                  child: circleIcon('+'),
                                ),
                              ],
                            ),
                          );
                        }),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('➕ Add More Items',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF34D399))),
                              const SizedBox(height: 8),
                              TextField(
                                onChanged: (v) => setState(() => editAddSearch = v),
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFFF1F5F9)),
                                decoration: InputDecoration(
                                  hintText: 'Search items to add...',
                                  hintStyle:
                                      const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: const Icon(Icons.search,
                                      size: 15, color: Color(0xFF64748B)),
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFF020617),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF334155))),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 176),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: const Color(0xFF1E293B)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: addList.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text('No items found',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B))))
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: addList.length,
                                        itemBuilder: (_, i) {
                                          final p = addList[i];
                                          final pid = sOf(p['id']);
                                          return InkWell(
                                            onTap: () => addProductToEditCart(p),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(sOf(p['name']),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            const TextStyle(
                                                                fontSize: 12,
                                                                color: Color(
                                                                    0xFFE2E8F0))),
                                                  ),
                                                  if ((qtyMap[pid] ?? 0) > 0)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              right: 6),
                                                      child: Text(
                                                          'x${qtyMap[pid]}',
                                                          style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight.w900,
                                                              color: Color(
                                                                  0xFFFBBF24))),
                                                    ),
                                                  Text(
                                                      '${_fmtNum(numOf(p['price']))} PKR',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              Color(0xFF34D399))),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF94A3B8))),
                          Text('${_fmtNum(editLiveTotal())} PKR',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF34D399))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : saveEditOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFF059669).withValues(alpha: .45),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_busy ? 'Saving...' : 'Save Changes',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget circleIcon(String ch) => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: Color(0xFF1E293B), shape: BoxShape.circle),
        child: Text(ch,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
      );
}
