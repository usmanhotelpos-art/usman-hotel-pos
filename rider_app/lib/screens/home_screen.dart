import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/order.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final Rider rider;
  final HotelSettings settings;

  const HomeScreen({super.key, required this.rider, required this.settings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Rider _rider;
  late HotelSettings _settings;
  String _riderTab = 'assigned';
  bool _loading = false;

  List<Map<String, dynamic>> _assignedOrders = [];
  List<Map<String, dynamic>> _deliveredCashOrders = [];
  List<Map<String, dynamic>> _deliveredOnlineOrders = [];
  List<Map<String, dynamic>> _newDeliveryOrders = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _availableRiders = [];
  Map<String, dynamic>? _selectedOrder;
  bool _showSummaryModal = false;
  bool _showAssignModal = false;
  Map<String, dynamic>? _selectedOrderForAssign;
  String _summaryType = 'cash';
  Map<String, dynamic>? _summaryData;

  bool get _isAdminRider => _rider.role.toLowerCase().contains('admin');

  @override
  void initState() {
    super.initState();
    _rider = widget.rider;
    _settings = widget.settings;
    _loadData();
  }

  String get _currency => _settings.currency;
  String formatCurrency(double value) => '$_currency ${value.toStringAsFixed(2)}';

  List<RiderShift> get _activeShifts => _settings.riderShifts.where((s) => s.active).toList();
  bool get _shiftActive => _activeShifts.isNotEmpty;

  String getOrderNumber(Map<String, dynamic>? order) {
    if (order == null) return 'N/A';
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    final idStr = o['id']?.toString() ?? '';
    return o['orderNumber']?.toString() ?? o['receiptNumber']?.toString() ?? o['invoiceNumber']?.toString() ?? (idStr.length > 8 ? idStr.substring(0, 8) : idStr.isEmpty ? 'N/A' : idStr);
  }

  String getCustomerName(Map<String, dynamic>? order) {
    if (order == null) return 'Customer';
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    return o['customerName']?.toString() ?? 'Customer';
  }

  String getAddress(Map<String, dynamic>? order) {
    if (order == null) return '';
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    return o['address']?.toString() ?? o['deliveryAddress']?.toString() ?? '';
  }

  String getPhone(Map<String, dynamic>? order) {
    if (order == null) return '';
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    return o['phone']?.toString() ?? o['customerPhone']?.toString() ?? '';
  }

  String getServiceType(Map<String, dynamic>? order) {
    if (order == null) return '';
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    return o['serviceType']?.toString() ?? '';
  }

  String getDeliveryAgent(Map<String, dynamic>? order) {
    if (order == null) return '';
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    return o['deliveryAgent']?.toString() ?? '';
  }

  double getDeliveryFee(Map<String, dynamic>? order) {
    if (order == null) return 0;
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    return (o['deliveryCharge'] ?? o['deliveryFee'] ?? o['serviceCharge'] ?? 0).toDouble();
  }

  double getTotal(Map<String, dynamic>? order) {
    if (order == null) return 0;
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    return (o['total'] ?? 0).toDouble();
  }

  double getSubtotal(Map<String, dynamic>? order) {
    if (order == null) return 0;
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    return (o['subtotal'] ?? 0).toDouble();
  }

  List<Map<String, dynamic>> getItems(Map<String, dynamic>? order) {
    if (order == null) return [];
    final o = order['originalOrder'] as Map<String, dynamic>? ?? order;
    final items = o['items'] as List?;
    return items?.cast<Map<String, dynamic>>() ?? [];
  }

  String _getOrderId(Map<String, dynamic>? order) {
    if (order == null) return '';
    return order['id']?.toString() ?? order['_id']?.toString() ?? order['orderId']?.toString() ?? '';
  }

  String _getOriginalOrderId(Map<String, dynamic> order) {
    final original = order['originalOrder'] as Map<String, dynamic>?;
    if (original != null) return original['id']?.toString() ?? original['_id']?.toString() ?? '';
    return _getOrderId(order);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final s = await ApiService.getSettings();
      _settings = s;
      await _loadOrders();
      if (_products.isEmpty) {
        final p = await ApiService.getProducts();
        _products = p;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadOrders() async {
    try {
      if (_riderTab == 'assigned') {
        _assignedOrders = await ApiService.getAssignedOrders(_rider.id);
      } else if (_riderTab == 'deliveredCash') {
        _deliveredCashOrders = await ApiService.getDeliveredOrders(_rider.id, 'cash');
      } else if (_riderTab == 'deliveredOnline') {
        _deliveredOnlineOrders = await ApiService.getDeliveredOrders(_rider.id, 'online');
      } else if (_riderTab == 'newOrders' && _isAdminRider) {
        final allOrders = await ApiService.getAllOrders();
        _newDeliveryOrders = allOrders.where((o) {
          final orderType = o['originalOrder']?['orderType']?.toString() ?? o['orderType']?.toString() ?? '';
          final deliveryAgent = o['originalOrder']?['deliveryAgent'] ?? o['deliveryAgent'];
          final status = o['originalOrder']?['status']?.toString() ?? o['status']?.toString() ?? '';
          return orderType == 'Delivery' && (deliveryAgent == null || status == 'Kitchen');
        }).toList();
        _availableRiders = await ApiService.getRiders();
        _availableRiders = _availableRiders.where((r) => r['id']?.toString() != _rider.id).toList();
      }
    } catch (_) {}
  }

  void _markDelivered(Map<String, dynamic> order, String paymentMethod, String paymentStatus) async {
    final orderId = _getOriginalOrderId(order);
    try {
      setState(() => _loading = true);
      final existing = order['originalOrder'] as Map<String, dynamic>? ?? order;
      await ApiService.markOrderDelivered(orderId, existing, paymentMethod, paymentStatus, _rider.name);
      _showSnackBar('Delivered successfully');
      await _loadOrders();
    } catch (e) {
      _showSnackBar('Failed: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _deleteOrder(Map<String, dynamic> order) async {
    final orderId = _getOriginalOrderId(order);
    try {
      setState(() => _loading = true);
      await ApiService.deleteOrder(orderId);
      _showSnackBar('Order deleted');
      await _loadOrders();
    } catch (e) {
      _showSnackBar('Delete failed: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _assignRider(Map<String, dynamic> order, Map<String, dynamic> selectedRider) async {
    final orderId = _getOriginalOrderId(order);
    try {
      setState(() => _loading = true);
      final existing = order['originalOrder'] as Map<String, dynamic>? ?? order;
      await ApiService.assignRiderToOrder(orderId, existing, selectedRider['name']?.toString() ?? '', selectedRider['id']?.toString() ?? '');
      _showSnackBar('Order assigned to ${selectedRider['name']}');
      setState(() { _showAssignModal = false; _selectedOrderForAssign = null; });
      await _loadOrders();
    } catch (e) {
      _showSnackBar('Failed to assign rider');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Map<String, dynamic> _calculateSummary(List<Map<String, dynamic>> orders, String type) {
    double orderTotal = 0, extrasTotal = 0, deliveryFeeTotal = 0, riderAmount = 0;

    for (final order in orders) {
      final items = getItems(order);
      double itemTotal = 0;
      double eTotal = 0;

      for (final item in items) {
        final qty = (item['quantity'] ?? 1).toInt();
        final price = (item['price'] ?? 0).toDouble();
        final amount = qty * price;
        itemTotal += amount;
        final cat = (item['category']?.toString() ?? item['name']?.toString() ?? '').toLowerCase();
        if (cat.contains('extra')) eTotal += amount;
      }

      final df = getDeliveryFee(order);
      orderTotal += itemTotal;
      extrasTotal += eTotal;
      deliveryFeeTotal += df;
      riderAmount += (type == 'cash') ? (itemTotal - eTotal) : (eTotal + df);
    }

    return {'orderTotal': orderTotal, 'extrasTotal': extrasTotal, 'deliveryFeeTotal': deliveryFeeTotal, 'riderAmount': riderAmount, 'count': orders.length};
  }

  double _riderDifference() {
    final cashAmount = _calculateSummary(_deliveredCashOrders, 'cash')['riderAmount'] as double;
    final onlineAmount = _calculateSummary(_deliveredOnlineOrders, 'online')['riderAmount'] as double;
    return cashAmount - onlineAmount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0F172A),
        child: Column(
          children: [
            _buildHeader(),
            if (_loading) const LinearProgressIndicator(backgroundColor: Color(0x33000000), color: Color(0xFFFF8C00)),
            _buildTabs(),
            Expanded(child: _buildContent()),
            if (_showSummaryModal) _buildSummaryModal(),
            if (_selectedOrder != null) _buildOrderSlipModal(),
            if (_showAssignModal) _buildAssignModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final cashData = _calculateSummary(_deliveredCashOrders, 'cash');
    final onlineData = _calculateSummary(_deliveredOnlineOrders, 'online');
    final diff = (cashData['riderAmount'] as double) - (onlineData['riderAmount'] as double);
    final diffLabel = diff < 0 ? 'RIDER HAQ' : diff > 0 ? 'USMAN HOTEL HAQ' : 'BALANCED';
    final totalDelivered = _deliveredCashOrders.length + _deliveredOnlineOrders.length;

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x33455675)))),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFFF1493)]),
                ),
                child: _settings.logo != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(_settings.logo!, fit: BoxFit.cover))
                    : const Center(child: Text('U', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Usman Hotel Rider', style: TextStyle(color: Color(0xFFFF8C00), fontSize: 11, letterSpacing: 2)),
                    Text(_settings.hotelName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _statChip('${_assignedOrders.length}', 'Assigned', const Color(0xFFFF8C00)),
              const SizedBox(width: 8),
              _statChip('$totalDelivered', 'Done', const Color(0xFF34D399)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryCard('Cash', formatCurrency(cashData['riderAmount'] as double), const Color(0xFF67E8F9), () {
                setState(() { _summaryType = 'cash'; _summaryData = _calculateSummary(_deliveredCashOrders, 'cash'); _showSummaryModal = true; });
              })),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Online', formatCurrency(onlineData['riderAmount'] as double), const Color(0xFF38BDF8), () {
                setState(() { _summaryType = 'online'; _summaryData = _calculateSummary(_deliveredOnlineOrders, 'online'); _showSummaryModal = true; });
              })),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard(diffLabel, formatCurrency(diff), diff < 0 ? const Color(0xFFF472B6) : diff > 0 ? const Color(0xFF34D399) : const Color(0xFF94A3B8), null)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.1)), color: const Color(0xCC0F172A)),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFF2563EB), child: Text(_rider.name.isNotEmpty ? _rider.name[0].toUpperCase() : 'R', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_rider.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(_rider.phone.isNotEmpty ? _rider.phone : 'No phone', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ])),
                TextButton.icon(
                  onPressed: () async {
                    await ApiService.clearToken();
                    if (mounted) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
                  },
                  icon: const Icon(Icons.logout, color: Color(0xFFF87171), size: 18),
                  label: const Text('Logout', style: TextStyle(color: Color(0xFFF87171))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0x1A1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
      ]),
    );
  }

  Widget _summaryCard(String title, String value, Color accent, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xCC0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _buildTabs() {
    final items = _isAdminRider
        ? [const _TabItem(key: 'newOrders', label: 'New Orders', icon: Icons.bolt), const _TabItem(key: 'assigned', label: 'Assigned', icon: Icons.inventory_2), const _TabItem(key: 'deliveredCash', label: 'Rider Book Cash', icon: Icons.monetization_on), const _TabItem(key: 'deliveredOnline', label: 'Rider Book Online', icon: Icons.credit_card)]
        : [const _TabItem(key: 'assigned', label: 'Assigned', icon: Icons.inventory_2), const _TabItem(key: 'deliveredCash', label: 'Rider Book Cash', icon: Icons.monetization_on), const _TabItem(key: 'deliveredOnline', label: 'Rider Book Online', icon: Icons.credit_card)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x33455675)))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((tab) {
            final isActive = _riderTab == tab.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () { setState(() => _riderTab = tab.key); _loadOrders(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: isActive ? const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFFF1493)]) : null,
                    color: isActive ? null : const Color(0xCC0F172A),
                    border: !isActive ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(tab.icon, color: isActive ? Colors.white : const Color(0xFF94A3B8), size: 18),
                    const SizedBox(width: 8),
                    Text(tab.label, style: TextStyle(color: isActive ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_riderTab == 'newOrders' && _isAdminRider) return _buildNewOrders();
    if (_riderTab == 'assigned') return _buildAssignedOrders();
    if (_riderTab == 'deliveredCash') return _buildDeliveredOrders(_deliveredCashOrders, const Color(0xFF34D399), 'Cash');
    if (_riderTab == 'deliveredOnline') return _buildDeliveredOrders(_deliveredOnlineOrders, const Color(0xFF3B82F6), 'Online');
    return const Center(child: Text('Select a tab', style: TextStyle(color: Color(0xFF94A3B8))));
  }

  Widget _buildNewOrders() {
    if (_newDeliveryOrders.isEmpty) return const Center(child: Text('No new delivery orders', style: TextStyle(color: Color(0xFF94A3B8))));
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFFFF8C00),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _newDeliveryOrders.length,
        itemBuilder: (_, i) => _buildOrderCard(_newDeliveryOrders[i], const Color(0xFFEF4444), 'New', [
          _ActionButton('Edit', Icons.edit, const Color(0xFF2563EB), () {}),
          _ActionButton('Assign', Icons.person_add, const Color(0xFF9333EA), () { setState(() { _selectedOrderForAssign = _newDeliveryOrders[i]; _showAssignModal = true; }); }),
          _ActionButton('Delete', Icons.delete, const Color(0xFFDC2626), () => _deleteOrder(_newDeliveryOrders[i])),
        ]),
      ),
    );
  }

  Widget _buildAssignedOrders() {
    if (_assignedOrders.isEmpty) return const Center(child: Text('No assigned orders', style: TextStyle(color: Color(0xFF94A3B8))));
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFFFF8C00),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _assignedOrders.length,
        itemBuilder: (_, i) {
          final order = _assignedOrders[i];
          final extras = _isAdminRider ? [
            _ActionButton('Delete', Icons.delete, const Color(0xFFDC2626), () => _deleteOrder(order)),
          ] : [];
          return _buildOrderCard(order, const Color(0xFFFF8C00), 'Go for Delivery', [
            _ActionButton('Delivered Cash', Icons.monetization_on, const Color(0xFFEAB308), () => _markDelivered(order, 'Cash', 'Receive Cash Till')),
            _ActionButton('Delivered Online', Icons.credit_card, const Color(0xFF0EA5E9), () => _markDelivered(order, 'Online', 'May be Online')),
            ...extras,
          ]);
        },
      ),
    );
  }

  Widget _buildDeliveredOrders(List<Map<String, dynamic>> orders, Color accent, String type) {
    final summary = _calculateSummary(orders, type.toLowerCase());
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rider Book $type', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            Text('$type payment records', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ]),
          ElevatedButton.icon(
            onPressed: () { setState(() { _summaryType = type.toLowerCase(); _summaryData = summary; _showSummaryModal = true; }); },
            icon: const Icon(Icons.summarize, size: 16),
            label: const Text('Summary'),
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
          ),
        ]),
      ),
      Expanded(
        child: orders.isEmpty
            ? Center(child: Text('No $type delivery records', style: const TextStyle(color: Color(0xFF94A3B8))))
            : RefreshIndicator(
                onRefresh: _loadOrders,
                color: const Color(0xFFFF8C00),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: orders.length,
                  itemBuilder: (_, i) {
                    final order = orders[i];
                    final extras = _isAdminRider ? [
                      _ActionButton('Delete', Icons.delete, const Color(0xFFDC2626), () => _deleteOrder(order)),
                    ] : [];
                    return _buildOrderCard(order, accent, 'Delivered $type', [
                      _ActionButton('View Slip', Icons.visibility, const Color(0xFF1E293B), () => setState(() => _selectedOrder = order)),
                      ...extras,
                    ]);
                  },
                ),
              ),
      ),
    ]);
  }

  Widget _buildOrderCard(Map<String, dynamic> order, Color accentColor, String statusBadge, List<_ActionButton> actions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: accentColor.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order #${getOrderNumber(order)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(getCustomerName(order), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            if (getAddress(order).isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('${getAddress(order)}${getServiceType(order).isNotEmpty ? " · ${getServiceType(order)}" : ""}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
            if (getDeliveryAgent(order).isNotEmpty) Text('Rider: ${getDeliveryAgent(order)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            if (getDeliveryFee(order) > 0) Text('Delivery fee: ${formatCurrency(getDeliveryFee(order))}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: Text(statusBadge, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text('Items: ${getItems(order).length}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(width: 16),
          Text('Total: ${formatCurrency(getTotal(order))}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        ...actions.map((a) => Padding(padding: const EdgeInsets.only(bottom: 6), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: a.onTap, icon: Icon(a.icon, size: 16), label: Text(a.label, style: const TextStyle(fontSize: 13)),
          style: ElevatedButton.styleFrom(backgroundColor: a.color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 10)),
        )))),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () => setState(() => _selectedOrder = order),
          icon: const Icon(Icons.visibility, size: 16), label: const Text('View Order Slip'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF94A3B8), side: const BorderSide(color: Color(0x33455675)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 10)),
        )),
      ]),
    );
  }

  Widget _buildOrderSlipModal() {
    final order = _selectedOrder!;
    final items = getItems(order);
    return Stack(children: [
      GestureDetector(onTap: () => setState(() => _selectedOrder = null), child: Container(color: Colors.black87)),
      Center(child: SingleChildScrollView(child: Container(
        margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x4D67E8F9))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Order Slip', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 22, fontWeight: FontWeight.w800)),
            IconButton(onPressed: () => setState(() => _selectedOrder = null), icon: const Icon(Icons.close, color: Color(0xFF67E8F9))),
          ]),
          const Divider(color: Color(0x4D67E8F9)),
          _slipField('Order ID', getOrderNumber(order)),
          _slipField('Customer', getCustomerName(order)),
          _slipField('Phone', getPhone(order)),
          _slipField('Address', getAddress(order)),
          _slipField('Service Type', getServiceType(order)),
          const SizedBox(height: 16),
          const Text('Items', style: TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.bold)),
          const Divider(color: Color(0x4D67E8F9)),
          ...items.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
            Expanded(child: Text(item['name']?.toString() ?? '', style: const TextStyle(color: Color(0xFFE2E8F0)))),
            Text('x${item['quantity'] ?? 1}', style: const TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(width: 16),
            Text(formatCurrency(((item['quantity'] ?? 1).toInt()) * ((item['price'] ?? 0).toDouble())), style: const TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.w600)),
          ]))),
          const Divider(color: Color(0x4D67E8F9)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Subtotal:', style: TextStyle(color: Color(0xFF94A3B8))),
            Text(formatCurrency(getSubtotal(order)), style: const TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.w600)),
          ]),
          if (getDeliveryFee(order) > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Delivery Fee:', style: TextStyle(color: Color(0xFF94A3B8))),
            Text(formatCurrency(getDeliveryFee(order)), style: const TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.w600)),
          ])),
          const Divider(color: Color(0x4D67E8F9)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total:', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 18, fontWeight: FontWeight.bold)),
            Text(formatCurrency(getTotal(order)), style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (_isAdminRider) ...[
              ElevatedButton.icon(onPressed: () { _deleteOrder(order); setState(() => _selectedOrder = null); }, icon: const Icon(Icons.delete, size: 16), label: const Text('Delete'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(width: 8),
            ],
            ElevatedButton(onPressed: () => setState(() => _selectedOrder = null),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: const Color(0xFF67E8F9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Close')),
          ]),
        ]),
      ))),
    ]);
  }

  Widget _slipField(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
      Expanded(child: Text(value.isNotEmpty ? value : 'N/A', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
    ]));
  }

  Widget _buildSummaryModal() {
    if (_summaryData == null) return const SizedBox();
    final data = _summaryData!;
    final diff = _riderDifference();
    final diffLabel = diff < 0 ? 'RIDER HAQ' : diff > 0 ? 'USMAN HOTEL HAQ' : 'BALANCED';
    final isCash = _summaryType == 'cash';

    return Stack(children: [
      GestureDetector(onTap: () => setState(() => _showSummaryModal = false), child: Container(color: Colors.black87)),
      Center(child: SingleChildScrollView(child: Container(
        margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)]),
          borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0x4DF472B6))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(alignment: Alignment.topRight, child: IconButton(onPressed: () => setState(() => _showSummaryModal = false), icon: const Icon(Icons.close, color: Color(0xFF94A3B8)))),
          CircleAvatar(radius: 44, backgroundColor: const Color(0x33FFFFFF),
            child: Text(diffLabel == 'RIDER HAQ' ? '-${formatCurrency(diff.abs())}' : diffLabel == 'USMAN HOTEL HAQ' ? '+${formatCurrency(diff)}' : '0', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Text(diffLabel, style: const TextStyle(color: Color(0xFFD8B4FE), fontSize: 12, letterSpacing: 3)),
          const SizedBox(height: 8),
          Text(isCash ? 'Rider Book Cash Summary' : 'Rider Book Online Summary', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(children: [
            _summaryStat('Order total', formatCurrency(data['orderTotal'] as double), const Color(0xFF67E8F9)),
            const SizedBox(width: 8),
            _summaryStat('Extras total', formatCurrency(data['extrasTotal'] as double), const Color(0xFFD8B4FE)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _summaryStat('Delivery fee', formatCurrency(data['deliveryFeeTotal'] as double), const Color(0xFF34D399)),
            const SizedBox(width: 8),
            _summaryStat(isCash ? 'Cash orders' : 'Online orders', '${data['count']}', const Color(0xFF94A3B8)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF67E8F9), Color(0xFFD8B4FE)])),
            child: Column(children: [
              Text(isCash ? 'Amount taken from rider' : 'Amount to give rider', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(formatCurrency(data['riderAmount'] as double), style: const TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ))),
    ]);
  }

  Widget _summaryStat(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xCC0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    ));
  }

  Widget _buildAssignModal() {
    return Stack(children: [
      GestureDetector(onTap: () => setState(() { _showAssignModal = false; _selectedOrderForAssign = null; }), child: Container(color: Colors.black87)),
      Center(child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x4D9333EA))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Assign Rider', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => setState(() { _showAssignModal = false; _selectedOrderForAssign = null; }), icon: const Icon(Icons.close, color: Color(0xFF94A3B8))),
          ]),
          if (_selectedOrderForAssign != null) Container(
            padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0x1A1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x339333EA))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${getOrderNumber(_selectedOrderForAssign)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text(getCustomerName(_selectedOrderForAssign), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ]),
          ),
          Expanded(
            child: _availableRiders.isEmpty
                ? const Center(child: Text('No riders available', style: TextStyle(color: Color(0xFF94A3B8))))
                : ListView.builder(
                    itemCount: _availableRiders.length,
                    itemBuilder: (_, i) {
                      final rider = _availableRiders[i];
                      return ListTile(
                        onTap: () => _assignRider(_selectedOrderForAssign!, rider),
                        title: Text(rider['name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(rider['email']?.toString() ?? '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward, color: Color(0xFF9333EA)),
                      );
                    },
                  ),
          ),
        ]),
      )),
    ]);
  }
}

class _TabItem {
  final String key;
  final String label;
  final IconData icon;
  const _TabItem({required this.key, required this.label, required this.icon});
}

class _ActionButton {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ActionButton(this.label, this.icon, this.color, this.onTap);
}
