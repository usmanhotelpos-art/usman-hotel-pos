import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterInfo {
  final String name;
  final String mac;
  const PrinterInfo(this.name, this.mac);
}

/// Bluetooth (SPP) thermal printer service.
///
/// Talks to the app's OWN native Android Bluetooth module
/// (MainActivity.kt, channel "usmanhotel/bt") instead of a third-party
/// plugin. This gives us:
///  * an explicit permission dialog every time we attach ("Nearby devices"),
///  * three connection transports + retries (secure RFCOMM, insecure,
///    reflection fallback) which is what actually makes cheap thermal
///    printers attach reliably,
///  * real Android error strings instead of silent failures,
///  * hard timeouts so nothing can hang the UI.
class BtService {
  static const _channel = MethodChannel('usmanhotel/bt');

  static const _macKey = 'bt_printer_mac';
  static const _nameKey = 'bt_printer_name';

  /// Human readable reason for the last failure (shown in toasts).
  static String lastError = '';

  static Future<PrinterInfo?> savedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_macKey);
    if (mac == null || mac.isEmpty) return null;
    return PrinterInfo(prefs.getString(_nameKey) ?? 'Printer', mac);
  }

  static Future<void> savePrinter(PrinterInfo p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_macKey, p.mac.trim().toUpperCase());
    await prefs.setString(_nameKey, p.name);
  }

  static Future<void> clearPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_macKey);
    await prefs.remove(_nameKey);
  }

  static Future<T?> _timeout<T>(Future<dynamic> future, Duration d) async {
    try {
      final v = await future.timeout(d);
      return v is T ? v : null;
    } on TimeoutException {
      lastError = 'Bluetooth system response timed out';
      return null;
    } on PlatformException catch (e) {
      lastError = e.message ?? e.code;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Asks Android for the Bluetooth permission ("Nearby devices") if it is
  /// not granted yet - the system dialog pops up right in front of the user.
  /// When permanently denied we open the app's settings page.
  static Future<bool> ensurePermission() async {
    lastError = '';

    // Native check first (works for all Android versions).
    final granted =
        await _timeout<bool>(_channel.invokeMethod('connectPermissionGranted'),
            const Duration(seconds: 5));
    if (granted == true) return true;

    // Fire the system permission dialog via the platform channel.
    final requested = await _timeout<bool>(
        _channel.invokeMethod('requestPermissions'), const Duration(seconds: 60));
    if (requested == true) return true;

    // Fall back to permission_handler (handles permanently-denied state).
    try {
      final status = await Permission.bluetoothConnect.status;
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied ||
          (requested == false && !status.isGranted)) {
        final again = await Permission.bluetoothConnect.request();
        if (again.isGranted) return true;
        if (again.isPermanentlyDenied) {
          lastError =
              'Bluetooth permission permanently denied - App Settings mein "Nearby devices" on karein';
          await openAppSettings();
          return false;
        }
      }
    } catch (_) {}

    lastError = lastError.isEmpty ? 'Bluetooth permission denied' : lastError;
    return false;
  }

  /// True when the phone's Bluetooth adapter is switched on.
  static Future<bool> bluetoothEnabled() async {
    final r = await _timeout<bool>(
        _channel.invokeMethod('bluetoothEnabled'), const Duration(seconds: 5));
    return r ?? false;
  }

  /// Paired printers from Android system Bluetooth settings.
  static Future<List<PrinterInfo>> pairedPrinters() async {
    lastError = '';
    if (!(await ensurePermission())) return [];
    final raw = await _timeout<List<dynamic>>(
        _channel.invokeMethod('pairedDevices'), const Duration(seconds: 10));
    if (raw == null) return [];
    return raw
        .whereType<String>()
        .map((entry) {
          final idx = entry.lastIndexOf('#');
          if (idx <= 0 || idx == entry.length - 1) return null;
          return PrinterInfo(entry.substring(0, idx),
              entry.substring(idx + 1).trim().toUpperCase());
        })
        .whereType<PrinterInfo>()
        .toList();
  }

  static Future<bool> isConnected() async {
    final r = await _timeout<bool>(_channel.invokeMethod('isConnected'),
        const Duration(seconds: 5));
    return r == true;
  }

  static Future<void> disconnect() async {
    try {
      await _timeout(
          _channel.invokeMethod('disconnect'), const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Robust connect: resets any stale socket and lets the native side try
  /// all transports; then retries the whole round once more after a pause.
  static Future<bool> connect(PrinterInfo p) async {
    lastError = '';
    if (!(await ensurePermission())) return false;

    for (var round = 1; round <= 2; round++) {
      final ok = await _timeout<bool>(
          _channel.invokeMethod('connect', p.mac.trim().toUpperCase()),
          const Duration(seconds: 20));
      if (ok == true) {
        lastError = '';
        return true;
      }
      if (lastError.isEmpty) {
        final err = await _timeout<String>(
            _channel.invokeMethod('lastError'), const Duration(seconds: 4));
        if (err != null && err.isNotEmpty) lastError = err;
      }
      // "Bluetooth OFF" won't fix itself - bail out immediately.
      if (lastError.contains('OFF')) return false;
      if (round < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
    }
    return false;
  }

  /// Serialised print queue - one slip at a time so concurrent prints never
  /// interleave (same as the web app's enqueuePrint).
  static Future<void> _queue = Future.value();

  static Future<void> enqueue(Future<void> Function() job) {
    final run = _queue.then((_) => job());
    _queue = run.catchError((_) {});
    return run;
  }

  static Future<void> write(List<int> data, {int chunkSize = 256}) async {
    for (var i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      final ok = await _timeout<bool>(
          _channel.invokeMethod('writeBytes', data.sublist(i, end)),
          const Duration(seconds: 15));
      if (ok != true) {
        throw Exception('Printer write failed (${lastError.isEmpty ? 'connection lost' : lastError})');
      }
      if (i + chunkSize < data.length) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }
  }
}
