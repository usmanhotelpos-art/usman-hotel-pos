import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

import 'escpos.dart' show Cmd, formatDate, fnum, nOf, sOf;

// Bitmap (raster) Bluetooth receipt renderer - port of the web app's
// renderReceiptToCanvas + canvasToEscposRaster so the Android slip matches
// the web Bluetooth slip (fonts, logo, bold flags, alignment, margins,
// PAID stamp, token slip, notes).

/// Bundled font (assets/fonts) registered under the same family name the web
/// app uses. Covers Latin + Urdu/Arabic glyphs so receipts match the web
/// exactly even for Urdu item names.
const String kReceiptFontFamily = 'Noto Naskh Arabic';

/// Resolves the btFontFamily setting to a family that actually exists on the
/// device. Only Noto Naskh Arabic is bundled (Urdu/Arabic glyphs); everything
/// else maps to a Flutter platform fallback so text never renders blank.
/// Maps the string font-size settings ('small'/'normal'/'large'/'xlarge')
/// to pixel sizes used by the raster renderer. Without this the renderer only
/// understood numeric sizes and silently fell back, so the Font & Style
/// controls had no visible effect.
double btFontPx(Map<String, dynamic> settings, String key, double fallback) {
  final v = settings[key];
  if (v is num && v != 0) return v.toDouble();
  final str = sOf(v).toLowerCase();
  switch (str) {
    case 'xsmall':
      return 14.0;
    case 'small':
      return 17.0;
    case 'normal':
      return 20.0;
    case 'large':
      return 24.0;
    case 'xlarge':
      return 30.0;
    default:
      return fallback;
  }
}

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

/// Numeric size for a text element, falling back to [fallback] when absent.
double elSize(Map<String, dynamic> settings, String key, double fallback) =>
    nOf(settings[key]) != 0
        ? nOf(settings[key]).clamp(1.0, 200.0).toDouble()
        : fallback;

/// Bold flag for a text element (defaults to [def] when not present).
bool elBold(Map<String, dynamic> settings, String key, {bool def = false}) {
  final v = settings[key];
  if (v == null) return def;
  if (v is bool) return v;
  return sOf(v).toLowerCase() == 'true';
}

/// Italic flag for a text element (defaults to [def] when not present).
bool elItalic(Map<String, dynamic> settings, String key, {bool def = false}) =>
    elBold(settings, key, def: def);

/// Font family/style for a text element, falling back to the receipt's
/// global family when that element does not have its own override.
String elFamily(Map<String, dynamic> settings, String key, String globalFam) {
  final v = sOf(settings[key]).trim();
  if (v.isEmpty) return globalFam;
  return receiptFontFamily(<String, dynamic>{'btFontFamily': v});
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
    bool italic = false,
    String? fontFamily,
    required ui.TextAlign align,
    ui.Color color = const ui.Color(0xFF000000),
  }) {
    // IMPORTANT: the paragraph must always be laid out LEFT-aligned.
    // Alignment is done MANUALLY in printLine() via maxIntrinsicWidth
    // offsets. Passing center/right into ParagraphStyle while laying out
    // at width 100000 places the glyphs ~50000px OFF the canvas - the
    // printer then outputs a slip with only the logo/token visible and
    // every other line blank.
    final fam = fontFamily ?? this.fontFamily;
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      fontSize: fontSize,
      fontFamily: fam,
      maxLines: 1,
    ))
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
        fontStyle: italic ? ui.FontStyle.italic : ui.FontStyle.normal,
        fontFamily: fam,
      ))
      ..addText(text);
    final p = pb.build();
    p.layout(const ui.ParagraphConstraints(width: 100000));
    return p;
  }

  double measure(String text, double fontSize,
          {bool bold = false, bool italic = false, String? fontFamily}) =>
      _para(text,
              fontSize: fontSize,
              bold: bold,
              italic: italic,
              fontFamily: fontFamily,
              align: ui.TextAlign.left)
          .maxIntrinsicWidth;

  void printLine(
    String text, {
    double? fontSize,
    bool bold = false,
    bool italic = false,
    String? fontFamily,
    ui.TextAlign? align,
    double? lineHeight,
    double? x,
    ui.Color color = const ui.Color(0xFF000000),
    bool noAdvance = false,
    required double baseFontSize,
  }) {
    final fs = fontSize ?? baseFontSize;
    final al = align ?? defaultAlign;
    final p = _para(text,
        fontSize: fs,
        bold: bold,
        italic: italic,
        fontFamily: fontFamily,
        align: al,
        color: color);
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
    bool paidItalic = false,
    String paidFamily = kReceiptFontFamily,
  }) {
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const ui.Color(0xFF000000);
    canvas.drawCircle(ui.Offset(cx, cy), radius, paint);
    void stampText(String t, double fs, double baselineY) {
      final p = _para(t,
          fontSize: fs,
          bold: paidBold,
          italic: paidItalic,
          fontFamily: paidFamily,
          align: ui.TextAlign.center);
      canvas.drawParagraph(
          p, ui.Offset(cx - p.maxIntrinsicWidth / 2, baselineY - fs * 0.85));
    }

    stampText('PAID', paidSize, cy - paidSize * 0.45);
    stampText('Usman Hotel', paidSize * 0.55, cy + paidSize * 0.5);
  }
}

List<String> _wrapByWidth(String text, double maxW, double fontSize,
    bool bold,
    {bool italic = false, String fontFamily = kReceiptFontFamily}) {
  double mw(String t) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(maxLines: 1))
      ..pushStyle(ui.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
          fontStyle: italic ? ui.FontStyle.italic : ui.FontStyle.normal,
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

  // ---- per-element font settings (size up to 200, bold, italic, family) ----
  final baseFontSize = btFontPx(settings, 'btFontSize', 20.0);
  final globalFamily = receiptFontFamily(settings);
  final headerFontSize = elSize(settings, 'btFontSize', baseFontSize * 1.1);
  final headerBold = elBold(settings, 'btHeaderBold', def: true);
  final headerItalic = elItalic(settings, 'btHeaderItalic');
  final headerFamily = elFamily(settings, 'btHeaderFontFamily', globalFamily);
  final infoFontSize = elSize(settings, 'btInfoFontSize',
      (baseFontSize * 0.85).roundToDouble());
  final infoBold = elBold(settings, 'btInfoBold');
  final infoItalic = elItalic(settings, 'btInfoItalic');
  final infoFamily = elFamily(settings, 'btInfoFontFamily', globalFamily);
  final orderTypeFontSize = elSize(settings, 'btOrderTypeFontSize', 18.0);
  final orderTypeBold = elBold(settings, 'btOrderTypeBold');
  final orderTypeItalic = elItalic(settings, 'btOrderTypeItalic');
  final orderTypeFamily = elFamily(settings, 'btOrderTypeFontFamily', globalFamily);
  final serviceTypeFontSize = elSize(settings, 'btServiceTypeFontSize', 16.0);
  final serviceTypeBold = elBold(settings, 'btServiceTypeBold');
  final serviceTypeItalic = elItalic(settings, 'btServiceTypeItalic');
  final serviceTypeFamily = elFamily(settings, 'btServiceTypeFontFamily', globalFamily);
  final locationFontSize = elSize(settings, 'btLocationFontSize', 14.0);
  final locationBold = elBold(settings, 'btLocationBold');
  final locationItalic = elItalic(settings, 'btLocationItalic');
  final locationFamily = elFamily(settings, 'btLocationFontFamily', globalFamily);
  final customerFontSize = elSize(settings, 'btCustomerFontSize', infoFontSize);
  final customerBold = elBold(settings, 'btCustomerBold');
  final customerItalic = elItalic(settings, 'btCustomerItalic');
  final customerFamily = elFamily(settings, 'btCustomerFontFamily', globalFamily);
  final productFontSize =
      elSize(settings, 'btProductFontSize', baseFontSize);
  final productBold = elBold(settings, 'btProductBold');
  final productItalic = elItalic(settings, 'btProductItalic');
  final productFamily = elFamily(settings, 'btProductFontFamily', globalFamily);
  final qtyBold = elBold(settings, 'btQtyBold');
  final qtyItalic = elItalic(settings, 'btQtyItalic');
  final qtyFontSize = elSize(settings, 'btQtyFontSize', productFontSize);
  final qtyFamily = elFamily(settings, 'btQtyFontFamily', globalFamily);
  final totalDueFontSize = elSize(settings, 'btTotalDueFontSize', 22.0);
  final totalDueBold = elBold(settings, 'btTotalDueBold', def: true);
  final totalDueItalic = elItalic(settings, 'btTotalDueItalic');
  final totalDueFamily = elFamily(settings, 'btTotalDueFontFamily', globalFamily);
  final totalFontSize = elSize(settings, 'btTotalFontSize', 26.0);
  final totalBold = elBold(settings, 'btTotalBold', def: true);
  final totalItalic = elItalic(settings, 'btTotalItalic');
  final totalFamily = elFamily(settings, 'btTotalFontFamily', globalFamily);
  final notesFontSize = elSize(settings, 'btNotesFontSize', 11.0);
  final notesBold = elBold(settings, 'btNotesBold');
  final notesItalic = elItalic(settings, 'btNotesItalic');
  final notesFamily = elFamily(settings, 'btNotesFontFamily', globalFamily);
  final deliveryAddressFontSize =
      elSize(settings, 'btDeliveryAddressFontSize', 12.0);
  final deliveryAddressBold = elBold(settings, 'btDeliveryAddressBold');
  final deliveryAddressItalic = elItalic(settings, 'btDeliveryAddressItalic');
  final deliveryAddressFamily =
      elFamily(settings, 'btDeliveryAddressFontFamily', globalFamily);
  final paidFontSize = elSize(settings, 'btPaidFontSize', 12.0);
  final paidBold = elBold(settings, 'btPaidBold', def: true);
  final paidItalic = elItalic(settings, 'btPaidItalic');
  final paidFamily = elFamily(settings, 'btPaidFontFamily', globalFamily);
  final tokenFontSize = elSize(settings, 'btTokenFontSize', 44.0);
  final tokenBold = elBold(settings, 'btTokenBold', def: true);
  final tokenItalic = elItalic(settings, 'btTokenItalic');
  final tokenFamily = elFamily(settings, 'btTokenFontFamily', globalFamily);
  final tokenLabelFontSize = elSize(settings, 'btTokenLabelFontSize', 14.0);
  final tokenLabelBold = elBold(settings, 'btTokenLabelBold', def: true);
  final tokenLabelItalic = elItalic(settings, 'btTokenLabelItalic');
  final tokenLabelFamily =
      elFamily(settings, 'btTokenLabelFontFamily', globalFamily);
  final footerFontSize = elSize(settings, 'btFooterFontSize', infoFontSize);
  final footerBold = elBold(settings, 'btFooterBold');
  final footerItalic = elItalic(settings, 'btFooterItalic');
  final footerFamily = elFamily(settings, 'btFooterFontFamily', globalFamily);
  final lineFontSize = elSize(settings, 'btLineFontSize', infoFontSize);
  final lineBold = elBold(settings, 'btLineBold');
  final lineItalic = elItalic(settings, 'btLineItalic');
  final lineFamily = elFamily(settings, 'btLineFontFamily', globalFamily);

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
      fontFamily: globalFamily);
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
        bold: headerBold,
        italic: headerItalic,
        fontFamily: headerFamily,
        fontSize: labelSz * 1.3,
        align: ui.TextAlign.center,
        lineHeight: (labelSz * 1.6).roundToDouble(),
        baseFontSize: labelSz * 1.3);
    P.printLine('Token Slip',
        bold: tokenLabelBold,
        italic: tokenLabelItalic,
        fontFamily: tokenLabelFamily,
        fontSize: labelSz,
        align: ui.TextAlign.center,
        lineHeight: (labelSz * 1.5).roundToDouble(),
        baseFontSize: labelSz);
    P.y += tokenFontSize * 0.7;
    P.printLine('$tokenPrefix-$tokenNumber',
        bold: tokenBold,
        italic: tokenItalic,
        fontFamily: tokenFamily,
        fontSize: tokenFontSize,
        align: ui.TextAlign.center,
        lineHeight: (tokenFontSize * 1.4).roundToDouble(),
        baseFontSize: tokenFontSize);
    if (showTotalOnToken && totalAmount > 0) {
      P.y += tokenFontSize * 0.4;
      P.printDivider('-', labelSz * 0.7);
      P.printLine('Total: ${fnum(totalAmount)} Rs',
          bold: totalBold,
          italic: totalItalic,
          fontFamily: totalFamily,
          fontSize: labelSz * 2,
          align: ui.TextAlign.center,
          lineHeight: (labelSz * 2.5).roundToDouble(),
          baseFontSize: labelSz * 2);
    }
    P.y += 8 + tokenMargin;
    final h = P.y.ceil().clamp(80, 100000).toInt();
    return await _encodeRaster(recorder, pxWidth, h);
  }

  final titleSz = headerFontSize;
  final infoSz = infoFontSize;
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
          bold: tokenBold,
          italic: tokenItalic,
          fontFamily: tokenFamily,
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
      bold: headerBold,
      italic: headerItalic,
      fontFamily: headerFamily,
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
        italic: locationItalic,
        fontFamily: locationFamily,
        align: ui.TextAlign.center,
        baseFontSize: baseFontSize);
  }
  if (sOf(settings['receiptCounterLabel']).isNotEmpty) {
    P.printLine(sOf(settings['receiptCounterLabel']),
        fontSize: infoSz,
        bold: infoBold,
        italic: infoItalic,
        fontFamily: infoFamily,
        align: ui.TextAlign.center,
        baseFontSize: baseFontSize);
  }

  final slipPrefix = sOf(settings['slipPrefix'], def: 'UH');
  final invoiceNo =
      '$slipPrefix-${sOf(order['orderNumber']).isEmpty ? sOf(order['id']) : sOf(order['orderNumber'])}';
  final dateText = formatDate(
    sOf(order['date']),
    settings['receiptDateTimeFormat']?.toString(),
    utcOffset: 5,
  );
  if (invoiceNo.isNotEmpty || dateText.isNotEmpty) {
    P.printLine('$invoiceNo    $dateText',
        fontSize: infoSz,
        bold: infoBold,
        italic: infoItalic,
        fontFamily: infoFamily,
        baseFontSize: baseFontSize);
  }

  if (settings['btShowOrderType'] != false && orderTypeDisplay.isNotEmpty) {
    P.printLine('Order Type: $orderTypeDisplay',
        fontSize: orderTypeFontSize,
        bold: orderTypeBold,
        italic: orderTypeItalic,
        fontFamily: orderTypeFamily,
        baseFontSize: baseFontSize);
  }
  if (osSt == 'completed') {
    P.printLine('Payment: Paid',
        fontSize: infoSz,
        bold: infoBold,
        italic: infoItalic,
        fontFamily: infoFamily,
        baseFontSize: baseFontSize);
  } else if (osSt == 'pay later') {
    P.printLine('Payment: Pay Later',
        fontSize: infoSz,
        bold: infoBold,
        italic: infoItalic,
        fontFamily: infoFamily,
        baseFontSize: baseFontSize);
  }
  if (settings['btShowCustomerName'] != false && customerName.isNotEmpty) {
    P.printLine('Customer: $customerName',
        fontSize: customerFontSize,
        bold: customerBold,
        italic: customerItalic,
        fontFamily: customerFamily,
        baseFontSize: baseFontSize);
  }
  if (orderTypeRaw == 'Dine-In') {
    if (settings['btShowTable'] != false) {
      P.printLine(
          'Table: ${sOf(order['tableNumber']).isEmpty ? '-' : sOf(order['tableNumber'])}',
          fontSize: customerFontSize,
          bold: customerBold,
          italic: customerItalic,
          fontFamily: customerFamily,
          baseFontSize: baseFontSize);
    }
    if (settings['btShowSalesPerson'] != false) {
      P.printLine(
          'Sales Person: ${sOf(order['waiter']).isEmpty ? '-' : sOf(order['waiter'])}',
          fontSize: infoSz,
          bold: infoBold,
          italic: infoItalic,
          fontFamily: infoFamily,
          baseFontSize: baseFontSize);
    }
  }
  if (orderTypeRaw == 'Delivery') {
    if (settings['btShowMobile'] != false) {
      P.printLine(
          'Mobile: ${sOf(order['phone']).isEmpty ? '-' : sOf(order['phone'])}',
          fontSize: infoSz,
          bold: infoBold,
          italic: infoItalic,
          fontFamily: infoFamily,
          baseFontSize: baseFontSize);
    }
    if (settings['btShowDeliveryLocation'] != false &&
        sOf(order['address']).isNotEmpty) {
      P.printLine('Location: ${sOf(order['address'])}',
          fontSize: deliveryAddressFontSize,
          bold: deliveryAddressBold,
          italic: deliveryAddressItalic,
          fontFamily: deliveryAddressFamily,
          baseFontSize: baseFontSize);
    }
    if (settings['btShowServiceType'] != false) {
      P.printLine(
          'Service Type: ${sOf(order['serviceType']).isEmpty ? '-' : sOf(order['serviceType'])}',
          fontSize: serviceTypeFontSize,
          bold: serviceTypeBold,
          italic: serviceTypeItalic,
          fontFamily: serviceTypeFamily,
          baseFontSize: baseFontSize);
    }
    if (settings['btShowRider'] != false) {
      P.printLine(
          'Rider: ${sOf(order['deliveryAgent']).isEmpty ? '-' : sOf(order['deliveryAgent'])}',
          fontSize: infoSz,
          bold: infoBold,
          italic: infoItalic,
          fontFamily: infoFamily,
          baseFontSize: baseFontSize);
    }
  }

  // PAID stamp gets its OWN centered band below the info block so it can
  // never overlap the text (it used to sit on top of the left-side lines).
  if (isPaid && settings['btShowPaidWatermark'] != false) {
    final paidW =
        P.measure('PAID', paidFontSize, bold: paidBold, italic: paidItalic, fontFamily: paidFamily);
    final hotelW = P.measure('Usman Hotel', paidFontSize * 0.55,
        bold: paidBold, italic: paidItalic, fontFamily: paidFamily);
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
      paidItalic: paidItalic,
      paidFamily: paidFamily,
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
  final qtyColW = P.measure('999', qtyFontSize, bold: true) + 4;
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

  void rightTextAt(String t, double x, double yy, double fs,
      {bool bold = false, bool italic = false, String? fontFamily}) {
    final p = P._para(t,
        fontSize: fs,
        bold: bold,
        italic: italic,
        fontFamily: fontFamily,
        align: ui.TextAlign.right);
    canvas.drawParagraph(p, ui.Offset(x - p.maxIntrinsicWidth, yy));
  }

  P.printLine('Product',
      fontSize: prodSz,
      bold: true,
      italic: productItalic,
      fontFamily: productFamily,
      x: nameX,
      align: isRightAlign ? ui.TextAlign.right : ui.TextAlign.left,
      noAdvance: true,
      baseFontSize: prodSz);
  rightTextAt('Qty', qtyX, P.y, qtyFontSize,
      bold: qtyBold, italic: qtyItalic, fontFamily: qtyFamily);
  rightTextAt('Rate', rateX, P.y, prodSz,
      bold: productBold, italic: productItalic, fontFamily: productFamily);
  rightTextAt('Amt', amtX, P.y, prodSz,
      bold: productBold, italic: productItalic, fontFamily: productFamily);
  P.y += lh;

  P.printDivider('-', dividerSz);

  for (final item in items) {
    final qty = nOf(item['quantity']) == 0 ? 1.0 : nOf(item['quantity']);
    final rate = nOf(item['price']) != 0 || item['unitPrice'] == null
        ? nOf(item['price'])
        : nOf(item['unitPrice']);
    final amount = item['total'] != null ? nOf(item['total']) : qty * rate;
    final name = sOf(item['name']).trim();

    final nameLines = _wrapByWidth(name, nameMaxW, prodSz, productBold,
        italic: productItalic, fontFamily: productFamily);
    for (var i = 0; i < nameLines.length; i++) {
      P.printLine(nameLines[i],
          fontSize: prodSz,
          bold: productBold,
          italic: productItalic,
          fontFamily: productFamily,
          x: nameX,
          align: isRightAlign ? ui.TextAlign.right : ui.TextAlign.left,
          noAdvance: true,
          baseFontSize: prodSz);
      if (i == 0) {
        rightTextAt(fnum(qty), qtyX, P.y, qtyFontSize,
            bold: qtyBold, italic: qtyItalic, fontFamily: qtyFamily);
        rightTextAt(fnum(rate), rateX, P.y, prodSz,
            bold: productBold, italic: productItalic, fontFamily: productFamily);
        rightTextAt(fnum(amount), amtX, P.y, prodSz,
            bold: productBold, italic: productItalic, fontFamily: productFamily);
      }
      P.y += lh;
    }

    final variants = <String>[];
    if (sOf(item['weight']).isNotEmpty) variants.add('Weight: ${item['weight']}');
    if (sOf(item['flavor']).isNotEmpty) variants.add('Flavor: ${item['flavor']}');
    if (variants.isNotEmpty) {
      final vLines = _wrapByWidth(variants.join('  '), nameMaxW, infoSz, false,
          fontFamily: infoFamily, italic: infoItalic);
      final vLh = (lh * 0.75).roundToDouble();
      for (final v in vLines) {
        final p = P._para(v,
            fontSize: infoSz,
            italic: infoItalic,
            fontFamily: infoFamily,
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
        fontSize: lineFontSize,
        bold: lineBold,
        italic: lineItalic,
        fontFamily: lineFamily,
        baseFontSize: baseFontSize);
  }
  if (serviceCharge > 0) {
    P.printLine('Service: ${fnum(serviceCharge)} Rs',
        fontSize: lineFontSize,
        bold: lineBold,
        italic: lineItalic,
        fontFamily: lineFamily,
        baseFontSize: baseFontSize);
  }
  if (discountAmount > 0) {
    P.printLine('Discount: ${fnum(discountAmount)} Rs',
        fontSize: lineFontSize,
        bold: lineBold,
        italic: lineItalic,
        fontFamily: lineFamily,
        baseFontSize: baseFontSize);
  }
  if (taxAmount > 0) {
    P.printLine('Tax: ${fnum(taxAmount)} Rs',
        fontSize: lineFontSize,
        bold: lineBold,
        italic: lineItalic,
        fontFamily: lineFamily,
        baseFontSize: baseFontSize);
  }
  P.printLine('Total: ${fnum(totalAmount)} Rs',
      bold: totalBold,
      italic: totalItalic,
      fontFamily: totalFamily,
      fontSize: totalFontSize,
      align: ui.TextAlign.center,
      baseFontSize: baseFontSize);

  // Cash received / customer return (change) lines.
  final cashReceived = nOf(order['cashReceived']);
  if (cashReceived > 0) {
    P.printLine('Cash Received: ${fnum(cashReceived)} Rs',
        fontSize: lineFontSize,
        bold: lineBold,
        italic: lineItalic,
        fontFamily: lineFamily,
        align: ui.TextAlign.center,
        baseFontSize: baseFontSize);
    final returnAmount = cashReceived - totalAmount;
    if (returnAmount > 0) {
      P.printLine('Customer Return: ${fnum(returnAmount)} Rs',
          bold: totalDueBold,
          italic: totalDueItalic,
          fontFamily: totalDueFamily,
          fontSize: totalDueFontSize,
          align: ui.TextAlign.center,
          baseFontSize: baseFontSize);
    }
  }

  // Notes (Remarks) - rendered below totals, above footer.
  final notesText = sOf(order['notes']).trim();
  if (settings['receiptShowNotes'] != false && notesText.isNotEmpty) {
    P.y += 4;
    final noteLines = _wrapByWidth('Remarks: $notesText',
        pxWidth - margin * 2, notesFontSize, notesBold,
        italic: notesItalic, fontFamily: notesFamily);
    for (final line in noteLines) {
      P.printLine(line,
          fontSize: notesFontSize,
          bold: notesBold,
          italic: notesItalic,
          fontFamily: notesFamily,
          baseFontSize: baseFontSize);
    }
  }

  P.y += 6;
  P.printDivider('-', dividerSz);
  P.printLine(footer,
      fontSize: footerFontSize,
      bold: footerBold,
      italic: footerItalic,
      fontFamily: footerFamily,
      align: ui.TextAlign.center,
      baseFontSize: baseFontSize);

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