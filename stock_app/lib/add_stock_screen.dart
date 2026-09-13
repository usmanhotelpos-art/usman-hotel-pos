import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'session.dart';
import 'stock_photo.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _customNameCtrl = TextEditingController();
  final _customQtyCtrl = TextEditingController();
  final _customDescCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _addedByCtrl = TextEditingController();
  final _counterCtrl = TextEditingController();

  // Custom (manually typed) items
  final List<Map<String, String>> _customItems = [];

  List<dynamic> _headings = [];
  String _selectedHeading = '';
  bool _headingsLoading = true;

  bool _saving = false;
  bool _showApprover = false;
  String _approvedBy = '';
  String _photoDataUrl = '';

  @override
  void initState() {
    super.initState();
    _addedByCtrl.text = Session.userName;
    _loadHeadings();
  }

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customQtyCtrl.dispose();
    _customDescCtrl.dispose();
    _notesCtrl.dispose();
    _addedByCtrl.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHeadings() async {
    try {
      final headings = await ApiClient.getStockHeadings(token: Session.token);
      if (!mounted) return;
      setState(() {
        _headings = headings;
        if (_selectedHeading.isEmpty && headings.isNotEmpty) {
          _selectedHeading = (headings.first['name'] ?? '').toString();
        }
      });
    } on ApiException {
      // Heading load optional - order can proceed without heading
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _headingsLoading = false);
    }
  }

  void _addCustomItem() {
    final name = _customNameCtrl.text.trim();
    final qty = _customQtyCtrl.text.trim();
    final desc = _customDescCtrl.text.trim();
    if (name.isEmpty) {
      _showMsg('Product name likhein', isError: true);
      return;
    }
    if (qty.isEmpty || (int.tryParse(qty) ?? 0) <= 0) {
      _showMsg('Sahi quantity dalein', isError: true);
      return;
    }
    setState(() {
      _customItems.add({'name': name, 'quantity': qty, 'description': desc, 'photo': ''});
      _customNameCtrl.clear();
      _customQtyCtrl.clear();
      _customDescCtrl.clear();
    });
    _showMsg('"$name" add ho gaya');
  }

  void _removeCustomItem(int index) {
    setState(() => _customItems.removeAt(index));
  }

  Uint8List? get _photoBytes {
    if (_photoDataUrl.isEmpty) return null;
    final i = _photoDataUrl.indexOf(',');
    if (i < 0) return null;
    try {
      return base64Decode(_photoDataUrl.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _attachPhoto() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (e) {
      if (mounted) _showMsg('Photo attach failed (camera)', isError: true);
    }
  }

  void _viewPhoto() {
    final bytes = _photoBytes;
    if (bytes == null || !mounted) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
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
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attachItemPhoto(int idx) async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _customItems[idx]['photo'] = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (_) {
      if (mounted) _showMsg('Item photo attach failed (camera)', isError: true);
    }
  }

  void _viewItemPhoto(int idx) {
    final raw = _customItems[idx]['photo'] ?? '';
    if (raw.isEmpty || !mounted) return;
    final i = raw.indexOf(',');
    if (i < 0) return;
    try {
      final bytes = base64Decode(raw.substring(i + 1));
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.9),
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
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  Widget _itemPhotoAction(int idx, Map<String, String> ci) {
    final raw = ci['photo'] ?? '';
    if (raw.isEmpty) {
      return GestureDetector(
        onTap: () => _attachItemPhoto(idx),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
          ),
          child: const Icon(Icons.photo_camera, size: 16, color: Color(0xFF38BDF8)),
        ),
      );
    }
    final i = raw.indexOf(',');
    Uint8List? bytes;
    if (i >= 0) {
      try {
        bytes = base64Decode(raw.substring(i + 1));
      } catch (_) {}
    }
    if (bytes == null) {
      return GestureDetector(
        onTap: () => _attachItemPhoto(idx),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
          ),
          child: const Icon(Icons.photo_camera, size: 16, color: Color(0xFF38BDF8)),
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _viewItemPhoto(idx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: -7,
          right: -7,
          child: GestureDetector(
            onTap: () => setState(() => _customItems[idx]['photo'] = ''),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 11, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoAttach() {
    final bytes = _photoBytes;
    if (bytes == null) {
      return GestureDetector(
        onTap: _attachPhoto,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
          ),
          child: const Column(
            children: [
              Icon(Icons.photo_camera, size: 30, color: Color(0xFF38BDF8)),
              SizedBox(height: 8),
              Text(
                'Photo lene ke liye tap karein (Camera)',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _viewPhoto,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Photo attached',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap photo baraye poori photo.',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _smallPhotoAction(
                    icon: Icons.photo_camera,
                    label: 'Retake',
                    color: const Color(0xFF38BDF8),
                    onTap: _attachPhoto,
                  ),
                  const SizedBox(width: 8),
                  _smallPhotoAction(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    color: Colors.redAccent,
                    onTap: () => setState(() => _photoDataUrl = ''),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallPhotoAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_customItems.isEmpty) {
      _showMsg('Kam se kam ek item type karein', isError: true);
      return;
    }
    if (_addedByCtrl.text.trim().isEmpty) {
      _showMsg('Enter your name', isError: true);
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final ci in _customItems) {
      final qty = int.tryParse(ci['quantity'] ?? '') ?? 0;
      if (qty > 0) {
        items.add({
          'productName': ci['name'],
          'quantity': qty,
          'unit': 'pcs',
          'description': ci['description'] ?? '',
          'photo': ci['photo'] ?? '',
        });
      }
    }

    if (items.isEmpty) {
      _showMsg('Enter quantity for items', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiClient.createStockOrder(
        {
          'items': items,
          'notes': _notesCtrl.text.trim(),
          'heading': _selectedHeading,
          'addedBy': _addedByCtrl.text.trim(),
          'counterName': _counterCtrl.text.trim(),
          'approvedBy': Session.isManager ? _approvedBy : '',
          'photo': _photoDataUrl,
        },
        token: Session.token,
      );
      if (mounted) {
        _showMsg('Stock order created successfully');
        setState(() {
          _customItems.clear();
          _notesCtrl.clear();
          _photoDataUrl = '';
        });
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Heading selector
              _headingCard(),
              const SizedBox(height: 12),
              // Custom item entry
              _sectionCard(
                title: 'Naya Product Likhein (Custom)',
                icon: Icons.edit_note,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _customNameCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Product ka naam...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                              prefixIcon: Icon(Icons.inventory_2_outlined, color: Colors.white.withOpacity(0.3), size: 20),
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
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _customQtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Qty',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addCustomItem,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.add_circle, size: 22, color: Color(0xFF22C55E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Item description
                    TextField(
                      controller: _customDescCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Description (optional)...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        prefixIcon: Icon(Icons.notes, color: Colors.white.withOpacity(0.3), size: 20),
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
                    // Custom items list
                    if (_customItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Items (${_customItems.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._customItems.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final ci = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.label_important, size: 14, color: Color(0xFF22C55E)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ci['name'] ?? '',
                                            style: const TextStyle(fontSize: 13, color: Colors.white),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if ((ci['description'] ?? '').isNotEmpty)
                                            Text(
                                              ci['description'] ?? '',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white.withOpacity(0.45),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Qty: ${ci['quantity']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF22C55E),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _itemPhotoAction(idx, ci),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _removeCustomItem(idx),
                                      child: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              );
}),
                           ],
                         ),
                       ),
],
                  const SizedBox(height: 12),
                  _sectionCard(
                    title: 'Photo Attach (Camera)',
                    icon: Icons.photo_camera_outlined,
                    child: _buildPhotoAttach(),
                  ),
                  const SizedBox(height: 14),
                 Container(height: 1, color: Colors.white.withOpacity(0.08)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addedByCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDecoration('Employee Name', Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _counterCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDecoration('Counter Name', Icons.storefront_outlined),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  decoration: _inputDecoration('Notes (optional)', Icons.notes),
                ),
                const SizedBox(height: 12),
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

  Widget _headingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book, size: 16, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Text(
                'Stock Order Heading',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_headingsLoading)
            const LinearProgressIndicator(minHeight: 2, color: Color(0xFF38BDF8))
          else if (_headings.isEmpty)
            Text(
              'No headings - Manager "Add Headings" tab mein banayein',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButton<String>(
                value: _selectedHeading,
                isExpanded: true,
                isDense: true,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1E293B),
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                items: _headings.map((h) {
                  final name = (h['name'] ?? '').toString();
                  return DropdownMenuItem(
                    value: name,
                    child: Row(
                      children: [
                        stockCirclePhoto(
                          stockPhotoBytes(h['photo']),
                          fallbackIcon: Icons.label_important,
                          fallbackColor: const Color(0xFF38BDF8),
                          radius: 10,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedHeading = v);
                },
              ),
            ),
        ],
      ),
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