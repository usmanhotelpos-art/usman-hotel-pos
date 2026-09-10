import 'dart:convert';
import 'dart:typed_data';

// ESC/POS stock slip builder - similar layout to order slips
// Prints a stock receipt: header, order info, items table, totals, footer.

const int CMD_INIT = 0x1B;
const int CMD_TEXT = 0x40;
const int CMD_LINE_FEED = 0x0A;
const int CMD_FEED_LINES = 0x1B;
const int CMD_ALIGN_CENTER = 0x1B;
const int CMD_ALIGN_LEFT = 0x1B;
const int CMD_ALIGN_RIGHT = 0x1B;
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

/// Builds a text ESC/POS stock slip.
Uint8List buildStockSlip(Map<String, dynamic> order, Map<String, dynamic> settings) {
  final bytes = BytesBuilder();
  final paperWidth = _sOf(settings['receiptPaperWidth'], def: '58');
  final charLimit = paperWidth == '80' ? 42 : 32;

  // Init
  bytes.addByte(CMD_INIT);
  bytes.addByte(CMD_TEXT);

  // Center helper
  void center(String text, {int? sizeFactor}) {
    if (text.isEmpty) return;
    final len = text.length;
    final pad = len < charLimit ? (charLimit - len) ~/ 2 : 0;
    bytes.addByte(CMD_ALIGN_CENTER);
    bytes.addByte(0x61);
    bytes.addByte(1);
    bytes.add(_text(' ' * pad + text));
    bytes.addByte(0x0A);
  }

  void left(String text, {bool bold = false}) {
    if (text.isEmpty) return;
    bytes.addByte(CMD_ALIGN_LEFT);
    bytes.addByte(0x61);
    bytes.addByte(0);
    if (bold) {
      bytes.addByte(CMD_BOLD_ON);
      bytes.addByte(0x45);
      bytes.addByte(1);
    }
    bytes.add(_text(text));
    bytes.addByte(0x0A);
    if (bold) {
      bytes.addByte(CMD_BOLD_OFF);
      bytes.addByte(0x45);
      bytes.addByte(0);
    }
  }

  void divider(String ch) {
    var count = charLimit;
    if (paperWidth == '80') count = 48;
    final countClamped = count.clamp(6, 56);
    center(ch * countClamped);
  }

  // ── Header ──
  final header = _sOf(settings['btReceiptHeader']).isNotEmpty
      ? _sOf(settings['btReceiptHeader'])
      : _sOf(settings['receiptHeader'], def: 'Usman Hotel');
  final footer = _sOf(settings['btReceiptFooter']).isNotEmpty
      ? _sOf(settings['btReceiptFooter'])
      : _sOf(settings['receiptFooter'], def: 'Thank you for your business');

  divider('=');
  center(header, sizeFactor: 2);
  center(_sOf(settings['location'], def: 'Karachi'));
  divider('=');

  // ── Order info ──
  final orderNo = order['orderNumber'] ?? '-';
  final date = order['date'] ?? getPkDate();
  final time = order['time'] ?? getPkTime();
  left('Stock Order: $orderNo', bold: true);
  left('Date: $date', bold: true);
  left('Time: $time');
  left('Status: ${order['status'] ?? 'pending'}', bold: true);

  if ((order['addedBy'] ?? '').isNotEmpty) {
    left('Added By: ${order['addedBy']}');
  }
  if ((order['approvedBy'] ?? '').isNotEmpty) {
    left('Approved By: ${order['approvedBy']}');
  }

  divider('-');

  // ── Items ──
  left('ITEM', bold: true);
  left('  -- QTY --');
  divider('-');
  final items = (order['items'] as List?) ?? [];
  for (final item in items) {
    final name = _sOf(item['productName'] ?? item['name'] ?? '');
    final qty = '${item['quantity'] ?? 0}';
    left(name.isNotEmpty ? name : 'Item');
    left('  QTY: $qty  ');
  }

  divider('-');

  // Total items count
  var totalQty = 0;
  for (final item in items) {
    totalQty += int.tryParse('${item['quantity'] ?? 0}') ?? 0;
  }
  left('Total Items: ${items.length}', bold: true);
  left('Total Qty: $totalQty', bold: true);

  // ── Notes ──
  if ((order['notes'] ?? '').isNotEmpty) {
    divider('-');
    left('Notes:', bold: true);
    left(_sOf(order['notes']));
  }

  divider('=');
  center(footer);
  center('STOCK SLIP');
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