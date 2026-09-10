import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api.dart';
import 'session.dart';
import 'stock_slip_builder.dart';
import 'bt_service.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final start = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
      final end = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;
      final orders = await ApiClient.getStockOrders(
        token: Session.token,
        startDate: start,
        endDate: end,
        status: _statusFilter.isEmpty ? null : _statusFilter,
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
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
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
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _load();
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _statusFilter = '';
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
          content: Text(ok ? 'Printed successfully' : 'Print failed: ${BtService.lastError}'),
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
                    label: _startDate != null ? DateFormat('dd MMM').format(_startDate!) : 'Start',
                    onTap: () => _pickDate(true),
                    active: _startDate != null,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    icon: Icons.calendar_today,
                    label: _endDate != null ? DateFormat('dd MMM').format(_endDate!) : 'End',
                    onTap: () => _pickDate(false),
                    active: _endDate != null,
                  ),
                  if (_startDate != null || _endDate != null || _statusFilter.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ],
              ),
              if (_showFilters) ...[
                const SizedBox(height: 12),
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
              ],
            ],
          ),
        ),
        // Orders list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 56, color: Colors.white.withOpacity(0.15)),
                              const SizedBox(height: 12),
                              Text(
                                'No stock orders',
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
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
          color: active ? const Color(0xFF38BDF8).withOpacity(0.15) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFF38BDF8).withOpacity(0.4) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? const Color(0xFF38BDF8) : Colors.white38),
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
          color: active ? const Color(0xFF38BDF8).withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFF38BDF8).withOpacity(0.5) : Colors.white.withOpacity(0.08),
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

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final items = (order['items'] as List?) ?? [];

    final isManager = Session.isManager;

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_statusIcon(status), size: 18, color: _statusColor(status)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['orderNumber'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order['date'] ?? ''} ${order['time'] ?? ''}',
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    border: Border.all(color: _statusColor(status).withOpacity(0.15)),
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
                          child: Icon(Icons.inventory_2, size: 18, color: Color(0xFF38BDF8)),
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
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          // Info & Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoTag(Icons.person, 'By: ${order['addedBy'] ?? ''}'),
                    const SizedBox(width: 8),
                    if ((order['approvedBy'] ?? '').isNotEmpty)
                      _infoTag(Icons.check, 'By: ${order['approvedBy']}'),
                  ],
                ),
                if ((order['notes'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      order['notes'],
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Print button
                    Expanded(
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
                              Text('Print', style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Manager approve/reject
                    if (isManager && status == 'pending') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _approve(order['id']),
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
                                Text('Approve', style: TextStyle(fontSize: 12, color: Color(0xFF22C55E), fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _reject(order['id']),
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
                                Text('Reject', style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
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
          Text(text, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }
}
