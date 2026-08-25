import 'dart:convert';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// ESC/POS receipt builder - faithful port of the POS web app's escpos.js
// (text path incl. token slip) so Bluetooth receipts print identically.
// ---------------------------------------------------------------------------

const Map<String, int> _cp1256 = {
  '\u20AC': 0x80,
  '\u201A': 0x82,
  '\u0192': 0x83,
  '\u201E': 0x84,
  '\u2026': 0x85,
  '\u2020': 0x86,
  '\u2021': 0x87,
  '\u02C6': 0x88,
  '\u2030': 0x89,
  '\u2039': 0x8B,
  '\u0152': 0x8C,
  '\u0686': 0x8D,
  '\u0698': 0x8E,
  '\u0688': 0x8F,
  '\u06AF': 0x90,
  '\u2018': 0x91,
  '\u2019': 0x92,
  '\u201C': 0x93,
  '\u201D': 0x94,
  '\u2022': 0x95,
  '\u2013': 0x96,
  '\u2014': 0x97,
  '\u06A9': 0x98,
  '\u2122': 0x99,
  '\u0691': 0x9A,
  '\u203A': 0x9B,
  '\u0153': 0x9C,
  '\u200C': 0x9D,
  '\u200D': 0x9E,
  '\u06BA': 0x9F,
  '\u00A0': 0xA0,
  '\u060C': 0xA1,
  '\u00A2': 0xA2,
  '\u00A3': 0xA3,
  '\u00A4': 0xA4,
  '\u00A5': 0xA5,
  '\u00A6': 0xA6,
  '\u00A7': 0xA7,
  '\u00A8': 0xA8,
  '\u00A9': 0xA9,
  '\u06BE': 0xAA,
  '\u00AB': 0xAB,
  '\u00AC': 0xAC,
  '\u00AD': 0xAD,
  '\u00AE': 0xAE,
  '\u00AF': 0xAF,
  '\u00B0': 0xB0,
  '\u00B1': 0xB1,
  '\u00B2': 0xB2,
  '\u00B3': 0xB3,
  '\u00B4': 0xB4,
  '\u00B5': 0xB5,
  '\u00B6': 0xB6,
  '\u00B7': 0xB7,
  '\u00B8': 0xB8,
  '\u00B9': 0xB9,
  '\u061B': 0xBA,
  '\u00BB': 0xBB,
  '\u00BC': 0xBC,
  '\u00BD': 0xBD,
  '\u00BE': 0xBE,
  '\u061F': 0xBF,
  '\u06C1': 0xC0,
  '\u0621': 0xC1,
  '\u0622': 0xC2,
  '\u0623': 0xC3,
  '\u0624': 0xC4,
  '\u0625': 0xC5,
  '\u0626': 0xC6,
  '\u0627': 0xC7,
  '\u0628': 0xC8,
  '\u0629': 0xC9,
  '\u062A': 0xCA,
  '\u062B': 0xCB,
  '\u062C': 0xCC,
  '\u062D': 0xCD,
  '\u062E': 0xCE,
  '\u062F': 0xCF,
  '\u0630': 0xD0,
  '\u0631': 0xD1,
  '\u0632': 0xD2,
  '\u0633': 0xD3,
  '\u0634': 0xD4,
  '\u0635': 0xD5,
  '\u0636': 0xD6,
  '\u0637': 0xD8,
  '\u0638': 0xD9,
  '\u0639': 0xDA,
  '\u063A': 0xDB,
  '\u0640': 0xDC,
  '\u0641': 0xDD,
  '\u0642': 0xDE,
  '\u0643': 0xDF,
  '\u0644': 0xE0,
  '\u0645': 0xE1,
  '\u0646': 0xE2,
  '\u0647': 0xE3,
  '\u0648': 0xE4,
  '\u0649': 0xE5,
  '\u064A': 0xE6,
  '\u064B': 0xE7,
  '\u064C': 0xE8,
  '\u064D': 0xE9,
  '\u064E': 0xEA,
  '\u064F': 0xEB,
  '\u0650': 0xEC,
  '\u0651': 0xED,
  '\u0652': 0xEE,
  '\u0670': 0xEF,
  '\u0671': 0xF0,
  '\u0672': 0xF1,
  '\u0673': 0xF2,
  '\u0674': 0xF3,
  '\u0675': 0xF4,
  '\u0676': 0xF5,
  '\u0677': 0xF6,
  '\u0678': 0xF7,
  '\u0679': 0xF8,
  '\u067A': 0xF9,
  '\u067B': 0xFA,
  '\u067C': 0xFB,
  '\u067D': 0xFC,
  '\u067E': 0xFD,
  '\u067F': 0xFE,
  '\u0680': 0xFF,
  '\u200E': 0xFD,
  '\u200F': 0xFE,
  '\u06D2': 0xFF,
};

const Map<String, int> _cp864 = {
  '\u0621': 0xC1,
  '\u0622': 0xC2,
  '\u0623': 0xC3,
  '\u0624': 0xC4,
  '\u0626': 0xC6,
  '\u0627': 0xC7,
  '\u0628': 0xA9,
  '\u0629': 0xC9,
  '\u062A': 0xAA,
  '\u062B': 0xAB,
  '\u062C': 0xAD,
  '\u062D': 0xAE,
  '\u062E': 0xAF,
  '\u062F': 0xCF,
  '\u0630': 0xD0,
  '\u0631': 0xD1,
  '\u0632': 0xD2,
  '\u0633': 0xBC,
  '\u0634': 0xBD,
  '\u0635': 0xBE,
  '\u0636': 0xEB,
  '\u0637': 0xD7,
  '\u0638': 0xD8,
  '\u0639': 0xDF,
  '\u063A': 0xEE,
  '\u0640': 0xE0,
  '\u0641': 0xBA,
  '\u0642': 0xF8,
  '\u0643': 0xFC,
  '\u0644': 0xFB,
  '\u0645': 0xEF,
  '\u0646': 0xF2,
  '\u0647': 0xF3,
  '\u0648': 0xE8,
  '\u0649': 0xE9,
  '\u064A': 0xFD,
  '\u0651': 0xF1,
  '\u0660': 0xB0,
  '\u0661': 0xB1,
  '\u0662': 0xB2,
  '\u0663': 0xB3,
  '\u0664': 0xB4,
  '\u0665': 0xB5,
  '\u0666': 0xB6,
  '\u0667': 0xB7,
  '\u0668': 0xB8,
  '\u0669': 0xB9,
  '\u060C': 0xAC,
  '\u061B': 0xBB,
  '\u061F': 0xBF,
};

Uint8List encodeText(String text, String? encoding) {
  if (encoding == null || encoding.isEmpty || encoding == 'utf-8') {
    return Uint8List.fromList(utf8.encode(text));
  }
  final map = encoding == 'cp864' ? _cp864 : _cp1256;
  final bytes = <int>[];
  for (final ch in text.runes) {
    final c = String.fromCharCode(ch);
    if (map.containsKey(c)) {
      bytes.add(map[c]!);
    } else if (ch < 128) {
      bytes.add(ch);
    } else {
      bytes.add(0x3F);
    }
  }
  return Uint8List.fromList(bytes);
}

class Cmd {
  static const List<int> init = [0x1B, 0x40];
  static const List<int> lf = [0x0A];
  static const List<int> cut = [0x1D, 0x56, 0x00];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> fontA = [0x1B, 0x21, 0x00];
  static const List<int> fontB = [0x1B, 0x21, 0x01];
  static const List<int> doubleHeight = [0x1B, 0x21, 0x10];
  static const List<int> doubleWidthHeight = [0x1B, 0x21, 0x30];
  static const List<int> lineSpacingDefault = [0x1B, 0x32];
  static List<int> feedLines(int n) => [0x1B, 0x64, n];
  static List<int> codePage(int n) => [0x1B, 0x74, n];
}

const Map<String, Map<String, int>> _charsPerLine = {
  '58': {'FONT_A': 32, 'FONT_B': 42},
  '80': {'FONT_A': 42, 'FONT_B': 56},
};

String _formatLine(dynamic left, dynamic right, int width) {
  final l = (left ?? '').toString();
  final r = (right ?? '').toString();
  final available = width - l.length - r.length;
  if (available <= 0) {
    final combined = '$l $r';
    return combined.substring(
      0,
      combined.length > width ? width : combined.length,
    );
  }
  return l + ' ' * available + r;
}

List<String> _wrapText(String text, int width) {
  final w = width > 8 ? width : 8;
  final words = text
      .split(' ')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
  final lines = <String>[];
  var current = '';
  for (var word in words) {
    while (word.length > w) {
      if (current.isNotEmpty) {
        lines.add(current);
        current = '';
      }
      lines.add(word.substring(0, w));
      word = word.substring(w);
    }
    if (word.isEmpty) continue;
    final testLen = current.length + word.length + (current.isNotEmpty ? 1 : 0);
    if (testLen > w) {
      if (current.isNotEmpty) lines.add(current);
      current = word;
    } else {
      current += (current.isNotEmpty ? ' ' : '') + word;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

String _divider(String style, int width) {
  const chars = {'dashed': '-', 'solid': '=', 'double': '=', 'thick': '#'};
  final ch = chars[style] ?? '-';
  return ch * width;
}

String formatDate(String? dateString, String? format) {
  if (dateString == null || dateString.isEmpty) return '';
  if (format == null || format.isEmpty) return '';
  final date = DateTime.tryParse(dateString);
  if (date == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return format
      .replaceFirst('DD', two(date.day))
      .replaceFirst('MM', two(date.month))
      .replaceFirst('YYYY', date.year.toString())
      .replaceFirst('HH', two(date.hour))
      .replaceFirst('hh', two(date.hour % 12 == 0 ? 12 : date.hour % 12))
      .replaceFirst('mm', two(date.minute))
      .replaceFirst('ss', two(date.second))
      .replaceFirst('A', date.hour < 12 ? 'AM' : 'PM');
}

String fnum(num v) => v == v.roundToDouble() ? v.round().toString() : '$v';

// ---------------------------------------------------------------------------
// Receipt builder
// ---------------------------------------------------------------------------

List<int> buildEscposReceipt(
  Map<String, dynamic> order,
  Map<String, dynamic> settings, {
  bool tokenOnly = false,
}) {
  final paperWidth = sOf(settings['receiptPaperWidth'], def: '58');
  final btFontSize = sOf(settings['btFontSize'], def: 'normal');
  final btDividerStyle = sOf(settings['btDividerStyle'], def: 'dashed');
  final btProductFontSize = sOf(settings['btProductFontSize'], def: 'normal');
  final btTotalFontSize = sOf(settings['btTotalFontSize'], def: 'large');
  final btEncoding = sOf(settings['btEncoding'], def: 'cp1256');
  final currency = sOf(settings['currency'], def: 'PKR');
  final header = sOf(settings['receiptHeader'], def: 'Usman Hotel');
  final footer = sOf(
    settings['receiptFooter'],
    def: 'Thank you for your business',
  );
  final slipPrefix = sOf(settings['slipPrefix'], def: 'UH');

  final encCP =
      btEncoding == 'cp864'
          ? 11
          : btEncoding == 'cp1256'
          ? 17
          : -1;

  final useSmallFont = btFontSize == 'small';
  final fontChars = _charsPerLine[paperWidth];
  final maxChars =
      useSmallFont
          ? (fontChars?['FONT_B'] ?? 32)
          : (fontChars?['FONT_A'] ?? 32);
  final isLarge = btFontSize == 'large';
  final useSmallProductFont = btProductFontSize == 'small';
  final useLargeProductFont = btProductFontSize == 'large';
  final useLargeTotal =
      btTotalFontSize == 'large' || btTotalFontSize == 'xlarge';
  final useXLargeTotal = btTotalFontSize == 'xlarge';

  Uint8List enc(String t) => encodeText(t, btEncoding);

  final invoiceNo =
      '$slipPrefix-${sOf(order['orderNumber']).isEmpty ? sOf(order['id']) : sOf(order['orderNumber'])}';
  final dateText = formatDate(
    sOf(order['date']),
    settings['receiptDateTimeFormat']?.toString(),
  );

  final orderTypeRaw = sOf(order['orderType']);
  final orderTypeDisplay = orderTypeRaw == 'Takeaway' ? 'Pickup' : orderTypeRaw;
  final customerName =
      orderTypeRaw == 'Takeaway' && sOf(order['customerName']).isEmpty
          ? 'Pickup'
          : sOf(order['customerName']);
  final phone = sOf(order['phone']);
  final tableNo = orderTypeRaw == 'Dine-In' ? sOf(order['tableNumber']) : '';
  final waiter = orderTypeRaw == 'Dine-In' ? sOf(order['waiter']) : '';
  final address = orderTypeRaw == 'Delivery' ? sOf(order['address']) : '';
  final serviceType =
      orderTypeRaw == 'Delivery' ? sOf(order['serviceType']) : '';
  final rider = orderTypeRaw == 'Delivery' ? sOf(order['deliveryAgent']) : '';
  final statusText =
      orderTypeRaw == 'Delivery'
          ? sOf(order['paymentStatus']).isEmpty
              ? sOf(order['status'])
              : sOf(order['paymentStatus'])
          : sOf(order['status']);

  final deliveryCharge =
      orderTypeRaw == 'Delivery'
          ? nOf(
            order['deliveryFee'] != null && nOf(order['deliveryFee']) != 0
                ? order['deliveryFee']
                : order['deliveryCharge'],
          )
          : 0.0;
  final serviceCharge = nOf(order['serviceCharge']);
  final discountAmount = nOf(order['discount']);
  final taxPercent = nOf(order['taxPercent']);
  final items = (order['items'] as List?) ?? [];

  double subtotal;
  if (order['subtotal'] != null && nOf(order['subtotal']) != 0) {
    subtotal = nOf(order['subtotal']);
  } else {
    subtotal = 0;
    for (final it in items) {
      final m = it as Map;
      final qty = nOf(m['quantity']);
      final rate = nOf(m['price']);
      final prod = rate * qty;
      subtotal += prod != 0 ? prod : nOf(m['total']);
    }
  }
  final taxAmountFallback =
      (subtotal - discountAmount) * taxPercent / (taxPercent > 1 ? 100 : 1);
  final taxAmount =
      order['tax'] != null && nOf(order['tax']) != 0
          ? nOf(order['tax'])
          : taxAmountFallback;
  final totalAmount =
      (subtotal - discountAmount + taxAmount + deliveryCharge + serviceCharge)
          .clamp(0, double.infinity)
          .toDouble();

  final tokenPrefix =
      sOf(settings['tokenSlipPrefix']).isNotEmpty
          ? sOf(settings['tokenSlipPrefix'])
          : (slipPrefix.isNotEmpty ? slipPrefix : 'TS');
  final tokenNumber =
      settings['tokenSlipNextNumber'] != null &&
              nOf(settings['tokenSlipNextNumber']) != 0
          ? nOf(settings['tokenSlipNextNumber']).round()
          : 1;

  final lines = <List<int>>[];

  if (tokenOnly) {
    final tokenMargin =
        settings['btTokenMargin'] != null
            ? nOf(settings['btTokenMargin'])
            : 8.0;
    final tokenLabelSz =
        settings['btTokenLabelFontSize'] != null
            ? nOf(settings['btTokenLabelFontSize'])
            : 14.0;
    final tokenNumSz =
        settings['btTokenFontSize'] != null
            ? nOf(settings['btTokenFontSize'])
            : 44.0;

    lines.add(Cmd.init);
    if (encCP >= 0) lines.add(Cmd.codePage(encCP));
    lines.add(Cmd.lineSpacingDefault);
    lines.add(Cmd.alignCenter);

    if (tokenMargin > 0) {
      lines.add(
        Cmd.feedLines(tokenMargin.round() > 15 ? 15 : tokenMargin.round()),
      );
    }

    lines.addAll([Cmd.boldOn, enc(header), Cmd.lf, Cmd.boldOff]);

    if (tokenLabelSz >= 18) lines.add(Cmd.doubleHeight);
    lines.addAll([enc('Token Slip'), Cmd.lf]);
    if (tokenLabelSz >= 18) {
      lines.add(useSmallFont ? Cmd.fontB : Cmd.fontA);
    }

    if (tokenNumSz >= 48) {
      lines.add(Cmd.doubleWidthHeight);
    } else if (tokenNumSz >= 28) {
      lines.add(Cmd.doubleHeight);
    }
    lines.addAll([
      Cmd.boldOn,
      enc('$tokenPrefix-$tokenNumber'),
      Cmd.lf,
      Cmd.boldOff,
    ]);
    lines.add(useSmallFont ? Cmd.fontB : Cmd.fontA);

    if (tokenMargin > 0) {
      lines.add(
        Cmd.feedLines(tokenMargin.round() > 15 ? 15 : tokenMargin.round()),
      );
    }
    lines.add(Cmd.cut);

    return _join(lines);
  }

  final separator = _divider(btDividerStyle, maxChars);

  final showReceiptNumber = settings['receiptShowReceiptNumber'] != false;
  final showDateTime = settings['receiptShowDateTime'] != false;
  final showProductQty = settings['receiptShowProductQuantity'] != false;
  final showProductPrice = settings['receiptShowProductUnitPrice'] != false;
  final showDelCharge = settings['receiptShowDeliveryCharge'] != false;
  final showSerCharge = settings['receiptShowServiceCharge'] != false;
  final showDiscount = settings['receiptShowDiscount'] != false;
  final showTax = settings['receiptShowTax'] != false;
  final showTotal = settings['receiptShowTotal'] != false;
  final showCustMsg = settings['receiptShowCustomerMessage'] != false;
  final showNotes = settings['receiptShowNotes'] != false;

  lines.add(Cmd.init);
  if (encCP >= 0) lines.add(Cmd.codePage(encCP));
  lines.add(Cmd.lineSpacingDefault);
  lines.add(useSmallFont ? Cmd.fontB : Cmd.fontA);

  lines.add(Cmd.alignCenter);
  lines.add(Cmd.boldOn);
  lines.add(isLarge ? Cmd.doubleWidthHeight : Cmd.doubleHeight);
  lines.add(enc(header));
  lines.add(Cmd.lf);
  lines.add(Cmd.boldOff);
  lines.add(useSmallFont ? Cmd.fontB : Cmd.fontA);

  final locationText =
      sOf(settings['btReceiptLocationText']).isNotEmpty
          ? sOf(settings['btReceiptLocationText'])
          : sOf(settings['location']);
  if (settings['btReceiptLocationShow'] != false && locationText.isNotEmpty) {
    lines.add(Cmd.alignCenter);
    lines.addAll([enc(locationText), Cmd.lf]);
  }
  if (sOf(settings['receiptCounterLabel']).isNotEmpty) {
    lines.add(Cmd.alignCenter);
    lines.addAll([enc(settings['receiptCounterLabel'].toString()), Cmd.lf]);
  }

  final showTokenForOrderType =
      ((orderTypeRaw == 'Dine-In') && settings['btTokenOnDineIn'] != false) ||
      ((orderTypeRaw == 'Takeaway') &&
          settings['btTokenOnTakeaway'] != false) ||
      ((orderTypeRaw == 'Delivery') &&
          settings['btTokenOnDelivery'] != false) ||
      (orderTypeRaw.isEmpty && settings['btTokenOnDineIn'] != false);
  final receiptTokenText =
      settings['tokenSlipEnabled'] == true && showTokenForOrderType
          ? '$tokenPrefix-$tokenNumber'
          : '';
  if (receiptTokenText.isNotEmpty) {
    lines.add(Cmd.alignLeft);
    lines.add(Cmd.boldOn);
    lines.add(isLarge ? Cmd.doubleWidthHeight : Cmd.doubleHeight);
    lines.addAll([enc(receiptTokenText), Cmd.lf]);
    lines.add(Cmd.boldOff);
    lines.add(useSmallFont ? Cmd.fontB : Cmd.fontA);
  }

  lines.add(Cmd.alignCenter);
  lines.addAll([enc(separator), Cmd.lf]);

  lines.add(Cmd.alignLeft);
  final invoiceText =
      showReceiptNumber && invoiceNo.isNotEmpty ? 'Invoice No. $invoiceNo' : '';
  if (invoiceText.isNotEmpty && showDateTime && dateText.isNotEmpty) {
    lines.addAll([enc(_formatLine(invoiceText, dateText, maxChars)), Cmd.lf]);
  } else {
    if (invoiceText.isNotEmpty) {
      lines.addAll([enc(invoiceText), Cmd.lf]);
    }
    if (showDateTime && dateText.isNotEmpty) {
      lines.addAll([enc(dateText), Cmd.lf]);
    }
  }

  if (orderTypeDisplay.isNotEmpty) {
    lines.addAll([
      enc(_formatLine('Order Type', orderTypeDisplay, maxChars)),
      Cmd.lf,
    ]);
  }
  if (statusText == 'Completed') {
    lines.addAll([enc(_formatLine('Payment', 'Paid', maxChars)), Cmd.lf]);
  } else if (statusText == 'Pay Later') {
    lines.addAll([enc(_formatLine('Payment', 'Pay Later', maxChars)), Cmd.lf]);
  }
  if (customerName.isNotEmpty) {
    final displayName =
        orderTypeRaw == 'Dine-In'
            ? (sOf(order['customerName']).isNotEmpty
                ? sOf(order['customerName'])
                : (tableNo.isNotEmpty ? tableNo : 'Table'))
            : customerName;
    lines.addAll([enc(_formatLine('Customer', displayName, maxChars)), Cmd.lf]);
  }
  if (orderTypeRaw == 'Dine-In') {
    lines.addAll([
      enc(_formatLine('Table', tableNo.isEmpty ? '-' : tableNo, maxChars)),
      Cmd.lf,
    ]);
    lines.addAll([
      enc(_formatLine('Sales Person', waiter.isEmpty ? '-' : waiter, maxChars)),
      Cmd.lf,
    ]);
  }
  if (orderTypeRaw == 'Delivery') {
    lines.addAll([
      enc(_formatLine('Mobile', phone.isEmpty ? '-' : phone, maxChars)),
      Cmd.lf,
    ]);
    if (address.isNotEmpty) {
      lines.addAll([enc('Location:'), Cmd.lf]);
      _wrapText(address, maxChars).forEach((line) {
        lines.addAll([enc(line), Cmd.lf]);
      });
    } else {
      lines.addAll([enc(_formatLine('Location', '-', maxChars)), Cmd.lf]);
    }
    lines.addAll([
      enc(
        _formatLine(
          'Service Type',
          serviceType.isEmpty ? '-' : serviceType,
          maxChars,
        ),
      ),
      Cmd.lf,
    ]);
    lines.addAll([
      enc(_formatLine('Rider', rider.isEmpty ? '-' : rider, maxChars)),
      Cmd.lf,
    ]);
    lines.addAll([
      enc(
        _formatLine('Status', statusText.isEmpty ? '-' : statusText, maxChars),
      ),
      Cmd.lf,
    ]);
  }
  if (orderTypeRaw != 'Dine-In' && orderTypeRaw != 'Delivery') {
    if (settings['receiptShowCustomerPhone'] != false && phone.isNotEmpty) {
      lines.addAll([enc(_formatLine('Mobile', phone, maxChars)), Cmd.lf]);
    }
    if (settings['receiptShowWaiterName'] != false && waiter.isNotEmpty) {
      lines.addAll([
        enc(_formatLine('Sales Person', waiter, maxChars)),
        Cmd.lf,
      ]);
    }
  }

  lines.add(Cmd.alignCenter);
  lines.addAll([enc(separator), Cmd.lf]);

  lines.add(Cmd.alignLeft);
  lines.add(Cmd.boldOn);
  if (showProductQty && showProductPrice) {
    lines.addAll([enc(_formatLine('Product', 'Qty Rate Amount', maxChars))]);
  } else if (showProductQty) {
    lines.addAll([enc(_formatLine('Product', 'Qty Amount', maxChars))]);
  } else if (showProductPrice) {
    lines.addAll([enc(_formatLine('Product', 'Rate Amount', maxChars))]);
  } else {
    lines.addAll([enc(_formatLine('Product', 'Amount', maxChars))]);
  }
  lines.add(Cmd.lf);
  lines.add(Cmd.boldOff);
  lines.add(Cmd.alignCenter);
  lines.addAll([enc(separator), Cmd.lf]);

  lines.add(Cmd.alignLeft);
  if (useSmallProductFont) {
    lines.add(Cmd.fontB);
  } else if (useLargeProductFont) {
    lines.add(Cmd.doubleHeight);
  }
  for (final rawItem in items) {
    final item = rawItem as Map;
    final qty = nOf(item['quantity']) == 0 ? 1 : nOf(item['quantity']);
    final rate = nOf(item['price'] ?? item['unitPrice']);
    final amount = item['total'] != null ? nOf(item['total']) : qty * rate;
    final itemName = sOf(item['name']).trim();

    _wrapText(itemName, maxChars).forEach((line) {
      lines.addAll([enc(line), Cmd.lf]);
    });

    final qtyStr = showProductQty ? fnum(qty) : '';
    final rateStr = showProductPrice ? '${fnum(rate)} $currency' : '';
    final amtStr = '${fnum(amount)} $currency';
    if (showProductQty && showProductPrice) {
      lines.addAll([enc('$qtyStr  $rateStr  $amtStr'), Cmd.lf]);
    } else if (showProductQty) {
      lines.addAll([
        enc(_formatLine('Qty: $qtyStr', amtStr, maxChars)),
        Cmd.lf,
      ]);
    } else if (showProductPrice) {
      lines.addAll([
        enc(_formatLine('Rate: $rateStr', amtStr, maxChars)),
        Cmd.lf,
      ]);
    } else {
      lines.addAll([enc(amtStr), Cmd.lf]);
    }

    if (sOf(item['weight']).isNotEmpty) {
      _wrapText('Weight: ${item['weight']}', maxChars).forEach((line) {
        lines.addAll([enc(line), Cmd.lf]);
      });
    }
    if (sOf(item['flavor']).isNotEmpty) {
      _wrapText('Flavor: ${item['flavor']}', maxChars).forEach((line) {
        lines.addAll([enc(line), Cmd.lf]);
      });
    }
  }
  if (useSmallProductFont || useLargeProductFont) {
    lines.add(Cmd.fontA);
  }

  lines.add(Cmd.alignCenter);
  lines.addAll([enc(separator), Cmd.lf]);

  lines.add(Cmd.alignLeft);

  if (orderTypeRaw == 'Delivery' && showDelCharge && deliveryCharge > 0) {
    lines.addAll([
      enc(_formatLine('Delivery:', '${fnum(deliveryCharge)} Rs', maxChars)),
      Cmd.lf,
    ]);
  }
  if (showSerCharge && serviceCharge > 0) {
    lines.addAll([
      enc(_formatLine('Service:', '${fnum(serviceCharge)} Rs', maxChars)),
      Cmd.lf,
    ]);
  }
  if (showDiscount && discountAmount > 0) {
    lines.addAll([
      enc(_formatLine('Discount:', '${fnum(discountAmount)} Rs', maxChars)),
      Cmd.lf,
    ]);
  }
  if (showTax && taxAmount > 0) {
    lines.addAll([
      enc(_formatLine('Tax:', '${fnum(taxAmount)} Rs', maxChars)),
      Cmd.lf,
    ]);
  }
  if (showTotal) {
    if (useXLargeTotal) {
      lines.add(Cmd.alignCenter);
      lines.add(Cmd.boldOn);
      lines.add(Cmd.doubleWidthHeight);
      lines.addAll([enc('Total: ${fnum(totalAmount)} Rs'), Cmd.lf]);
      lines.add(Cmd.boldOff);
      lines.add(useSmallFont ? Cmd.fontB : Cmd.fontA);
      lines.add(Cmd.alignLeft);
    } else if (useLargeTotal) {
      lines.add(Cmd.alignCenter);
      lines.add(Cmd.boldOn);
      lines.add(Cmd.doubleHeight);
      lines.addAll([enc('Total: ${fnum(totalAmount)} Rs'), Cmd.lf]);
      lines.add(Cmd.boldOff);
      lines.add(useSmallFont ? Cmd.fontB : Cmd.fontA);
      lines.add(Cmd.alignLeft);
    } else {
      lines.add(Cmd.boldOn);
      lines.addAll([
        enc(_formatLine('Total:', '${fnum(totalAmount)} Rs', maxChars)),
        Cmd.lf,
      ]);
      lines.add(Cmd.boldOff);
    }
  }

  // Cash received / customer return (change).
  final cashReceived = nOf(order['cashReceived']);
  if (cashReceived > 0) {
    lines.add(Cmd.alignLeft);
    lines.addAll([
      enc(_formatLine('Cash Received:', '${fnum(cashReceived)} Rs', maxChars)),
      Cmd.lf,
    ]);
    final returnAmount = cashReceived - totalAmount;
    if (returnAmount > 0) {
      lines.addAll([
        enc(
          _formatLine('Customer Return:', '${fnum(returnAmount)} Rs', maxChars),
        ),
        Cmd.lf,
      ]);
    }
  }

  if (showCustMsg && sOf(order['customerMessage']).isNotEmpty) {
    lines.add(Cmd.alignLeft);
    _wrapText('Note: ${order['customerMessage']}', maxChars).forEach((line) {
      lines.addAll([enc(line), Cmd.lf]);
    });
  }
  if (showNotes && sOf(order['notes']).isNotEmpty) {
    lines.add(Cmd.alignLeft);
    _wrapText('Remarks: ${order['notes']}', maxChars).forEach((line) {
      lines.addAll([enc(line), Cmd.lf]);
    });
  }

  lines.add(Cmd.alignCenter);
  lines.addAll([enc(separator), Cmd.lf]);
  lines.addAll([enc(footer), Cmd.lf]);

  lines.add(Cmd.feedLines(3));
  lines.add(Cmd.cut);

  return _join(lines);
}

Uint8List _join(List<List<int>> parts) {
  var totalLen = 0;
  for (final p in parts) {
    totalLen += p.length;
  }
  final result = Uint8List(totalLen);
  var offset = 0;
  for (final p in parts) {
    result.setRange(offset, offset + p.length, p);
    offset += p.length;
  }
  return result;
}

String sOf(dynamic v, {String def = ''}) {
  if (v == null) return def;
  final t = v.toString();
  return t;
}

double nOf(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}
