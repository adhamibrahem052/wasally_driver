import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings, linux: linuxSettings);
    await _plugin.initialize(settings);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'wasally_driver',
      'إشعارات السائق',
      channelDescription: 'إشعارات الطلبات والتوصيل',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  static Future<void> showOrderNotification({
    required int orderNum,
    required String orderDetails,
  }) async {
    await showNotification(
      id: orderNum,
      title: 'طلب جديد 🚚',
      body: 'لديك طلب جديد: $orderDetails',
    );
  }

  static Future<void> showStoreInvoiceNotification({
    required String storeName,
    required double amount,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'فاتورة متجر',
      body: 'فاتورة جديدة من $storeName بقيمة $amount ج.م',
    );
  }
}
