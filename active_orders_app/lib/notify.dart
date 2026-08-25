import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for new-order alerts.
///
/// Shows a loud heads-up notification on the alarm stream whenever a new
/// dine-in order lands, and handles the Android 13+ POST_NOTIFICATIONS
/// runtime permission request.
class NotifyService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const String _channelId = 'active_orders_alerts';
  static const String _channelName = 'New Order Alerts';
  static const String _channelDesc = 'Loud alert for every new dine-in order';

  static Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);
      _ready = true;
    } catch (_) {}
  }

  /// Returns true when notifications are allowed. On Android 13+ this pops
  /// the system permission dialog the first time.
  static Future<bool> requestPermission() async {
    await init();
    try {
      final impl =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final granted = await impl?.requestNotificationsPermission();
      return granted == true;
    } catch (_) {
      return false;
    }
  }

  /// Fire-and-forget heads-up notification for a new order.
  static Future<void> showNewOrder({
    required String title,
    required String body,
    int id = 1001,
  }) async {
    await init();
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          ongoing: false,
          autoCancel: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          fullScreenIntent: true,
        ),
      );
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }
}
