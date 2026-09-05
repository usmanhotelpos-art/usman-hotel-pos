import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'bmp_receipt.dart' as bmp;
import 'bt_service.dart';
import 'escpos.dart' as esc;

class OrderTakerPrinterSettings extends StatefulWidget {
  const OrderTakerPrinterSettings({super.key});

  @override
  State<OrderTakerPrinterSettings> createState() => _OrderTakerPrinterSettingsState();
}

class _FontEl {
  final String id, label, sizeKey, boldKey, italicKey, familyKey;
  final double defaultSize;
  final bool defaultBold;
  const _FontEl(this.id, this.label, this.sizeKey, this.boldKey, this.italicKey,
      this.familyKey,
      {this.defaultSize = 20, this.defaultBold = false});
}

class _OrderTakerPrinterSettingsState extends State<OrderTakerPrinterSettings> {
  // Same key OrderTakerScreen reads its print overrides from, so that the
  // settings saved here are actually applied to real order prints.
  static const String _overridesKey = 'nshBtPrinterOverrides';

  static const accent = Color(0xFFF5C542);
  static const bg = Color(0xFFF8FAFC);
  static const cardBg = Colors.white;
  static const panel = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const txtDim = Color(0xFF64748B);
  static const txtDark = Color(0xFF1E293B);

  static const List<String> fontOptions = [
    'Noto Naskh Arabic (Urdu)',
    'Sans-serif',
    'Serif',
    'Monospace',
  ];

  // Every text element on the receipt gets its own size (1-200), bold,
  // italic and font-family/style setting.
  static const List<_FontEl> fontElements = [
    _FontEl('header', 'Receipt Header', 'btFontSize', 'btHeaderBold',
        'btHeaderItalic', 'btHeaderFontFamily',
        defaultSize: 22, defaultBold: true),
    _FontEl('info', 'Info Lines', 'btInfoFontSize', 'btInfoBold',
        'btInfoItalic', 'btInfoFontFamily', defaultSize: 17),
    _FontEl('orderType', 'Order Type', 'btOrderTypeFontSize',
        'btOrderTypeBold', 'btOrderTypeItalic', 'btOrderTypeFontFamily',
        defaultSize: 18),
    _FontEl('serviceType', 'Service Type', 'btServiceTypeFontSize',
        'btServiceTypeBold', 'btServiceTypeItalic', 'btServiceTypeFontFamily',
        defaultSize: 16),
    _FontEl('location', 'Location', 'btLocationFontSize', 'btLocationBold',
        'btLocationItalic', 'btLocationFontFamily', defaultSize: 14),
    _FontEl('customer', 'Customer / Table', 'btCustomerFontSize',
        'btCustomerBold', 'btCustomerItalic', 'btCustomerFontFamily',
        defaultSize: 12),
    _FontEl('deliveryAddress', 'Delivery Address', 'btDeliveryAddressFontSize',
        'btDeliveryAddressBold', 'btDeliveryAddressItalic',
        'btDeliveryAddressFontFamily', defaultSize: 12),
    _FontEl('product', 'Product Items', 'btProductFontSize', 'btProductBold',
        'btProductItalic', 'btProductFontFamily', defaultSize: 20),
    _FontEl('qty', 'Qty', 'btQtyFontSize', 'btQtyBold', 'btQtyItalic',
        'btQtyFontFamily', defaultSize: 20),
    _FontEl('line', 'Totals Lines', 'btLineFontSize', 'btLineBold',
        'btLineItalic', 'btLineFontFamily', defaultSize: 17),
    _FontEl('totalDue', 'Total Due / Return', 'btTotalDueFontSize',
        'btTotalDueBold', 'btTotalDueItalic', 'btTotalDueFontFamily',
        defaultSize: 22, defaultBold: true),
    _FontEl('total', 'Total', 'btTotalFontSize', 'btTotalBold',
        'btTotalItalic', 'btTotalFontFamily',
        defaultSize: 26, defaultBold: true),
    _FontEl('notes', 'Notes (Remarks)', 'btNotesFontSize', 'btNotesBold',
        'btNotesItalic', 'btNotesFontFamily', defaultSize: 12),
    _FontEl('footer', 'Footer', 'btFooterFontSize', 'btFooterBold',
        'btFooterItalic', 'btFooterFontFamily', defaultSize: 17),
    _FontEl('paid', 'PAID Stamp', 'btPaidFontSize', 'btPaidBold',
        'btPaidItalic', 'btPaidFontFamily',
        defaultSize: 12, defaultBold: true),
    _FontEl('token', 'Token Number', 'btTokenFontSize', 'btTokenBold',
        'btTokenItalic', 'btTokenFontFamily',
        defaultSize: 44, defaultBold: true),
    _FontEl('tokenLabel', 'Token Label', 'btTokenLabelFontSize',
        'btTokenLabelBold', 'btTokenLabelItalic', 'btTokenLabelFontFamily',
        defaultSize: 14, defaultBold: true),
  ];

  bool _loading = true;
  PrinterInfo? _savedPrinter;
  bool _btConnected = false;
  bool _btEnabled = false;
  List<PrinterInfo> _pairedDevices = [];
  String _message = '';

  String _paperWidth = '58';
  String _btEncoding = 'bmp';
  String _receiptHeader = 'Usman Hotel';
  String _receiptFooter = 'Thank you for your business';
  String _slipPrefix = 'UH';
  String _currency = 'PKR';
  String _btDividerStyle = 'dashed';
  bool _tokenSlipEnabled = true;
  bool _btTokenOnDineIn = true;
  bool _btTokenOnTakeaway = true;
  bool _btTokenOnDelivery = true;
  bool _btLogoEnabled = true;
  bool _btShowNotes = true;
  bool _autoPrintEnabled = false;
  String _btTextAlign = 'center';
  bool _saving = false;

  final Map<String, double> _fontSizes = {};
  final Map<String, bool> _fontBold = {};
  final Map<String, bool> _fontItalic = {};
  final Map<String, String> _fontFamily = {};
  final Map<String, TextEditingController> _sizeCtrls = {};

  @override
  void initState() {
    super.initState();
    _sizeCtrls.addEntries(
        fontElements.map((e) => MapEntry(e.id, TextEditingController())));
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
    _paperWidth = prefs.getString('ot_paperWidth') ?? '58';
    _btEncoding = prefs.getString('ot_encoding') ?? 'cp1256';
    _receiptHeader = prefs.getString('ot_header') ?? 'Usman Hotel';
    _receiptFooter = prefs.getString('ot_footer') ?? 'Thank you for your business';
    _slipPrefix = prefs.getString('ot_slipPrefix') ?? 'UH';
    _currency = prefs.getString('ot_currency') ?? 'PKR';
    _btDividerStyle = prefs.getString('ot_dividerStyle') ?? 'dashed';
    _btTextAlign = prefs.getString('ot_textAlign') ?? 'center';
    _tokenSlipEnabled = prefs.getBool('ot_tokenEnabled') ?? true;
    _btTokenOnDineIn = prefs.getBool('ot_tokenOnDineIn') ?? true;
    _btTokenOnTakeaway = prefs.getBool('ot_tokenOnTakeaway') ?? true;
    _btTokenOnDelivery = prefs.getBool('ot_tokenOnDelivery') ?? true;
    _btLogoEnabled = prefs.getBool('ot_logoEnabled') ?? true;
    _btShowNotes = prefs.getBool('ot_showNotes') ?? true;
    _autoPrintEnabled = prefs.getBool('ot_autoPrint') ?? false;

    // Legacy categorical font prefs (kept from older versions).
    double legacySize(String key) {
      switch ((prefs.getString(key) ?? '').toLowerCase()) {
        case 'small':
          return 17;
        case 'normal':
          return 20;
        case 'large':
          return 24;
        case 'xlarge':
          return 30;
        default:
          return 0;
      }
    }

    // Previously saved overrides map (source of truth for numeric fonts).
    Map<String, dynamic> ov = {};
    final raw = prefs.getString(_overridesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        ov = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }

    for (final el in fontElements) {
      double size = el.defaultSize;
      if (el.sizeKey == 'btFontSize' && legacySize('ot_fontSize') != 0) {
        size = legacySize('ot_fontSize');
      } else if (el.sizeKey == 'btProductFontSize' &&
          legacySize('ot_productFontSize') != 0) {
        size = legacySize('ot_productFontSize');
      } else if (el.sizeKey == 'btTotalFontSize' &&
          legacySize('ot_totalFontSize') != 0) {
        size = legacySize('ot_totalFontSize');
      }
      final ovSize = ov[el.sizeKey];
      if (ovSize is num && ovSize != 0) size = ovSize.toDouble();
      _fontSizes[el.id] = size.clamp(1.0, 200.0).toDouble();
      _sizeCtrls[el.id]?.text = _fontSizes[el.id]!.round().toString();
      bool bold = el.defaultBold;
      if (ov[el.boldKey] != null) bold = ov[el.boldKey] == true;
      _fontBold[el.id] = bold;
      final italic = ov[el.italicKey] == true;
      _fontItalic[el.id] = italic;
      final fam = sOf(ov[el.familyKey]);
      _fontFamily[el.id] = fam.isEmpty
          ? (el.id == 'header' || el.id == 'product' || el.id == 'total'
              ? 'Noto Naskh Arabic (Urdu)'
              : 'Noto Naskh Arabic (Urdu)')
          : fam;
    }
    if (mounted) setState(() {});
  }

  String sOf(dynamic v) => v == null ? '' : v.toString();

  Future<void> _saveSettings() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ot_paperWidth', _paperWidth);
      await prefs.setString('ot_encoding', _btEncoding);
      await prefs.setString('ot_header', _receiptHeader);
      await prefs.setString('ot_footer', _receiptFooter);
      await prefs.setString('ot_slipPrefix', _slipPrefix);
      await prefs.setString('ot_currency', _currency);
      await prefs.setString('ot_dividerStyle', _btDividerStyle);
      await prefs.setString('ot_textAlign', _btTextAlign);
      await prefs.setBool('ot_tokenEnabled', _tokenSlipEnabled);
      await prefs.setBool('ot_tokenOnDineIn', _btTokenOnDineIn);
      await prefs.setBool('ot_tokenOnTakeaway', _btTokenOnTakeaway);
      await prefs.setBool('ot_tokenOnDelivery', _btTokenOnDelivery);
      await prefs.setBool('ot_logoEnabled', _btLogoEnabled);
      await prefs.setBool('ot_showNotes', _btShowNotes);
      await prefs.setBool('ot_autoPrint', _autoPrintEnabled);
      // Push the resolved settings map to the SAME key OrderTakerScreen reads
      // for its print overrides, so saved settings actually apply to prints.
      await prefs.setString(_overridesKey, jsonEncode(_buildSettingsMap()));
      if (mounted) _showMsg('Settings saved \u2713');
    } catch (e) {
      if (mounted) _showMsg('Save failed: $e', seconds: 5);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkBluetooth() async {
    _btEnabled = await BtService.bluetoothEnabled();
    if (_btEnabled) {
      _savedPrinter = await BtService.savedPrinter();
      _pairedDevices = await BtService.pairedPrinters();
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
      'btDividerStyle': _btDividerStyle,
      'btEncoding': _btEncoding,
      'receiptHeader': _receiptHeader,
      'receiptFooter': _receiptFooter,
      'slipPrefix': _slipPrefix,
      'currency': _currency,
      'tokenSlipEnabled': _tokenSlipEnabled,
      'btTokenOnDineIn': _btTokenOnDineIn,
      'btTokenOnTakeaway': _btTokenOnTakeaway,
      'btTokenOnDelivery': _btTokenOnDelivery,
      'btLogoEnabled': _btLogoEnabled,
      'btTextAlign': _btTextAlign,
      'receiptShowNotes': _btShowNotes,
      'receiptShowReceiptNumber': true,
      'receiptShowDateTime': true,
      'receiptShowProductQuantity': true,
      'receiptShowProductUnitPrice': true,
      'receiptShowSubtotal': true,
      'receiptShowDiscount': true,
      'receiptShowTax': true,
      'receiptShowTotal': true,
    };
    for (final el in fontElements) {
      m[el.sizeKey] = (_fontSizes[el.id] ?? el.defaultSize).round();
      m[el.boldKey] = _fontBold[el.id] == true;
      m[el.italicKey] = _fontItalic[el.id] == true;
      m[el.familyKey] = _fontFamily[el.id] ?? 'Noto Naskh Arabic (Urdu)';
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
      'id': 'TEST-001', 'orderNumber': 'TEST-001',
      'orderType': 'Dine-In', 'status': 'Pending',
      'tableNumber': 'T-1', 'customerName': 'Test',
      'waiter': 'Waiter', 'orderTaker': 'Waiter',
      'notes': 'Extra bara burger, na hamari baqi note yahan ayi.',
      'date': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'items': [
        {'name': 'Chicken Karahi', 'quantity': 2, 'price': 850, 'total': 1700},
        {'name': 'Naan', 'quantity': 4, 'price': 40, 'total': 160},
      ],
      'subtotal': 1860, 'total': 1860, 'amount': 1860,
      'paymentMethod': 'Cash', 'paymentStatus': 'Unpaid',
    };
    final sm = _buildSettingsMap();
    Future<void> attempt() async {
      if (!(await BtService.isConnected())) {
        final ok = await BtService.connect(printer);
        if (!ok) throw Exception('Connect failed');
      }
      final isBmp = _btEncoding == 'bmp';
      if (isBmp) {
        await BtService.write(await bmp.buildBmpReceipt(testOrder, sm, host: ApiClient.host));
      } else {
        try {
          await BtService.write(esc.buildEscposReceipt(testOrder, sm));
        } catch (_) {
          await BtService.write(await bmp.buildBmpReceipt(testOrder, sm, host: ApiClient.host));
        }
      }
    }
    try {
      await BtService.enqueue(attempt);
      _showMsg('Test print sent!');
    } catch (err) {
      await BtService.disconnect();
      try {
        await BtService.enqueue(() async {
          final ok = await BtService.connect(printer);
          if (!ok) throw Exception('Reconnect failed');
          await attempt();
        });
        _showMsg('Test print sent (reconnected)');
      } catch (e) {
        _showMsg('Print failed: $e', seconds: 5);
      }
    }
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
    final list = await BtService.pairedPrinters();
    if (!mounted) return;
    if (list.isEmpty) {
      _showMsg('No paired printers found', seconds: 5);
      return;
    }
    PrinterInfo? picked = await showModalBottomSheet<PrinterInfo>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Bluetooth Printer', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ...list.map((p) => ListTile(
              leading: const Icon(Icons.print, color: Color(0xFF059669)),
              title: Text(p.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(p.mac, style: const TextStyle(fontSize: 11, color: txtDim)),
              trailing: _savedPrinter?.mac == p.mac ? const Icon(Icons.check_circle, color: Color(0xFF059669)) : null,
              onTap: () => Navigator.pop(ctx, p),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      await BtService.savePrinter(picked);
      _savedPrinter = picked;
      final connected = await BtService.connect(picked);
      _btConnected = connected;
      _showMsg(connected ? 'Connected: ${picked.name}' : 'Selected but not connected');
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_message.isNotEmpty) _buildMessageBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildConnectionCard(),
                  const SizedBox(height: 12),
                  _buildPaperCard(),
                  const SizedBox(height: 12),
                  _buildFontCard(),
                  const SizedBox(height: 12),
                  _buildTokenCard(),
                  const SizedBox(height: 12),
                  _buildAutoPrintCard(),
                  const SizedBox(height: 12),
                  _buildTestCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 20, color: txtDark),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.print, color: Color(0xFF059669), size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Printer Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: txtDark)),
          ),
          ElevatedButton(
            onPressed: _saving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('SAVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
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
        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
        child: Text(_message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
      child: child,
    );
  }

  Widget _title(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: txtDark)),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: txtDark))),
          Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF059669)),
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
            activeColor: const Color(0xFF059669),
            activeTrackColor: const Color(0xFF86EFAC),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: txtDark)),
          ),
        ],
      ),
    );
  }

  Widget _drop(String label, String value, List<String> opts, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: txtDark))),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
              child: DropdownButton<String>(
                value: value, isDense: true, underline: const SizedBox(), dropdownColor: panel,
                style: const TextStyle(fontSize: 12, color: txtDark),
                items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) { if (v != null) onChanged(v); },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _text(String label, String value, ValueChanged<String> onChanged, {String hint = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: txtDim)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            style: const TextStyle(color: txtDark, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint, hintStyle: const TextStyle(color: txtDim, fontSize: 13),
              filled: true, fillColor: panel,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF059669))),
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
          _title('🖨️', 'Bluetooth Printer'),
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _btConnected ? const Color(0xFF059669) : (_btEnabled ? Colors.amber : Colors.red)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_btEnabled ? (_savedPrinter != null ? _savedPrinter!.name : 'No printer selected') : 'Bluetooth is OFF', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: txtDark)),
                    Text(_btConnected ? 'Connected' : '${_pairedDevices.length} paired devices', style: TextStyle(fontSize: 12, color: _btConnected ? const Color(0xFF059669) : txtDim)),
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
                  label: Text(_savedPrinter != null ? 'Change' : 'Select Printer'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
              if (_savedPrinter != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disconnectPrinter,
                    icon: const Icon(Icons.bluetooth_disabled, size: 16, color: Colors.red),
                    label: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaperCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('📄', 'Paper & Encoding'),
          _drop('Paper Width', _paperWidth, ['58', '80'], (v) => setState(() => _paperWidth = v)),
          _drop('Encoding', _btEncoding, ['utf-8', 'cp1256', 'cp864', 'bmp'], (v) => setState(() => _btEncoding = v)),
          _drop('Currency', _currency, ['PKR', 'USD', 'EUR', 'GBP', 'AED'], (v) => setState(() => _currency = v)),
          _drop('Text Align', _btTextAlign, ['left', 'center', 'right'], (v) => setState(() => _btTextAlign = v)),
          _text('Receipt Header', _receiptHeader, (v) => setState(() => _receiptHeader = v)),
          _text('Receipt Footer', _receiptFooter, (v) => setState(() => _receiptFooter = v)),
          _text('Slip Prefix', _slipPrefix, (v) => setState(() => _slipPrefix = v)),
          _toggle('Show Logo', _btLogoEnabled, (v) => setState(() => _btLogoEnabled = v)),
        ],
      ),
    );
  }

  Widget _buildFontCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('🔤', 'Font & Style (size 1-200)'),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Har text ka size, bold, italic aur font style alag se set karein. Size 1 se 200 tak.',
              style: TextStyle(fontSize: 12, color: txtDim),
            ),
          ),
          _drop('Divider Style', _btDividerStyle, ['dashed', 'solid', 'double', 'thick'], (v) => setState(() => _btDividerStyle = v)),
          const SizedBox(height: 4),
          ...fontElements.map((el) => _fontElementCard(el)),
          const SizedBox(height: 8),
          _toggle('Show Notes on Receipt', _btShowNotes, (v) => setState(() => _btShowNotes = v)),
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
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(el.label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: txtDark)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Size', style: TextStyle(fontSize: 12, color: txtDim)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF059669)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _setSize(el.id, (_fontSizes[el.id] ?? el.defaultSize) - 1),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _sizeCtrls[el.id],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: txtDark),
                  decoration: InputDecoration(
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: border)),
                  ),
                  onSubmitted: (v) => _setSize(el.id, double.tryParse(v) ?? el.defaultSize),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF059669)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _setSize(el.id, (_fontSizes[el.id] ?? el.defaultSize) + 1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _miniToggle('Bold', _fontBold[el.id] == true,
                  (v) => setState(() => _fontBold[el.id] = v)),
              const SizedBox(width: 12),
              _miniToggle('Italic', _fontItalic[el.id] == true,
                  (v) => setState(() => _fontItalic[el.id] = v)),
            ],
          ),
          const SizedBox(height: 6),
          _drop('Font Style',
              _fontFamily[el.id] ?? 'Noto Naskh Arabic (Urdu)', fontOptions,
              (v) => setState(() => _fontFamily[el.id] = v)),
        ],
      ),
    );
  }

  Widget _buildTokenCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('🎫', 'Token Slip'),
          _toggle('Enable Token Slip', _tokenSlipEnabled, (v) => setState(() => _tokenSlipEnabled = v)),
          if (_tokenSlipEnabled) ...[
            _toggle('Token on Dine-In', _btTokenOnDineIn, (v) => setState(() => _btTokenOnDineIn = v)),
            _toggle('Token on Takeaway', _btTokenOnTakeaway, (v) => setState(() => _btTokenOnTakeaway = v)),
            _toggle('Token on Delivery', _btTokenOnDelivery, (v) => setState(() => _btTokenOnDelivery = v)),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoPrintCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('⚡', 'Auto Print'),
          _toggle('Auto Print on Order', _autoPrintEnabled, (v) => setState(() => _autoPrintEnabled = v)),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Jab order banega, printer pe automatically print ho jayega.', style: TextStyle(fontSize: 12, color: txtDim)),
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
          _title('🧪', 'Test Print'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savedPrinter != null ? _testPrint : null,
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Send Test Receipt'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }
}