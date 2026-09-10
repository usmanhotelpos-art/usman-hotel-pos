import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterInfo {
  final String name;
  final String mac;
  const PrinterInfo(this.name, this.mac);
}

class BtService {
  static const _channel = MethodChannel('usmanhotel/bt');
  static const _macKey = 'stock_bt_mac';
  static const _nameKey = 'stock_bt_name';
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

  static Future<bool> ensurePermission() async {
    lastError = '';
    final granted = await _timeout<bool>(
        _channel.invokeMethod('connectPermissionGranted'), const Duration(seconds: 5));
    if (granted == true) return true;

    final requested = await _timeout<bool>(
        _channel.invokeMethod('requestPermissions'), const Duration(seconds: 10));
    if (requested == true) return true;

    final status = await Permission.bluetoothConnect.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    lastError = 'Bluetooth permission denied';
    return false;
  }

  static Future<bool> isBluetoothEnabled() async {
    final enabled = await _timeout<bool>(
        _channel.invokeMethod('bluetoothEnabled'), const Duration(seconds: 3));
    return enabled == true;
  }

  static Future<bool> enableBluetooth() async {
    final enabled = await _timeout<bool>(
        _channel.invokeMethod('enableBluetooth'), const Duration(seconds: 5));
    // If already enabled, returns false - treat as enabled
    final isOn = await isBluetoothEnabled();
    return enabled == true || isOn;
  }

  static Future<List<PrinterInfo>> getPairedDevices() async {
    final result = await _timeout<List>(
        _channel.invokeMethod('pairedDevices'), const Duration(seconds: 5));
    if (result == null) return [];
    return result.map((entry) {
      final parts = entry.toString().split('#');
      final name = parts.isNotEmpty ? parts.first : 'Unknown';
      final mac = parts.length > 1 ? parts[1] : '';
      return PrinterInfo(name, mac);
    }).where((p) => p.mac.isNotEmpty).toList();
  }

  static Future<bool> connect(String mac) async {
    lastError = '';
    final result = await _timeout<bool>(
        _channel.invokeMethod('connect', mac), const Duration(seconds: 15));
    return result == true;
  }

  static Future<bool> disconnect() async {
    await _timeout(_channel.invokeMethod('disconnect'), const Duration(seconds: 5));
    return true;
  }

  static Future<bool> isConnected() async {
    final result = await _timeout<bool>(
        _channel.invokeMethod('isConnected'), const Duration(seconds: 3));
    return result == true;
  }

  static Future<bool> printBytes(List<int> data) async {
    lastError = '';
    final result = await _timeout<bool>(
        _channel.invokeMethod('writeBytes', Uint8List.fromList(data)),
        const Duration(seconds: 10));
    if (result != true) {
      lastError = lastError.isEmpty ? 'Print failed' : lastError;
    }
    return result == true;
  }
}