import 'dart:convert';
import 'dart:typed_data';

// ESC/POS stock slip builder
// Fixed layout: header, slip heading, order number (SO-0001), date+time,
// status, items (name/qty/desc), employee+counter, footer.
// Per-element bold + font size support via ESC E (bold) and GS ! (size).

const int CMD_INIT = 0x1B;
const int CMD_TEXT = 0x40;
const int CMD_LINE_FEED = 0x0A;
const int CMD_FEED_LINES = 0x1B;
const int CMD_ALIGN_CENTER = 0x1B;
const int CMD_ALIGN_LEFT = 0x1B;
const int CMD_BOLD_ON = 0x1B;
const int CMD_BOLD_OFF = 0x1B;
const int CMD_CUT = 0x1D;
const int CMD_DOUBLE_SIZE = 0x1D;

String _sOf(dynamic v, {String def = ''}) =>
    v == null ? def : v.toString();

String getPkDate() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5));
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String getPkTime() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5));
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

Uint8List _text(String s) => Uint8List.fromList(utf8.encode(s));

/// Strips the date part: SO-20260911-0001 -> SO-0001
String _shortOrderNo(dynamic orderNo) {
  final s = _sOf(orderNo);
  final m = RegExp(r'^SO-\d{8}-(\d+)$').firstMatch(s);
  if (m != null) return 'SO-${m.group(1)}';
  return s;
}

/// GS ! ratio from abstract size (1-200)
int _sizeRatio(double size) => size >= 30 ? 0x22 : (size >= 16 ? 0x11 : 0x00);

/// Builds a text ESC/POS stock slip with the fixed layout.
Uint8List buildStockSlip(Map<String, dynamic> order, Map<String, dynamic> settings) {
  final bytes = BytesBuilder();
  final paperWidth = _sOf(settings['receiptPaperWidth'], def: '58');
  final charLimit = paperWidth == '80' ? 42 : 32;

  double sizeOf(String key, double def) {
    final v = settings[key];
    if (v is num) return v.toDouble().clamp(1, 200);
    return def;
  }

  bool boldOf(String key) => settings[key] == true;

  // Init
  bytes.addByte(CMD_INIT);
  bytes.addByte(CMD_TEXT);

  // BMP font selection (ESC M 1 selects font B / "BMP" font style)
  if (_sOf(settings['btEncoding']) == 'bmp') {
    bytes.addByte(0x1B);
    bytes.addByte(0x4D);
    bytes.addByte(1);
  }

  void setFont(bool bold, int size) {
    bytes.addByte(CMD_BOLD_ON);
    bytes.addByte(0x45);
    bytes.addByte(bold ? 1 : 0);
    bytes.addByte(CMD_DOUBLE_SIZE);
    bytes.addByte(0x21);
    bytes.addByte(_sizeRatio(size.toDouble()));
  }

  void resetFont() {
    bytes.addByte(CMD_BOLD_ON);
    bytes.addByte(0x45);
    bytes.addByte(0);
    bytes.addByte(CMD_DOUBLE_SIZE);
    bytes.addByte(0x21);
    bytes.addByte(0);
  }

  void emitLine(String text, {bool bold = false, double size = 17, bool center = false}) {
    if (text.isEmpty) return;
    if (center) {
      bytes.addByte(CMD_ALIGN_CENTER);
      bytes.addByte(0x61);
      bytes.addByte(1);
    } else {
      bytes.addByte(CMD_ALIGN_LEFT);
      bytes.addByte(0x61);
      bytes.addByte(0);
    }
    setFont(bold, size.round());
    bytes.add(_text(text));
    bytes.addByte(0x0A);
    resetFont();
  }

  void divider(String ch) {
    var count = charLimit;
    if (paperWidth == '80') count = 48;
    final countClamped = count.clamp(6, 56);
    bytes.addByte(CMD_ALIGN_CENTER);
    bytes.addByte(0x61);
    bytes.addByte(1);
    setFont(false, 17);
    bytes.add(_text(ch * countClamped));
    bytes.addByte(0x0A);
    resetFont();
  }

  // ── Header ──
  final header = _sOf(settings['btReceiptHeader']).isNotEmpty
      ? _sOf(settings['btReceiptHeader'])
      : _sOf(settings['receiptHeader'], def: 'Usman Hotel');
  final slipHeading = _sOf(settings['btSlipHeading']).isNotEmpty
      ? _sOf(settings['btSlipHeading'])
      : _sOf(settings['slipHeading'], def: 'Stock List Daily');
  final footer = _sOf(settings['btReceiptFooter']).isNotEmpty
      ? _sOf(settings['btReceiptFooter'])
      : _sOf(settings['receiptFooter'], def: 'Thank you for your business');

  divider('=');
  emitLine(header, bold: boldOf('stBtHeaderBold'), size: sizeOf('stBtFontSize', 24), center: true);
  emitLine(slipHeading, bold: boldOf('stBtHeadingBold'), size: sizeOf('stBtHeadingFontSize', 18), center: true);
  divider('=');

  // ── Order info ──
  final orderNo = _shortOrderNo(order['orderNumber']);
  final date = _sOf(order['date'], def: getPkDate());
  final time = _sOf(order['time'], def: getPkTime());
  emitLine('Stock Order # $orderNo',
      bold: boldOf('stBtOrderNoBold'), size: sizeOf('stBtOrderNoFontSize', 17));
  emitLine('Date: $date   Time: $time',
      bold: boldOf('stBtInfoBold'), size: sizeOf('stBtInfoFontSize', 17));
  emitLine('Status: ${order['status'] ?? 'pending'}',
      bold: boldOf('stBtInfoBold'), size: sizeOf('stBtInfoFontSize', 17));

  divider('-');

  // ── Items ──
  emitLine('ITEM  QTY  DESCRIPTION',
      bold: boldOf('stBtProductBold'), size: sizeOf('stBtProductFontSize', 20));
  divider('-');
  final items = (order['items'] as List?) ?? [];
  for (final item in items) {
    final name = _sOf(item['productName'] ?? item['name'] ?? '');
    final qty = '${item['quantity'] ?? 0}';
    final desc = _sOf(item['description']);
    emitLine(name.isNotEmpty ? name : 'Item',
        bold: boldOf('stBtProductBold'), size: sizeOf('stBtProductFontSize', 20));
    if (desc.isNotEmpty) {
      emitLine('    QTY: $qty    DESC: $desc',
          bold: boldOf('stBtDescBold'), size: sizeOf('stBtDescFontSize', 15));
    } else {
      emitLine('    QTY: $qty',
          bold: boldOf('stBtDescBold'), size: sizeOf('stBtDescFontSize', 15));
    }
  }

  divider('-');

  // ── Employee / counter ──
  final addedBy = _sOf(order['addedBy']);
  final counter = _sOf(order['counterName']);
  final nameParts = [
    if (addedBy.isNotEmpty) 'Added By: $addedBy',
    if (counter.isNotEmpty) 'Counter: $counter',
  ];
  if (nameParts.isNotEmpty) {
    emitLine(nameParts.join('   '),
        bold: boldOf('stBtNamesBold'), size: sizeOf('stBtNamesFontSize', 17));
  }
  if (_sOf(order['approvedBy']).isNotEmpty) {
    emitLine('Approved: ${order['approvedBy']}',
        bold: boldOf('stBtNamesBold'), size: sizeOf('stBtNamesFontSize', 17));
  }

  divider('=');
  if (footer.isNotEmpty) {
    emitLine(footer, bold: boldOf('stBtFooterBold'), size: sizeOf('stBtFooterFontSize', 17), center: true);
  }
  divider('=');

  // Feed and cut
  bytes.addByte(CMD_FEED_LINES);
  bytes.addByte(0x4A);
  bytes.addByte(4);
  bytes.addByte(CMD_CUT);
  bytes.addByte(0x56);
  bytes.addByte(0x42);
  bytes.addByte(1);

  return bytes.toBytes();
}