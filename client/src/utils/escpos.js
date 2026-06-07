const CP1256_MAP = {
  '\u20AC': 0x80,
  '\u067E': 0x81,
  '\u201A': 0x82,
  '\u0192': 0x83,
  '\u201E': 0x84,
  '\u2026': 0x85,
  '\u2020': 0x86,
  '\u2021': 0x87,
  '\u02C6': 0x88,
  '\u2030': 0x89,
  '\u0679': 0x8A,
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
  '\u0644': 0xE1,
  '\u0645': 0xE3,
  '\u0646': 0xE4,
  '\u0647': 0xE5,
  '\u0648': 0xE6,
  '\u0649': 0xEC,
  '\u064A': 0xED,
  '\u064B': 0xF0,
  '\u064C': 0xF1,
  '\u064D': 0xF2,
  '\u064E': 0xF3,
  '\u064F': 0xF5,
  '\u0650': 0xF6,
  '\u0651': 0xF8,
  '\u0652': 0xFA,
  '\u200E': 0xFD,
  '\u200F': 0xFE,
  '\u06D2': 0xFF,
  '\u0660': 0xB0, '\u0661': 0xB1, '\u0662': 0xB2, '\u0663': 0xB3,
  '\u0664': 0xB4, '\u0665': 0xB5, '\u0666': 0xB6, '\u0667': 0xB7,
  '\u0668': 0xB8, '\u0669': 0xB9,
};

const CP864_MAP = {
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
  '\u0660': 0xB0, '\u0661': 0xB1, '\u0662': 0xB2, '\u0663': 0xB3,
  '\u0664': 0xB4, '\u0665': 0xB5, '\u0666': 0xB6, '\u0667': 0xB7,
  '\u0668': 0xB8, '\u0669': 0xB9,
  '\u060C': 0xAC,
  '\u061B': 0xBB,
  '\u061F': 0xBF,
};

export function encodeText(text, encoding) {
  if (!encoding || encoding === 'utf-8') {
    const encoder = new TextEncoder();
    return encoder.encode(text);
  }
  const map = encoding === 'cp864' ? CP864_MAP : CP1256_MAP;
  const bytes = [];
  for (const ch of text) {
    if (map[ch] !== undefined) {
      bytes.push(map[ch]);
    } else {
      const code = ch.charCodeAt(0);
      if (code < 128) {
        bytes.push(code);
      } else {
        bytes.push(0x3F);
      }
    }
  }
  return Uint8Array.from(bytes);
}

function crc16(data) {
  let crc = 0x0000;
  for (let i = 0; i < data.length; i++) {
    crc ^= data[i];
    for (let j = 0; j < 8; j++) {
      if (crc & 0x0001) {
        crc = (crc >> 1) ^ 0xA001;
      } else {
        crc = crc >> 1;
      }
    }
  }
  return crc;
}

export const CMD = {
  INIT: [0x1B, 0x40],
  LF: [0x0A],
  CUT: [0x1D, 0x56, 0x00],
  CUT_PARTIAL: [0x1D, 0x56, 0x01],
  ALIGN_LEFT: [0x1B, 0x61, 0x00],
  ALIGN_CENTER: [0x1B, 0x61, 0x01],
  ALIGN_RIGHT: [0x1B, 0x61, 0x02],
  BOLD_ON: [0x1B, 0x45, 0x01],
  BOLD_OFF: [0x1B, 0x45, 0x00],
  FONT_A: [0x1B, 0x21, 0x00],
  FONT_B: [0x1B, 0x21, 0x01],
  DOUBLE_HEIGHT: [0x1B, 0x21, 0x10],
  DOUBLE_WIDTH: [0x1B, 0x21, 0x20],
  DOUBLE_WH: [0x1B, 0x21, 0x30],
  UNDERLINE_ON: [0x1B, 0x2D, 0x01],
  UNDERLINE_OFF: [0x1B, 0x2D, 0x00],
  FEED_LINES: (n) => [0x1B, 0x64, n],
  FEED_UNITS: (n) => [0x1B, 0x4A, n],
  LINE_SPACING_24: [0x1B, 0x33, 0x24],
  LINE_SPACING_30: [0x1B, 0x33, 0x30],
  LINE_SPACING_DEFAULT: [0x1B, 0x32],
  BARCODE_EAN13: [0x1D, 0x6B, 0x43],
  BARCODE_TEXT_ABOVE: [0x1D, 0x48, 0x02],
  BARCODE_TEXT_NONE: [0x1D, 0x48, 0x00],
  BARCODE_HEIGHT: (h) => [0x1D, 0x68, h],
  BARCODE_WIDTH: (w) => [0x1D, 0x77, w],
  CHAR_SIZE: (w, h) => [0x1D, 0x21, ((h - 1) << 4) | (w - 1)],
  CODE_PAGE: (n) => [0x1B, 0x74, n],
  TAB: [0x09],
  GS_v_0: (m, xL, xH, yL, yH) => [0x1D, 0x76, 0x30, m, xL, xH, yL, yH],
};

export const CHARS_PER_LINE = {
  '58': { FONT_A: 32, FONT_B: 42 },
  '80': { FONT_A: 42, FONT_B: 56 },
};

function toBytes(...args) {
  const result = [];
  for (const arg of args) {
    if (typeof arg === 'number') {
      result.push(arg);
    } else if (Array.isArray(arg)) {
      result.push(...arg);
    } else if (arg instanceof Uint8Array) {
      result.push(...arg);
    }
  }
  return Uint8Array.from(result);
}

function padLine(text, width, align = 'left') {
  if (align === 'center') {
    const pad = Math.max(0, width - text.length);
    const leftPad = Math.floor(pad / 2);
    return ' '.repeat(leftPad) + text;
  } else if (align === 'right') {
    const pad = Math.max(0, width - text.length);
    return ' '.repeat(pad) + text;
  }
  return text.padEnd(width, ' ');
}

function formatLine(left, right, width) {
  left = String(left || '');
  right = String(right || '');
  const available = width - left.length - right.length;
  if (available <= 0) {
    return (left + ' ' + right).slice(0, width);
  }
  return left + ' '.repeat(available) + right;
}

function wrapText(text, width) {
  const words = String(text || '').split(' ').filter(Boolean);
  const lines = [];
  let current = '';
  for (const word of words) {
    if ((current + word).length + (current ? 1 : 0) > width) {
      if (current) lines.push(current);
      current = word;
    } else {
      current += (current ? ' ' : '') + word;
    }
  }
  if (current) lines.push(current);
  return lines;
}

function divider(style = 'dashed', width = 32) {
  const chars = { dashed: '-', solid: '=', double: '=', thick: '#' };
  const char = chars[style] || '-';
  return char.repeat(width);
}

export function buildEscposReceipt(order, settings = {}) {
  const paperWidth = settings.receiptPaperWidth || '58';
  const btFontSize = settings.btFontSize || 'normal';
  const btDividerStyle = settings.btDividerStyle || 'dashed';
  const btProductFontSize = settings.btProductFontSize || 'normal';
  const btTotalFontSize = settings.btTotalFontSize || 'large';
  const btEncoding = settings.btEncoding || 'cp1256';
  const _enc = (text) => encodeText(text, btEncoding);
  const _encCP = btEncoding === 'cp864' ? 11 : btEncoding === 'cp1256' ? 17 : -1;
  const useSmallFont = btFontSize === 'small';
  const fontMode = useSmallFont ? CHARS_PER_LINE[paperWidth]?.FONT_B : CHARS_PER_LINE[paperWidth]?.FONT_A;
  const maxChars = fontMode || 32;
  const isLarge = btFontSize === 'large';
  const useSmallProductFont = btProductFontSize === 'small';
  const useLargeProductFont = btProductFontSize === 'large';
  const useLargeTotal = btTotalFontSize === 'large' || btTotalFontSize === 'xlarge';
  const useXLargeTotal = btTotalFontSize === 'xlarge';
  const currency = settings.currency || 'PKR';
  const header = settings.receiptHeader || 'Usman Hotel';
  const footer = settings.receiptFooter || 'Thank you for your business';
  const slipPrefix = settings.slipPrefix || 'UH';
  const invoiceNo = `${slipPrefix}-${order.orderNumber || order.id || ''}`;
  const dateText = formatDate(order.date, settings.receiptDateTimeFormat);

  const orderTypeDisplay = order.orderType === 'Takeaway' ? 'Pickup' : order.orderType || '';
  const customerName = order.customerName || (order.orderType === 'Takeaway' ? 'Pickup' : '');
  const phone = order.phone || '';
  const tableNo = order.orderType === 'Dine-In' ? (order.tableNumber || '') : '';
  const waiter = order.orderType === 'Dine-In' ? (order.waiter || '') : '';
  const address = order.orderType === 'Delivery' ? (order.address || '') : '';
  const serviceType = order.orderType === 'Delivery' ? (order.serviceType || '') : '';
  const rider = order.orderType === 'Delivery' ? (order.deliveryAgent || '') : '';
  const status = order.orderType === 'Delivery' ? (order.paymentStatus || order.status || '') : (order.status || '');

  const deliveryCharge = order.orderType === 'Delivery' ? Number(order.deliveryFee || order.deliveryCharge || 0) : 0;
  const serviceCharge = Number(order.serviceCharge || 0);
  const discountAmount = Number(order.discount || 0);
  const taxPercent = Number(order.taxPercent) || 0;
  const subtotal = (order.subtotal != null && order.subtotal !== 0)
    ? Number(order.subtotal)
    : (order.items || []).reduce((s, it) => s + ((Number(it.price || 0) * Number(it.quantity || 0)) || Number(it.total) || 0), 0);
  const taxAmount = Number(order.tax || ((subtotal - discountAmount) * taxPercent) / (taxPercent > 1 ? 100 : 1));
  const totalAmount = Math.max(0, subtotal - discountAmount + taxAmount + deliveryCharge + serviceCharge);

  const tokenPrefix = settings.tokenSlipPrefix || settings.slipPrefix || 'TS';
  const tokenNumber = settings.tokenSlipNextNumber || 1;
  const lines = [];

  if (settings._tokenOnly) {
    const tokenMargin = Number(settings.btTokenMargin ?? 8);
    const tokenLabelSz = Number(settings.btTokenLabelFontSize ?? 14);
    const tokenNumSz = Number(settings.btTokenFontSize ?? 44);

    lines.push(CMD.INIT);
    if (_encCP >= 0) lines.push(CMD.CODE_PAGE(_encCP));
    lines.push(CMD.LINE_SPACING_DEFAULT);
    lines.push(CMD.ALIGN_CENTER);

    if (tokenMargin > 0) lines.push(CMD.FEED_LINES(Math.min(tokenMargin, 15)));

    lines.push(CMD.BOLD_ON);
    lines.push(_enc(header));
    lines.push(CMD.LF);
    lines.push(CMD.BOLD_OFF);

    if (tokenLabelSz >= 18) {
      lines.push(CMD.DOUBLE_HEIGHT);
    }
    lines.push(_enc('Token Slip'));
    lines.push(CMD.LF);
    if (tokenLabelSz >= 18) {
      lines.push(useSmallFont ? CMD.FONT_B : CMD.FONT_A);
    }

    if (tokenNumSz >= 48) {
      lines.push(CMD.DOUBLE_WH);
    } else if (tokenNumSz >= 28) {
      lines.push(CMD.DOUBLE_HEIGHT);
    }
    lines.push(CMD.BOLD_ON);
    lines.push(_enc(`${tokenPrefix}-${tokenNumber}`));
    lines.push(CMD.LF, CMD.BOLD_OFF);
    lines.push(useSmallFont ? CMD.FONT_B : CMD.FONT_A);

    if (tokenMargin > 0) lines.push(CMD.FEED_LINES(Math.min(tokenMargin, 15)));
    lines.push(CMD.CUT);

    const totalLen = lines.reduce((sum, l) => sum + l.length, 0);
    const result = new Uint8Array(totalLen);
    let offset = 0;
    for (const chunk of lines) {
      result.set(chunk, offset);
      offset += chunk.length;
    }
    return result;
  }

  const separator = divider(btDividerStyle, maxChars);

  const showReceiptNumber = settings.receiptShowReceiptNumber !== false;
  const showDateTime = settings.receiptShowDateTime !== false;
  const showProductQty = settings.receiptShowProductQuantity !== false;
  const showProductPrice = settings.receiptShowProductUnitPrice !== false;
  const showSubtotal = settings.receiptShowSubtotal !== false;
  const showDelCharge = settings.receiptShowDeliveryCharge !== false;
  const showSerCharge = settings.receiptShowServiceCharge !== false;
  const showDiscount = settings.receiptShowDiscount !== false;
  const showTax = settings.receiptShowTax !== false;
  const showTotal = settings.receiptShowTotal !== false;
  const showCustMsg = settings.receiptShowCustomerMessage !== false;
  const showNotes = settings.receiptShowNotes !== false;

  lines.push(CMD.INIT);
  if (_encCP >= 0) lines.push(CMD.CODE_PAGE(_encCP));
  lines.push(CMD.LINE_SPACING_DEFAULT);
  lines.push(useSmallFont ? CMD.FONT_B : CMD.FONT_A);

  lines.push(CMD.ALIGN_CENTER, CMD.BOLD_ON, isLarge ? CMD.DOUBLE_WH : CMD.DOUBLE_HEIGHT);
  lines.push(_enc(header));
  lines.push(CMD.LF);
  lines.push(CMD.BOLD_OFF);
  lines.push(useSmallFont ? CMD.FONT_B : CMD.FONT_A);

  if (settings.location) {
    lines.push(CMD.ALIGN_CENTER);
    lines.push(_enc(settings.location));
    lines.push(CMD.LF);
  }
  if (settings.receiptCounterLabel) {
    lines.push(CMD.ALIGN_CENTER);
    lines.push(_enc(settings.receiptCounterLabel));
    lines.push(CMD.LF);
  }

  const showTokenForOrderType = (
    (order.orderType === 'Dine-In' && settings.btTokenOnDineIn !== false) ||
    (order.orderType === 'Takeaway' && settings.btTokenOnTakeaway !== false) ||
    (order.orderType === 'Delivery' && settings.btTokenOnDelivery !== false) ||
    (!order.orderType && settings.btTokenOnDineIn !== false)
  );
  const receiptTokenText = settings.tokenSlipEnabled && showTokenForOrderType
    ? `${tokenPrefix}-${tokenNumber}`
    : '';
  if (receiptTokenText) {
    lines.push(CMD.ALIGN_LEFT);
    lines.push(CMD.BOLD_ON);
    lines.push(isLarge ? CMD.DOUBLE_WH : CMD.DOUBLE_HEIGHT);
    lines.push(_enc(receiptTokenText));
    lines.push(CMD.LF);
    lines.push(CMD.BOLD_OFF);
    lines.push(useSmallFont ? CMD.FONT_B : CMD.FONT_A);
  }

  lines.push(CMD.ALIGN_CENTER);
  lines.push(_enc(separator));
  lines.push(CMD.LF);

  lines.push(CMD.ALIGN_LEFT);
  const invoiceText = showReceiptNumber && invoiceNo ? `Invoice No. ${invoiceNo}` : '';
  if (invoiceText && showDateTime && dateText) {
    lines.push(_enc(formatLine(invoiceText, dateText, maxChars)));
    lines.push(CMD.LF);
  } else {
    if (invoiceText) {
      lines.push(_enc(invoiceText));
      lines.push(CMD.LF);
    }
    if (showDateTime && dateText) {
      lines.push(_enc(dateText));
      lines.push(CMD.LF);
    }
  }

  if (orderTypeDisplay) {
    lines.push(_enc(formatLine('Order Type', orderTypeDisplay, maxChars)));
    lines.push(CMD.LF);
  }
  if (order.status === 'Completed') {
    lines.push(_enc(formatLine('Payment', 'Paid', maxChars)));
    lines.push(CMD.LF);
  } else if (order.status === 'Pay Later') {
    lines.push(_enc(formatLine('Payment', 'Pay Later', maxChars)));
    lines.push(CMD.LF);
  }
  if (customerName) {
    const displayName = order.orderType === 'Dine-In'
      ? (order.customerName || order.tableNumber || 'Table')
      : customerName;
    lines.push(_enc(formatLine('Customer', displayName, maxChars)));
    lines.push(CMD.LF);
  }
  if (order.orderType === 'Dine-In') {
    lines.push(_enc(formatLine('Table', tableNo || '-', maxChars)));
    lines.push(CMD.LF);
    lines.push(_enc(formatLine('Sales Person', waiter || '-', maxChars)));
    lines.push(CMD.LF);
  }
  if (order.orderType === 'Delivery') {
    lines.push(_enc(formatLine('Mobile', phone || '-', maxChars)));
    lines.push(CMD.LF);
    if (address) {
      lines.push(_enc('Location:'));
      lines.push(CMD.LF);
      wrapText(address, maxChars).forEach((line) => {
        lines.push(_enc(line));
        lines.push(CMD.LF);
      });
    } else {
      lines.push(_enc(formatLine('Location', '-', maxChars)));
      lines.push(CMD.LF);
    }
    lines.push(_enc(formatLine('Service Type', serviceType || '-', maxChars)));
    lines.push(CMD.LF);
    lines.push(_enc(formatLine('Rider', rider || '-', maxChars)));
    lines.push(CMD.LF);
    lines.push(_enc(formatLine('Status', status || '-', maxChars)));
    lines.push(CMD.LF);
  }
  if (order.orderType !== 'Dine-In' && order.orderType !== 'Delivery') {
    if (settings.receiptShowCustomerPhone !== false && phone) {
      lines.push(_enc(formatLine('Mobile', phone, maxChars)));
      lines.push(CMD.LF);
    }
    if (settings.receiptShowWaiterName !== false && waiter) {
      lines.push(_enc(formatLine('Sales Person', waiter, maxChars)));
      lines.push(CMD.LF);
    }
  }

  lines.push(CMD.ALIGN_CENTER);
  lines.push(_enc(separator));
  lines.push(CMD.LF);

  lines.push(CMD.ALIGN_LEFT);
  lines.push(CMD.BOLD_ON);
  if (showProductQty && showProductPrice) {
    lines.push(_enc(formatLine('Product', 'Qty Rate Amount', maxChars)));
  } else if (showProductQty) {
    lines.push(_enc(formatLine('Product', 'Qty Amount', maxChars)));
  } else if (showProductPrice) {
    lines.push(_enc(formatLine('Product', 'Rate Amount', maxChars)));
  } else {
    lines.push(_enc(formatLine('Product', 'Amount', maxChars)));
  }
  lines.push(CMD.LF);
  lines.push(CMD.BOLD_OFF);
  lines.push(CMD.ALIGN_CENTER);
  lines.push(_enc(separator));
  lines.push(CMD.LF);

  lines.push(CMD.ALIGN_LEFT);
  if (useSmallProductFont) {
    lines.push(useSmallFont ? CMD.FONT_B : CMD.FONT_B);
  } else if (useLargeProductFont) {
    lines.push(CMD.DOUBLE_HEIGHT);
  }
  for (const item of (order.items || [])) {
    const qty = Number(item.quantity || 1);
    const rate = Number(item.price || item.unitPrice || 0);
    const amount = Number(item.total ?? qty * rate);
    const itemName = String(item.name || '').trim();

    wrapText(itemName, maxChars).forEach((line) => {
      lines.push(_enc(line));
      lines.push(CMD.LF);
    });

    const qtyStr = showProductQty ? String(qty) : '';
    const rateStr = showProductPrice ? `${rate} ${currency}` : '';
    const amtStr = `${amount} ${currency}`;
    if (showProductQty && showProductPrice) {
      const detailLine = `${qtyStr}  ${rateStr}  ${amtStr}`;
      lines.push(_enc(detailLine));
      lines.push(CMD.LF);
    } else if (showProductQty) {
      lines.push(_enc(formatLine(`Qty: ${qtyStr}`, amtStr, maxChars)));
      lines.push(CMD.LF);
    } else if (showProductPrice) {
      lines.push(_enc(formatLine(`Rate: ${rateStr}`, amtStr, maxChars)));
      lines.push(CMD.LF);
    } else {
      lines.push(_enc(amtStr));
      lines.push(CMD.LF);
    }

    if (item.weight) {
      wrapText(`Weight: ${item.weight}`, maxChars).forEach((line) => {
        lines.push(_enc(line));
        lines.push(CMD.LF);
      });
    }
    if (item.flavor) {
      wrapText(`Flavor: ${item.flavor}`, maxChars).forEach((line) => {
        lines.push(_enc(line));
        lines.push(CMD.LF);
      });
    }
  }
  if (useSmallProductFont || useLargeProductFont) {
    lines.push(useSmallFont ? CMD.FONT_A : CMD.FONT_A);
  }

  lines.push(CMD.ALIGN_CENTER);
  lines.push(_enc(separator));
  lines.push(CMD.LF);

  lines.push(CMD.ALIGN_LEFT);

  lines.push(CMD.BOLD_ON);
  lines.push(_enc(`Total Due: ${totalAmount} Rs`));
  lines.push(CMD.LF);
  lines.push(CMD.BOLD_OFF);

  if (showSubtotal) {
    lines.push(_enc(formatLine('Subtotal:', `${subtotal} Rs`, maxChars)));
    lines.push(CMD.LF);
  }
  if (order.orderType === 'Delivery' && showDelCharge && deliveryCharge > 0) {
    lines.push(_enc(formatLine('Delivery:', `${deliveryCharge} Rs`, maxChars)));
    lines.push(CMD.LF);
  }
  if (showSerCharge && serviceCharge > 0) {
    lines.push(_enc(formatLine('Service:', `${serviceCharge} Rs`, maxChars)));
    lines.push(CMD.LF);
  }
  if (showDiscount && discountAmount > 0) {
    lines.push(_enc(formatLine('Discount:', `${discountAmount} Rs`, maxChars)));
    lines.push(CMD.LF);
  }
  if (showTax && taxAmount > 0) {
    lines.push(_enc(formatLine('Tax:', `${taxAmount} Rs`, maxChars)));
    lines.push(CMD.LF);
  }
  if (showTotal) {
    if (useXLargeTotal) {
      lines.push(CMD.ALIGN_CENTER);
      lines.push(CMD.BOLD_ON);
      lines.push(CMD.DOUBLE_WH);
      lines.push(_enc(`Total: ${totalAmount} Rs`));
      lines.push(CMD.LF);
      lines.push(CMD.BOLD_OFF);
      lines.push(useSmallFont ? CMD.FONT_B : CMD.FONT_A);
      lines.push(CMD.ALIGN_LEFT);
    } else if (useLargeTotal) {
      lines.push(CMD.ALIGN_CENTER);
      lines.push(CMD.BOLD_ON);
      lines.push(CMD.DOUBLE_HEIGHT);
      lines.push(_enc(`Total: ${totalAmount} Rs`));
      lines.push(CMD.LF);
      lines.push(CMD.BOLD_OFF);
      lines.push(useSmallFont ? CMD.FONT_B : CMD.FONT_A);
      lines.push(CMD.ALIGN_LEFT);
    } else {
      lines.push(CMD.BOLD_ON);
      lines.push(_enc(formatLine('Total:', `${totalAmount} Rs`, maxChars)));
      lines.push(CMD.LF);
      lines.push(CMD.BOLD_OFF);
    }
  }

  if (showCustMsg && order.customerMessage) {
    lines.push(CMD.ALIGN_LEFT);
    wrapText(`Note: ${order.customerMessage}`, maxChars).forEach((line) => {
      lines.push(_enc(line));
      lines.push(CMD.LF);
    });
  }
  if (showNotes && order.notes) {
    lines.push(CMD.ALIGN_LEFT);
    wrapText(`Remarks: ${order.notes}`, maxChars).forEach((line) => {
      lines.push(_enc(line));
      lines.push(CMD.LF);
    });
  }

  lines.push(CMD.ALIGN_CENTER);
  lines.push(_enc(separator));
  lines.push(CMD.LF);
  lines.push(_enc(footer));
  lines.push(CMD.LF);

  lines.push(CMD.FEED_LINES(3));
  lines.push(CMD.CUT);

  const totalLen = lines.reduce((sum, l) => sum + l.length, 0);
  const result = new Uint8Array(totalLen);
  let offset = 0;
  for (const l of lines) {
    result.set(l, offset);
    offset += l.length;
  }
  return result;
}

export function renderReceiptToCanvas(order, settings = {}) {
  const paperWidth = settings.receiptPaperWidth || '58';
  const mmWidth = paperWidth === '80' ? 80 : 58;
  const pxWidth = Math.round(mmWidth * 8);
  const fontFamily = settings.btFontFamily || 'Noto Naskh Arabic, Segoe UI, Arial, sans-serif';
  const currency = settings.currency || 'PKR';
  const header = settings.btReceiptHeader || settings.receiptHeader || 'Usman Hotel';
  const footer = settings.btReceiptFooter || settings.receiptFooter || 'Thank you for your business';
  const fontSize = Number(settings.btFontSize) || 20;
  const totalFontSize = Number(settings.btTotalFontSize) || 26;
  const productFontSize = Number(settings.btProductFontSize) || fontSize;
  const orderTypeFontSize = Number(settings.btOrderTypeFontSize) || 18;
  const serviceTypeFontSize = Number(settings.btServiceTypeFontSize) || 16;
  const tokenFontSize = Number(settings.btTokenFontSize) || 44;
  const tokenLabelFontSize = Number(settings.btTokenLabelFontSize) || 14;
  const textAlign = settings.btTextAlign || 'left';
  const marginTop = settings.btMarginCustom ? (Number(settings.btMarginTop) || 10) : 10;
  const marginBottom = settings.btMarginCustom ? (Number(settings.btMarginBottom) || 10) : 10;
  const logoEnabled = settings.btLogoEnabled !== false;
  const tokenOnReceipt = settings.btTokenOnReceipt !== false;
  const showTotalOnToken = settings.btShowTotalOnToken !== false;

  const canvas = document.createElement('canvas');
  canvas.width = pxWidth;
  canvas.height = 12000;
  const ctx = canvas.getContext('2d');

  let y = marginTop;
  const margin = 2;

  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, pxWidth, 12000);

  function printLine(text, opts = {}) {
    const sz = opts.fontSize || fontSize;
    ctx.font = `${opts.bold ? 'bold ' : ''}${sz}px ${fontFamily}`;
    ctx.fillStyle = '#000000';
    const align = opts.align || textAlign;
    ctx.textAlign = align;
    let x;
    if (opts.x != null) {
      x = opts.x;
    } else {
      x = align === 'center' ? pxWidth / 2 : align === 'right' ? pxWidth - margin : margin;
    }
    ctx.fillText(String(text), x, y);
    if (opts.noAdvance) return;
    y += opts.lineHeight || Math.round(sz * 1.5);
  }

  function printDivider(ch, opts = {}) {
    const sz = opts.fontSize || Math.round(fontSize * 0.7);
    ctx.font = `${sz}px ${fontFamily}`;
    ctx.fillStyle = '#000000';
    ctx.textAlign = 'center';
    const dash = ch || '-';
    const dashW = ctx.measureText(dash).width || 6;
    const count = Math.min(Math.floor((pxWidth - margin * 2) / dashW), 48);
    ctx.fillText(dash.repeat(Math.max(count, 6)), pxWidth / 2, y);
    y += opts.lineHeight || Math.round(sz * 1.6);
  }

  const totalAmount = (() => {
    if (settings._tokenOnly) return Math.max(0, Number(order.total || order.grandTotal || 0));
    const subtotal = (order.subtotal != null && order.subtotal !== 0)
      ? Number(order.subtotal)
      : (order.items || []).reduce((s, it) => s + ((Number(it.price || 0) * Number(it.quantity || 0)) || Number(it.total) || 0), 0);
    const discountAmount = Number(order.discount || 0);
    const taxAmount = Number(order.tax || 0);
    const deliveryCharge = order.orderType === 'Delivery' ? Number(order.deliveryFee || order.deliveryCharge || 0) : 0;
    const serviceCharge = Number(order.serviceCharge || 0);
    return Math.max(0, subtotal - discountAmount + taxAmount + deliveryCharge + serviceCharge);
  })();

  if (settings._tokenOnly) {
    const slipPrefix = settings.tokenSlipPrefix || settings.slipPrefix || 'TS';
    const tokenNumber = settings.tokenSlipNextNumber || 1;
    const tokenSlipLogoEnabled = settings.btTokenSlipLogoEnabled !== false;
    const tokenMargin = Number(settings.btTokenMargin ?? 8);
    y = tokenMargin;

    const logoUrl = settings.logo;
    if (logoUrl && tokenSlipLogoEnabled) {
      const logoW = Math.min(Number(settings.btLogoWidth) || 70, pxWidth * 0.35);
      if (logoUrl.startsWith('data:')) {
        const img = new Image();
        img.src = logoUrl;
        if (img.complete && img.naturalWidth > 0) {
          const aspect = img.naturalHeight / img.naturalWidth;
          const logoH = logoW * aspect;
          ctx.drawImage(img, (pxWidth - logoW) / 2, y, logoW, logoH);
          y += logoH + 4;
        } else {
          ctx.font = `${Math.round(fontSize * 0.8)}px ${fontFamily}`;
          ctx.textAlign = 'center';
          ctx.fillStyle = '#000';
          ctx.fillText(header, pxWidth / 2, y + Math.round(fontSize * 0.8));
          y += Math.round(fontSize * 0.8) + 4;
        }
      }
    }

    printLine(header, { bold: true, fontSize: Math.round(tokenLabelFontSize * 1.3), align: 'center', lineHeight: Math.round(tokenLabelFontSize * 1.6) });
    printLine('Token Slip', { bold: true, fontSize: tokenLabelFontSize, align: 'center', lineHeight: Math.round(tokenLabelFontSize * 1.5) });
    y += Math.round(tokenFontSize * 0.3);
    printLine(`${slipPrefix}-${tokenNumber}`, { bold: true, fontSize: tokenFontSize, align: 'center', lineHeight: Math.round(tokenFontSize * 1.3) });
    if (showTotalOnToken && totalAmount > 0) {
      y += Math.round(tokenFontSize * 0.15);
      printDivider('-', { fontSize: Math.round(tokenLabelFontSize * 0.7) });
      printLine(`Total: ${totalAmount} Rs`, { bold: true, fontSize: Math.round(tokenLabelFontSize * 1.3), align: 'center' });
    }
    y += 8 + tokenMargin;
    const h = Math.max(Math.ceil(y), 80);
    const imgData = ctx.getImageData(0, 0, pxWidth, Math.min(h, canvas.height));
    canvas.width = pxWidth;
    canvas.height = h;
    ctx.putImageData(imgData, 0, 0);
    return canvas;
  }

  const titleSz = Math.round(fontSize * 1.1);
  const infoSz = Math.round(fontSize * 0.85);
  const dividerSz = Math.round(fontSize * 0.65);
  const logoW = Math.min(Number(settings.receiptLogoWidth) || 70, pxWidth * 0.35);

  const showTokenForOrderType = (
    (order.orderType === 'Dine-In' && settings.btTokenOnDineIn !== false) ||
    (order.orderType === 'Takeaway' && settings.btTokenOnTakeaway !== false) ||
    (order.orderType === 'Delivery' && settings.btTokenOnDelivery !== false) ||
    (!order.orderType && settings.btTokenOnDineIn !== false)
  );
  const receiptTokenText = tokenOnReceipt && settings.tokenSlipEnabled && showTokenForOrderType
    ? `${settings.tokenSlipPrefix || settings.slipPrefix || 'TS'}-${settings.tokenSlipNextNumber || 1}`
    : '';

  const logoUrl = settings.logo;

  if (receiptTokenText || (logoUrl && logoEnabled)) {
    const lineH = Math.max(infoSz + 4, logoW * 0.3 + 4);
    if (receiptTokenText) {
      ctx.font = `bold ${infoSz}px ${fontFamily}`;
      ctx.textAlign = 'left';
      ctx.fillStyle = '#000000';
      ctx.fillText(`#${receiptTokenText}`, margin, y + infoSz);
    }
    if (logoUrl && logoEnabled) {
      const img = new Image();
      img.src = logoUrl;
      const aspect = img.width ? img.height / img.width : 0.3;
      const logoH = Math.min(logoW * aspect, logoW * 0.4);
      if (img.complete && img.naturalWidth > 0) {
        ctx.drawImage(img, pxWidth - margin - logoW, y, logoW, logoH);
      } else {
        ctx.font = `${infoSz}px ${fontFamily}`;
        ctx.textAlign = 'right';
        ctx.fillStyle = '#999';
        ctx.fillText('[Logo]', pxWidth - margin, y + infoSz);
      }
    }
    y += Math.max(infoSz + 6, Math.round(logoW * 0.3) + 4);
  }

  printLine(header, { bold: true, fontSize: titleSz, align: 'center', lineHeight: Math.round(titleSz * 1.4) });
  if (settings.location) {
    printLine(settings.location, { fontSize: infoSz, align: 'center' });
  }
  if (settings.receiptCounterLabel) {
    printLine(settings.receiptCounterLabel, { fontSize: infoSz, align: 'center' });
  }

  const slipPrefix = settings.slipPrefix || 'UH';
  const invoiceNo = `${slipPrefix}-${order.orderNumber || order.id || ''}`;
  const dateText = formatDate(order.date, settings.receiptDateTimeFormat);
  if (invoiceNo || dateText) {
    printLine(`${invoiceNo}    ${dateText}`, { fontSize: infoSz });
  }

  const orderTypeDisplay = order.orderType === 'Takeaway' ? 'Pickup' : order.orderType || '';
  const customerName = order.customerName || (order.orderType === 'Takeaway' ? 'Pickup' : '');

  if (orderTypeDisplay) printLine(`Order Type: ${orderTypeDisplay}`, { fontSize: orderTypeFontSize });
  if (order.status === 'Completed') printLine('Payment: Paid', { fontSize: infoSz });
  else if (order.status === 'Pay Later') printLine('Payment: Pay Later', { fontSize: infoSz });
  if (customerName) printLine(`Customer: ${customerName}`, { fontSize: infoSz });
  if (order.orderType === 'Dine-In') {
    printLine(`Table: ${order.tableNumber || '-'}`, { fontSize: infoSz });
    printLine(`Sales Person: ${order.waiter || '-'}`, { fontSize: infoSz });
  }
  if (order.orderType === 'Delivery') {
    printLine(`Mobile: ${order.phone || '-'}`, { fontSize: infoSz });
    if (order.address) printLine(`Location: ${order.address}`, { fontSize: infoSz });
    printLine(`Service Type: ${order.serviceType || '-'}`, { fontSize: serviceTypeFontSize });
    printLine(`Rider: ${order.deliveryAgent || '-'}`, { fontSize: infoSz });
  }

  y += 6;
  printDivider('-', { fontSize: dividerSz });

  const prodSz = productFontSize;
  const lh = Math.round(prodSz * 1.5);
  const rightEdge = pxWidth - margin;

  ctx.font = `bold ${prodSz}px ${fontFamily}`;
  const colW = ctx.measureText('9999').width + 6;
  const qtyColW = ctx.measureText('999').width + 4;
  const rateColW = ctx.measureText('9999').width + 4;
  const amtColW = colW;
  const totalsColsW = qtyColW + rateColW + amtColW + 8;
  const nameMaxW = Math.max(40, pxWidth - margin * 2 - totalsColsW - 4);

  ctx.textAlign = 'left';
  ctx.fillStyle = '#000000';
  ctx.fillText('Product', margin, y);
  ctx.textAlign = 'right';
  ctx.fillText('Qty', rightEdge - amtColW - rateColW - 4, y);
  ctx.fillText('Rate', rightEdge - amtColW, y);
  ctx.fillText('Amt', rightEdge, y);
  y += lh;

  printDivider('-', { fontSize: dividerSz });

  for (const item of (order.items || [])) {
    const qty = Number(item.quantity || 1);
    const rate = Number(item.price || item.unitPrice || 0);
    const amount = Number(item.total ?? qty * rate);
    const name = String(item.name || '').trim();
    ctx.font = `${prodSz}px ${fontFamily}`;
    const words = name.split(' ').filter(Boolean);
    const nameLines = [];
    let currentLine = '';
    for (const word of words) {
      const testLine = currentLine ? currentLine + ' ' + word : word;
      if (ctx.measureText(testLine).width > nameMaxW && currentLine) {
        nameLines.push(currentLine);
        currentLine = word;
      } else {
        currentLine = testLine;
      }
    }
    if (currentLine) nameLines.push(currentLine);
    if (nameLines.length === 0) nameLines.push('');
    nameLines.forEach((line, idx) => {
      ctx.textAlign = 'left';
      ctx.fillStyle = '#000000';
      ctx.fillText(line, margin, y);
      ctx.textAlign = 'right';
      if (idx === 0) {
        ctx.fillText(String(qty), rightEdge - amtColW - rateColW - 4, y);
        ctx.fillText(String(rate), rightEdge - amtColW, y);
        ctx.fillText(String(amount), rightEdge, y);
      }
      y += lh;
    });
  }

  printDivider('-', { fontSize: dividerSz });

  const subtotal = (order.subtotal != null && order.subtotal !== 0)
    ? Number(order.subtotal)
    : (order.items || []).reduce((s, it) => s + ((Number(it.price || 0) * Number(it.quantity || 0)) || Number(it.total) || 0), 0);
  const discountAmount = Number(order.discount || 0);
  const taxAmount = Number(order.tax || 0);
  const deliveryCharge = order.orderType === 'Delivery' ? Number(order.deliveryFee || order.deliveryCharge || 0) : 0;
  const serviceCharge = Number(order.serviceCharge || 0);

  printLine(`Total Due: ${totalAmount} Rs`, { bold: true, fontSize: Math.round(totalFontSize * 0.85) });
  if (subtotal > 0) printLine(`Subtotal: ${subtotal} Rs`, { fontSize: infoSz });
  if (deliveryCharge > 0) printLine(`Delivery: ${deliveryCharge} Rs`, { fontSize: infoSz });
  if (serviceCharge > 0) printLine(`Service: ${serviceCharge} Rs`, { fontSize: infoSz });
  if (discountAmount > 0) printLine(`Discount: ${discountAmount} Rs`, { fontSize: infoSz });
  if (taxAmount > 0) printLine(`Tax: ${taxAmount} Rs`, { fontSize: infoSz });
  printLine(`Total: ${totalAmount} Rs`, { bold: true, fontSize: totalFontSize, align: 'center' });

  y += 6;
  printDivider('-', { fontSize: dividerSz });
  printLine(footer, { fontSize: infoSz, align: 'center' });

  const actualHeight = Math.ceil(y + marginBottom);

  const ps = String(order.paymentStatus || '').toLowerCase();
  const os = String(order.status || '').toLowerCase();
  const isPaid = os === 'completed' || os === 'paid' || ps === 'paid' || ps === 'paid to cash on counter' || ps.includes('paid');
  if (isPaid && settings.btShowPaidWatermark !== false) {
    const cx = pxWidth / 2;
    const cy = actualHeight / 2;
    const maxDim = Math.min(pxWidth, Math.max(actualHeight, 200)) * 0.5;
    const r = Math.max(maxDim, 50);

    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(-Math.PI / 6);

    ctx.font = `bold ${Math.round(r * 0.38)}px Arial`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillText('PAID', 0, Math.round(-r * 0.08));

    ctx.font = `bold ${Math.round(r * 0.14)}px Arial`;
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillText('Usman Hotel', 0, Math.round(r * 0.16));

    ctx.restore();

    ctx.save();
    ctx.strokeStyle = 'rgba(0,0,0,0.3)';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(cx, cy, r * 0.55, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  const imageData = ctx.getImageData(0, 0, pxWidth, Math.min(actualHeight, canvas.height));
  canvas.width = pxWidth;
  canvas.height = actualHeight;
  ctx.putImageData(imageData, 0, 0);

  return canvas;
}

export function canvasToEscposRaster(canvas) {
  const ctx = canvas.getContext('2d');
  const width = canvas.width;
  const height = canvas.height;
  const imageData = ctx.getImageData(0, 0, width, height);
  const data = imageData.data;

  const bytesPerLine = Math.ceil(width / 8);
  const rasterData = [];

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x += 8) {
      let byte = 0;
      for (let b = 0; b < 8; b++) {
        const px = x + b;
        if (px < width) {
          const idx = (y * width + px) * 4;
          const brightness = (data[idx] + data[idx + 1] + data[idx + 2]) / 3;
          if (brightness < 128) {
            byte |= (1 << (7 - b));
          }
        }
      }
      rasterData.push(byte);
    }
  }

  const xL = bytesPerLine & 0xFF;
  const xH = (bytesPerLine >> 8) & 0xFF;
  const yL = height & 0xFF;
  const yH = (height >> 8) & 0xFF;

  const header = CMD.GS_v_0(0, xL, xH, yL, yH);
  return new Uint8Array([...header, ...rasterData]);
}

function formatDate(dateString, format) {
  if (!dateString || !format) return '';
  const date = new Date(dateString);
  const zero = (v) => String(v).padStart(2, '0');
  return format
    .replace('DD', zero(date.getDate()))
    .replace('MM', zero(date.getMonth() + 1))
    .replace('YYYY', String(date.getFullYear()))
    .replace('HH', zero(date.getHours()))
    .replace('mm', zero(date.getMinutes()))
    .replace('ss', zero(date.getSeconds()));
}
