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
import 'login_screen.dart';
import 'printer_settings_screen.dart';
import 'session.dart';

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
  'Extra': '\u{2795}', 'Dips': '\u{1F96B}', 'Sauce': '\u{1F96B}',
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
  final d = esc.applyTimeZone(raw, utcOffset);
  var h = d.hour % 12;
  if (h == 0) h = 12;
  return '$h:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String dateTime12(String? iso, {int utcOffset = 5}) {
  final raw = DateTime.tryParse(iso ?? '');
  if (raw == null) return '';
  final d = esc.applyTimeZone(raw, utcOffset);
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

  // Order types for this app (Delivery only - rider app)
  static const List<String> orderTypes = ['Delivery'];
  static const String _orderSource = 'bbq-delivery-app';
  String activeType = 'Delivery';
  final Map<String, List<Map<String, dynamic>>> carts = {
    'Delivery': [],
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

  String ordersDateRange = 'today';
  DateTime? ordersFromDate;
  DateTime? ordersToDate;

  bool showCart = false;
  bool showVariant = false;
  Map<String, dynamic>? variantProduct;
  Map<String, dynamic>? variantFlavor;
  String variantStep = 'flavors';

  bool initialLoading = true;
  bool showOrdersScreen = false;
  String ordersView = 'Delivery';
  String ordersSubTab = 'active';
  String ordersRiderFilter = '';      // biker-role rider filter for orders screen

  final ValueNotifier<DateTime> _now = ValueNotifier<DateTime>(DateTime.now());

  PrinterInfo? btInfo;
  bool btConnected = false;
  Map<String, dynamic> btOverrides = {};
  static const _btOverridesKey = 'nshBtPrinterOverrides';
  Map<String, dynamic> get btSettings =>
      <String, dynamic>{...settings, ...btOverrides};

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
        sig(orders) == sig(_appFilteredOrders(r[2] as List?)) &&
        sig(settings) == sig(_normSettings(r[3]));
  }

  List<dynamic> _appFilteredOrders(List<dynamic>? raw) {
    if (raw == null) return const [];
    return raw.where((o) {
      if (o is! Map) return false;
      return sOf(o['source']).trim().toLowerCase() == _orderSource;
    }).toList();
  }

  Future<void> _loadData({bool silent = false}) async {
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
      if (silent && initialLoading == false && _sameAsOnScreen(results)) return;
      setState(() {
        if (results[0] is List) categories = results[0] as List<dynamic>;
        if (results[1] is List) products = results[1] as List<dynamic>;
        if (results[2] is List) orders = _appFilteredOrders(results[2] as List<dynamic>);
        if (results[3] is Map) settings = _normSettings(results[3]);
        if (results[4] is List) deliveryAgents = results[4] as List<dynamic>;
        if (results[5] is List) serviceTypes = results[5] as List<dynamic>;
        if (results[6] is List) customers = results[6] as List<dynamic>;
        if (results[7] is List) deliveryLocations = results[7] as List<dynamic>;
        if (results[8] is List) ridersRecords = results[8] as List<dynamic>;
        if (results[9] is List) staffMembers = results[9] as List<dynamic>;
        if (results[10] is List) tables = results[10] as List<dynamic>;
        initialLoading = false;
      });
    } catch (e) {
      if (!silent && mounted) {
        setState(() => initialLoading = false);
        toast(e.toString());
      }
    }
  }

  Future<void> _refreshOrdersOnly() async {
    try {
      final r = await _fetch('/pos/orders?source=$_orderSource').catchError((_) => null);
      if (r is List && mounted) setState(() => orders = _appFilteredOrders(r));
    } catch (_) {}
  }

  // ---------------------------------------------------------- POS categories
  // The web POS inventory stores categories under these REAL names (mostly
  // Urdu). Naan / Roti alias matching is still used for the bread picker.
  static const List<String> _breadAliases = [
    'نان اور روٹی',
    'Naan Roti',
    'Naan',
    'Roti',
    'نان',
    'روٹی',
  ];

  bool _aliasMatch(List<String> aliases, String name) =>
      aliases.any((a) => a.toLowerCase() == name.toLowerCase());

  // Show ALL categories/items fetched from inventory, in their given order.
  List<String> get _visiblePosCats {
    final present = <String>[];
    for (final c in categories.whereType<Map>()) {
      final n = sOf(c['name']);
      if (n.isNotEmpty && !present.contains(n)) present.add(n);
    }
    return present;
  }

  List<String> get posCategories => _visiblePosCats;

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
          : (sOf(user['username']).isNotEmpty ? sOf(user['username']) : sOf(user['email']));
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
      final created = await _fetch('/pos/orders', method: 'POST', body: payload);
      if (created is Map && sOf(created['source']).trim().isEmpty) {
        final cid = sOf(created['id']);
        if (cid.isNotEmpty) {
          await _fetch('/pos/orders/$cid', method: 'PUT', body: {'source': _orderSource}).catchError((_) => null);
        }
      }
      if (orderType == 'Delivery' && selectedCustomerId.isEmpty) {
        final ph = _c('phone').text.trim();
        final ad = _c('address').text.trim();
        if (ph.isNotEmpty || ad.isNotEmpty) {
          await _fetch('/pos_customers', method: 'POST', body: {
            'name': '',
            'phone': ph,
            'address': ad,
            'serviceType': selectedZone,
            'deliveryLocation': selectedZone,
            'source': _orderSource,
          }).catchError((_) => null);
        }
      }
      if (created is Map && paid) {
        await _fetch('/pos/payments', method: 'POST', body: {
          'orderId': created['id'],
          'amount': created['total'],
          'paymentMethod': payMethod,
          'status': 'Completed',
          'description': 'Payment for order ${created['orderNumber'] ?? created['id']}',
        }).catchError((_) => null);
      }
      if (!mounted) return created is Map ? Map<String, dynamic>.from(created) : null;
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
      toast(paid
          ? 'Order created & paid \u2705'
          : orderType == 'Takeaway'
              ? 'Takeaway order (Pay Later) created \u{1F6CD}'
              : 'Order created successfully \u2705');
      if ((btConnected || btInfo != null || settings['btPrintEnabled'] == true) &&
          created is Map) {
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
      return created is Map ? Map<String, dynamic>.from(created) : null;
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
      final me = sOf(user['name']).isNotEmpty
          ? sOf(user['name'])
          : (sOf(user['username']).isNotEmpty ? sOf(user['username']) : sOf(user['email']));
      await _fetch('/pos/orders/${order['id']}', method: 'PUT', body: {...body, 'orderTaker': me});
      if (!mounted) return;
      toast('Updated \u2705');
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
      final orderId = order['id'];
      final result = await ApiClient.send('DELETE', '/pos/orders/$orderId', token: token);
      if (!mounted) return;
      if (result is Map && result['success'] == true) {
        toast('Order deleted successfully');
        await _refreshOrdersOnly();
      } else {
        toast(result?['error'] ?? 'Failed to delete order');
      }
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
      await Future.wait(ids.map((id) => ApiClient.send('DELETE', '/pos/orders/$id', token: token).catchError((_) => null)));
      if (!mounted) return;
      setState(() {
        orders = orders.whereType<Map>().where((o) => !ids.contains(sOf(o['id']))).toList();
        selectMode = false;
        _selectedOrderIds.clear();
      });
      toast('${ids.length} order(s) deleted');
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
      await Future.wait(ids.map((id) => _fetch('/pos/orders/$id', method: 'PUT', body: {'deliveryAgent': pick, 'status': 'Riders Assigned'}).catchError((_) => null)));
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
      toast('${ids.length} order(s) assigned to $pick');
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
      await Future.wait(ids.map((id) => _fetch('/pos/orders/$id', method: 'PUT', body: {'paymentStatus': 'paid', 'status': 'Delivered', 'paidAt': paidAt}).catchError((_) => null)));
      await Future.wait(list.map((o) => _fetch('/pos/payments', method: 'POST', body: {'orderId': sOf(o['id']), 'amount': o['total'] ?? o['amount'] ?? 0, 'paymentMethod': 'Cash', 'status': 'Completed', 'description': 'Bulk payment for order ${o['orderNumber'] ?? o['id']}'}).catchError((_) => null)));
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
      toast('${ids.length} order(s) marked paid');
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
      await Future.wait(ids.map((id) => _fetch('/pos/orders/$id', method: 'PUT', body: {'paymentStatus': 'Due', 'status': 'Due'}).catchError((_) => null)));
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
      toast('${ids.length} order(s) marked due');
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
    // Only staff members with a BIKER or RIDER role are synced as riders.
    // Other staff (waiters, order takers, cashiers, managers, etc.) are never shown.
    for (final s in staffMembers) {
      if (s is! Map) continue;
      final role = sOf(s['role']).toLowerCase();
      if (role.contains('biker') || role.contains('rider')) {
        final n = sOf(s['name']).trim();
        if (n.isNotEmpty) names[n] = true;
      }
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
    final uemail = sOf(user['email']).trim().toLowerCase();
    if (name.isNotEmpty && ot == name) return true;
    if (uname.isNotEmpty && ot == uname) return true;
    if (uemail.isNotEmpty && ot == uemail) return true;
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
    if (ordersSubTab == 'assigned') return deliveryAssigned;
    if (ordersSubTab == 'paid') return deliveryPaid;
    if (ordersSubTab == 'due') return deliveryDue;
    if (ordersSubTab == 'cancelled') return deliveryCancelled;
    return deliveryActive;
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

  List<Map<String, dynamic>> get filteredVisibleOrders => visibleOrders
      .where(_inOrdersDateRange)
      .where((o) {
        if (ordersRiderFilter.isEmpty) return true;
        return sOf(o['deliveryAgent']).trim() == ordersRiderFilter;
      })
      .toList();

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
                  onPressed: () => setState(() => showCart = true),
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
          Image.asset('assets/img/logo.png', width: 30, height: 30),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delivery',
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
        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.56,
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
                      width: 86, height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                          width: active ? 2.5 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: sOf(p['photo']).isNotEmpty
                            ? SmartImage(src: sOf(p['photo']), size: 86)
                            : Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(Icons.fastfood, color: Color(0xFF94A3B8), size: 34),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(p['name']?.toString() ?? '',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    const SizedBox(height: 2),
                    Text('${_fmtNum(numOf(p['price']))} PKR',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
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
          Expanded(child: GestureDetector(onTap: () => setState(() { showCart = false; showVariant = false; }), child: Container(color: Colors.black54))),
          child,
        ]),
      );

  Widget _cartSheet() {
    return _sheet(Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Row(children: [
            Text('$activeType Order', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
            const Spacer(),
            IconButton(onPressed: () => setState(() => showCart = false), icon: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...cart.map((i) => _cartItem(i)).toList(),
              const Divider(),
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
                    onPressed: () => createOrder('Delivery', paid: false),
                    icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 20),
                    label: const Text('Create Delivery Order',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
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
            if (selectedZone.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                child: const Text('Select delivery location to place order',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ]),
    ));
  }

  Widget _cartItem(Map<String, dynamic> i) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: sOf(i['photo']).isNotEmpty
              ? SmartImage(src: sOf(i['photo']), size: 44)
              : Container(width: 44, height: 44, color: const Color(0xFFF1F5F9), child: const Icon(Icons.fastfood, color: Color(0xFF94A3B8))),
        ),
        title: Text('${i['name']} ${sOf(i['flavor']).isNotEmpty ? '(${i['flavor']})' : ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text('${_fmtNum(numOf(i['price']))} PKR', style: const TextStyle(fontSize: 11, color: Color(0xFF059669))),
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
    final views = ['Delivery'];
    final subTabs = [
      const ['active', 'Active'],
      const ['assigned', 'Assigned'],
      const ['paid', 'Paid'],
      const ['due', 'Due'],
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
              const Text('Delivery Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
              const Spacer(),
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
          _ordersDateFilterBar(),
          _ordersRiderFilterBar(),
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

  Widget _ordersRiderFilterBar() {
    final riders = ridersList;
    if (riders.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('All Riders', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              selected: ordersRiderFilter.isEmpty,
              onSelected: (_) => setState(() => ordersRiderFilter = ''),
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: const Color(0xFFF1F5F9),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ordersRiderFilter.isEmpty ? Colors.white : const Color(0xFF475569)),
              side: BorderSide(color: const Color(0xFFE2E8F0)),
            ),
          ),
          ...riders.map((r) {
            final sel = ordersRiderFilter == r;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(r, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                selected: sel,
                onSelected: (_) => setState(() => ordersRiderFilter = sel ? '' : r),
                selectedColor: const Color(0xFF059669),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : const Color(0xFF475569)),
                side: BorderSide(color: const Color(0xFFE2E8F0)),
              ),
            );
          }).toList(),
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
    final total = o['total'] ?? o['amount'] ?? 0;
    final rider = sOf(o['deliveryAgent']);
    final cust = sOf(o['customerName']);
    final ot = sOf(o['orderTaker']);
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
          ListTile(
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
            leading: selectMode && _isManager()
                ? Icon(sel ? Icons.check_circle : Icons.radio_button_off, color: sel ? const Color(0xFF2563EB) : const Color(0xFF94A3B8), size: 26)
                : CircleAvatar(backgroundColor: const Color(0xFF059669).withValues(alpha: .15), child: Text(type.isNotEmpty ? type[0] : '?', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF059669)))),
            title: Text('#$num  \u00B7  $type', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            subtitle: Text(
              _isManager()
                  ? '${cust.isNotEmpty ? cust : 'Walk-in'}  \u00B7  ${ot.isNotEmpty ? ot : '\u2014'}  \u00B7  ${time12(o['createdAt'], utcOffset: esc.timeZoneOffsetFor(btSettings['receiptTimeZone']?.toString()))}'
                  : '${cust.isNotEmpty ? cust : 'Walk-in'}  \u00B7  ${time12(o['createdAt'], utcOffset: esc.timeZoneOffsetFor(btSettings['receiptTimeZone']?.toString()))}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              if (rider.isNotEmpty) Text(rider, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB))),
            ]),
          ),
          if (expanded) _orderDetail(o),
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
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _editOrder(Map<String, dynamic> o) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditOrderScreen(
        token: token,
        user: user,
        order: Map<String, dynamic>.from(o),
        riders: ridersList,
        posItems: allNashtaProducts,
        onSaved: () => _loadData(silent: true),
      ),
    ));
  }
}

// ============================================================ Edit Order Screen
class EditOrderScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final Map<String, dynamic> order;
  final List<String> riders;
  final List<Map<String, dynamic>> posItems;
  final VoidCallback onSaved;
  const EditOrderScreen({super.key, required this.token, required this.user, required this.order, required this.riders, required this.posItems, required this.onSaved});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  late List<Map<String, dynamic>> items;
  final Map<String, TextEditingController> _c = {};
  final TextEditingController _itemSearch = TextEditingController();
  String _itemQ = '';
  String status = '';
  String rider = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final raw = (widget.order['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    items = raw.map((it) => {...it, 'itemId': sOf(it['id']) + '_' + sOf(it['flavor']) + '_' + (it['quantity']?.toString() ?? '1')}).toList();
    status = sOf(widget.order['status']);
    rider = sOf(widget.order['deliveryAgent']);
    _c['phone'] = TextEditingController(text: sOf(widget.order['phone']));
    _c['address'] = TextEditingController(text: sOf(widget.order['address']));
    _c['table'] = TextEditingController(text: sOf(widget.order['tableNumber']));
    _c['notes'] = TextEditingController(text: sOf(widget.order['notes']));
  }

  @override
  void dispose() {
    _itemSearch.dispose();
    for (final c in _c.values) c.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPosItems {
    final q = _itemQ.toLowerCase().trim();
    if (q.isEmpty) return widget.posItems;
    return widget.posItems.where((p) =>
        sOf(p['name']).toLowerCase().contains(q) ||
        sOf(p['category']).toLowerCase().contains(q) ||
        sOf(p['code']).toLowerCase().contains(q)).toList();
  }

  void _addItem(Map<String, dynamic> p) {
    final existing = items.where((it) =>
        sOf(it['productId']) == sOf(p['id']) &&
        sOf(it['flavor']) == sOf(p['flavor'] ?? '')).toList();
    setState(() {
      if (existing.isNotEmpty) {
        existing.first['quantity'] = numOf(existing.first['quantity']) + 1;
      } else {
        items.add({
          'itemId': sOf(p['id']) + '_' + sOf(p['flavor'] ?? '') + '_' + DateTime.now().microsecondsSinceEpoch.toString(),
          'productId': p['id'],
          'id': p['id'],
          'name': p['name'],
          'price': numOf(p['price']),
          'quantity': 1,
          'code': sOf(p['code'] ?? ''),
          'weight': sOf(p['weight'] ?? ''),
          'flavor': sOf(p['flavor'] ?? ''),
        });
      }
      _itemQ = '';
      _itemSearch.clear();
    });
  }

  int get _total => items.fold<int>(0, (s, it) => s + (numOf(it['price']) * numOf(it['quantity'])).round());

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'items': items.map((it) => {
              'productId': it['productId'] ?? it['id'],
              'name': it['name'],
              'price': numOf(it['price']),
              'quantity': numOf(it['quantity']),
              'code': it['code'] ?? '',
              'weight': it['weight'] ?? '',
              'flavor': it['flavor'] ?? '',
            }).toList(),
        'status': status,
        'phone': _c['phone']!.text.trim(),
        'address': _c['address']!.text.trim(),
        'tableNumber': _c['table']!.text.trim(),
        'notes': _c['notes']!.text.trim(),
        'deliveryAgent': rider,
        'total': _total,
      };
      await ApiClient.send('PUT', '/pos/orders/${widget.order['id']}', token: widget.token, body: body);
      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = sOf(widget.order['orderType']);
    final num = widget.order['orderNumber']?.toString() ?? widget.order['id']?.toString() ?? '-';
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit #$num', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        actions: [
          TextButton(onPressed: _busy ? null : _save, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF059669)))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        ...items.map((it) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${it['name']} ${sOf(it['flavor']).isNotEmpty ? '(${it['flavor']})' : ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('${_fmtNum(numOf(it['price']))} PKR', style: const TextStyle(fontSize: 11, color: Color(0xFF059669))),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(onPressed: () => setState(() => it['quantity'] = (numOf(it['quantity']) - 1).clamp(0, 999)), icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626))),
                Text('${it['quantity']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                IconButton(onPressed: () => setState(() => it['quantity'] = numOf(it['quantity']) + 1), icon: const Icon(Icons.add_circle_outline, color: Color(0xFF059669))),
                IconButton(onPressed: () => setState(() => items.removeWhere((x) => x['itemId'] == it['itemId'])), icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626))),
              ]),
            )),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Items from POS',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
            const SizedBox(height: 8),
            TextField(
              controller: _itemSearch,
              onChanged: (v) => setState(() => _itemQ = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1FAE5))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF059669))),
              ),
            ),
            const SizedBox(height: 8),
            if (_filteredPosItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No items found', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _filteredPosItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _filteredPosItems[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add_box, color: Color(0xFF059669), size: 20),
                      title: Text(sOf(p['name']),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      subtitle: Text(sOf(p['category']),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      trailing: Text('${_fmtNum(numOf(p['price']))} PKR',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                      onTap: () => _addItem(p),
                    );
                  },
                ),
              ),
          ]),
        ),
        const Divider(),
        if (type == 'Delivery') ...[
          _editField('Phone', _c['phone']!, type: TextInputType.phone),
          _editField('Address', _c['address']!),
          Row(children: [
            const Text('Rider', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: widget.riders.contains(rider) ? rider : (widget.riders.isNotEmpty ? widget.riders.first : ''),
              items: ['', ...widget.riders].map((r) => DropdownMenuItem(value: r, child: Text(r.isEmpty ? 'None' : r))).toList(),
              onChanged: (v) => setState(() => rider = v ?? ''),
            ),
          ]),
        ],
        if (type == 'Table' || type == 'Dine-In') _editField('Table No', _c['table']!),
        _editField('Notes', _c['notes']!),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('$_total PKR', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
          ]),
        ),
      ]),
    );
  }

  Widget _editField(String label, TextEditingController c, {TextInputType? type}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextField(
          controller: c,
          keyboardType: type,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            filled: true, fillColor: const Color(0xFFF8FAFC), isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      );
}
