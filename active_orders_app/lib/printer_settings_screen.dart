import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'bmp_receipt.dart' as bmp;
import 'bt_service.dart';
import 'escpos.dart' as esc;

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  static const bg = Color(0xFF020617);
  static const cardBg = Color(0xFF0F172A);
  static const panel = Color(0xFF1E293B);
  static const border = Color(0xFF334155);
  static const accent = Color(0xFF10B981);
  static const txtDim = Color(0xFF94A3B8);
  static const txtLight = Color(0xFFCBD5E1);

  bool _loading = true;
  Map<String, dynamic> settings = {};
  Map<String, dynamic> serverSettings = {};

  PrinterInfo? _savedPrinter;
  bool _btConnected = false;
  bool _btEnabled = false;
  List<PrinterInfo> _pairedDevices = [];

  String _paperWidth = '58';
  String _btEncoding = 'cp1256';
  String _receiptHeader = 'Usman Hotel';
  String _receiptFooter = 'Thank you for your business';
  String _slipPrefix = 'UH';
  String _receiptDateTimeFormat = 'DD/MM/YYYY hh:mm A';
  String _receiptLocationText = '';
  bool _receiptLocationShow = true;
  String _receiptCounterLabel = '';
  String _currency = 'PKR';

  final bool _btFontSizeNormal = true;
  final bool _btFontSizeSmall = false;
  final bool _btFontSizeLarge = false;
  String _btFontSize = 'normal';
  String _btProductFontSize = 'normal';
  String _btTotalFontSize = 'large';
  String _btDividerStyle = 'dashed';

  bool _tokenSlipEnabled = false;
  bool _btTokenOnDineIn = true;
  bool _btTokenOnTakeaway = true;
  bool _btTokenOnDelivery = true;
  bool _btTokenSlipDineIn = true;
  bool _btTokenSlipTakeaway = true;
  bool _btTokenSlipDelivery = true;
  String _tokenSlipPrefix = 'TS';
  String _btTokenMargin = '8';
  String _btTokenFontSize = '44';
  String _btTokenLabelFontSize = '14';
  bool _btShowTotalOnToken = true;
  bool _btTokenSlipLogoEnabled = true;

  bool _btLogoEnabled = true;
  String _btLogoWidth = '70';
  bool _btShowOrderType = true;
  bool _btShowCustomerName = true;
  bool _btShowTable = true;
  bool _btShowSalesPerson = true;
  bool _btShowMobile = true;
  bool _btShowDeliveryLocation = true;
  bool _btShowServiceType = true;
  bool _btShowRider = true;
  bool _btShowPaidWatermark = true;
  bool _btShowReceiptNumber = true;
  bool _btShowDateTime = true;
  bool _btShowProductQuantity = true;
  bool _btShowProductUnitPrice = true;
  bool _btShowSubtotal = true;
  bool _btShowDeliveryCharge = true;
  bool _btShowServiceCharge = true;
  bool _btShowDiscount = true;
  bool _btShowTax = true;
  bool _btShowTotal = true;
  bool _btShowCustomerMessage = true;
  bool _btShowNotes = true;
  bool _btShowCustomerPhone = true;
  bool _btShowWaiterName = true;
  bool _btMarginCustom = false;
  String _btMarginTop = '10';
  String _btMarginBottom = '10';
  String _btTextAlign = 'center';

  bool _autoPrintEnabled = false;
  bool _autoPrintDineIn = true;
  bool _autoPrintTakeaway = true;
  bool _autoPrintDelivery = true;

  String _message = '';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _loadServerSettings();
    await _loadLocalSettings();
    await _checkBluetooth();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadServerSettings() async {
    try {
      final data = await ApiClient.send('GET', '/settings');
      if (data is Map) {
        serverSettings = Map<String, dynamic>.from(data);
      }
    } catch (_) {}
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _paperWidth = prefs.getString('bt_paperWidth') ?? serverSettings['receiptPaperWidth']?.toString() ?? '58';
    _btEncoding = prefs.getString('bt_encoding') ?? serverSettings['btEncoding']?.toString() ?? 'cp1256';
    _receiptHeader = prefs.getString('bt_header') ?? serverSettings['receiptHeader']?.toString() ?? 'Usman Hotel';
    _receiptFooter = prefs.getString('bt_footer') ?? serverSettings['receiptFooter']?.toString() ?? 'Thank you for your business';
    _slipPrefix = prefs.getString('bt_slipPrefix') ?? serverSettings['slipPrefix']?.toString() ?? 'UH';
    _receiptDateTimeFormat = prefs.getString('bt_dateFormat') ?? serverSettings['receiptDateTimeFormat']?.toString() ?? 'DD/MM/YYYY hh:mm A';
    _receiptLocationText = prefs.getString('bt_locationText') ?? serverSettings['btReceiptLocationText']?.toString() ?? '';
    _receiptLocationShow = prefs.getBool('bt_locationShow') ?? (serverSettings['btReceiptLocationShow'] ?? true);
    _receiptCounterLabel = prefs.getString('bt_counterLabel') ?? serverSettings['receiptCounterLabel']?.toString() ?? '';
    _currency = prefs.getString('bt_currency') ?? serverSettings['currency']?.toString() ?? 'PKR';

    _btFontSize = prefs.getString('bt_fontSize') ?? serverSettings['btFontSize']?.toString() ?? 'normal';
    _btProductFontSize = prefs.getString('bt_productFontSize') ?? serverSettings['btProductFontSize']?.toString() ?? 'normal';
    _btTotalFontSize = prefs.getString('bt_totalFontSize') ?? serverSettings['btTotalFontSize']?.toString() ?? 'large';
    _btDividerStyle = prefs.getString('bt_dividerStyle') ?? serverSettings['btDividerStyle']?.toString() ?? 'dashed';

    _tokenSlipEnabled = prefs.getBool('bt_tokenEnabled') ?? (serverSettings['tokenSlipEnabled'] == true);
    _btTokenOnDineIn = prefs.getBool('bt_tokenOnDineIn') ?? (serverSettings['btTokenOnDineIn'] ?? true);
    _btTokenOnTakeaway = prefs.getBool('bt_tokenOnTakeaway') ?? (serverSettings['btTokenOnTakeaway'] ?? true);
    _btTokenOnDelivery = prefs.getBool('bt_tokenOnDelivery') ?? (serverSettings['btTokenOnDelivery'] ?? true);
    _btTokenSlipDineIn = prefs.getBool('bt_tokenSlipDineIn') ?? (serverSettings['btTokenSlipDineIn'] ?? true);
    _btTokenSlipTakeaway = prefs.getBool('bt_tokenSlipTakeaway') ?? (serverSettings['btTokenSlipTakeaway'] ?? true);
    _btTokenSlipDelivery = prefs.getBool('bt_tokenSlipDelivery') ?? (serverSettings['btTokenSlipDelivery'] ?? true);
    _tokenSlipPrefix = prefs.getString('bt_tokenPrefix') ?? serverSettings['tokenSlipPrefix']?.toString() ?? 'TS';
    _btTokenMargin = prefs.getString('bt_tokenMargin') ?? serverSettings['btTokenMargin']?.toString() ?? '8';
    _btTokenFontSize = prefs.getString('bt_tokenFontSize') ?? serverSettings['btTokenFontSize']?.toString() ?? '44';
    _btTokenLabelFontSize = prefs.getString('bt_tokenLabelFontSize') ?? serverSettings['btTokenLabelFontSize']?.toString() ?? '14';
    _btShowTotalOnToken = prefs.getBool('bt_showTotalOnToken') ?? (serverSettings['btShowTotalOnToken'] ?? true);
    _btTokenSlipLogoEnabled = prefs.getBool('bt_tokenSlipLogoEnabled') ?? (serverSettings['btTokenSlipLogoEnabled'] ?? true);

    _btLogoEnabled = prefs.getBool('bt_logoEnabled') ?? (serverSettings['btLogoEnabled'] ?? true);
    _btLogoWidth = prefs.getString('bt_logoWidth') ?? serverSettings['btLogoWidth']?.toString() ?? '70';
    _btShowOrderType = prefs.getBool('bt_showOrderType') ?? (serverSettings['btShowOrderType'] ?? true);
    _btShowCustomerName = prefs.getBool('bt_showCustomerName') ?? (serverSettings['btShowCustomerName'] ?? true);
    _btShowTable = prefs.getBool('bt_showTable') ?? (serverSettings['btShowTable'] ?? true);
    _btShowSalesPerson = prefs.getBool('bt_showSalesPerson') ?? (serverSettings['btShowSalesPerson'] ?? true);
    _btShowMobile = prefs.getBool('bt_showMobile') ?? (serverSettings['btShowMobile'] ?? true);
    _btShowDeliveryLocation = prefs.getBool('bt_showDeliveryLocation') ?? (serverSettings['btShowDeliveryLocation'] ?? true);
    _btShowServiceType = prefs.getBool('bt_showServiceType') ?? (serverSettings['btShowServiceType'] ?? true);
    _btShowRider = prefs.getBool('bt_showRider') ?? (serverSettings['btShowRider'] ?? true);
    _btShowPaidWatermark = prefs.getBool('bt_showPaidWatermark') ?? (serverSettings['btShowPaidWatermark'] ?? true);
    _btShowReceiptNumber = prefs.getBool('bt_showReceiptNumber') ?? (serverSettings['receiptShowReceiptNumber'] ?? true);
    _btShowDateTime = prefs.getBool('bt_showDateTime') ?? (serverSettings['receiptShowDateTime'] ?? true);
    _btShowProductQuantity = prefs.getBool('bt_showProductQty') ?? (serverSettings['receiptShowProductQuantity'] ?? true);
    _btShowProductUnitPrice = prefs.getBool('bt_showProductPrice') ?? (serverSettings['receiptShowProductUnitPrice'] ?? true);
    _btShowSubtotal = prefs.getBool('bt_showSubtotal') ?? (serverSettings['receiptShowSubtotal'] ?? true);
    _btShowDeliveryCharge = prefs.getBool('bt_showDelCharge') ?? (serverSettings['receiptShowDeliveryCharge'] ?? true);
    _btShowServiceCharge = prefs.getBool('bt_showSerCharge') ?? (serverSettings['receiptShowServiceCharge'] ?? true);
    _btShowDiscount = prefs.getBool('bt_showDiscount') ?? (serverSettings['receiptShowDiscount'] ?? true);
    _btShowTax = prefs.getBool('bt_showTax') ?? (serverSettings['receiptShowTax'] ?? true);
    _btShowTotal = prefs.getBool('bt_showTotal') ?? (serverSettings['receiptShowTotal'] ?? true);
    _btShowCustomerMessage = prefs.getBool('bt_showCustMsg') ?? (serverSettings['receiptShowCustomerMessage'] ?? true);
    _btShowNotes = prefs.getBool('bt_showNotes') ?? (serverSettings['receiptShowNotes'] ?? true);
    _btShowCustomerPhone = prefs.getBool('bt_showCustPhone') ?? (serverSettings['receiptShowCustomerPhone'] ?? true);
    _btShowWaiterName = prefs.getBool('bt_showWaiter') ?? (serverSettings['receiptShowWaiterName'] ?? true);
    _btMarginCustom = prefs.getBool('bt_marginCustom') ?? (serverSettings['btMarginCustom'] == true);
    _btMarginTop = prefs.getString('bt_marginTop') ?? serverSettings['btMarginTop']?.toString() ?? '10';
    _btMarginBottom = prefs.getString('bt_marginBottom') ?? serverSettings['btMarginBottom']?.toString() ?? '10';
    _btTextAlign = prefs.getString('bt_textAlign') ?? serverSettings['btTextAlign']?.toString() ?? 'center';

    _autoPrintEnabled = prefs.getBool('bt_autoPrintEnabled') ?? false;
    _autoPrintDineIn = prefs.getBool('bt_autoPrintDineIn') ?? true;
    _autoPrintTakeaway = prefs.getBool('bt_autoPrintTakeaway') ?? true;
    _autoPrintDelivery = prefs.getBool('bt_autoPrintDelivery') ?? true;

    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bt_paperWidth', _paperWidth);
    await prefs.setString('bt_encoding', _btEncoding);
    await prefs.setString('bt_header', _receiptHeader);
    await prefs.setString('bt_footer', _receiptFooter);
    await prefs.setString('bt_slipPrefix', _slipPrefix);
    await prefs.setString('bt_dateFormat', _receiptDateTimeFormat);
    await prefs.setString('bt_locationText', _receiptLocationText);
    await prefs.setBool('bt_locationShow', _receiptLocationShow);
    await prefs.setString('bt_counterLabel', _receiptCounterLabel);
    await prefs.setString('bt_currency', _currency);
    await prefs.setString('bt_fontSize', _btFontSize);
    await prefs.setString('bt_productFontSize', _btProductFontSize);
    await prefs.setString('bt_totalFontSize', _btTotalFontSize);
    await prefs.setString('bt_dividerStyle', _btDividerStyle);
    await prefs.setBool('bt_tokenEnabled', _tokenSlipEnabled);
    await prefs.setBool('bt_tokenOnDineIn', _btTokenOnDineIn);
    await prefs.setBool('bt_tokenOnTakeaway', _btTokenOnTakeaway);
    await prefs.setBool('bt_tokenOnDelivery', _btTokenOnDelivery);
    await prefs.setBool('bt_tokenSlipDineIn', _btTokenSlipDineIn);
    await prefs.setBool('bt_tokenSlipTakeaway', _btTokenSlipTakeaway);
    await prefs.setBool('bt_tokenSlipDelivery', _btTokenSlipDelivery);
    await prefs.setString('bt_tokenPrefix', _tokenSlipPrefix);
    await prefs.setString('bt_tokenMargin', _btTokenMargin);
    await prefs.setString('bt_tokenFontSize', _btTokenFontSize);
    await prefs.setString('bt_tokenLabelFontSize', _btTokenLabelFontSize);
    await prefs.setBool('bt_showTotalOnToken', _btShowTotalOnToken);
    await prefs.setBool('bt_tokenSlipLogoEnabled', _btTokenSlipLogoEnabled);
    await prefs.setBool('bt_logoEnabled', _btLogoEnabled);
    await prefs.setString('bt_logoWidth', _btLogoWidth);
    await prefs.setBool('bt_showOrderType', _btShowOrderType);
    await prefs.setBool('bt_showCustomerName', _btShowCustomerName);
    await prefs.setBool('bt_showTable', _btShowTable);
    await prefs.setBool('bt_showSalesPerson', _btShowSalesPerson);
    await prefs.setBool('bt_showMobile', _btShowMobile);
    await prefs.setBool('bt_showDeliveryLocation', _btShowDeliveryLocation);
    await prefs.setBool('bt_showServiceType', _btShowServiceType);
    await prefs.setBool('bt_showRider', _btShowRider);
    await prefs.setBool('bt_showPaidWatermark', _btShowPaidWatermark);
    await prefs.setBool('bt_showReceiptNumber', _btShowReceiptNumber);
    await prefs.setBool('bt_showDateTime', _btShowDateTime);
    await prefs.setBool('bt_showProductQty', _btShowProductQuantity);
    await prefs.setBool('bt_showProductPrice', _btShowProductUnitPrice);
    await prefs.setBool('bt_showSubtotal', _btShowSubtotal);
    await prefs.setBool('bt_showDelCharge', _btShowDeliveryCharge);
    await prefs.setBool('bt_showSerCharge', _btShowServiceCharge);
    await prefs.setBool('bt_showDiscount', _btShowDiscount);
    await prefs.setBool('bt_showTax', _btShowTax);
    await prefs.setBool('bt_showTotal', _btShowTotal);
    await prefs.setBool('bt_showCustMsg', _btShowCustomerMessage);
    await prefs.setBool('bt_showNotes', _btShowNotes);
    await prefs.setBool('bt_showCustPhone', _btShowCustomerPhone);
    await prefs.setBool('bt_showWaiter', _btShowWaiterName);
    await prefs.setBool('bt_marginCustom', _btMarginCustom);
    await prefs.setString('bt_marginTop', _btMarginTop);
    await prefs.setString('bt_marginBottom', _btMarginBottom);
    await prefs.setString('bt_textAlign', _btTextAlign);
    await prefs.setBool('bt_autoPrintEnabled', _autoPrintEnabled);
    await prefs.setBool('bt_autoPrintDineIn', _autoPrintDineIn);
    await prefs.setBool('bt_autoPrintTakeaway', _autoPrintTakeaway);
    await prefs.setBool('bt_autoPrintDelivery', _autoPrintDelivery);
    if (mounted) {
      _showMsg('✅ Printer settings saved successfully!', seconds: 3);
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

  Map<String, dynamic> _buildSettingsMap() {
    return {
      'receiptPaperWidth': _paperWidth,
      'btFontSize': _btFontSize,
      'btProductFontSize': _btProductFontSize,
      'btTotalFontSize': _btTotalFontSize,
      'btDividerStyle': _btDividerStyle,
      'btEncoding': _btEncoding,
      'receiptHeader': _receiptHeader,
      'receiptFooter': _receiptFooter,
      'slipPrefix': _slipPrefix,
      'receiptDateTimeFormat': _receiptDateTimeFormat,
      'btReceiptLocationText': _receiptLocationText,
      'btReceiptLocationShow': _receiptLocationShow,
      'receiptCounterLabel': _receiptCounterLabel,
      'currency': _currency,
      'tokenSlipEnabled': _tokenSlipEnabled,
      'btTokenOnDineIn': _btTokenOnDineIn,
      'btTokenOnTakeaway': _btTokenOnTakeaway,
      'btTokenOnDelivery': _btTokenOnDelivery,
      'btTokenSlipDineIn': _btTokenSlipDineIn,
      'btTokenSlipTakeaway': _btTokenSlipTakeaway,
      'btTokenSlipDelivery': _btTokenSlipDelivery,
      'tokenSlipPrefix': _tokenSlipPrefix,
      'btTokenMargin': double.tryParse(_btTokenMargin) ?? 8,
      'btTokenFontSize': double.tryParse(_btTokenFontSize) ?? 44,
      'btTokenLabelFontSize': double.tryParse(_btTokenLabelFontSize) ?? 14,
      'btShowTotalOnToken': _btShowTotalOnToken,
      'btTokenSlipLogoEnabled': _btTokenSlipLogoEnabled,
      'btLogoEnabled': _btLogoEnabled,
      'btLogoWidth': double.tryParse(_btLogoWidth) ?? 70,
      'btShowOrderType': _btShowOrderType,
      'btShowCustomerName': _btShowCustomerName,
      'btShowTable': _btShowTable,
      'btShowSalesPerson': _btShowSalesPerson,
      'btShowMobile': _btShowMobile,
      'btShowDeliveryLocation': _btShowDeliveryLocation,
      'btShowServiceType': _btShowServiceType,
      'btShowRider': _btShowRider,
      'btShowPaidWatermark': _btShowPaidWatermark,
      'receiptShowReceiptNumber': _btShowReceiptNumber,
      'receiptShowDateTime': _btShowDateTime,
      'receiptShowProductQuantity': _btShowProductQuantity,
      'receiptShowProductUnitPrice': _btShowProductUnitPrice,
      'receiptShowSubtotal': _btShowSubtotal,
      'receiptShowDeliveryCharge': _btShowDeliveryCharge,
      'receiptShowServiceCharge': _btShowServiceCharge,
      'receiptShowDiscount': _btShowDiscount,
      'receiptShowTax': _btShowTax,
      'receiptShowTotal': _btShowTotal,
      'receiptShowCustomerMessage': _btShowCustomerMessage,
      'receiptShowNotes': _btShowNotes,
      'receiptShowCustomerPhone': _btShowCustomerPhone,
      'receiptShowWaiterName': _btShowWaiterName,
      'btMarginCustom': _btMarginCustom,
      'btMarginTop': double.tryParse(_btMarginTop) ?? 10,
      'btMarginBottom': double.tryParse(_btMarginBottom) ?? 10,
      'btTextAlign': _btTextAlign,
    };
  }

  Future<void> _testPrint() async {
    if (!(await BtService.ensurePermission())) {
      _showMsg('Bluetooth permission denied', seconds: 4);
      return;
    }

    final printer = _savedPrinter;
    if (printer == null) {
      _showMsg('No printer selected. Pehle printer select karein', seconds: 4);
      return;
    }

    _showMsg('Testing print...');

    final testOrder = <String, dynamic>{
      'id': 'TEST-001',
      'orderNumber': 'TEST-001',
      'orderType': 'Dine-In',
      'status': 'Pending',
      'tableNumber': 'T-1',
      'customerName': 'Test Customer',
      'phone': '0300-1234567',
      'waiter': 'Test Waiter',
      'orderTaker': 'Test Waiter',
      'date': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'items': [
        {'name': 'Chicken Karahi', 'quantity': 2, 'price': 850, 'total': 1700},
        {'name': 'Naan', 'quantity': 4, 'price': 40, 'total': 160},
        {'name': 'Raita', 'quantity': 1, 'price': 80, 'total': 80},
      ],
      'subtotal': 1940,
      'discount': 0,
      'tax': 0,
      'taxPercent': 0,
      'deliveryFee': 0,
      'serviceCharge': 0,
      'total': 1940,
      'amount': 1940,
      'paymentMethod': 'Cash',
      'paymentStatus': 'Unpaid',
      'notes': 'Test print from Active Orders app',
    };

    final settingsMap = _buildSettingsMap();

    Future<void> attemptPrint() async {
      if (!(await BtService.isConnected())) {
        final ok = await BtService.connect(printer);
        if (!ok) throw Exception('Could not connect to ${printer.name}');
      }
      final isBmp = _btEncoding == 'bmp';
      if (isBmp) {
        await BtService.write(
          await bmp.buildBmpReceipt(
            testOrder,
            settingsMap,
            host: ApiClient.host,
          ),
        );
      } else {
        try {
          await BtService.write(esc.buildEscposReceipt(testOrder, settingsMap));
        } catch (_) {
          await BtService.write(
            await bmp.buildBmpReceipt(
              testOrder,
              settingsMap,
              host: ApiClient.host,
            ),
          );
        }
      }
    }

    try {
      await BtService.enqueue(attemptPrint);
      _showMsg('Test print sent successfully!');
    } catch (err) {
      await BtService.disconnect();
      try {
        await BtService.enqueue(() async {
          final ok = await BtService.connect(printer);
          if (!ok) throw Exception('Reconnect failed');
          await attemptPrint();
        });
        _showMsg('Test print sent (reconnected)');
      } catch (retryErr) {
        _showMsg('Print failed: $retryErr', seconds: 5);
      }
    }
  }

  Future<void> _selectPrinter() async {
    if (!(await BtService.ensurePermission())) {
      _showMsg('Bluetooth permission denied', seconds: 4);
      return;
    }
    if (!_btEnabled) {
      _showMsg('Bluetooth is OFF. Please enable it in settings', seconds: 4);
      return;
    }

    final list = await BtService.pairedPrinters();
    if (!mounted) return;

    if (list.isEmpty) {
      _showMsg('No paired printers found. Pehle Android Bluetooth settings mein printer pair karein', seconds: 5);
      return;
    }

    PrinterInfo? picked = await showModalBottomSheet<PrinterInfo>(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Bluetooth Printer',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
              ),
            ),
            ...list.map((p) => ListTile(
              leading: const Icon(Icons.print, color: accent),
              title: Text(p.name, style: const TextStyle(fontSize: 14, color: Colors.white)),
              subtitle: Text(p.mac, style: const TextStyle(fontSize: 11, color: txtDim)),
              trailing: _savedPrinter?.mac == p.mac
                  ? const Icon(Icons.check_circle, color: accent)
                  : null,
              onTap: () {
                Navigator.pop(ctx, p);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked != null) {
      await BtService.savePrinter(picked);
      _savedPrinter = picked;
      _showMsg('Printer selected: ${picked.name}');
      final connected = await BtService.connect(picked);
      _btConnected = connected;
      if (connected) {
        _showMsg('Connected to ${picked.name}');
      }
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

  Future<void> _testPrintToken() async {
    if (!(await BtService.ensurePermission())) {
      _showMsg('Bluetooth permission denied', seconds: 4);
      return;
    }
    final printer = _savedPrinter;
    if (printer == null) {
      _showMsg('No printer selected', seconds: 4);
      return;
    }

    _showMsg('Printing token slip...');

    final testOrder = <String, dynamic>{
      'id': 'TEST-TOKEN',
      'orderNumber': 'TEST-TOKEN',
      'items': [],
    };
    final settingsMap = _buildSettingsMap();
    settingsMap['tokenSlipEnabled'] = true;
    settingsMap['btTokenOnDineIn'] = true;

    Future<void> attemptPrint() async {
      if (!(await BtService.isConnected())) {
        final ok = await BtService.connect(printer);
        if (!ok) throw Exception('Could not connect');
      }
      final isBmp = _btEncoding == 'bmp';
      if (isBmp) {
        await BtService.write(
          await bmp.buildBmpReceipt(testOrder, settingsMap, tokenOnly: true, host: ApiClient.host),
        );
      } else {
        try {
          await BtService.write(esc.buildEscposReceipt(testOrder, settingsMap, tokenOnly: true));
        } catch (_) {
          await BtService.write(
            await bmp.buildBmpReceipt(testOrder, settingsMap, tokenOnly: true, host: ApiClient.host),
          );
        }
      }
    }

    try {
      await BtService.enqueue(attemptPrint);
      _showMsg('Token slip printed!');
    } catch (err) {
      _showMsg('Token print failed: $err', seconds: 5);
    }
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
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                children: [
                  _buildPrinterConnectionCard(),
                  const SizedBox(height: 12),
                  _buildPaperEncodingCard(),
                  const SizedBox(height: 12),
                  _buildReceiptHeaderFooterCard(),
                  const SizedBox(height: 12),
                  _buildFontDividerCard(),
                  const SizedBox(height: 12),
                  _buildTokenSlipCard(),
                  const SizedBox(height: 12),
                  _buildLayoutDisplayCard(),
                  const SizedBox(height: 12),
                  _buildAutoPrintCard(),
                  const SizedBox(height: 12),
                  _buildTestPrintCard(),
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
      decoration: const BoxDecoration(
        color: Color(0xF5020617),
        border: Border(bottom: BorderSide(color: panel)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: panel, shape: BoxShape.circle),
              child: const Text('←', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.settings, color: accent, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Bluetooth Printer Settings',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
            ),
          ),
          GestureDetector(
            onTap: _saveSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('SAVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF022C22).withValues(alpha: .7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6EE7B7))),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: panel),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: txtLight)),
                if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 10, color: txtDim)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: accent,
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: txtLight))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              underline: const SizedBox(),
              dropdownColor: panel,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _textRow(String label, String value, ValueChanged<String> onChanged, {TextInputType type = TextInputType.text, int maxLines = 1, String hint = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: txtLight)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            keyboardType: type,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: txtDim, fontSize: 12),
              filled: true,
              fillColor: panel,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: accent),
              ),
            ),
            onSubmitted: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _numberRow(String label, String value, ValueChanged<String> onChanged, {String hint = '0'}) {
    return _textRow(label, value, onChanged, type: TextInputType.number, hint: hint);
  }

  Widget _divider() => const Divider(color: border, height: 16);

  // ---- CARDS ----

  Widget _buildPrinterConnectionCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🖨️', 'Bluetooth Printer Connection'),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _btConnected ? accent : (_btEnabled ? Colors.amber : Colors.red),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _btEnabled ? (_savedPrinter != null ? _savedPrinter!.name : 'No printer selected') : 'Bluetooth is OFF',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      _btConnected ? 'Connected' : (_btEnabled ? '${_pairedDevices.length} paired devices' : 'Enable Bluetooth in Android settings'),
                      style: TextStyle(fontSize: 11, color: _btConnected ? accent : txtDim),
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
                  label: Text(_savedPrinter != null ? 'Change Printer' : 'Select Printer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (_savedPrinter != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _disconnectPrinter,
                    icon: const Icon(Icons.bluetooth_disabled, size: 16),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildPaperEncodingCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('📄', 'Paper & Encoding'),
          _dropdownRow('Paper Width', _paperWidth, ['58', '80'], (v) => setState(() => _paperWidth = v)),
          _dropdownRow('Encoding', _btEncoding, ['utf-8', 'cp1256', 'cp864', 'bmp'], (v) => setState(() => _btEncoding = v)),
          _dropdownRow('Currency', _currency, ['PKR', 'USD', 'EUR', 'GBP', 'AED', 'SAR', 'INR'], (v) => setState(() => _currency = v)),
          _textRow('Receipt Header', _receiptHeader, (v) => setState(() => _receiptHeader = v), hint: 'Restaurant name'),
          _textRow('Receipt Footer', _receiptFooter, (v) => setState(() => _receiptFooter = v), hint: 'Thank you message'),
          _textRow('Slip Prefix', _slipPrefix, (v) => setState(() => _slipPrefix = v), hint: 'UH'),
          _textRow('Date/Time Format', _receiptDateTimeFormat, (v) => setState(() => _receiptDateTimeFormat = v), hint: 'DD/MM/YYYY hh:mm A'),
        ],
      ),
    );
  }

  Widget _buildReceiptHeaderFooterCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🏢', 'Location & Counter'),
          _toggleRow('Show Location', _receiptLocationShow, (v) => setState(() => _receiptLocationShow = v)),
          _textRow('Location Text', _receiptLocationText, (v) => setState(() => _receiptLocationText = v), hint: 'Address or branch name'),
          _textRow('Counter Label', _receiptCounterLabel, (v) => setState(() => _receiptCounterLabel = v), hint: 'e.g. Counter 1'),
        ],
      ),
    );
  }

  Widget _buildFontDividerCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🔤', 'Font & Divider Style'),
          _dropdownRow('Receipt Font', _btFontSize, ['small', 'normal', 'large'], (v) => setState(() => _btFontSize = v)),
          _dropdownRow('Product Font', _btProductFontSize, ['small', 'normal', 'large'], (v) => setState(() => _btProductFontSize = v)),
          _dropdownRow('Total Font', _btTotalFontSize, ['normal', 'large', 'xlarge'], (v) => setState(() => _btTotalFontSize = v)),
          _dropdownRow('Divider Style', _btDividerStyle, ['dashed', 'solid', 'double', 'thick'], (v) => setState(() => _btDividerStyle = v)),
        ],
      ),
    );
  }

  Widget _buildTokenSlipCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🎫', 'Token Slip Settings'),
          _toggleRow('Enable Token Slip', _tokenSlipEnabled, (v) => setState(() => _tokenSlipEnabled = v)),
          if (_tokenSlipEnabled) ...[
            _divider(),
            _textRow('Token Slip Prefix', _tokenSlipPrefix, (v) => setState(() => _tokenSlipPrefix = v), hint: 'TS'),
            _toggleRow('Show on Dine-In Receipt', _btTokenOnDineIn, (v) => setState(() => _btTokenOnDineIn = v)),
            _toggleRow('Show on Takeaway Receipt', _btTokenOnTakeaway, (v) => setState(() => _btTokenOnTakeaway = v)),
            _toggleRow('Show on Delivery Receipt', _btTokenOnDelivery, (v) => setState(() => _btTokenOnDelivery = v)),
            _divider(),
            const Text('Separate Token Slip Printing:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: txtDim)),
            _toggleRow('Print Token for Dine-In', _btTokenSlipDineIn, (v) => setState(() => _btTokenSlipDineIn = v)),
            _toggleRow('Print Token for Takeaway', _btTokenSlipTakeaway, (v) => setState(() => _btTokenSlipTakeaway = v)),
            _toggleRow('Print Token for Delivery', _btTokenSlipDelivery, (v) => setState(() => _btTokenSlipDelivery = v)),
            _divider(),
            const Text('Token Slip Appearance:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: txtDim)),
            _toggleRow('Show Logo on Token Slip', _btTokenSlipLogoEnabled, (v) => setState(() => _btTokenSlipLogoEnabled = v)),
            _toggleRow('Show Total on Token', _btShowTotalOnToken, (v) => setState(() => _btShowTotalOnToken = v)),
            _numberRow('Token Margin (top)', _btTokenMargin, (v) => setState(() => _btTokenMargin = v)),
            _numberRow('Token Number Font Size', _btTokenFontSize, (v) => setState(() => _btTokenFontSize = v)),
            _numberRow('Token Label Font Size', _btTokenLabelFontSize, (v) => setState(() => _btTokenLabelFontSize = v)),
          ],
        ],
      ),
    );
  }

  Widget _buildLayoutDisplayCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🎨', 'Receipt Layout & Display'),
          _toggleRow('Show Logo', _btLogoEnabled, (v) => setState(() => _btLogoEnabled = v)),
          if (_btLogoEnabled) _numberRow('Logo Width (px)', _btLogoWidth, (v) => setState(() => _btLogoWidth = v)),
          _dropdownRow('Text Alignment', _btTextAlign, ['left', 'center', 'right'], (v) => setState(() => _btTextAlign = v)),
          _divider(),
          const Text('Show on Receipt:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: txtDim)),
          _toggleRow('Order Type', _btShowOrderType, (v) => setState(() => _btShowOrderType = v)),
          _toggleRow('Customer Name', _btShowCustomerName, (v) => setState(() => _btShowCustomerName = v)),
          _toggleRow('Table Number', _btShowTable, (v) => setState(() => _btShowTable = v)),
          _toggleRow('Sales Person / Waiter', _btShowSalesPerson, (v) => setState(() => _btShowSalesPerson = v)),
          _toggleRow('Receipt Number', _btShowReceiptNumber, (v) => setState(() => _btShowReceiptNumber = v)),
          _toggleRow('Date & Time', _btShowDateTime, (v) => setState(() => _btShowDateTime = v)),
          _toggleRow('Product Quantity', _btShowProductQuantity, (v) => setState(() => _btShowProductQuantity = v)),
          _toggleRow('Product Unit Price', _btShowProductUnitPrice, (v) => setState(() => _btShowProductUnitPrice = v)),
          _toggleRow('Subtotal', _btShowSubtotal, (v) => setState(() => _btShowSubtotal = v)),
          _toggleRow('Discount', _btShowDiscount, (v) => setState(() => _btShowDiscount = v)),
          _toggleRow('Tax', _btShowTax, (v) => setState(() => _btShowTax = v)),
          _toggleRow('Service Charge', _btShowServiceCharge, (v) => setState(() => _btShowServiceCharge = v)),
          _toggleRow('Delivery Charge', _btShowDeliveryCharge, (v) => setState(() => _btShowDeliveryCharge = v)),
          _toggleRow('Total', _btShowTotal, (v) => setState(() => _btShowTotal = v)),
          _toggleRow('Customer Message', _btShowCustomerMessage, (v) => setState(() => _btShowCustomerMessage = v)),
          _toggleRow('Notes / Remarks', _btShowNotes, (v) => setState(() => _btShowNotes = v)),
          _toggleRow('Paid Watermark', _btShowPaidWatermark, (v) => setState(() => _btShowPaidWatermark = v)),
          _divider(),
          const Text('Delivery Order Fields:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: txtDim)),
          _toggleRow('Mobile Number', _btShowMobile, (v) => setState(() => _btShowMobile = v)),
          _toggleRow('Customer Phone', _btShowCustomerPhone, (v) => setState(() => _btShowCustomerPhone = v)),
          _toggleRow('Delivery Location', _btShowDeliveryLocation, (v) => setState(() => _btShowDeliveryLocation = v)),
          _toggleRow('Service Type', _btShowServiceType, (v) => setState(() => _btShowServiceType = v)),
          _toggleRow('Rider', _btShowRider, (v) => setState(() => _btShowRider = v)),
          _toggleRow('Waiter Name (non-dinein)', _btShowWaiterName, (v) => setState(() => _btShowWaiterName = v)),
          _divider(),
          const Text('Custom Margins:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: txtDim)),
          _toggleRow('Custom Margins', _btMarginCustom, (v) => setState(() => _btMarginCustom = v)),
          if (_btMarginCustom) ...[
            _numberRow('Top Margin', _btMarginTop, (v) => setState(() => _btMarginTop = v)),
            _numberRow('Bottom Margin', _btMarginBottom, (v) => setState(() => _btMarginBottom = v)),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoPrintCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('⚡', 'Auto Print Settings'),
          _toggleRow('Auto Print on Order', _autoPrintEnabled, (v) => setState(() => _autoPrintEnabled = v)),
          if (_autoPrintEnabled) ...[
            _toggleRow('Auto Print Dine-In Orders', _autoPrintDineIn, (v) => setState(() => _autoPrintDineIn = v)),
            _toggleRow('Auto Print Takeaway Orders', _autoPrintTakeaway, (v) => setState(() => _autoPrintTakeaway = v)),
            _toggleRow('Auto Print Delivery Orders', _autoPrintDelivery, (v) => setState(() => _autoPrintDelivery = v)),
          ],
        ],
      ),
    );
  }

  Widget _buildTestPrintCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🧪', 'Test Print'),
          const Text(
            'Test print se pehle ensure karein ke printer select aur connected hai.',
            style: TextStyle(fontSize: 11, color: txtDim),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _savedPrinter != null ? _testPrint : null,
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Test Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_savedPrinter != null && _tokenSlipEnabled) ? _testPrintToken : null,
                  icon: const Icon(Icons.confirmation_number, size: 16),
                  label: const Text('Test Token Slip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
