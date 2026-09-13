import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bt_service.dart';
import 'stock_slip_builder.dart';

class StockPrinterSettings extends StatefulWidget {
  const StockPrinterSettings({super.key});

  @override
  State<StockPrinterSettings> createState() => _StockPrinterSettingsState();
}

class _FontEl {
  final String id, label, sizeKey, boldKey;
  final double defaultSize;
  final bool defaultBold;
  const _FontEl(
    this.id,
    this.label,
    this.sizeKey,
    this.boldKey, {
    this.defaultSize = 20,
    this.defaultBold = false,
  });
}

class _StockPrinterSettingsState extends State<StockPrinterSettings> {
  static const String _overridesKey = 'stockBtPrinterOverrides';

  static const List<_FontEl> fontElements = [
    _FontEl(
      'header',
      'Receipt Header (Usman Hotel)',
      'stBtFontSize',
      'stBtHeaderBold',
      defaultSize: 24,
      defaultBold: true,
    ),
    _FontEl(
      'heading',
      'Slip Heading (Stock List Daily)',
      'stBtHeadingFontSize',
      'stBtHeadingBold',
      defaultSize: 18,
      defaultBold: true,
    ),
    _FontEl(
      'orderNo',
      'Order Number (SO-0001)',
      'stBtOrderNoFontSize',
      'stBtOrderNoBold',
      defaultSize: 17,
      defaultBold: true,
    ),
    _FontEl(
      'info',
      'Date / Time / Status',
      'stBtInfoFontSize',
      'stBtInfoBold',
      defaultSize: 17,
    ),
    _FontEl(
      'product',
      'Item Name',
      'stBtProductFontSize',
      'stBtProductBold',
      defaultSize: 20,
    ),
    _FontEl(
      'desc',
      'Description (QTY + Desc)',
      'stBtDescFontSize',
      'stBtDescBold',
      defaultSize: 15,
    ),
    _FontEl(
      'names',
      'Employee / Counter',
      'stBtNamesFontSize',
      'stBtNamesBold',
      defaultSize: 17,
    ),
    _FontEl(
      'footer',
      'Footer',
      'stBtFooterFontSize',
      'stBtFooterBold',
      defaultSize: 17,
    ),
  ];

  bool _loading = true;
  PrinterInfo? _savedPrinter;
  bool _btConnected = false;
  bool _btEnabled = false;
  List<PrinterInfo> _pairedDevices = [];
  String _message = '';

  String _paperWidth = '58';
  String _btEncoding = 'cp1256';
  String _receiptHeader = 'Usman Hotel';
  String _slipHeading = 'Stock List Daily';
  String _receiptFooter = 'Thank you for your business';
  bool _saving = false;

  final Map<String, double> _fontSizes = {};
  final Map<String, bool> _fontBold = {};
  final Map<String, TextEditingController> _sizeCtrls = {};

  @override
  void initState() {
    super.initState();
    _sizeCtrls.addEntries(
      fontElements.map((e) => MapEntry(e.id, TextEditingController())),
    );
    _boot();
  }

  @override
  void dispose() {
    for (final c in _sizeCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await _loadSettings();
    await _checkBluetooth();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _paperWidth = prefs.getString('st_paperWidth') ?? '58';
    _btEncoding = prefs.getString('st_encoding') ?? 'cp1256';
    _receiptHeader = prefs.getString('st_header') ?? 'Usman Hotel';
    _slipHeading = prefs.getString('st_slipHeading') ?? 'Stock List Daily';
    _receiptFooter =
        prefs.getString('st_footer') ?? 'Thank you for your business';

    Map<String, dynamic> ov = {};
    final raw = prefs.getString(_overridesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        ov = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }

    for (final el in fontElements) {
      double size = el.defaultSize;
      final ovSize = ov[el.sizeKey];
      if (ovSize is num && ovSize != 0) size = ovSize.toDouble();
      _fontSizes[el.id] = size.clamp(1.0, 200.0).toDouble();
      _sizeCtrls[el.id]?.text = _fontSizes[el.id]!.round().toString();
      bool bold = el.defaultBold;
      if (ov[el.boldKey] != null) bold = ov[el.boldKey] == true;
      _fontBold[el.id] = bold;
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('st_paperWidth', _paperWidth);
      await prefs.setString('st_encoding', _btEncoding);
      await prefs.setString('st_header', _receiptHeader);
      await prefs.setString('st_slipHeading', _slipHeading);
      await prefs.setString('st_footer', _receiptFooter);
      await prefs.setString(_overridesKey, jsonEncode(_buildSettingsMap()));
      if (mounted) _showMsg('Settings saved');
    } catch (e) {
      if (mounted) _showMsg('Save failed: $e', seconds: 5);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkBluetooth() async {
    _btEnabled = await BtService.isBluetoothEnabled();
    if (_btEnabled) {
      _savedPrinter = await BtService.savedPrinter();
      _pairedDevices = await BtService.getPairedDevices();
      _btConnected = await BtService.isConnected();
    }
    if (mounted) setState(() {});
  }

  void _showMsg(String msg, {int seconds = 3}) {
    if (!mounted) return;
    setState(() => _message = msg);
    Timer(Duration(seconds: seconds), () {
      if (mounted && _message == msg) setState(() => _message = '');
    });
  }

  void _setSize(String id, double v) {
    if (v < 1) v = 1;
    if (v > 200) v = 200;
    setState(() {
      _fontSizes[id] = v;
      _sizeCtrls[id]?.text = v.round().toString();
    });
  }

  Map<String, dynamic> _buildSettingsMap() {
    final m = <String, dynamic>{
      'receiptPaperWidth': _paperWidth,
      'btEncoding': _btEncoding,
      'receiptHeader': _receiptHeader,
      'slipHeading': _slipHeading,
      'receiptFooter': _receiptFooter,
    };
    for (final el in fontElements) {
      m[el.sizeKey] = (_fontSizes[el.id] ?? el.defaultSize).round();
      m[el.boldKey] = _fontBold[el.id] == true;
    }
    return m;
  }

  Future<void> _testPrint() async {
    if (!(await BtService.ensurePermission())) {
      _showMsg('Bluetooth permission denied', seconds: 4);
      return;
    }
    final printer = _savedPrinter;
    if (printer == null) {
      _showMsg('Pehle printer select karein', seconds: 4);
      return;
    }
    _showMsg('Testing print...');
    final testOrder = <String, dynamic>{
      'id': 'TEST-001',
      'orderNumber': 'SO-20260911-0001',
      'status': 'pending',
      'date': '2026-09-11',
      'time': '12:00',
      'addedBy': 'Rashid',
      'counterName': 'Counter 1',
      'heading': 'Morning',
      'items': [
        {'productName': 'Chicken', 'quantity': 10, 'description': 'Whole fry'},
        {'productName': 'Oil', 'quantity': 5, 'description': ''},
      ],
    };
    try {
      if (!(await BtService.isConnected())) {
        final ok = await BtService.connect(printer.mac);
        if (!ok) throw Exception('Connect failed');
      }
      final bytes = buildStockSlip(testOrder, _buildSettingsMap());
      await BtService.printBytes(bytes);
      _showMsg('Test print sent!');
    } catch (err) {
      await BtService.disconnect();
      try {
        final ok = await BtService.connect(printer.mac);
        if (ok) {
          final bytes = buildStockSlip(testOrder, _buildSettingsMap());
          await BtService.printBytes(bytes);
          _showMsg('Test print sent (reconnected)');
        } else {
          _showMsg('Print failed: $err', seconds: 5);
        }
      } catch (e) {
        _showMsg('Print failed: $e', seconds: 5);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          _buildHeader(),
          if (_message.isNotEmpty) _buildMessageBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildConnectionCard(),
                const SizedBox(height: 12),
                _buildPrintCard(),
                const SizedBox(height: 12),
                _buildFontCard(),
                const SizedBox(height: 12),
                _buildTestCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.print, color: Color(0xFF38BDF8), size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Printer Settings',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _saving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'SAVE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
        ),
        child: Text(
          _message,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF22C55E),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Color(0xFF38BDF8)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF38BDF8),
            activeTrackColor: const Color(0xFF38BDF8).withOpacity(0.3),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drop(
    String label,
    String value,
    List<String> opts,
    ValueChanged<String> onChanged, {
    Map<String, String>? labels,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1E293B),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
                items: opts
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(labels?[o] ?? o),
                      ),
                    )
                    .toList(),
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

  Widget _text(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    String hint = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
              ),
            ),
            onSubmitted: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Bluetooth Printer'),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _btConnected
                      ? const Color(0xFF22C55E)
                      : (_btEnabled ? Colors.amber : Colors.red),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _btEnabled
                          ? (_savedPrinter != null
                                ? _savedPrinter!.name
                                : 'No printer selected')
                          : 'Bluetooth is OFF',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _btConnected
                          ? 'Connected'
                          : '${_pairedDevices.length} paired devices',
                      style: TextStyle(
                        fontSize: 12,
                        color: _btConnected
                            ? const Color(0xFF22C55E)
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectPrinter,
                  icon: const Icon(Icons.bluetooth_searching, size: 16),
                  label: Text(
                    _savedPrinter != null ? 'Change' : 'Select Printer',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_savedPrinter != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disconnectPrinter,
                    icon: const Icon(
                      Icons.bluetooth_disabled,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Disconnect',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrintCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Print Options'),
          _drop('Paper Width', _paperWidth, [
            '58',
            '80',
          ], (v) => setState(() => _paperWidth = v)),
          _drop(
            'Encoding',
            _btEncoding,
            ['utf-8', 'cp1256', 'cp864', 'bmp'],
            (v) => setState(() => _btEncoding = v),
            labels: const {
              'utf-8': 'UTF-8',
              'cp1256': 'CP-1256 (Arabic)',
              'cp864': 'CP-864 (Arabic)',
              'bmp': 'BMP Fonts (Raster Image)',
            },
          ),
          _text(
            'Receipt Header',
            _receiptHeader,
            (v) => setState(() => _receiptHeader = v),
          ),
          _text(
            'Slip Heading',
            _slipHeading,
            (v) => setState(() => _slipHeading = v),
          ),
          _text(
            'Receipt Footer',
            _receiptFooter,
            (v) => setState(() => _receiptFooter = v),
          ),
        ],
      ),
    );
  }

  Widget _buildFontCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Font & Style (size 1-200)'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Har line ka apna size aur bold set karein. Bara size printer pe text 2x / 3x bana deta hai.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),
          ...fontElements.map((el) => _fontElementCard(el)),
        ],
      ),
    );
  }

  Widget _fontElementCard(_FontEl el) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            el.label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Size',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  size: 18,
                  color: Color(0xFF38BDF8),
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _setSize(el.id, (_fontSizes[el.id] ?? el.defaultSize) - 1),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _sizeCtrls[el.id],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  onSubmitted: (v) =>
                      _setSize(el.id, double.tryParse(v) ?? el.defaultSize),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: Color(0xFF38BDF8),
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _setSize(el.id, (_fontSizes[el.id] ?? el.defaultSize) + 1),
              ),
              const SizedBox(width: 8),
              _miniToggle(
                'Bold',
                _fontBold[el.id] == true,
                (v) => setState(() => _fontBold[el.id] = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Test Print'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savedPrinter != null ? _testPrint : null,
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Send Test Receipt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPrinter() async {
    if (!(await BtService.ensurePermission())) {
      _showMsg('Bluetooth permission denied', seconds: 4);
      return;
    }
    if (!_btEnabled) {
      _showMsg('Bluetooth is OFF', seconds: 4);
      return;
    }
    final list = await BtService.getPairedDevices();
    if (!mounted) return;
    if (list.isEmpty) {
      _showMsg('No paired printers found', seconds: 5);
      return;
    }
    PrinterInfo? picked = await showModalBottomSheet<PrinterInfo>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Bluetooth Printer',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            ...list.map(
              (p) => ListTile(
                leading: const Icon(Icons.print, color: Color(0xFF38BDF8)),
                title: Text(
                  p.name,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                subtitle: Text(
                  p.mac,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                trailing: _savedPrinter?.mac == p.mac
                    ? const Icon(Icons.check_circle, color: Color(0xFF38BDF8))
                    : null,
                onTap: () => Navigator.pop(ctx, p),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      await BtService.savePrinter(picked);
      _savedPrinter = picked;
      final connected = await BtService.connect(picked.mac);
      _btConnected = connected;
      _showMsg(
        connected ? 'Connected: ${picked.name}' : 'Selected but not connected',
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _disconnectPrinter() async {
    await BtService.disconnect();
    await BtService.clearPrinter();
    _savedPrinter = null;
    _btConnected = false;
    _showMsg('Printer disconnected');
    if (mounted) setState(() {});
  }
}
