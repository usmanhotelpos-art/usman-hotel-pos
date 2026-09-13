import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'session.dart';
import 'stock_photo.dart';
import 'stock_slip_builder.dart';
import 'stock_voice.dart';
import 'bt_service.dart';

const List<String> _defaultMessageTypes = [
  'Note',
  'Query',
  'Warning',
  'Instruction',
  'Important',
];

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => StockListScreenState();
}

class StockListScreenState extends State<StockListScreen> {
  List<dynamic> _orders = [];
  List<dynamic> _headings = [];
  String _headingFilter = '';
  bool _loading = true;
  String? _error;
  String _statusFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String _datePreset = '';
  bool _showFilters = false;

  List<String> _messageTypes = _defaultMessageTypes;

  @override
  void initState() {
    super.initState();
    _loadHeadings();
    _loadMessageTypes();
    _load();
  }

  Future<void> _loadMessageTypes() async {
    try {
      final types = await ApiClient.getMessageTypes(token: Session.token);
      if (types.isNotEmpty) {
        if (mounted) setState(() => _messageTypes = types.cast<String>());
      }
    } catch (_) {}
  }

  /// Called when the tab becomes visible so freshly created orders
  /// (with their photos) show up immediately.
  Future<void> refresh() async {
    await _loadHeadings();
    await _load();
  }

  Future<void> _loadHeadings() async {
    try {
      final headings = await ApiClient.getStockHeadings(token: Session.token);
      if (mounted) setState(() => _headings = headings);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final start = _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null;
      final end = _endDate != null
          ? DateFormat('yyyy-MM-dd').format(_endDate!)
          : null;
      final orders = await ApiClient.getStockOrders(
        token: Session.token,
        startDate: start,
        endDate: end,
        status: _statusFilter.isEmpty ? null : _statusFilter,
        heading: _headingFilter.isEmpty ? null : _headingFilter,
      );
      setState(() => _orders = orders);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to load orders');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _datePreset = '';
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _load();
    }
  }

  void _setDatePreset(String preset) {
    setState(() {
      _datePreset = preset;
      final now = DateTime.now();
      if (preset == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day);
      } else if (preset == 'yesterday') {
        final y = now.subtract(const Duration(days: 1));
        _startDate = DateTime(y.year, y.month, y.day);
        _endDate = DateTime(y.year, y.month, y.day);
      } else {
        _startDate = null;
        _endDate = null;
      }
    });
    _load();
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _datePreset = '';
      _statusFilter = '';
      _headingFilter = '';
    });
    _load();
  }

  Future<void> _approve(String id) async {
    try {
      await ApiClient.approveStockOrder(id, token: Session.token);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reject(String id) async {
    try {
      await ApiClient.rejectStockOrder(id, token: Session.token);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Delete stock order?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${order['orderNumber'] ?? ''} delete karein?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.deleteStockOrder(
        order['id'].toString(),
        token: Session.token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock order deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printOrder(Map<String, dynamic> order) async {
    final printer = await BtService.savedPrinter();
    if (printer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No printer configured. Go to Settings to pair.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final settings = await ApiClient.getSettings(token: Session.token);
    // Merge saved printer overrides from StockPrinterSettings
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('stockBtPrinterOverrides');
    if (raw != null && raw.isNotEmpty) {
      try {
        final overrides = Map<String, dynamic>.from(jsonDecode(raw));
        settings.addAll(overrides);
      } catch (_) {}
    }
    final bytes = buildStockSlip(order, settings);

    if (!await BtService.ensurePermission()) return;
    if (!await BtService.isConnected()) {
      if (!await BtService.connect(printer.mac)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot connect to ${printer.name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final ok = await BtService.printBytes(bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Printed successfully'
                : 'Print failed: ${BtService.lastError}',
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _filterChip(
                      icon: Icons.filter_list,
                      label: 'Filters',
                      active: _showFilters,
                      onTap: () => setState(() => _showFilters = !_showFilters),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    icon: Icons.calendar_today,
                    label: _startDate != null
                        ? DateFormat('dd MMM').format(_startDate!)
                        : 'Start',
                    onTap: () => _pickDate(true),
                    active: _startDate != null,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    icon: Icons.calendar_today,
                    label: _endDate != null
                        ? DateFormat('dd MMM').format(_endDate!)
                        : 'End',
                    onTap: () => _pickDate(false),
                    active: _endDate != null,
                  ),
                  if (_startDate != null ||
                      _endDate != null ||
                      _statusFilter.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_showFilters) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _quickChip('Today', 'today', icon: Icons.today),
                    const SizedBox(width: 8),
                    _quickChip(
                      'Yesterday',
                      'yesterday',
                      icon: Icons.chevron_left,
                    ),
                    if (_datePreset.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _quickChip('All Dates', '', icon: Icons.event_available),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statusFilterChip('All', ''),
                    const SizedBox(width: 8),
                    _statusFilterChip('Pending', 'pending'),
                    const SizedBox(width: 8),
                    _statusFilterChip('Approved', 'approved'),
                    const SizedBox(width: 8),
                    _statusFilterChip('Rejected', 'rejected'),
                  ],
                ),
                if (_headings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _headingFilterBar(),
                ],
              ],
            ],
          ),
        ),
        // Orders list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                )
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No stock orders',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF38BDF8),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (ctx, i) => _orderCard(_orders[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF38BDF8).withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF38BDF8).withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? const Color(0xFF38BDF8) : Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? const Color(0xFF38BDF8) : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusFilterChip(String label, String value) {
    final active = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = value);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF38BDF8).withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xFF38BDF8).withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? const Color(0xFF38BDF8) : Colors.white38,
          ),
        ),
      ),
    );
  }

  Widget _quickChip(String label, String value, {required IconData icon}) {
    final active = _datePreset == value;
    return GestureDetector(
      onTap: () => _setDatePreset(active ? '' : value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFF59E0B).withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xFFF59E0B).withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? const Color(0xFFF59E0B) : Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? const Color(0xFFF59E0B) : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headingFilterBar() {
    const all = 'All Headings';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 16,
            color: Colors.white.withOpacity(0.4),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: _headingFilter.isEmpty ? all : _headingFilter,
              isExpanded: true,
              isDense: true,
              underline: const SizedBox(),
              dropdownColor: const Color(0xFF1E293B),
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
              items: [
                const DropdownMenuItem(value: all, child: Text(all)),
                ..._headings.map((h) {
                  final name = (h['name'] ?? '').toString();
                  return DropdownMenuItem(
                    value: name,
                    child: Row(
                      children: [
                        stockCirclePhoto(
                          stockPhotoBytes(h['photo']),
                          fallbackIcon: Icons.label_important,
                          fallbackColor: _headingColor(name),
                          radius: 10,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (v) {
                setState(() {
                  _headingFilter = (v == null || v == all) ? '' : v;
                });
                _load();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final items = (order['items'] as List?) ?? [];
    final photoBytes = stockPhotoBytes(order['photo']);

    final isManager = Session.isManager;
    final isAdmin = Session.isAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _statusIcon(status),
                    size: 18,
                    color: _statusColor(status),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((order['heading'] ?? '').isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _headingColor('${order['heading']}')
                                    .withOpacity(0.22),
                                _headingColor('${order['heading']}')
                                    .withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _headingColor('${order['heading']}')
                                  .withOpacity(0.45),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _headingColor('${order['heading']}')
                                    .withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              stockCirclePhoto(
                                _headingPhoto('${order['heading']}'),
                                fallbackIcon: Icons.label_important,
                                fallbackColor: _headingColor(
                                  '${order['heading']}',
                                ),
                                radius: 11,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${order['heading']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: _headingColor('${order['heading']}'),
                                    letterSpacing: 0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Text(
                        order['orderNumber'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Bold highlighted date/time with glowing effect
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFF59E0B).withOpacity(0.2),
                              const Color(0xFFF97316).withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withOpacity(0.15),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_filled,
                              size: 14,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${order['date'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFBBF24),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              height: 14,
                              color: const Color(0xFFFBBF24).withOpacity(0.3),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${order['time'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFCD34D),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _statusColor(status),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              children: items.map<Widget>((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _statusColor(status).withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.inventory_2,
                            size: 18,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['productName'] ?? item['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            if ((item['description'] ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item['description'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.45),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if ((item['photo'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _itemPhotoThumb(item['photo']),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Qty: ${item['quantity']}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // Attached photo
          if (photoBytes != null) _photoSection(photoBytes),
          // Message thread
          if (_hasMessage(order)) _messageSection(order),
          // Info & Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoTag(Icons.person, 'By: ${order['addedBy'] ?? ''}'),
                    const SizedBox(width: 8),
                    if ((order['counterName'] ?? '').isNotEmpty) ...[
                      _infoTag(
                        Icons.storefront,
                        'Counter: ${order['counterName']}',
                      ),
                      const SizedBox(width: 8),
                    ],
                    if ((order['approvedBy'] ?? '').isNotEmpty)
                      _approveTag('${order['approvedBy']}'),
                  ],
                ),
                if ((order['notes'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      order['notes'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (isAdmin)
                  Column(
                    children: [
                      Row(
                        children: [
                          _printButton(order),
                          if (status == 'pending') ...[
                            const SizedBox(width: 8),
                            _approveButton(order['id']),
                            const SizedBox(width: 8),
                            _rejectButton(order['id']),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      _adminMessageButton(order),
                    ],
                  )
                else
                  Row(
                    children: [
                      _printButton(order),
                      if (isManager && status == 'pending') ...[
                        const SizedBox(width: 8),
                        _approveButton(order['id']),
                        const SizedBox(width: 8),
                        _rejectButton(order['id']),
                      ],
                      if (isManager) ...[
                        const SizedBox(width: 8),
                        _deleteButton(order),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _printButton(Map<String, dynamic> order) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _printOrder(order),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.print, size: 16, color: Colors.white54),
              SizedBox(width: 6),
              Text(
                'Print',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _approveButton(dynamic id) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _approve(id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check, size: 16, color: Color(0xFF22C55E)),
              SizedBox(width: 6),
              Text(
                'Approve',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rejectButton(dynamic id) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _reject(id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close, size: 16, color: Colors.redAccent),
              SizedBox(width: 6),
              Text(
                'Reject',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deleteButton(Map<String, dynamic> order) {
    return GestureDetector(
      onTap: () => _deleteOrder(order),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: const Icon(
          Icons.delete_outline,
          size: 18,
          color: Colors.redAccent,
        ),
      ),
    );
  }

  Widget _infoTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withOpacity(0.35)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approveTag(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 12, color: Color(0xFF22C55E)),
          const SizedBox(width: 4),
          Text(
            'Approved: $name',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF22C55E),
            ),
          ),
        ],
      ),
    );
  }

  Color _headingColor(String heading) {
    const colors = [
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFFF43F5E),
      Color(0xFF06B6D4),
    ];
    final hash = heading.codeUnits.fold<int>(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  Uint8List? _headingPhoto(String headingName) {
    if (headingName.isEmpty) return null;
    for (final h in _headings) {
      if ((h['name'] ?? '').toString() == headingName) {
        return stockPhotoBytes(h['photo']);
      }
    }
    return null;
  }

  Widget _itemPhotoThumb(dynamic raw) {
    final bytes = stockPhotoBytes(raw);
    if (bytes == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _viewPhoto(bytes),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Image.memory(bytes, width: 44, height: 44, fit: BoxFit.cover),
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.fullscreen,
                  size: 10,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewPhoto(Uint8List bytes) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoSection(Uint8List bytes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 14, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text(
                'Attached Photo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _viewPhoto(bytes),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withOpacity(0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fullscreen,
                        size: 14,
                        color: Color(0xFF38BDF8),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'View Photo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _viewPhoto(bytes),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.memory(
                    bytes,
                    width: double.infinity,
                    height: 170,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    width: double.infinity,
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0),
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fullscreen,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to view full photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  bool _hasMessage(Map<String, dynamic> order) {
    final m = order['message'];
    if (m is! Map) return false;
    if (((m['text'] ?? '') as String? ?? '').toString().trim().isNotEmpty)
      return true;
    if (((m['voice'] ?? '') as String? ?? '').toString().trim().isNotEmpty)
      return true;
    final r = m['replies'];
    return r is List && r.isNotEmpty;
  }

  Widget _messageSection(Map<String, dynamic> order) {
    final msg = (order['message'] is Map)
        ? Map<String, dynamic>.from(order['message'] as Map)
        : <String, dynamic>{};
    final repliesRaw = msg['replies'];
    final replies = (repliesRaw is List)
        ? repliesRaw
              .map(
                (r) => r is Map
                    ? Map<String, dynamic>.from(r)
                    : <String, dynamic>{},
              )
              .toList()
        : <Map<String, dynamic>>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.forum, size: 13, color: Color(0xFFA78BFA)),
                const SizedBox(width: 6),
                const Text(
                  'Message Thread',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFA78BFA),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _replyToOrder(order),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF0D9488).withOpacity(0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply, size: 12, color: Color(0xFF14B8A6)),
                        SizedBox(width: 4),
                        Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14B8A6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FractionallySizedBox(
              widthFactor: 0.88,
              alignment: Alignment.centerRight,
              child: _msgBubble(msg, orderId: order['id']),
            ),
            ...replies.asMap().entries.map(
              (e) => FractionallySizedBox(
                widthFactor: 0.88,
                alignment: Alignment.centerRight,
                child: _msgBubble(
                  e.value,
                  orderId: order['id'],
                  replyIndex: e.key,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _msgBubble(
    Map<String, dynamic> msg, {
    String? orderId,
    int? replyIndex,
  }) {
    final role = (msg['role'] ?? '').toString();
    final isAdminSide = role == 'admin';
    late final Color c;
    if (role == 'manager') {
      c = const Color(0xFF0D9488);
    } else if (role == 'cashier') {
      c = const Color(0xFFFACC15);
    } else {
      c = const Color(0xFFA78BFA);
    }
    final text = (msg['text'] ?? '').toString();
    final voiceRaw = (msg['voice'] ?? '').toString();
    final voiceBytes = voiceRaw.isNotEmpty ? stockVoiceBytes(voiceRaw) : null;
    final voiceDur = (num.tryParse('${msg['voiceDuration'] ?? 0}') ?? 0)
        .toInt();
    final sentBy = (msg['sentBy'] ?? '').toString();
    final sentAt = (msg['sentAt'] ?? '').toString();
    final type = ((msg['type'] ?? '').toString()).isEmpty
        ? (isAdminSide ? 'Note' : 'Reply')
        : (msg['type'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isAdminSide ? Icons.admin_panel_settings : Icons.person,
                size: 12,
                color: c,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  sentBy.isEmpty ? (isAdminSide ? 'Admin' : 'Staff') : sentBy,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: c,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: c,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              if (orderId != null)
                GestureDetector(
                  onTap: () => _deleteMessage(orderId, replyIndex),
                  child: Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: c.withOpacity(0.7),
                  ),
                ),
            ],
          ),
          if (voiceBytes != null) ...[
            const SizedBox(height: 6),
            VoicePlayerChip(bytes: voiceBytes, durationMs: voiceDur, color: c),
          ],
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ],
          if (sentAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sentAt,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String orderId, int? replyIndex) async {
    final okay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Delete message?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          replyIndex == null
              ? 'Yeh message (text/voice) delete karein?'
              : 'Yeh reply delete karein?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (okay != true) return;
    try {
      if (replyIndex == null) {
        await ApiClient.deleteStockOrderMessage(orderId, token: Session.token);
      } else {
        await ApiClient.deleteStockOrderReply(
          orderId,
          replyIndex,
          token: Session.token,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message removed'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _replyToOrder(Map<String, dynamic> order) async {
    final textCtrl = TextEditingController();
    String? voiceDataUrl;
    int? voiceDur;
    bool sending = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text(
              'Reply — ${order['orderNumber'] ?? ''}',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Reply likhein...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide(
                          color: Color(0xFF0D9488),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  VoiceRecorderButton(
                    color: const Color(0xFF0D9488),
                    label: 'Voice reply record',
                    onRecorded: (res) {
                      voiceDataUrl =
                          'data:audio/m4a;base64,${base64Encode(res.bytes)}';
                      voiceDur = res.durationMs;
                    },
                    onCleared: () {
                      voiceDataUrl = null;
                      voiceDur = 0;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: sending
                    ? null
                    : () async {
                        final text = textCtrl.text.trim();
                        if (text.isEmpty && voiceDataUrl == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Text ya voice likho'),
                              backgroundColor: Color(0xFFF59E0B),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => sending = true);
                        try {
                          await ApiClient.replyStockOrderMessage(
                            order['id'].toString(),
                            text: text,
                            voice: voiceDataUrl ?? '',
                            voiceDuration: voiceDur ?? 0,
                            token: Session.token,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } on ApiException catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(e.message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          setDialogState(() => sending = false);
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0D9488),
                        ),
                      )
                    : const Text(
                        'Send',
                        style: TextStyle(
                          color: Color(0xFF0D9488),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply sent'),
          backgroundColor: Colors.green,
        ),
      );
      _load();
    }
  }

  Widget _adminMessageButton(Map<String, dynamic> order) {
    final hasMsg =
        (order['message'] is Map) &&
        (((order['message']['text'] ?? '').toString()).isNotEmpty ||
            ((order['message']['voice'] ?? '').toString()).isNotEmpty);
    return GestureDetector(
      onTap: () => _adminSendMessage(order),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFA78BFA).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasMsg ? Icons.edit_note : Icons.forum_outlined,
              size: 16,
              color: const Color(0xFFA78BFA),
            ),
            const SizedBox(width: 6),
            const Text(
              'Send Message',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFA78BFA),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adminSendMessage(Map<String, dynamic> order) async {
    String type = 'Note';
    final textCtrl = TextEditingController();
    String? voiceDataUrl;
    int? voiceDur;
    bool sending = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              'Admin Message',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order: ${order['orderNumber'] ?? ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Message Type',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButton<String>(
                      value: type,
                      isExpanded: true,
                      isDense: true,
                      underline: const SizedBox(),
                      dropdownColor: const Color(0xFF1E293B),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      items: _messageTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => type = v ?? 'Note'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Message likhein...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide(
                          color: Color(0xFFA78BFA),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  VoiceRecorderButton(
                    color: const Color(0xFFA78BFA),
                    label: 'Voice message record',
                    onRecorded: (res) {
                      voiceDataUrl =
                          'data:audio/m4a;base64,${base64Encode(res.bytes)}';
                      voiceDur = res.durationMs;
                    },
                    onCleared: () {
                      voiceDataUrl = null;
                      voiceDur = 0;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: sending
                    ? null
                    : () async {
                        final text = textCtrl.text.trim();
                        if (text.isEmpty && voiceDataUrl == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Text ya voice likho'),
                              backgroundColor: Color(0xFFF59E0B),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => sending = true);
                        try {
                          await ApiClient.sendStockOrderMessage(
                            order['id'].toString(),
                            type,
                            text,
                            voice: voiceDataUrl ?? '',
                            voiceDuration: voiceDur ?? 0,
                            token: Session.token,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } on ApiException catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(e.message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          setDialogState(() => sending = false);
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFA78BFA),
                        ),
                      )
                    : const Text(
                        'Send',
                        style: TextStyle(
                          color: Color(0xFFA78BFA),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent'),
          backgroundColor: Colors.green,
        ),
      );
      _load();
    }
  }
}
