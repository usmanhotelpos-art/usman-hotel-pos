import { buildEscposReceipt, CMD } from './escpos.js';

const BT_PRINTER_KEY = 'bt_printer_info';

// SPP service UUID (many Bluetooth printers expose this)
const SPP_SERVICE_UUID = '00001101-0000-1000-8000-00805f9b34fb';

export function getSavedPrinterInfo() {
  try {
    const saved = localStorage.getItem(BT_PRINTER_KEY);
    return saved ? JSON.parse(saved) : null;
  } catch {
    return null;
  }
}

export function savePrinterInfo(info) {
  localStorage.setItem(BT_PRINTER_KEY, JSON.stringify(info));
}

export function clearPrinterInfo() {
  localStorage.removeItem(BT_PRINTER_KEY);
}

export async function requestBluetoothPrinter() {
  if (!navigator.bluetooth) {
    throw new Error('Web Bluetooth API not available. Use Chrome on Android.');
  }

  const device = await navigator.bluetooth.requestDevice({
    acceptAllDevices: true,
    optionalServices: [SPP_SERVICE_UUID, '000018f0-0000-1000-8000-00805f9b34fb'],
  });

  const info = {
    id: device.id,
    name: device.name || 'Unknown Printer',
  };

  savePrinterInfo({ id: device.id, name: device.name || 'Unknown Printer' });

  return { device, info };
}

async function findServiceAndChar(server) {
  let service = null;
  let characteristic = null;

  try {
    service = await server.getPrimaryService(SPP_SERVICE_UUID);
  } catch {}

  if (!service) {
    try {
      service = await server.getPrimaryService('000018f0-0000-1000-8000-00805f9b34fb');
    } catch {}
  }

  if (!service) {
    try {
      const services = await server.getPrimaryServices();
      if (services && services.length > 0) {
        service = services[0];
      }
    } catch {}
  }

  if (!service) {
    throw new Error('Could not find a suitable service on the printer');
  }

  const characteristics = await service.getCharacteristics();
  for (const char of characteristics) {
    if (char.properties.write || char.properties.writeWithoutResponse) {
      characteristic = char;
      break;
    }
  }

  if (!characteristic) {
    throw new Error('No writable characteristic found on the printer');
  }

  return { service, characteristic };
}

async function connectGatt(device) {
  // If already connected, try to reuse the connection
  if (device.gatt.connected) {
    try {
      return await findServiceAndChar(device.gatt);
    } catch (err) {
      console.warn('Reusing existing GATT connection failed, reconnecting:', err.message);
      try { device.gatt.disconnect(); } catch {}
    }
  }

  const server = await device.gatt.connect();
  return await findServiceAndChar(server);
}

async function writeWithRetry(characteristic, buf, retries = 2) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      if (characteristic.writeValueWithoutResponse) {
        await characteristic.writeValueWithoutResponse(buf);
      } else {
        await characteristic.writeValue(buf);
      }
      return;
    } catch (err) {
      if (attempt < retries) {
        await new Promise((r) => setTimeout(r, 20));
      } else {
        throw err;
      }
    }
  }
}

export async function disconnectDevice(device) {
  try {
    if (device && device.gatt) {
      if (device.gatt.connected) {
        await device.gatt.disconnect();
      }
    }
  } catch (err) {
    console.warn('Bluetooth disconnect error:', err.message);
  }
}

export async function printToBluetooth(device, data) {
  let characteristic;

  try {
    const result = await connectGatt(device);
    characteristic = result.characteristic;
  } catch (err) {
    // If connection fails, try one full reconnect: disconnect and re-connect
    console.warn('BT connect failed, retrying with full reconnect:', err.message);
    try { await disconnectDevice(device); } catch {}
    const result = await connectGatt(device);
    characteristic = result.characteristic;
  }

  const initCmd = new Uint8Array(CMD.INIT);
  await writeWithRetry(characteristic, initCmd);
  await new Promise((r) => setTimeout(r, 100));

  const chunkSize = 512;
  for (let i = 0; i < data.length; i += chunkSize) {
    const chunk = data.slice(i, i + chunkSize);
    await writeWithRetry(characteristic, chunk);
    if (i + chunkSize < data.length) {
      await new Promise((r) => setTimeout(r, 8));
    }
  }

  return true;
}

export async function autoConnectSavedPrinter() {
  const saved = getSavedPrinterInfo();
  if (!saved || !saved.id) {
    throw new Error('No saved printer found');
  }

  if (!navigator.bluetooth) {
    throw new Error('Web Bluetooth API not available. Use Chrome on Android.');
  }

  try {
    // Try getDevices() first (Chrome 100+, no user gesture needed on reconnect)
    if (navigator.bluetooth.getDevices) {
      const pairedDevices = await navigator.bluetooth.getDevices();
      const match = pairedDevices.find(d => d.id === saved.id);
      if (match) {
        return { device: match, info: { id: match.id, name: match.name || saved.name || 'Printer' } };
      }
    }

    // Fall back to requestDevice (requires user gesture/dialog)
    const device = await navigator.bluetooth.requestDevice({
      filters: [{ deviceId: saved.id }],
      optionalServices: [SPP_SERVICE_UUID, '000018f0-0000-1000-8000-00805f9b34fb'],
    });

    return { device, info: { id: device.id, name: device.name || saved.name || 'Printer' } };
  } catch (err) {
    throw new Error(`Auto-reconnect failed: ${err.message}`);
  }
}

export async function connectAndPrint(order, settings = {}) {
  if (!navigator.bluetooth) {
    throw new Error('Web Bluetooth API not available. Use Chrome on Android.');
  }

  const device = await navigator.bluetooth.requestDevice({
    acceptAllDevices: true,
    optionalServices: [SPP_SERVICE_UUID, '000018f0-0000-1000-8000-00805f9b34fb'],
  });

  const escposData = buildEscposReceipt(order, settings);

  await printToBluetooth(device, escposData);

  savePrinterInfo({ id: device.id, name: device.name || 'Unknown Printer' });

  return device.name || 'Printer';
}
