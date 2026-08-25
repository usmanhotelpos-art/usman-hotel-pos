import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

import 'escpos.dart' show Cmd, formatDate, fnum, nOf, sOf;

// Bitmap (raster) Bluetooth receipt renderer - port of the web app's
// renderReceiptToCanvas + canvasToEscposRaster so the Android slip matches
// the web Bluetooth slip (fonts, logo, bold flags, alignment, margins,
// PAID stamp, token slip).

/// Bundled font (assets/fonts) registered under the same family name the web
/// app uses. Covers Latin + Urdu/Arabic glyphs so receipts match the web
/// exactly even for Urdu item names.
const String kReceiptFontFamily = 'Noto Naskh Arabic';

/// Resolves the btFontFamily setting to a family that actually exists on the
/// device. Only Noto Naskh Arabic is bundled (Urdu/Arabic glyphs); everything
/// else maps to a Flutter platform fallback so text never renders blank.
String receiptFontFamily(Map<String, dynamic> settings) {
  final f = sOf(settings['btFontFamily']).toLowerCase();
  // Urdu/Arabic-capable fonts -> bundled Naskh (covers Urdu + Latin).
  if (f.contains('naskh') ||
      f.contains('nastaliq') ||
      f.contains('nafees') ||
      f.contains('jameel') ||
      f.contains('alvi') ||
      f.contains('urdu')) {
    return kReceiptFontFamily;
  }
  if (f.contains('mono') || f.contains('courier')) return 'monospace';
  if (f.contains('sans') || f.contains('arial') || f.contains('helvetica') ||
      f.contains('tahoma') || f.contains('verdana')) {
    return 'sans-serif';
  }
  if (f.contains('serif')) return 'serif';
  return kReceiptFontFamily;
}

Future<ui.Image?> _loadImage(String src, String host) async {
  try {
    Uint8List bytes;
    if (src.startsWith('data:')) {
      final idx = src.indexOf(',');
      final b64 = idx >= 0 ? src.substring(idx + 1) : src;
      bytes = base64Decode(b64);
    } else if (src.startsWith('http')) {
      final res =
          await http.get(Uri.parse(src)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      bytes = res.bodyBytes;
    } else {
      final res = await http
          .get(Uri.parse('$host$src'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      bytes = res.bodyBytes;
    }
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

class _Painter {
  final ui.Canvas canvas;
  final double pxWidth;
  final ui.TextAlign defaultAlign;
  final String fontFamily;
  _Painter(this.canvas, this.pxWidth,
      {this.defaultAlign = ui.TextAlign.left, this.fontFamily = kReceiptFontFamily});

  double y = 10;

  ui.Paragraph _para(
    String text, {
    required double fontSize,
    bool bold = false,
    required ui.TextAlign align,
    ui.Color color = const ui.Color(0xFF000000),
  }) {
    // IMPORTANT: the paragraph must always be laid out LEFT-aligned.
    // Alignment is done MANUALLY in printLine() via maxIntrinsicWidth
    // offsets. Passing center/right into ParagraphStyle while laying out
    // at width 100000 places the glyphs ~50000px OFF the canvas - the
    // printer then outputs a slip with only the logo/token visible and
    // every other line blank.
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      fontSize: fontSize,
      fontFamily: fontFamily,
      maxLines: 1,
    ))
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
        fontFamily: fontFamily,
      ))
      ..addText(text);
    final p = pb.build();
    p.layout(const ui.ParagraphConstraints(width: 100000));
    return p;
  }

  double measure(String text, double fontSize, {bool bold = false}) =>
      _para(text, fontSize: fontSize, bold: bold, align: ui.TextAlign.left)
          .maxIntrinsicWidth;

  void printLine(
    String text, {
    double? fontSize,
    bool bold = false,
    ui.TextAlign? align,
    double? lineHeight,
    double? x,
    ui.Color color = const ui.Color(0xFF000000),
    bool noAdvance = false,
    required double baseFontSize,
  }) {
    final fs = fontSize ?? baseFontSize;
    final al = align ?? defaultAlign;
    final p = _para(text, fontSize: fs, bold: bold, align: al, color: color);
    double dx;
    if (x != null) {
      dx = x;
    } else {
      dx = al == ui.TextAlign.center
          ? pxWidth / 2
          : al == ui.TextAlign.right
              ? pxWidth - 2
              : 2;
    }
    if (al == ui.TextAlign.center) {
      canvas.drawParagraph(p, ui.Offset(dx - p.maxIntrinsicWidth / 2, y));
    } else if (al == ui.TextAlign.right) {
      canvas.drawParagraph(p, ui.Offset(dx - p.maxIntrinsicWidth, y));
    } else {
      canvas.drawParagraph(p, ui.Offset(dx, y));
    }
    if (!noAdvance) y += lineHeight ?? (fs * 1.5).roundToDouble();
  }

  void printDivider(String ch, double fontSize, {double? lineHeight}) {
    final dashW = measure(ch, fontSize);
    var count = dashW > 0 ? ((pxWidth - 4) / dashW).floor() : 24;
    count = count.clamp(6, 48).toInt();
    printLine(ch * count,
        fontSize: fontSize,
        align: ui.TextAlign.center,
        lineHeight: lineHeight ?? (fontSize * 1.6).roundToDouble(),
        baseFontSize: fontSize);
  }

  void circleStamp({
    required double cx,
    required double cy,
    required double radius,
    required double paidSize,
    required bool paidBold,
  }) {
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const ui.Color(0xFF000000);
    canvas.drawCircle(ui.Offset(cx, cy), radius, paint);
    void stampText(String t, double fs, double baselineY) {
      final p =
          _para(t, fontSize: fs, bold: paidBold, align: ui.TextAlign.center);
      canvas.drawParagraph(
          p, ui.Offset(cx - p.maxIntrinsicWidth / 2, baselineY - fs * 0.85));
    }

    stampText('PAID', paidSize, cy - paidSize * 0.45);
    stampText('Usman Hotel', paidSize * 0.55, cy + paidSize * 0.5);
  }
}

List<String> _wrapByWidth(String text, double maxW, double fontSize,
    bool bold,
    {String fontFamily = kReceiptFontFamily}) {
  double mw(String t) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(maxLines: 1))
      ..pushStyle(ui.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
          fontFamily: fontFamily))
      ..addText(t);
    final p = pb.build()..layout(const ui.ParagraphConstraints(width: 100000));
    return p.maxIntrinsicWidth;
  }

  final words = text.split(' ').where((w) => w.isNotEmpty).toList();
  final lines = <String>[];
  var current = '';
  for (var word in words) {
    while (mw(word) > maxW) {
      if (current.isNotEmpty) {
        lines.add(current);
        current = '';
      }
      var breakIdx = word.length;
      while (breakIdx > 0 && mw(word.substring(0, breakIdx)) > maxW) {
        breakIdx--;
      }
      if (breakIdx <= 0) breakIdx = 1;
      lines.add(word.substring(0, breakIdx));
      word = word.substring(breakIdx);
    }
    if (word.isEmpty) continue;
    final test = current.isEmpty ? word : '$current $word';
    if (mw(test) > maxW && current.isNotEmpty) {
      lines.add(current);
      current = word;
    } else {
      current = test;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  if (lines.isEmpty) lines.add('');
  return lines;
}

/// Renders the receipt like the web canvas and returns ready-to-send ESC/POS
/// bytes: ESC @ + band-sliced GS v 0 raster + feed + cut.
///
/// All logo decoding happens BEFORE the picture is recorded so the actual
/// drawing pass is fully synchronous (reliable across engines).
Future<Uint8List> buildBmpReceipt(
  Map<String, dynamic> order,
  Map<String, dynamic> settings, {
  bool tokenOnly = false,
  String host = '',
}) async {
  final paperWidth = sOf(settings['receiptPaperWidth'], def: '58');
  final mmWidth = paperWidth == '80' ? 80 : 58;
  // Print-head dot width - NOT mm*8. 58mm heads are 384 dots (48 bytes/row),
  // 80mm heads are 576 dots (72 bytes/row). Oversized rasters (e.g. 464 dots)
  // are silently REJECTED by cheap firmware (Hasio/Xprinter) which prints an
  // EMPTY WHITE slip because init/feed/cut still execute.
  final pxWidth = mmWidth == 80 ? 576 : 384;
  final header = sOf(settings['btReceiptHeader']).isNotEmpty
      ? sOf(settings['btReceiptHeader'])
      : sOf(settings['receiptHeader'], def: 'Usman Hotel');
  final footer = sOf(settings['btReceiptFooter']).isNotEmpty
      ? sOf(settings['btReceiptFooter'])
      : sOf(settings['receiptFooter'], def: 'Thank you for your business');
  final baseFontSize =
      nOf(settings['btFontSize']) != 0 ? nOf(settings['btFontSize']) : 20.0;
  final totalFontSize =
      nOf(settings['btTotalFontSize']) != 0 ? nOf(settings['btTotalFontSize']) : 26.0;
  final productFontSize = nOf(settings['btProductFontSize']) != 0
      ? nOf(settings['btProductFontSize'])
      : baseFontSize;
  final orderTypeFontSize = nOf(settings['btOrderTypeFontSize']) != 0
      ? nOf(settings['btOrderTypeFontSize'])
      : 18.0;
  final serviceTypeFontSize = nOf(settings['btServiceTypeFontSize']) != 0
      ? nOf(settings['btServiceTypeFontSize'])
      : 16.0;
  final serviceTypeBold = settings['btServiceTypeBold'] == true;
  final locationFontSize = nOf(settings['btLocationFontSize']) != 0
      ? nOf(settings['btLocationFontSize'])
      : 14.0;
  final locationBold = settings['btLocationBold'] == true;
  final productBold = settings['btProductBold'] == true;
  final qtyBold = settings['btQtyBold'] == true;
  final totalDueFontSize = nOf(settings['btTotalDueFontSize']) != 0
      ? nOf(settings['btTotalDueFontSize'])
      : 22.0;
  final deliveryAddressFontSize = nOf(settings['btDeliveryAddressFontSize']) != 0
      ? nOf(settings['btDeliveryAddressFontSize'])
      : 14.0;
  final deliveryAddressBold = settings['btDeliveryAddressBold'] == true;
  final paidFontSize = nOf(settings['btPaidFontSize']) != 0
      ? nOf(settings['btPaidFontSize'])
      : 12.0;
  final paidBold = settings['btPaidBold'] != false;
  final tokenFontSize =
      nOf(settings['btTokenFontSize']) != 0 ? nOf(settings['btTokenFontSize']) : 44.0;
  final tokenLabelFontSize = nOf(settings['btTokenLabelFontSize']) != 0
      ? nOf(settings['btTokenLabelFontSize'])
      : 14.0;
  // Receipt alignment: left, center, or right. Defaults to center for a
  // clean centered slip on narrow thermal paper.
  final alignRaw = sOf(settings['btTextAlign']).toLowerCase();
  final globalAlign = alignRaw == 'left'
      ? ui.TextAlign.left
      : alignRaw == 'right'
          ? ui.TextAlign.right
          : ui.TextAlign.center;
  final marginTop = settings['btMarginCustom'] == true
      ? (nOf(settings['btMarginTop']) != 0 ? nOf(settings['btMarginTop']) : 10.0)
      : 10.0;
  final marginBottom = settings['btMarginCustom'] == true
      ? (nOf(settings['btMarginBottom']) != 0
          ? nOf(settings['btMarginBottom'])
          : 10.0)
      : 10.0;
  final logoEnabled = settings['btLogoEnabled'] != false;
  final tokenOnReceipt = settings['btTokenOnReceipt'] != false;
  final showTotalOnToken = settings['btShowTotalOnToken'] != false;

  final itemsRaw = (order['items'] as List?) ?? [];
  final items = itemsRaw.whereType<Map>().map((e) => e).toList();

  double subtotalOf(Map o) {
    if (o['subtotal'] != null && nOf(o['subtotal']) != 0) {
      return nOf(o['subtotal']);
    }
    var s = 0.0;
    for (final it in items) {
      final prod = nOf(it['price']) * nOf(it['quantity']);
      s += prod != 0 ? prod : nOf(it['total']);
    }
    return s;
  }

  double grandTotal(Map o) {
    if (tokenOnly) {
      final t = nOf(o['total']) != 0 ? nOf(o['total']) : nOf(o['grandTotal']);
      return t.clamp(0, double.infinity).toDouble();
    }
    final subtotal = subtotalOf(o);
    final discount = nOf(o['discount']);
    final tax = nOf(o['tax']);
    final delivery = o['orderType'] == 'Delivery'
        ? (nOf(o['deliveryFee']) != 0
            ? nOf(o['deliveryFee'])
            : nOf(o['deliveryCharge']))
        : 0.0;
    final service = nOf(o['serviceCharge']);
    return (subtotal - discount + tax + delivery + service)
        .clamp(0, double.infinity)
        .toDouble();
  }

  final totalAmount = grandTotal(order);

  final tokenPrefix = sOf(settings['tokenSlipPrefix']).isNotEmpty
      ? sOf(settings['tokenSlipPrefix'])
      : (sOf(settings['slipPrefix']).isNotEmpty
          ? sOf(settings['slipPrefix'])
          : 'TS');
  final tokenNumber = settings['tokenSlipNextNumber'] != null &&
          nOf(settings['tokenSlipNextNumber']) != 0
      ? nOf(settings['tokenSlipNextNumber']).round()
      : 1;

  // ---- preload images BEFORE recording (keeps drawing synchronous) ------
  ui.Image? preloadedLogo;
  if (tokenOnly) {
    final logoUrl = sOf(settings['logo']);
    if (logoUrl.isNotEmpty && settings['btTokenSlipLogoEnabled'] != false) {
      preloadedLogo = await _loadImage(logoUrl, host);
    }
  } else {
    final logoUrl = sOf(settings['logo']);
    if (logoUrl.isNotEmpty && logoEnabled) {
      preloadedLogo = await _loadImage(logoUrl, host);
    }
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final P = _Painter(canvas, pxWidth.toDouble(), defaultAlign: globalAlign,
      fontFamily: receiptFontFamily(settings));
  P.y = marginTop;
  final margin = 2.0;

  final bg = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, pxWidth.toDouble(), 12000), bg);

  void drawLogoCenteredTop(ui.Image img, double w, double top) {
    final aspect = img.height / img.width;
    final h = w * aspect;
    canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        ui.Rect.fromLTWH((pxWidth - w) / 2, top, w, h),
        bg);
    P.y = top + h + 4;
  }

    if (tokenOnly) {
    final tokenMargin = settings['btTokenMargin'] != null
        ? nOf(settings['btTokenMargin'])
        : 8.0;
    P.y = tokenMargin;

    if (preloadedLogo != null) {
      final logoW = (nOf(settings['btLogoWidth']) != 0
              ? nOf(settings['btLogoWidth'])
              : 90.0)
          .clamp(0.0, pxWidth * 0.45)
          .toDouble();
      drawLogoCenteredTop(preloadedLogo, logoW, P.y);
    }

    final labelSz = tokenLabelFontSize;
    P.printLine(header,
        bold: true,
        fontSize: labelSz * 1.3,
        align: ui.TextAlign.center,
        lineHeight: (labelSz * 1.6).roundToDouble(),
        baseFontSize: labelSz * 1.3);
    P.printLine('Token Slip',
        bold: true,
        fontSize: labelSz,
        align: ui.TextAlign.center,
        lineHeight: (labelSz * 1.5).roundToDouble(),
        baseFontSize: labelSz);
    P.y += tokenFontSize * 0.7;
    P.printLine('$tokenPrefix-$tokenNumber',
        bold: true,
        fontSize: tokenFontSize,
        align: ui.TextAlign.center,
        lineHeight: (tokenFontSize * 1.4).roundToDouble(),
        baseFontSize: tokenFontSize);
    if (showTotalOnToken && totalAmount > 0) {
      P.y += tokenFontSize * 0.4;
      P.printDivider('-', labelSz * 0.7);
      P.printLine('Total: ${fnum(totalAmount)} Rs',
          bold: true,
          fontSize: labelSz * 2,
          align: ui.TextAlign.center,
          lineHeight: (labelSz * 2.5).roundToDouble(),
          baseFontSize: labelSz * 2);
    }
    P.y += 8 + tokenMargin;
    final h = P.y.ceil().clamp(80, 100000).toInt();
    return await _encodeRaster(recorder, pxWidth, h);
  }

  final titleSz = (baseFontSize * 1.1).roundToDouble();
  final infoSz = (baseFontSize * 0.85).roundToDouble();
  final dividerSz = (baseFontSize * 0.65).roundToDouble();

  final orderTypeRaw = sOf(order['orderType']);
  final orderTypeDisplay = orderTypeRaw == 'Takeaway' ? 'Pickup' : orderTypeRaw;
  final customerName = sOf(order['customerName']).isNotEmpty
      ? sOf(order['customerName'])
      : (orderTypeRaw == 'Takeaway' ? 'Pickup' : '');

  final ps = sOf(order['paymentStatus']).toLowerCase();
  final osSt = sOf(order['status']).toLowerCase();
  final isPaid = osSt == 'completed' ||
      osSt == 'paid' ||
      ps == 'paid' ||
      ps == 'paid to cash on counter' ||
      ps.contains('paid');

  final showTokenForOrderType =
      ((orderTypeRaw == 'Dine-In') && settings['btTokenOnDineIn'] != false) ||
          ((orderTypeRaw == 'Takeaway') &&
              settings['btTokenOnTakeaway'] != false) ||
          ((orderTypeRaw == 'Delivery') &&
              settings['btTokenOnDelivery'] != false) ||
          (orderTypeRaw.isEmpty && settings['btTokenOnDineIn'] != false);
  final receiptTokenText =
      tokenOnReceipt && settings['tokenSlipEnabled'] == true && showTokenForOrderType
          ? '$tokenPrefix-$tokenNumber'
          : '';

  final hasLogo = preloadedLogo != null;
  final hasToken = receiptTokenText.isNotEmpty;

  if (hasLogo || hasToken) {
    final tokenSz = (infoSz * 1.4).roundToDouble();
    var logoH = 0.0;
    if (hasLogo) {
      final logoW = (sOf(settings['receiptLogoWidth']).isNotEmpty
                  ? nOf(settings['receiptLogoWidth'])
                  : 110.0)
              .clamp(0.0, pxWidth * 0.55)
              .toDouble();
      final aspect = preloadedLogo.height / preloadedLogo.width;
      logoH = (logoW * aspect).clamp(0.0, logoW * 0.45).toDouble();
    }
    final lineHeight = hasLogo
        ? (logoH > tokenSz + 4 ? logoH : tokenSz + 4)
        : tokenSz + 4.0;
    if (hasToken) {
      P.printLine('#$receiptTokenText',
          bold: true,
          fontSize: tokenSz,
          align: ui.TextAlign.left,
          noAdvance: true,
          x: margin,
          baseFontSize: tokenSz);
    }
    if (hasLogo) {
      final logoW = (sOf(settings['receiptLogoWidth']).isNotEmpty
                  ? nOf(settings['receiptLogoWidth'])
                  : 110.0)
              .clamp(0.0, pxWidth * 0.55)
              .toDouble();
      final logoY = P.y + (lineHeight - logoH) / 2;
      canvas.drawImageRect(
          preloadedLogo,
          ui.Rect.fromLTWH(
              0, 0, preloadedLogo.width.toDouble(), preloadedLogo.height.toDouble()),
          ui.Rect.fromLTWH(pxWidth - margin - logoW, logoY, logoW, logoH),
          bg);
    }
    P.y += lineHeight + 6;
  }

  P.printLine(header,
      bold: true,
      fontSize: titleSz,
      align: ui.TextAlign.center,
      lineHeight: (titleSz * 1.4).roundToDouble(),
      baseFontSize: baseFontSize);
  final locText = sOf(settings['btReceiptLocationText']).isNotEmpty
      ? sOf(settings['btReceiptLocationText'])
      : sOf(settings['location']);
  if (settings['btReceiptLocationShow'] != false && locText.isNotEmpty) {
    P.printLine(locText,
        fontSize: locationFontSize,
        bold: locationBold,
        align: ui.TextAlign.center,
        baseFontSize: baseFontSize);
  }
  if (sOf(settings['receiptCounterLabel']).isNotEmpty) {
    P.printLine(sOf(settings['receiptCounterLabel']),
        fontSize: infoSz,
        align: ui.TextAlign.center,
        baseFontSize: baseFontSize);
  }

  final slipPrefix = sOf(settings['slipPrefix'], def: 'UH');
  final invoiceNo =
      '$slipPrefix-${sOf(order['orderNumber']).isEmpty ? sOf(order['id']) : sOf(order['orderNumber'])}';
  final dateText = formatDate(
    sOf(order['date']),
    settings['receiptDateTimeFormat']?.toString(),
  );
  if (invoiceNo.isNotEmpty || dateText.isNotEmpty) {
    P.printLine('$invoiceNo    $dateText',
        fontSize: infoSz, baseFontSize: baseFontSize);
  }

  if (settings['btShowOrderType'] != false && orderTypeDisplay.isNotEmpty) {
    P.printLine('Order Type: $orderTypeDisplay',
        fontSize: orderTypeFontSize, baseFontSize: baseFontSize);
  }
  if (osSt == 'completed') {
    P.printLine('Payment: Paid', fontSize: infoSz, baseFontSize: baseFontSize);
  } else if (osSt == 'pay later') {
    P.printLine('Payment: Pay Later',
        fontSize: infoSz, baseFontSize: baseFontSize);
  }
  if (settings['btShowCustomerName'] != false && customerName.isNotEmpty) {
    P.printLine('Customer: $customerName',
        fontSize: infoSz, baseFontSize: baseFontSize);
  }
  if (orderTypeRaw == 'Dine-In') {
    if (settings['btShowTable'] != false) {
      P.printLine(
          'Table: ${sOf(order['tableNumber']).isEmpty ? '-' : sOf(order['tableNumber'])}',
          fontSize: infoSz,
          baseFontSize: baseFontSize);
    }
    if (settings['btShowSalesPerson'] != false) {
      P.printLine(
          'Sales Person: ${sOf(order['waiter']).isEmpty ? '-' : sOf(order['waiter'])}',
          fontSize: infoSz,
          baseFontSize: baseFontSize);
    }
  }
  if (orderTypeRaw == 'Delivery') {
    if (settings['btShowMobile'] != false) {
      P.printLine(
          'Mobile: ${sOf(order['phone']).isEmpty ? '-' : sOf(order['phone'])}',
          fontSize: infoSz,
          baseFontSize: baseFontSize);
    }
    if (settings['btShowDeliveryLocation'] != false &&
        sOf(order['address']).isNotEmpty) {
      P.printLine('Location: ${sOf(order['address'])}',
          fontSize: deliveryAddressFontSize,
          bold: deliveryAddressBold,
          baseFontSize: baseFontSize);
    }
    if (settings['btShowServiceType'] != false) {
      P.printLine(
          'Service Type: ${sOf(order['serviceType']).isEmpty ? '-' : sOf(order['serviceType'])}',
          fontSize: serviceTypeFontSize,
          bold: serviceTypeBold,
          baseFontSize: baseFontSize);
    }
    if (settings['btShowRider'] != false) {
      P.printLine(
          'Rider: ${sOf(order['deliveryAgent']).isEmpty ? '-' : sOf(order['deliveryAgent'])}',
          fontSize: infoSz,
          baseFontSize: baseFontSize);
    }
  }

  // PAID stamp gets its OWN centered band below the info block so it can
  // never overlap the text (it used to sit on top of the left-side lines).
  if (isPaid && settings['btShowPaidWatermark'] != false) {
    final paidW = P.measure('PAID', paidFontSize, bold: paidBold);
    final hotelW = P.measure('Usman Hotel', paidFontSize * 0.55, bold: paidBold);
    final totalH = paidFontSize + (paidFontSize * 0.55).roundToDouble() + 4;
    final r = (paidW > hotelW ? paidW : hotelW) > totalH
        ? ((paidW > hotelW ? paidW : hotelW) / 2 + 6)
        : (totalH / 2 + 6);
    P.y += 8;
    final cy = P.y + r;
    P.circleStamp(
      cx: pxWidth / 2,
      cy: cy,
      radius: r,
      paidSize: paidFontSize,
      paidBold: paidBold,
    );
    P.y = cy + r + 10;
  }

  P.y += 6;
  P.printDivider('-', dividerSz);

  final prodSz = productFontSize;
  final lh = (prodSz * 1.5).roundToDouble();
  final rightEdge = pxWidth - margin;
  final isRightAlign = alignRaw == 'right';

  final colW = P.measure('9999', prodSz, bold: true) + 6;
  final qtyColW = P.measure('999', prodSz, bold: true) + 4;
  final rateColW = P.measure('9999', prodSz, bold: true) + 4;
  final amtColW = colW;
  final totalsColsW = qtyColW + rateColW + amtColW;
  final nameMaxW =
      (pxWidth - margin * 2 - totalsColsW - 12).clamp(60.0, double.infinity).toDouble();

  late double nameX, qtyX, rateX, amtX;
  if (isRightAlign) {
    final blockW = nameMaxW + 4 + qtyColW + 4 + rateColW + 4 + amtColW;
    final blockLeft = rightEdge - blockW;
    nameX = blockLeft + nameMaxW;
    qtyX = blockLeft + nameMaxW + 4 + qtyColW;
    rateX = blockLeft + nameMaxW + 4 + qtyColW + 4 + rateColW;
    amtX = rightEdge;
  } else {
    nameX = margin;
    qtyX = rightEdge - amtColW - rateColW - 4;
    rateX = rightEdge - amtColW;
    amtX = rightEdge;
  }

  void rightTextAt(String t, double x, double yy, double fs, bool bold) {
    final p = P._para(t, fontSize: fs, bold: bold, align: ui.TextAlign.right);
    canvas.drawParagraph(p, ui.Offset(x - p.maxIntrinsicWidth, yy));
  }

  P.printLine('Product',
      fontSize: prodSz,
      bold: true,
      x: nameX,
      align: isRightAlign ? ui.TextAlign.right : ui.TextAlign.left,
      noAdvance: true,
      baseFontSize: prodSz);
  rightTextAt('Qty', qtyX, P.y, prodSz, true);
  rightTextAt('Rate', rateX, P.y, prodSz, true);
  rightTextAt('Amt', amtX, P.y, prodSz, true);
  P.y += lh;

  P.printDivider('-', dividerSz);

  for (final item in items) {
    final qty = nOf(item['quantity']) == 0 ? 1.0 : nOf(item['quantity']);
    final rate = nOf(item['price']) != 0 || item['unitPrice'] == null
        ? nOf(item['price'])
        : nOf(item['unitPrice']);
    final amount = item['total'] != null ? nOf(item['total']) : qty * rate;
    final name = sOf(item['name']).trim();

    final nameLines =
        _wrapByWidth(name, nameMaxW, prodSz, productBold, fontFamily: P.fontFamily);
    for (var i = 0; i < nameLines.length; i++) {
      P.printLine(nameLines[i],
          fontSize: prodSz,
          bold: productBold,
          x: nameX,
          align: isRightAlign ? ui.TextAlign.right : ui.TextAlign.left,
          noAdvance: true,
          baseFontSize: prodSz);
      if (i == 0) {
        rightTextAt(fnum(qty), qtyX, P.y, prodSz, qtyBold);
        rightTextAt(fnum(rate), rateX, P.y, prodSz, productBold);
        rightTextAt(fnum(amount), amtX, P.y, prodSz, productBold);
      }
      P.y += lh;
    }

    final variants = <String>[];
    if (sOf(item['weight']).isNotEmpty) variants.add('Weight: ${item['weight']}');
    if (sOf(item['flavor']).isNotEmpty) variants.add('Flavor: ${item['flavor']}');
    if (variants.isNotEmpty) {
      final vLines = _wrapByWidth(variants.join('  '), nameMaxW, infoSz, false,
          fontFamily: P.fontFamily);
      final vLh = (lh * 0.75).roundToDouble();
      for (final v in vLines) {
        final p = P._para(v,
            fontSize: infoSz,
            align: ui.TextAlign.left,
            color: const ui.Color(0xFF666666));
        canvas.drawParagraph(p, ui.Offset(nameX, P.y));
        P.y += vLh;
      }
    }
  }

  P.printDivider('-', dividerSz);

  final discountAmount = nOf(order['discount']);
  final taxAmount = nOf(order['tax']);
  final deliveryCharge = orderTypeRaw == 'Delivery'
      ? (nOf(order['deliveryFee']) != 0
          ? nOf(order['deliveryFee'])
          : nOf(order['deliveryCharge']))
      : 0.0;
  final serviceCharge = nOf(order['serviceCharge']);

  if (deliveryCharge > 0) {
    P.printLine('Delivery: ${fnum(deliveryCharge)} Rs',
        fontSize: infoSz, baseFontSize: baseFontSize);
  }
  if (serviceCharge > 0) {
    P.printLine('Service: ${fnum(serviceCharge)} Rs',
        fontSize: infoSz, baseFontSize: baseFontSize);
  }
  if (discountAmount > 0) {
    P.printLine('Discount: ${fnum(discountAmount)} Rs',
        fontSize: infoSz, baseFontSize: baseFontSize);
  }
  if (taxAmount > 0) {
    P.printLine('Tax: ${fnum(taxAmount)} Rs',
        fontSize: infoSz, baseFontSize: baseFontSize);
  }
  P.printLine('Total: ${fnum(totalAmount)} Rs',
      bold: true,
      fontSize: totalFontSize,
      align: ui.TextAlign.center,
      baseFontSize: baseFontSize);

  // Cash received / customer return (change) lines.
  final cashReceived = nOf(order['cashReceived']);
  if (cashReceived > 0) {
    P.printLine('Cash Received: ${fnum(cashReceived)} Rs',
        fontSize: infoSz, align: ui.TextAlign.center, baseFontSize: baseFontSize);
    final returnAmount = cashReceived - totalAmount;
    if (returnAmount > 0) {
      P.printLine('Customer Return: ${fnum(returnAmount)} Rs',
          bold: true,
          fontSize: totalDueFontSize,
          align: ui.TextAlign.center,
          baseFontSize: baseFontSize);
    }
  }

  P.y += 6;
  P.printDivider('-', dividerSz);
  P.printLine(footer,
      fontSize: infoSz, align: ui.TextAlign.center, baseFontSize: baseFontSize);

  final actualHeight = (P.y + marginBottom).ceil();
  return await _encodeRaster(recorder, pxWidth, actualHeight);
}

/// Crops the recorded picture to [height] dots and encodes it as ESC/POS:
/// ESC @ reset, then the bitmap sliced into 256-dot-tall GS v 0 bands
/// (cheap printer firmwares choke on one huge raster), then feed + cut.
Future<Uint8List> _encodeRaster(
  ui.PictureRecorder recorder,
  int width,
  int height,
) async {
  final picture = recorder.endRecording();
  final h = height.clamp(1, 12000).toInt();
  final img = await picture.toImage(width, h);
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bd == null) throw Exception('Receipt render failed');
  final pixels = bd.buffer.asUint8List();

  final bytesPerLine = (width + 7) >> 3;
  final body = Uint8List(bytesPerLine * h);
  for (var row = 0; row < h; row++) {
    for (var x = 0; x < width; x += 8) {
      var byteVal = 0;
      for (var b = 0; b < 8; b++) {
        final px = x + b;
        if (px < width) {
          final idx = (row * width + px) * 4;
          final brightness =
              (pixels[idx] + pixels[idx + 1] + pixels[idx + 2]) / 3;
          if (brightness < 128) byteVal |= (1 << (7 - b));
        }
      }
      body[row * bytesPerLine + (x >> 3)] = byteVal;
    }
  }

  final out = BytesBuilder();
  out.add(Cmd.init);
  // 128-dot bands: some cheap firmwares reject tall (256-row) raster windows.
  const bandRows = 128;
  var rowStart = 0;
  while (rowStart < h) {
    final rows = (h - rowStart) < bandRows ? (h - rowStart) : bandRows;
    out.add(<int>[
      0x1D, 0x76, 0x30, 0x00,
      bytesPerLine & 0xFF, (bytesPerLine >> 8) & 0xFF,
      rows & 0xFF, (rows >> 8) & 0xFF,
    ]);
    final start = rowStart * bytesPerLine;
    out.add(Uint8List.sublistView(body, start, start + rows * bytesPerLine));
    rowStart += rows;
  }
  out.add(Cmd.feedLines(8));
  out.add(Cmd.cut);
  return out.toBytes();
}
