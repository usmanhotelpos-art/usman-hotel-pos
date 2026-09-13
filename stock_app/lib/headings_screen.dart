import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'session.dart';
import 'stock_photo.dart';

class HeadingsScreen extends StatefulWidget {
  const HeadingsScreen({super.key});

  @override
  State<HeadingsScreen> createState() => _HeadingsScreenState();
}

class _HeadingsScreenState extends State<HeadingsScreen> {
  final _nameCtrl = TextEditingController();

  List<dynamic> _headings = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _photoDataUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headings = await ApiClient.getStockHeadings(token: Session.token);
      setState(() => _headings = headings);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to load headings');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showMsg('Heading name likhein', isError: true);
      return;
    }
    if (_headings.any((h) => (h['name'] ?? '').toString().trim() == name)) {
      _showMsg('Ye heading pehle se hai', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.createStockHeading(
        name,
        photo: _photoDataUrl,
        token: Session.token,
      );
      _nameCtrl.clear();
      setState(() => _photoDataUrl = '');
      _showMsg('Heading add ho gaya');
      _load();
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (e) {
      _showMsg('Failed to add heading', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Uint8List? get _photoBytes => stockPhotoBytes(_photoDataUrl);

  Future<void> _attachPhoto() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
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
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoAttach() {
    final bytes = _photoBytes;
    return Row(
      children: [
        stockCirclePhoto(
          bytes,
          fallbackIcon: Icons.photo_camera,
          fallbackColor: const Color(0xFF8B5CF6),
          radius: 34,
          onTap: bytes == null ? _attachPhoto : _viewPhoto,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bytes == null
                    ? 'Heading ke saath photo (Camera)'
                    : 'Heading photo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bytes == null
                    ? 'Circle par tap karke photo lein'
                    : 'Circle par tap karke poori photo dekhein',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              if (bytes != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _smallAction(
                      icon: Icons.photo_camera,
                      label: 'Retake',
                      color: const Color(0xFF8B5CF6),
                      onTap: _attachPhoto,
                    ),
                    const SizedBox(width: 8),
                    _smallAction(
                      icon: Icons.delete_outline,
                      label: 'Remove',
                      color: Colors.redAccent,
                      onTap: () => setState(() => _photoDataUrl = ''),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallAction({
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(dynamic heading) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Delete heading?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "'${heading['name'] ?? ''}' delete karein?",
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
      await ApiClient.deleteStockHeading(
        heading['id'].toString(),
        token: Session.token,
      );
      _showMsg('Heading deleted');
      _load();
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
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
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book,
                  size: 20,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Headings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Stock order headings yahan banayein / delete karein',
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
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                )
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off,
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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Add heading
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.add_chart,
                                size: 16,
                                color: Color(0xFF8B5CF6),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Naya Heading',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameCtrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Heading name...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                              ),
                              prefixIcon: Icon(
                                Icons.menu_book_outlined,
                                color: Colors.white.withOpacity(0.3),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF8B5CF6),
                                  width: 1.2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _add(),
                          ),
                          const SizedBox(height: 14),
                          _buildPhotoAttach(),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _add,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'ADD HEADING',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Heading list
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Headings (${_headings.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_headings.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Koi heading nahi',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._headings.asMap().entries.map((entry) {
                              final h = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    stockCirclePhoto(
                                      stockPhotoBytes(h['photo']),
                                      fallbackIcon: Icons.label_important,
                                      fallbackColor: _headingColor(
                                        h['name'] ?? '',
                                      ),
                                      radius: 14,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        h['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _delete(h),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
        ),
      ],
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
}
