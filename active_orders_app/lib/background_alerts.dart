import 'dart:io';

import 'package:flutter/services.dart';

class BackgroundAlerts {
  static const MethodChannel _channel = MethodChannel(
    'active_orders/background',
  );

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('start');
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
