import 'package:flutter/material.dart';

import 'api.dart';
import 'session.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _addedByCtrl = TextEditingController();

  List<dynamic> _products = [];
  List<dynamic> _filtered = [];
  final Set<String> _selectedProductIds = {};
  final Map<String, String> _selectedQtys = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _showApprover = false;
  String _approvedBy = '';

  @override
  void initState() {
    super.initState();
    _addedByCtrl.text = Session.userName;
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _addedByCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ApiClient.getProducts(token: Session.token);
      setState(() {
        _products = products;
        _filtered = products;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to load products');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = _products);
      return;
    }
    setState(() {
      _filtered = _products.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final category = (p['category'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase()) || category.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _toggleProduct(dynamic product) {
    final id = product['id'].toString();
    setState(() {
      if (_selectedProductIds.contains(id)) {
        _selectedProductIds.remove(id);
        _selectedQtys.remove(id);
      } else {
        _selectedProductIds.add(id);
        _selectedQtys[id] = '1';
      }
    });
  }

  Future<void> _save() async {
    if (_selectedProductIds.isEmpty) {
      _showMsg('Select at least one item', isError: true);
      return;
    }
    if (_addedByCtrl.text.trim().isEmpty) {
      _showMsg('Enter your name', isError: true);
      return;
    }

    final items = _selectedProductIds.map((id) {
      final product = _products.firstWhere((p) => p['id'].toString() == id);
      return {
        'productId': id,
        'productName': product['name'],
        'quantity': int.tryParse(_selectedQtys[id] ?? '') ?? 0,
        'unit': 'pcs',
      };
    }).where((i) => i['quantity'] > 0).toList();

    if (items.isEmpty) {
      _showMsg('Enter quantity for selected items', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiClient.createStockOrder(
        {
          'items': items,
          'notes': _notesCtrl.text.trim(),
          'addedBy': _addedByCtrl.text.trim(),
          'approvedBy': Session.isManager ? _approvedBy : '',
        },
        token: Session.token,
      );
      if (mounted) {
        _showMsg('Stock order created successfully');
        setState(() {
          _selectedProductIds.clear();
          _selectedQtys.clear();
          _notesCtrl.clear();
        });
        _searchCtrl.clear();
        _search('');
      }
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (e) {
      _showMsg('Failed to create stock order', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF22C55E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_box, size: 20, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Stock',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Create a new stock order',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 48, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _loadProducts, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Product search & select
                        _sectionCard(
                          title: 'Select Items',
                          icon: Icons.food_bank_outlined,
                          child: Column(
                            children: [
                              // Search box
                              TextField(
                                controller: _searchCtrl,
                                onChanged: _search,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search products...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3), size: 20),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Products list (searchable)
                              if (_filtered.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'No products found',
                                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  ),
                                )
                              else
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filtered.length,
                                    itemBuilder: (ctx, i) {
                                      final p = _filtered[i];
                                      final id = p['id'].toString();
                                      final selected = _selectedProductIds.contains(id);
                                      final stock = p['availableStock'] ?? p['stock'] ?? 0;
                                      return InkWell(
                                        onTap: () => _toggleProduct(p),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? const Color(0xFF38BDF8).withOpacity(0.1)
                                                : Colors.transparent,
                                            border: Border(
                                              bottom: BorderSide(color: Colors.white.withOpacity(0.03)),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                selected ? Icons.check_circle : Icons.circle_outlined,
                                                size: 20,
                                                color: selected ? const Color(0xFF38BDF8) : Colors.white24,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      p['name'] ?? '',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${p['category'] ?? ''} · Stock: ${stock}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white.withOpacity(0.35),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              // Selected items with quantity
                              if (_selectedProductIds.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.15)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Selected (${_selectedProductIds.length})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ..._selectedProductIds.map((id) {
                                        final product = _products.firstWhere((p) => p['id'].toString() == id);
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  product['name'] ?? '',
                                                  style: const TextStyle(fontSize: 13, color: Colors.white),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                width: 70,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: TextField(
                                                  controller: TextEditingController(text: _selectedQtys[id]),
                                                  onChanged: (v) => setState(() => _selectedQtys[id] = v),
                                                  keyboardType: TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                                  decoration: const InputDecoration(
                                                    hintText: 'Qty',
                                                    hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                                                    border: InputBorder.none,
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () => _toggleProduct(product),
                                                icon: const Icon(Icons.remove_circle_outline,
                                                    size: 18, color: Colors.redAccent),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                splashRadius: 16,
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Details card
                        _sectionCard(
                          title: 'Order Details',
                          icon: Icons.receipt_long_outlined,
                          child: Column(
                            children: [
                              // Added by
                              TextField(
                                controller: _addedByCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: _inputDecoration('Your name', Icons.person_outline),
                              ),
                              const SizedBox(height: 12),
                              // Notes
                              TextField(
                                controller: _notesCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                maxLines: 2,
                                decoration: _inputDecoration('Notes (optional)', Icons.notes),
                              ),
                              const SizedBox(height: 12),
                              // Approver (manager only)
                              if (Session.isManager) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Approve this stock',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: _showApprover,
                                      onChanged: (v) => setState(() => _showApprover = v),
                                      activeColor: const Color(0xFF38BDF8),
                                    ),
                                  ],
                                ),
                                if (_showApprover) ...[
                                  const SizedBox(height: 8),
                                  TextField(
                                    onChanged: (v) => _approvedBy = v,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: _inputDecoration('Approver name', Icons.verified_outlined),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Color(0xFF0F172A)),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'CREATE STOCK ORDER',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.3), size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}