import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionService {
  static final PermissionService _instance = PermissionService._();
  factory PermissionService() => _instance;
  PermissionService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get _context => navigatorKey.currentContext;

  Future<ph.PermissionStatus> requestLocationPermission() async {
    final status = await ph.Permission.location.request();
    if (status.isDenied && await ph.Permission.location.shouldShowRequestRationale) {
      await _showRationale(
        title: 'صلاحية الموقع',
        message: 'يحتاج التطبيق إلى الوصول إلى موقعك لعرض المتاجر القريبة وتحديد عنوان التوصيل.',
      );
    }
    if (status.isPermanentlyDenied) {
      await _showSettingsRedirect(
        title: 'صلاحية الموقع',
        message: 'يرجى تفعيل صلاحية الموقع من الإعدادات.',
      );
    }
    return status;
  }

  Future<ph.PermissionStatus> requestNotificationPermission() async {
    final status = await ph.Permission.notification.request();
    if (status.isDenied && await ph.Permission.notification.shouldShowRequestRationale) {
      await _showRationale(
        title: 'الإشعارات',
        message: 'يحتاج التطبيق إلى إرسال إشعارات لتحديثك بحالة طلباتك.',
      );
    }
    if (status.isPermanentlyDenied) {
      await _showSettingsRedirect(
        title: 'الإشعارات',
        message: 'يرجى تفعيل صلاحية الإشعارات من الإعدادات.',
      );
    }
    return status;
  }

  Future<ph.PermissionStatus> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    if (status.isDenied && await ph.Permission.camera.shouldShowRequestRationale) {
      await _showRationale(
        title: 'الكاميرا',
        message: 'يحتاج التطبيق إلى الكاميرا لمسح رموز QR الخاصة بالطلبات.',
      );
    }
    if (status.isPermanentlyDenied) {
      await _showSettingsRedirect(
        title: 'الكاميرا',
        message: 'يرجى تفعيل صلاحية الكاميرا من الإعدادات.',
      );
    }
    return status;
  }

  Future<ph.PermissionStatus> requestBackgroundLocationPermission() async {
    final status = await ph.Permission.locationAlways.request();
    if (status.isDenied && await ph.Permission.locationAlways.shouldShowRequestRationale) {
      await _showRationale(
        title: 'الموقع في الخلفية',
        message: 'يحتاج التطبيق إلى الوصول إلى موقعك في الخلفية لتتبع طلباتك أثناء التوصيل.',
      );
    }
    if (status.isPermanentlyDenied) {
      await _showSettingsRedirect(
        title: 'الموقع في الخلفية',
        message: 'يرجى تفعيل صلاحية الموقع في الخلفية من الإعدادات.',
      );
    }
    return status;
  }

  Future<bool> isLocationGranted() async => await ph.Permission.location.isGranted;
  Future<bool> isNotificationGranted() async => await ph.Permission.notification.isGranted;
  Future<bool> isCameraGranted() async => await ph.Permission.camera.isGranted;

  Future<void> openSettings() async => await ph.openAppSettings();

  Future<void> _showRationale({required String title, required String message}) async {
    final ctx = _context;
    if (ctx == null) return;
    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsRedirect({required String title, required String message}) async {
    final ctx = _context;
    if (ctx == null) return;
    final shouldOpen = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('الإعدادات'),
          ),
        ],
      ),
    );
    if (shouldOpen == true) await openSettings();
  }
}
